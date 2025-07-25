// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

pub use checked::*;

#[sui_macros::with_checked_arithmetic]
mod checked {
    use crate::{
        adapter::substitute_package_id,
        data_store::{PackageStore, legacy::sui_data_store::SuiDataStore},
        execution_mode::ExecutionMode,
        execution_value::{
            CommandKind, ExecutionState, ObjectContents, ObjectValue, RawValueType, Value,
            ensure_serialized_size,
        },
        gas_charger::GasCharger,
        programmable_transactions::{context::*, trace_utils},
        static_programmable_transactions,
        type_resolver::TypeTagResolver,
    };
    use move_binary_format::file_format::AbilitySet;
    use move_binary_format::{
        CompiledModule,
        compatibility::{Compatibility, InclusionCheck},
        errors::{Location, PartialVMResult, VMResult},
        file_format::{CodeOffset, FunctionDefinitionIndex, LocalIndex, Visibility},
        file_format_common::VERSION_6,
        normalized,
    };
    use move_core_types::{
        account_address::AccountAddress,
        identifier::{IdentStr, Identifier},
        language_storage::{ModuleId, StructTag, TypeTag},
        u256::U256,
    };
    use move_trace_format::format::MoveTraceBuilder;
    use move_vm_runtime::{
        move_vm::MoveVM,
        session::{LoadedFunctionInstantiation, SerializedReturnValues},
    };
    use move_vm_types::loaded_data::runtime_types::{CachedDatatype, Type};
    use serde::{Deserialize, de::DeserializeSeed};
    use std::{
        cell::{OnceCell, RefCell},
        collections::{BTreeMap, BTreeSet},
        fmt,
        rc::Rc,
        sync::Arc,
        time::Instant,
    };
    use sui_move_natives::object_runtime::ObjectRuntime;
    use sui_protocol_config::ProtocolConfig;
    use sui_types::{
        SUI_FRAMEWORK_ADDRESS,
        base_types::{
            MoveLegacyTxContext, MoveObjectType, ObjectID, RESOLVED_ASCII_STR, RESOLVED_STD_OPTION,
            RESOLVED_UTF8_STR, SuiAddress, TX_CONTEXT_MODULE_NAME, TX_CONTEXT_STRUCT_NAME,
            TxContext, TxContextKind,
        },
        coin::Coin,
        error::{ExecutionError, ExecutionErrorKind, command_argument_error},
        execution::{ExecutionTiming, ResultWithTimings},
        execution_config_utils::to_binary_config,
        execution_status::{CommandArgumentError, PackageUpgradeError, TypeArgumentError},
        id::RESOLVED_SUI_ID,
        metrics::LimitsMetrics,
        move_package::{
            MovePackage, UpgradeCap, UpgradePolicy, UpgradeReceipt, UpgradeTicket,
            normalize_deserialized_modules,
        },
        storage::{BackingPackageStore, PackageObject, get_package_objects},
        transaction::{Command, ProgrammableMoveCall, ProgrammableTransaction},
        transfer::RESOLVED_RECEIVING_STRUCT,
        type_input::{StructInput, TypeInput},
    };
    use sui_verifier::{
        INIT_FN_NAME,
        private_generics::{EVENT_MODULE, PRIVATE_TRANSFER_FUNCTIONS, TRANSFER_MODULE},
    };
    use tracing::instrument;

    pub fn execute<Mode: ExecutionMode>(
        protocol_config: &ProtocolConfig,
        metrics: Arc<LimitsMetrics>,
        vm: &MoveVM,
        state_view: &mut dyn ExecutionState,
        package_store: &dyn BackingPackageStore,
        tx_context: Rc<RefCell<TxContext>>,
        gas_charger: &mut GasCharger,
        pt: ProgrammableTransaction,
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> ResultWithTimings<Mode::ExecutionResults, ExecutionError> {
        if protocol_config.enable_ptb_execution_v2() {
            return static_programmable_transactions::execute::<Mode>(
                protocol_config,
                metrics,
                vm,
                state_view,
                package_store,
                tx_context,
                gas_charger,
                pt,
                trace_builder_opt,
            );
        }

        let mut timings = vec![];
        let result = execute_inner::<Mode>(
            &mut timings,
            protocol_config,
            metrics,
            vm,
            state_view,
            tx_context,
            gas_charger,
            pt,
            trace_builder_opt,
        );

        match result {
            Ok(result) => Ok((result, timings)),
            Err(e) => {
                trace_utils::trace_execution_error(trace_builder_opt, e.to_string());

                Err((e, timings))
            }
        }
    }

    pub fn execute_inner<Mode: ExecutionMode>(
        timings: &mut Vec<ExecutionTiming>,
        protocol_config: &ProtocolConfig,
        metrics: Arc<LimitsMetrics>,
        vm: &MoveVM,
        state_view: &mut dyn ExecutionState,
        tx_context: Rc<RefCell<TxContext>>,
        gas_charger: &mut GasCharger,
        pt: ProgrammableTransaction,
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> Result<Mode::ExecutionResults, ExecutionError> {
        let ProgrammableTransaction { inputs, commands } = pt;
        let mut context = ExecutionContext::new(
            protocol_config,
            metrics,
            vm,
            state_view,
            tx_context,
            gas_charger,
            inputs,
        )?;

        trace_utils::trace_ptb_summary::<Mode>(&mut context, trace_builder_opt, &commands)?;

        // execute commands
        let mut mode_results = Mode::empty_results();
        for (idx, command) in commands.into_iter().enumerate() {
            let start = Instant::now();
            if let Err(err) =
                execute_command::<Mode>(&mut context, &mut mode_results, command, trace_builder_opt)
            {
                let object_runtime: &ObjectRuntime = context.object_runtime()?;
                // We still need to record the loaded child objects for replay
                let loaded_runtime_objects = object_runtime.loaded_runtime_objects();
                // we do not save the wrapped objects since on error, they should not be modified
                drop(context);
                state_view.save_loaded_runtime_objects(loaded_runtime_objects);
                timings.push(ExecutionTiming::Abort(start.elapsed()));
                return Err(err.with_command_index(idx));
            };
            timings.push(ExecutionTiming::Success(start.elapsed()));
        }

        // Save loaded objects table in case we fail in post execution
        let object_runtime: &ObjectRuntime = context.object_runtime()?;
        // We still need to record the loaded child objects for replay
        // Record the objects loaded at runtime (dynamic fields + received) for
        // storage rebate calculation.
        let loaded_runtime_objects = object_runtime.loaded_runtime_objects();
        // We record what objects were contained in at the start of the transaction
        // for expensive invariant checks
        let wrapped_object_containers = object_runtime.wrapped_object_containers();

        // apply changes
        let finished = context.finish::<Mode>();
        // Save loaded objects for debug. We dont want to lose the info
        state_view.save_loaded_runtime_objects(loaded_runtime_objects);
        state_view.save_wrapped_object_containers(wrapped_object_containers);
        state_view.record_execution_results(finished?);
        Ok(mode_results)
    }

    /// Execute a single command
    #[instrument(level = "trace", skip_all)]
    fn execute_command<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        mode_results: &mut Mode::ExecutionResults,
        command: Command,
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> Result<(), ExecutionError> {
        let mut argument_updates = Mode::empty_arguments();
        let results = match command {
            Command::MakeMoveVec(tag_opt, args) if args.is_empty() => {
                let Some(tag) = tag_opt else {
                    invariant_violation!(
                        "input checker ensures if args are empty, there is a type specified"
                    );
                };

                let tag = to_type_tag(context, tag, 0)?;

                let elem_ty = context.load_type(&tag).map_err(|e| {
                    if context.protocol_config.convert_type_argument_error() {
                        context.convert_type_argument_error(0, e)
                    } else {
                        context.convert_vm_error(e)
                    }
                })?;

                let ty = Type::Vector(Box::new(elem_ty));
                let abilities = context.get_type_abilities(&ty)?;
                // BCS layout for any empty vector should be the same
                let bytes = bcs::to_bytes::<Vec<u8>>(&vec![]).unwrap();

                trace_utils::trace_make_move_vec(context, trace_builder_opt, vec![], &ty)?;

                vec![Value::Raw(
                    RawValueType::Loaded {
                        ty,
                        abilities,
                        used_in_non_entry_move_call: false,
                    },
                    bytes,
                )]
            }
            Command::MakeMoveVec(tag_opt, args) => {
                let args = context.splat_args(0, args)?;
                let elem_abilities = OnceCell::<AbilitySet>::new();
                let mut res = vec![];
                leb128::write::unsigned(&mut res, args.len() as u64).unwrap();
                let mut arg_iter = args.into_iter().enumerate();
                let mut move_values = vec![];
                let (mut used_in_non_entry_move_call, elem_ty) = match tag_opt {
                    Some(tag) => {
                        let tag = to_type_tag(context, tag, 0)?;
                        let elem_ty = context.load_type(&tag).map_err(|e| {
                            if context.protocol_config.convert_type_argument_error() {
                                context.convert_type_argument_error(0, e)
                            } else {
                                context.convert_vm_error(e)
                            }
                        })?;
                        (false, elem_ty)
                    }
                    // If no tag specified, it _must_ be an object
                    None => {
                        // empty args covered above
                        let (idx, arg) = arg_iter.next().unwrap();
                        let obj: ObjectValue =
                            context.by_value_arg(CommandKind::MakeMoveVec, idx, arg)?;
                        trace_utils::add_move_value_info_from_obj_value(
                            context,
                            trace_builder_opt,
                            &mut move_values,
                            &obj,
                        )?;
                        let bound =
                            amplification_bound::<Mode>(context, &obj.type_, &elem_abilities)?;
                        obj.write_bcs_bytes(
                            &mut res,
                            bound.map(|b| context.size_bound_vector_elem(b)),
                        )?;
                        (obj.used_in_non_entry_move_call, obj.type_)
                    }
                };
                for (idx, arg) in arg_iter {
                    let value: Value = context.by_value_arg(CommandKind::MakeMoveVec, idx, arg)?;
                    trace_utils::add_move_value_info_from_value(
                        context,
                        trace_builder_opt,
                        &mut move_values,
                        &elem_ty,
                        &value,
                    )?;
                    check_param_type::<Mode>(context, idx, &value, &elem_ty)?;
                    used_in_non_entry_move_call =
                        used_in_non_entry_move_call || value.was_used_in_non_entry_move_call();
                    let bound = amplification_bound::<Mode>(context, &elem_ty, &elem_abilities)?;
                    value.write_bcs_bytes(
                        &mut res,
                        bound.map(|b| context.size_bound_vector_elem(b)),
                    )?;
                }
                let ty = Type::Vector(Box::new(elem_ty));
                let abilities = context.get_type_abilities(&ty)?;

                trace_utils::trace_make_move_vec(context, trace_builder_opt, move_values, &ty)?;

                vec![Value::Raw(
                    RawValueType::Loaded {
                        ty,
                        abilities,
                        used_in_non_entry_move_call,
                    },
                    res,
                )]
            }
            Command::TransferObjects(objs, addr_arg) => {
                let unsplat_objs_len = objs.len();
                let objs = context.splat_args(0, objs)?;
                let addr_arg = context.one_arg(unsplat_objs_len, addr_arg)?;
                let objs: Vec<ObjectValue> = objs
                    .into_iter()
                    .enumerate()
                    .map(|(idx, arg)| context.by_value_arg(CommandKind::TransferObjects, idx, arg))
                    .collect::<Result<_, _>>()?;
                let addr: SuiAddress =
                    context.by_value_arg(CommandKind::TransferObjects, objs.len(), addr_arg)?;

                trace_utils::trace_transfer(context, trace_builder_opt, &objs)?;

                for obj in objs {
                    obj.ensure_public_transfer_eligible()?;
                    context.transfer_object(obj, addr)?;
                }
                vec![]
            }
            Command::SplitCoins(coin_arg, amount_args) => {
                let coin_arg = context.one_arg(0, coin_arg)?;
                let amount_args = context.splat_args(1, amount_args)?;
                let mut obj: ObjectValue = context.borrow_arg_mut(0, coin_arg)?;
                let ObjectContents::Coin(coin) = &mut obj.contents else {
                    let e = ExecutionErrorKind::command_argument_error(
                        CommandArgumentError::TypeMismatch,
                        0,
                    );
                    let msg = "Expected a coin but got an non coin object".to_owned();
                    return Err(ExecutionError::new_with_source(e, msg));
                };
                let split_coins: Vec<Value> = amount_args
                    .into_iter()
                    .map(|amount_arg| {
                        let amount: u64 =
                            context.by_value_arg(CommandKind::SplitCoins, 1, amount_arg)?;
                        let new_coin_id = context.fresh_id()?;
                        let new_coin = coin.split(amount, new_coin_id)?;
                        let coin_type = obj.type_.clone();
                        // safe because we are propagating the coin type, and relying on the internal
                        // invariant that coin values have a coin type
                        let new_coin = unsafe { ObjectValue::coin(coin_type, new_coin) };
                        Ok(Value::Object(new_coin))
                    })
                    .collect::<Result<_, ExecutionError>>()?;

                trace_utils::trace_split_coins(
                    context,
                    trace_builder_opt,
                    &obj.type_,
                    coin,
                    &split_coins,
                )?;

                context.restore_arg::<Mode>(&mut argument_updates, coin_arg, Value::Object(obj))?;
                split_coins
            }
            Command::MergeCoins(target_arg, coin_args) => {
                let target_arg = context.one_arg(0, target_arg)?;
                let coin_args = context.splat_args(1, coin_args)?;
                let mut target: ObjectValue = context.borrow_arg_mut(0, target_arg)?;
                let ObjectContents::Coin(target_coin) = &mut target.contents else {
                    let e = ExecutionErrorKind::command_argument_error(
                        CommandArgumentError::TypeMismatch,
                        0,
                    );
                    let msg = "Expected a coin but got an non coin object".to_owned();
                    return Err(ExecutionError::new_with_source(e, msg));
                };
                let coins: Vec<ObjectValue> = coin_args
                    .into_iter()
                    .enumerate()
                    .map(|(idx, arg)| context.by_value_arg(CommandKind::MergeCoins, idx + 1, arg))
                    .collect::<Result<_, _>>()?;
                let mut input_infos = vec![];
                for (idx, coin) in coins.into_iter().enumerate() {
                    if target.type_ != coin.type_ {
                        let e = ExecutionErrorKind::command_argument_error(
                            CommandArgumentError::TypeMismatch,
                            (idx + 1) as u16,
                        );
                        let msg = "Coins do not have the same type".to_owned();
                        return Err(ExecutionError::new_with_source(e, msg));
                    }
                    let ObjectContents::Coin(Coin { id, balance }) = coin.contents else {
                        invariant_violation!(
                            "Target coin was a coin, and we already checked for the same type. \
                            This should be a coin"
                        );
                    };
                    trace_utils::add_coin_obj_info(
                        trace_builder_opt,
                        &mut input_infos,
                        balance.value(),
                        *id.object_id(),
                    );
                    context.delete_id(*id.object_id())?;
                    target_coin.add(balance)?;
                }

                trace_utils::trace_merge_coins(
                    context,
                    trace_builder_opt,
                    &target.type_,
                    &input_infos,
                    target_coin,
                )?;

                context.restore_arg::<Mode>(
                    &mut argument_updates,
                    target_arg,
                    Value::Object(target),
                )?;
                vec![]
            }
            Command::MoveCall(move_call) => {
                let ProgrammableMoveCall {
                    package,
                    module,
                    function,
                    type_arguments,
                    arguments,
                } = *move_call;
                trace_utils::trace_move_call_start(trace_builder_opt);

                let arguments = context.splat_args(0, arguments)?;

                let module = to_identifier(context, module)?;
                let function = to_identifier(context, function)?;

                // Convert type arguments to `Type`s
                let mut loaded_type_arguments = Vec::with_capacity(type_arguments.len());
                for (ix, type_arg) in type_arguments.into_iter().enumerate() {
                    let type_arg = to_type_tag(context, type_arg, ix)?;
                    let ty = context
                        .load_type(&type_arg)
                        .map_err(|e| context.convert_type_argument_error(ix, e))?;
                    loaded_type_arguments.push(ty);
                }

                let original_address = context.set_link_context(package)?;
                let storage_id = ModuleId::new(*package, module.clone());
                let runtime_id = ModuleId::new(original_address, module);
                let return_values = execute_move_call::<Mode>(
                    context,
                    &mut argument_updates,
                    &storage_id,
                    &runtime_id,
                    &function,
                    loaded_type_arguments,
                    arguments,
                    /* is_init */ false,
                    trace_builder_opt,
                );

                trace_utils::trace_move_call_end(trace_builder_opt);

                context.linkage_view.reset_linkage()?;
                return_values?
            }
            Command::Publish(modules, dep_ids) => {
                trace_utils::trace_publish_event(trace_builder_opt)?;

                execute_move_publish::<Mode>(
                    context,
                    &mut argument_updates,
                    modules,
                    dep_ids,
                    trace_builder_opt,
                )?
            }
            Command::Upgrade(modules, dep_ids, current_package_id, upgrade_ticket) => {
                trace_utils::trace_upgrade_event(trace_builder_opt)?;

                let upgrade_ticket = context.one_arg(0, upgrade_ticket)?;
                execute_move_upgrade::<Mode>(
                    context,
                    modules,
                    dep_ids,
                    current_package_id,
                    upgrade_ticket,
                )?
            }
        };

        Mode::finish_command(context, mode_results, argument_updates, &results)?;
        context.push_command_results(results)?;
        Ok(())
    }

    /// Execute a single Move call
    fn execute_move_call<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        argument_updates: &mut Mode::ArgumentUpdates,
        storage_id: &ModuleId,
        runtime_id: &ModuleId,
        function: &IdentStr,
        type_arguments: Vec<Type>,
        arguments: Vec<Arg>,
        is_init: bool,
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> Result<Vec<Value>, ExecutionError> {
        // check that the function is either an entry function or a valid public function
        let LoadedFunctionInfo {
            kind,
            signature,
            return_value_kinds,
            index,
            last_instr,
        } = check_visibility_and_signature::<Mode>(
            context,
            runtime_id,
            function,
            &type_arguments,
            is_init,
        )?;
        // build the arguments, storing meta data about by-mut-ref args
        let (tx_context_kind, by_mut_ref, serialized_arguments) =
            build_move_args::<Mode>(context, runtime_id, function, kind, &signature, &arguments)?;
        // invoke the VM
        let SerializedReturnValues {
            mutable_reference_outputs,
            return_values,
        } = vm_move_call(
            context,
            runtime_id,
            function,
            type_arguments,
            tx_context_kind,
            serialized_arguments,
            trace_builder_opt,
        )?;
        assert_invariant!(
            by_mut_ref.len() == mutable_reference_outputs.len(),
            "lost mutable input"
        );

        if context.protocol_config.relocate_event_module() {
            context.take_user_events(storage_id, index, last_instr)?;
        } else {
            context.take_user_events(runtime_id, index, last_instr)?;
        }

        // save the link context because calls to `make_value` below can set new ones, and we don't want
        // it to be clobbered.
        let saved_linkage = context.linkage_view.steal_linkage();
        // write back mutable inputs. We also update if they were used in non entry Move calls
        // though we do not care for immutable usages of objects or other values
        let used_in_non_entry_move_call = kind == FunctionKind::NonEntry;
        let res = write_back_results::<Mode>(
            context,
            argument_updates,
            &arguments,
            used_in_non_entry_move_call,
            mutable_reference_outputs
                .into_iter()
                .map(|(i, bytes, _layout)| (i, bytes)),
            by_mut_ref,
            return_values.into_iter().map(|(bytes, _layout)| bytes),
            return_value_kinds,
        );

        context.linkage_view.restore_linkage(saved_linkage)?;
        res
    }

    fn write_back_results<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        argument_updates: &mut Mode::ArgumentUpdates,
        arguments: &[Arg],
        non_entry_move_call: bool,
        mut_ref_values: impl IntoIterator<Item = (u8, Vec<u8>)>,
        mut_ref_kinds: impl IntoIterator<Item = (u8, ValueKind)>,
        return_values: impl IntoIterator<Item = Vec<u8>>,
        return_value_kinds: impl IntoIterator<Item = ValueKind>,
    ) -> Result<Vec<Value>, ExecutionError> {
        for ((i, bytes), (j, kind)) in mut_ref_values.into_iter().zip(mut_ref_kinds) {
            assert_invariant!(i == j, "lost mutable input");
            let arg_idx = i as usize;
            let value = make_value(context, kind, bytes, non_entry_move_call)?;
            context.restore_arg::<Mode>(argument_updates, arguments[arg_idx], value)?;
        }

        return_values
            .into_iter()
            .zip(return_value_kinds)
            .map(|(bytes, kind)| {
                // only non entry functions have return values
                make_value(
                    context, kind, bytes, /* used_in_non_entry_move_call */ true,
                )
            })
            .collect()
    }

    fn make_value(
        context: &mut ExecutionContext<'_, '_, '_>,
        value_info: ValueKind,
        bytes: Vec<u8>,
        used_in_non_entry_move_call: bool,
    ) -> Result<Value, ExecutionError> {
        Ok(match value_info {
            ValueKind::Object {
                type_,
                has_public_transfer,
            } => Value::Object(context.make_object_value(
                type_,
                has_public_transfer,
                used_in_non_entry_move_call,
                &bytes,
            )?),
            ValueKind::Raw(ty, abilities) => Value::Raw(
                RawValueType::Loaded {
                    ty,
                    abilities,
                    used_in_non_entry_move_call,
                },
                bytes,
            ),
        })
    }

    /// Publish Move modules and call the init functions.  Returns an `UpgradeCap` for the newly
    /// published package on success.
    fn execute_move_publish<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        argument_updates: &mut Mode::ArgumentUpdates,
        module_bytes: Vec<Vec<u8>>,
        dep_ids: Vec<ObjectID>,
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> Result<Vec<Value>, ExecutionError> {
        assert_invariant!(
            !module_bytes.is_empty(),
            "empty package is checked in transaction input checker"
        );
        context
            .gas_charger
            .charge_publish_package(module_bytes.iter().map(|v| v.len()).sum())?;

        let mut modules = context.deserialize_modules(&module_bytes)?;

        // It should be fine that this does not go through ExecutionContext::fresh_id since the Move
        // runtime does not to know about new packages created, since Move objects and Move packages
        // cannot interact
        let runtime_id = if Mode::packages_are_predefined() {
            // do not calculate or substitute id for predefined packages
            (*modules[0].self_id().address()).into()
        } else {
            let id = context.tx_context.borrow_mut().fresh_id();
            substitute_package_id(&mut modules, id)?;
            id
        };

        // For newly published packages, runtime ID matches storage ID.
        let storage_id = runtime_id;
        let dependencies = fetch_packages(&context.state_view, &dep_ids)?;
        let package =
            context.new_package(&modules, dependencies.iter().map(|p| p.move_package()))?;

        // Here we optimistically push the package that is being published/upgraded
        // and if there is an error of any kind (verification or module init) we
        // remove it.
        // The call to `pop_last_package` later is fine because we cannot re-enter and
        // the last package we pushed is the one we are verifying and running the init from
        context.linkage_view.set_linkage(&package)?;
        context.write_package(package);
        let res = publish_and_verify_modules(context, runtime_id, &modules).and_then(|_| {
            init_modules::<Mode>(context, argument_updates, &modules, trace_builder_opt)
        });
        context.linkage_view.reset_linkage()?;
        if res.is_err() {
            context.pop_package();
        }
        res?;

        let values = if Mode::packages_are_predefined() {
            // no upgrade cap for genesis modules
            vec![]
        } else {
            let cap = &UpgradeCap::new(context.fresh_id()?, storage_id);
            vec![Value::Object(context.make_object_value(
                UpgradeCap::type_().into(),
                /* has_public_transfer */ true,
                /* used_in_non_entry_move_call */ false,
                &bcs::to_bytes(cap).unwrap(),
            )?)]
        };
        Ok(values)
    }

    /// Upgrade a Move package.  Returns an `UpgradeReceipt` for the upgraded package on success.
    fn execute_move_upgrade<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        module_bytes: Vec<Vec<u8>>,
        dep_ids: Vec<ObjectID>,
        current_package_id: ObjectID,
        upgrade_ticket_arg: Arg,
    ) -> Result<Vec<Value>, ExecutionError> {
        assert_invariant!(
            !module_bytes.is_empty(),
            "empty package is checked in transaction input checker"
        );
        context
            .gas_charger
            .charge_upgrade_package(module_bytes.iter().map(|v| v.len()).sum())?;

        let upgrade_ticket_type = context
            .load_type_from_struct(&UpgradeTicket::type_())
            .map_err(|e| context.convert_vm_error(e))?;
        let upgrade_receipt_type = context
            .load_type_from_struct(&UpgradeReceipt::type_())
            .map_err(|e| context.convert_vm_error(e))?;

        let upgrade_ticket: UpgradeTicket = {
            let mut ticket_bytes = Vec::new();
            let ticket_val: Value =
                context.by_value_arg(CommandKind::Upgrade, 0, upgrade_ticket_arg)?;
            check_param_type::<Mode>(context, 0, &ticket_val, &upgrade_ticket_type)?;
            let bound =
                amplification_bound::<Mode>(context, &upgrade_ticket_type, &OnceCell::new())?;
            ticket_val
                .write_bcs_bytes(&mut ticket_bytes, bound.map(|b| context.size_bound_raw(b)))?;
            bcs::from_bytes(&ticket_bytes).map_err(|_| {
                ExecutionError::from_kind(ExecutionErrorKind::CommandArgumentError {
                    arg_idx: 0,
                    kind: CommandArgumentError::InvalidBCSBytes,
                })
            })?
        };

        // Make sure the passed-in package ID matches the package ID in the `upgrade_ticket`.
        if current_package_id != upgrade_ticket.package.bytes {
            return Err(ExecutionError::from_kind(
                ExecutionErrorKind::PackageUpgradeError {
                    upgrade_error: PackageUpgradeError::PackageIDDoesNotMatch {
                        package_id: current_package_id,
                        ticket_id: upgrade_ticket.package.bytes,
                    },
                },
            ));
        }

        // Check digest.
        let hash_modules = true;
        let computed_digest =
            MovePackage::compute_digest_for_modules_and_deps(&module_bytes, &dep_ids, hash_modules)
                .to_vec();
        if computed_digest != upgrade_ticket.digest {
            return Err(ExecutionError::from_kind(
                ExecutionErrorKind::PackageUpgradeError {
                    upgrade_error: PackageUpgradeError::DigestDoesNotMatch {
                        digest: computed_digest,
                    },
                },
            ));
        }

        // Check that this package ID points to a package and get the package we're upgrading.
        let current_package = fetch_package(&context.state_view, &upgrade_ticket.package.bytes)?;

        let mut modules = context.deserialize_modules(&module_bytes)?;
        let runtime_id = current_package.move_package().original_package_id();
        substitute_package_id(&mut modules, runtime_id)?;

        // Upgraded packages share their predecessor's runtime ID but get a new storage ID.
        let storage_id = context.tx_context.borrow_mut().fresh_id();

        let dependencies = fetch_packages(&context.state_view, &dep_ids)?;
        let package = context.upgrade_package(
            storage_id,
            current_package.move_package(),
            &modules,
            dependencies.iter().map(|p| p.move_package()),
        )?;

        context.linkage_view.set_linkage(&package)?;
        let res = publish_and_verify_modules(context, runtime_id, &modules);
        context.linkage_view.reset_linkage()?;
        res?;

        check_compatibility(
            context.protocol_config,
            current_package.move_package(),
            &modules,
            upgrade_ticket.policy,
        )?;

        context.write_package(package);
        Ok(vec![Value::Raw(
            RawValueType::Loaded {
                ty: upgrade_receipt_type,
                abilities: AbilitySet::EMPTY,
                used_in_non_entry_move_call: false,
            },
            bcs::to_bytes(&UpgradeReceipt::new(upgrade_ticket, storage_id)).unwrap(),
        )])
    }

    pub fn check_compatibility(
        protocol_config: &ProtocolConfig,
        existing_package: &MovePackage,
        upgrading_modules: &[CompiledModule],
        policy: u8,
    ) -> Result<(), ExecutionError> {
        // Make sure this is a known upgrade policy.
        let Ok(policy) = UpgradePolicy::try_from(policy) else {
            return Err(ExecutionError::from_kind(
                ExecutionErrorKind::PackageUpgradeError {
                    upgrade_error: PackageUpgradeError::UnknownUpgradePolicy { policy },
                },
            ));
        };

        let pool = &mut normalized::RcPool::new();
        let binary_config = to_binary_config(protocol_config);
        let Ok(current_normalized) =
            existing_package.normalize(pool, &binary_config, /* include code */ true)
        else {
            invariant_violation!("Tried to normalize modules in existing package but failed")
        };

        let existing_modules_len = current_normalized.len();
        let upgrading_modules_len = upgrading_modules.len();
        let disallow_new_modules = protocol_config.disallow_new_modules_in_deps_only_packages()
            && policy as u8 == UpgradePolicy::DEP_ONLY;

        if disallow_new_modules && existing_modules_len != upgrading_modules_len {
            return Err(ExecutionError::new_with_source(
                ExecutionErrorKind::PackageUpgradeError {
                    upgrade_error: PackageUpgradeError::IncompatibleUpgrade,
                },
                format!(
                    "Existing package has {existing_modules_len} modules, but new package has \
                     {upgrading_modules_len}. Adding or removing a module to a deps only package is not allowed."
                ),
            ));
        }

        let mut new_normalized = normalize_deserialized_modules(
            pool,
            upgrading_modules.iter(),
            /* include code */ true,
        );
        for (name, cur_module) in current_normalized {
            let Some(new_module) = new_normalized.remove(&name) else {
                return Err(ExecutionError::new_with_source(
                    ExecutionErrorKind::PackageUpgradeError {
                        upgrade_error: PackageUpgradeError::IncompatibleUpgrade,
                    },
                    format!("Existing module {name} not found in next version of package"),
                ));
            };

            check_module_compatibility(&policy, &cur_module, &new_module)?;
        }

        // If we disallow new modules double check that there are no modules left in `new_normalized`.
        debug_assert!(!disallow_new_modules || new_normalized.is_empty());

        Ok(())
    }

    fn check_module_compatibility(
        policy: &UpgradePolicy,
        cur_module: &move_binary_format::compatibility::Module,
        new_module: &move_binary_format::compatibility::Module,
    ) -> Result<(), ExecutionError> {
        match policy {
            UpgradePolicy::Additive => InclusionCheck::Subset.check(cur_module, new_module),
            UpgradePolicy::DepOnly => InclusionCheck::Equal.check(cur_module, new_module),
            UpgradePolicy::Compatible => {
                let compatibility = Compatibility::upgrade_check();

                compatibility.check(cur_module, new_module)
            }
        }
        .map_err(|e| {
            ExecutionError::new_with_source(
                ExecutionErrorKind::PackageUpgradeError {
                    upgrade_error: PackageUpgradeError::IncompatibleUpgrade,
                },
                e,
            )
        })
    }

    pub fn fetch_package(
        state_view: &impl BackingPackageStore,
        package_id: &ObjectID,
    ) -> Result<PackageObject, ExecutionError> {
        let mut fetched_packages = fetch_packages(state_view, vec![package_id])?;
        assert_invariant!(
            fetched_packages.len() == 1,
            "Number of fetched packages must match the number of package object IDs if successful."
        );
        match fetched_packages.pop() {
            Some(pkg) => Ok(pkg),
            None => invariant_violation!(
                "We should always fetch a package for each object or return a dependency error."
            ),
        }
    }

    pub fn fetch_packages<'ctx, 'state>(
        state_view: &'state impl BackingPackageStore,
        package_ids: impl IntoIterator<Item = &'ctx ObjectID>,
    ) -> Result<Vec<PackageObject>, ExecutionError> {
        let package_ids: BTreeSet<_> = package_ids.into_iter().collect();
        match get_package_objects(state_view, package_ids) {
            Err(e) => Err(ExecutionError::new_with_source(
                ExecutionErrorKind::PublishUpgradeMissingDependency,
                e,
            )),
            Ok(Err(missing_deps)) => {
                let msg = format!(
                    "Missing dependencies: {}",
                    missing_deps
                        .into_iter()
                        .map(|dep| format!("{}", dep))
                        .collect::<Vec<_>>()
                        .join(", ")
                );
                Err(ExecutionError::new_with_source(
                    ExecutionErrorKind::PublishUpgradeMissingDependency,
                    msg,
                ))
            }
            Ok(Ok(pkgs)) => Ok(pkgs),
        }
    }

    /***************************************************************************************************
     * Move execution
     **************************************************************************************************/

    fn vm_move_call(
        context: &mut ExecutionContext<'_, '_, '_>,
        module_id: &ModuleId,
        function: &IdentStr,
        type_arguments: Vec<Type>,
        tx_context_kind: TxContextKind,
        mut serialized_arguments: Vec<Vec<u8>>,
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> Result<SerializedReturnValues, ExecutionError> {
        match tx_context_kind {
            TxContextKind::None => (),
            TxContextKind::Mutable | TxContextKind::Immutable => {
                serialized_arguments.push(context.tx_context.borrow().to_bcs_legacy_context());
            }
        }
        // script visibility checked manually for entry points
        let mut result = context
            .execute_function_bypass_visibility(
                module_id,
                function,
                type_arguments,
                serialized_arguments,
                trace_builder_opt,
            )
            .map_err(|e| context.convert_vm_error(e))?;

        // When this function is used during publishing, it
        // may be executed several times, with objects being
        // created in the Move VM in each Move call. In such
        // case, we need to update TxContext value so that it
        // reflects what happened each time we call into the
        // Move VM (e.g. to account for the number of created
        // objects).
        if tx_context_kind == TxContextKind::Mutable {
            let Some((_, ctx_bytes, _)) = result.mutable_reference_outputs.pop() else {
                invariant_violation!("Missing TxContext in reference outputs");
            };
            let updated_ctx: MoveLegacyTxContext = bcs::from_bytes(&ctx_bytes).map_err(|e| {
                ExecutionError::invariant_violation(format!(
                    "Unable to deserialize TxContext bytes. {e}"
                ))
            })?;
            context.tx_context.borrow_mut().update_state(updated_ctx)?;
        }
        Ok(result)
    }

    fn publish_and_verify_modules(
        context: &mut ExecutionContext<'_, '_, '_>,
        package_id: ObjectID,
        modules: &[CompiledModule],
    ) -> Result<(), ExecutionError> {
        // TODO(https://github.com/MystenLabs/sui/issues/69): avoid this redundant serialization by exposing VM API that allows us to run the linker directly on `Vec<CompiledModule>`
        let binary_version = context.protocol_config.move_binary_format_version();
        let new_module_bytes: Vec<_> = modules
            .iter()
            .map(|m| {
                let mut bytes = Vec::new();
                let version = if binary_version > VERSION_6 {
                    m.version
                } else {
                    VERSION_6
                };
                m.serialize_with_version(version, &mut bytes).unwrap();
                bytes
            })
            .collect();
        context
            .publish_module_bundle(new_module_bytes, AccountAddress::from(package_id))
            .map_err(|e| context.convert_vm_error(e))?;

        // run the Sui verifier
        for module in modules {
            // Run Sui bytecode verifier, which runs some additional checks that assume the Move
            // bytecode verifier has passed.
            sui_verifier::verifier::sui_verify_module_unmetered(
                module,
                &BTreeMap::new(),
                &context
                    .protocol_config
                    .verifier_config(/* signing_limits */ None),
            )?;
        }

        Ok(())
    }

    fn init_modules<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        argument_updates: &mut Mode::ArgumentUpdates,
        modules: &[CompiledModule],
        trace_builder_opt: &mut Option<MoveTraceBuilder>,
    ) -> Result<(), ExecutionError> {
        let modules_to_init = modules.iter().filter_map(|module| {
            for fdef in &module.function_defs {
                let fhandle = module.function_handle_at(fdef.function);
                let fname = module.identifier_at(fhandle.name);
                if fname == INIT_FN_NAME {
                    return Some(module.self_id());
                }
            }
            None
        });

        for module_id in modules_to_init {
            trace_utils::trace_move_call_start(trace_builder_opt);
            let return_values = execute_move_call::<Mode>(
                context,
                argument_updates,
                // `init` is currently only called on packages when they are published for the
                // first time, meaning their runtime and storage IDs match. If this were to change
                // for some reason, then we would need to perform relocation here.
                &module_id,
                &module_id,
                INIT_FN_NAME,
                vec![],
                vec![],
                /* is_init */ true,
                trace_builder_opt,
            )?;

            assert_invariant!(
                return_values.is_empty(),
                "init should not have return values"
            );

            trace_utils::trace_move_call_end(trace_builder_opt);
        }

        Ok(())
    }

    /***************************************************************************************************
     * Move signatures
     **************************************************************************************************/

    /// Helper marking what function we are invoking
    #[derive(PartialEq, Eq, Clone, Copy)]
    enum FunctionKind {
        PrivateEntry,
        PublicEntry,
        NonEntry,
        Init,
    }

    /// Used to remember type information about a type when resolving the signature
    enum ValueKind {
        Object {
            type_: MoveObjectType,
            has_public_transfer: bool,
        },
        Raw(Type, AbilitySet),
    }

    struct LoadedFunctionInfo {
        /// The kind of the function, e.g. public or private or init
        kind: FunctionKind,
        /// The signature information of the function
        signature: LoadedFunctionInstantiation,
        /// Object or type information for the return values
        return_value_kinds: Vec<ValueKind>,
        /// Definition index of the function
        index: FunctionDefinitionIndex,
        /// The length of the function used for setting error information, or 0 if native
        last_instr: CodeOffset,
    }

    /// Checks that the function to be called is either
    /// - an entry function
    /// - a public function that does not return references
    /// - module init (only internal usage)
    fn check_visibility_and_signature<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        module_id: &ModuleId,
        function: &IdentStr,
        type_arguments: &[Type],
        from_init: bool,
    ) -> Result<LoadedFunctionInfo, ExecutionError> {
        if from_init {
            let result = context.load_function(module_id, function, type_arguments);
            assert_invariant!(
                result.is_ok(),
                "The modules init should be able to be loaded"
            );
        }
        let no_new_packages = vec![];
        let data_store = SuiDataStore::new(&context.linkage_view, &no_new_packages);
        let module = context
            .vm
            .get_runtime()
            .load_module(module_id, &data_store)
            .map_err(|e| context.convert_vm_error(e))?;
        let Some((index, fdef)) = module
            .function_defs
            .iter()
            .enumerate()
            .find(|(_index, fdef)| {
                module.identifier_at(module.function_handle_at(fdef.function).name) == function
            })
        else {
            return Err(ExecutionError::new_with_source(
                ExecutionErrorKind::FunctionNotFound,
                format!(
                    "Could not resolve function '{}' in module {}",
                    function, &module_id,
                ),
            ));
        };

        // entry on init is now banned, so ban invoking it
        if !from_init && function == INIT_FN_NAME && context.protocol_config.ban_entry_init() {
            return Err(ExecutionError::new_with_source(
                ExecutionErrorKind::NonEntryFunctionInvoked,
                "Cannot call 'init'",
            ));
        }

        let last_instr: CodeOffset = fdef
            .code
            .as_ref()
            .map(|code| code.code.len() - 1)
            .unwrap_or(0) as CodeOffset;
        let function_kind = match (fdef.visibility, fdef.is_entry) {
            (Visibility::Private | Visibility::Friend, true) => FunctionKind::PrivateEntry,
            (Visibility::Public, true) => FunctionKind::PublicEntry,
            (Visibility::Public, false) => FunctionKind::NonEntry,
            (Visibility::Private, false) if from_init => {
                assert_invariant!(
                    function == INIT_FN_NAME,
                    "module init specified non-init function"
                );
                FunctionKind::Init
            }
            (Visibility::Private | Visibility::Friend, false)
                if Mode::allow_arbitrary_function_calls() =>
            {
                FunctionKind::NonEntry
            }
            (Visibility::Private | Visibility::Friend, false) => {
                return Err(ExecutionError::new_with_source(
                    ExecutionErrorKind::NonEntryFunctionInvoked,
                    "Can only call `entry` or `public` functions",
                ));
            }
        };
        let signature = context
            .load_function(module_id, function, type_arguments)
            .map_err(|e| context.convert_vm_error(e))?;
        let signature =
            subst_signature(signature, type_arguments).map_err(|e| context.convert_vm_error(e))?;
        let return_value_kinds = match function_kind {
            FunctionKind::Init => {
                assert_invariant!(
                    signature.return_.is_empty(),
                    "init functions must have no return values"
                );
                vec![]
            }
            FunctionKind::PrivateEntry | FunctionKind::PublicEntry | FunctionKind::NonEntry => {
                check_non_entry_signature::<Mode>(context, module_id, function, &signature)?
            }
        };
        check_private_generics(module_id, function)?;
        Ok(LoadedFunctionInfo {
            kind: function_kind,
            signature,
            return_value_kinds,
            index: FunctionDefinitionIndex(index as u16),
            last_instr,
        })
    }

    /// substitutes the type arguments into the parameter and return types
    pub fn subst_signature(
        signature: LoadedFunctionInstantiation,
        type_arguments: &[Type],
    ) -> VMResult<LoadedFunctionInstantiation> {
        let LoadedFunctionInstantiation {
            parameters,
            return_,
            instruction_length,
            definition_index,
        } = signature;
        let parameters = parameters
            .into_iter()
            .map(|ty| ty.subst(type_arguments))
            .collect::<PartialVMResult<Vec<_>>>()
            .map_err(|err| err.finish(Location::Undefined))?;
        let return_ = return_
            .into_iter()
            .map(|ty| ty.subst(type_arguments))
            .collect::<PartialVMResult<Vec<_>>>()
            .map_err(|err| err.finish(Location::Undefined))?;
        Ok(LoadedFunctionInstantiation {
            parameters,
            return_,
            instruction_length,
            definition_index,
        })
    }

    /// Checks that the non-entry function does not return references. And marks the return values
    /// as object or non-object return values
    fn check_non_entry_signature<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        _module_id: &ModuleId,
        _function: &IdentStr,
        signature: &LoadedFunctionInstantiation,
    ) -> Result<Vec<ValueKind>, ExecutionError> {
        signature
            .return_
            .iter()
            .enumerate()
            .map(|(idx, return_type)| {
                let return_type = match return_type {
                    // for dev-inspect, just dereference the value
                    Type::Reference(inner) | Type::MutableReference(inner)
                        if Mode::allow_arbitrary_values() =>
                    {
                        inner
                    }
                    Type::Reference(_) | Type::MutableReference(_) => {
                        return Err(ExecutionError::from_kind(
                            ExecutionErrorKind::InvalidPublicFunctionReturnType { idx: idx as u16 },
                        ));
                    }
                    t => t,
                };
                let abilities = context.get_type_abilities(return_type)?;
                Ok(match return_type {
                    Type::MutableReference(_) | Type::Reference(_) => unreachable!(),
                    Type::TyParam(_) => {
                        invariant_violation!("TyParam should have been substituted")
                    }
                    Type::Datatype(_) | Type::DatatypeInstantiation(_) if abilities.has_key() => {
                        let type_tag = context
                            .vm
                            .get_runtime()
                            .get_type_tag(return_type)
                            .map_err(|e| context.convert_vm_error(e))?;
                        let TypeTag::Struct(struct_tag) = type_tag else {
                            invariant_violation!("Struct type make a non struct type tag")
                        };
                        ValueKind::Object {
                            type_: MoveObjectType::from(*struct_tag),
                            has_public_transfer: abilities.has_store(),
                        }
                    }
                    Type::Datatype(_)
                    | Type::DatatypeInstantiation(_)
                    | Type::Bool
                    | Type::U8
                    | Type::U64
                    | Type::U128
                    | Type::Address
                    | Type::Signer
                    | Type::Vector(_)
                    | Type::U16
                    | Type::U32
                    | Type::U256 => ValueKind::Raw(return_type.clone(), abilities),
                })
            })
            .collect()
    }

    pub fn check_private_generics(
        module_id: &ModuleId,
        function: &IdentStr,
    ) -> Result<(), ExecutionError> {
        let module_ident = (module_id.address(), module_id.name());
        if module_ident == (&SUI_FRAMEWORK_ADDRESS, EVENT_MODULE) {
            return Err(ExecutionError::new_with_source(
                ExecutionErrorKind::NonEntryFunctionInvoked,
                format!("Cannot directly call functions in sui::{}", EVENT_MODULE),
            ));
        }

        if module_ident == (&SUI_FRAMEWORK_ADDRESS, TRANSFER_MODULE)
            && PRIVATE_TRANSFER_FUNCTIONS.contains(&function)
        {
            let msg = format!(
                "Cannot directly call sui::{m}::{f}. \
                Use the public variant instead, sui::{m}::public_{f}",
                m = TRANSFER_MODULE,
                f = function
            );
            return Err(ExecutionError::new_with_source(
                ExecutionErrorKind::NonEntryFunctionInvoked,
                msg,
            ));
        }

        Ok(())
    }

    type ArgInfo = (
        TxContextKind,
        /* mut ref */
        Vec<(LocalIndex, ValueKind)>,
        Vec<Vec<u8>>,
    );

    /// Serializes the arguments into BCS values for Move. Performs the necessary type checking for
    /// each value
    fn build_move_args<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        module_id: &ModuleId,
        function: &IdentStr,
        function_kind: FunctionKind,
        signature: &LoadedFunctionInstantiation,
        args: &[Arg],
    ) -> Result<ArgInfo, ExecutionError> {
        // check the arity
        let parameters = &signature.parameters;
        let tx_ctx_kind = match parameters.last() {
            Some(t) => is_tx_context(context, t)?,
            None => TxContextKind::None,
        };
        // an init function can have one or two arguments, with the last one always being of type
        // &mut TxContext and the additional (first) one representing a one time witness type (see
        // one_time_witness verifier pass for additional explanation)
        let has_one_time_witness = function_kind == FunctionKind::Init && parameters.len() == 2;
        let has_tx_context = tx_ctx_kind != TxContextKind::None;
        let num_args = args.len() + (has_one_time_witness as usize) + (has_tx_context as usize);
        if num_args != parameters.len() {
            return Err(ExecutionError::new_with_source(
                ExecutionErrorKind::ArityMismatch,
                format!(
                    "Expected {:?} argument{} calling function '{}', but found {:?}",
                    parameters.len(),
                    if parameters.len() == 1 { "" } else { "s" },
                    function,
                    num_args
                ),
            ));
        }

        // check the types and remember which are by mutable ref
        let mut by_mut_ref = vec![];
        let mut serialized_args = Vec::with_capacity(num_args);
        let command_kind = CommandKind::MoveCall {
            package: (*module_id.address()).into(),
            module: module_id.name(),
            function,
        };
        // an init function can have one or two arguments, with the last one always being of type
        // &mut TxContext and the additional (first) one representing a one time witness type (see
        // one_time_witness verifier pass for additional explanation)
        if has_one_time_witness {
            // one time witness type is a struct with a single bool filed which in bcs is encoded as
            // 0x01
            let bcs_true_value = bcs::to_bytes(&true).unwrap();
            serialized_args.push(bcs_true_value)
        }
        for ((idx, arg), param_ty) in args.iter().copied().enumerate().zip(parameters) {
            let (value, non_ref_param_ty): (Value, &Type) = match param_ty {
                Type::MutableReference(inner) => {
                    let value = context.borrow_arg_mut(idx, arg)?;
                    let object_info = if let Value::Object(ObjectValue {
                        type_,
                        has_public_transfer,
                        ..
                    }) = &value
                    {
                        let type_tag = context
                            .vm
                            .get_runtime()
                            .get_type_tag(type_)
                            .map_err(|e| context.convert_vm_error(e))?;
                        let TypeTag::Struct(struct_tag) = type_tag else {
                            invariant_violation!("Struct type make a non struct type tag")
                        };
                        let type_ = (*struct_tag).into();
                        ValueKind::Object {
                            type_,
                            has_public_transfer: *has_public_transfer,
                        }
                    } else {
                        let abilities = context.get_type_abilities(inner)?;
                        ValueKind::Raw((**inner).clone(), abilities)
                    };
                    by_mut_ref.push((idx as LocalIndex, object_info));
                    (value, inner)
                }
                Type::Reference(inner) => (context.borrow_arg(idx, arg, param_ty)?, inner),
                t => {
                    let value = context.by_value_arg(command_kind, idx, arg)?;
                    (value, t)
                }
            };
            if matches!(
                function_kind,
                FunctionKind::PrivateEntry | FunctionKind::Init
            ) && value.was_used_in_non_entry_move_call()
            {
                return Err(command_argument_error(
                    CommandArgumentError::InvalidArgumentToPrivateEntryFunction,
                    idx,
                ));
            }
            check_param_type::<Mode>(context, idx, &value, non_ref_param_ty)?;
            let bytes = {
                let mut v = vec![];
                value.write_bcs_bytes(&mut v, None)?;
                v
            };
            serialized_args.push(bytes);
        }
        Ok((tx_ctx_kind, by_mut_ref, serialized_args))
    }

    /// checks that the value is compatible with the specified type
    fn check_param_type<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        idx: usize,
        value: &Value,
        param_ty: &Type,
    ) -> Result<(), ExecutionError> {
        match value {
            // For dev-spect, allow any BCS bytes. This does mean internal invariants for types can
            // be violated (like for string or Option)
            Value::Raw(RawValueType::Any, bytes) if Mode::allow_arbitrary_values() => {
                if let Some(bound) = amplification_bound_::<Mode>(context, param_ty)? {
                    let bound = context.size_bound_raw(bound);
                    return ensure_serialized_size(bytes.len() as u64, bound);
                } else {
                    return Ok(());
                }
            }
            // Any means this was just some bytes passed in as an argument (as opposed to being
            // generated from a Move function). Meaning we only allow "primitive" values
            // and might need to run validation in addition to the BCS layout
            Value::Raw(RawValueType::Any, bytes) => {
                let Some(layout) = primitive_serialization_layout(context, param_ty)? else {
                    let msg = format!(
                        "Non-primitive argument at index {}. If it is an object, it must be \
                        populated by an object",
                        idx,
                    );
                    return Err(ExecutionError::new_with_source(
                        ExecutionErrorKind::command_argument_error(
                            CommandArgumentError::InvalidUsageOfPureArg,
                            idx as u16,
                        ),
                        msg,
                    ));
                };
                bcs_argument_validate(bytes, idx as u16, layout)?;
                return Ok(());
            }
            Value::Raw(RawValueType::Loaded { ty, abilities, .. }, _) => {
                assert_invariant!(
                    Mode::allow_arbitrary_values() || !abilities.has_key(),
                    "Raw value should never be an object"
                );
                if ty != param_ty {
                    return Err(command_argument_error(
                        CommandArgumentError::TypeMismatch,
                        idx,
                    ));
                }
            }
            Value::Object(obj) => {
                let ty = &obj.type_;
                if ty != param_ty {
                    return Err(command_argument_error(
                        CommandArgumentError::TypeMismatch,
                        idx,
                    ));
                }
            }
            Value::Receiving(_, _, assigned_type) => {
                // If the type has been fixed, make sure the types match up
                if let Some(assigned_type) = assigned_type {
                    if assigned_type != param_ty {
                        return Err(command_argument_error(
                            CommandArgumentError::TypeMismatch,
                            idx,
                        ));
                    }
                }

                // Now make sure the param type is a struct instantiation of the receiving struct
                let Type::DatatypeInstantiation(inst) = param_ty else {
                    return Err(command_argument_error(
                        CommandArgumentError::TypeMismatch,
                        idx,
                    ));
                };
                let (sidx, targs) = &**inst;
                let Some(s) = context.vm.get_runtime().get_type(*sidx) else {
                    invariant_violation!("sui::transfer::Receiving struct not found in session")
                };
                let resolved_struct = get_datatype_ident(&s);

                if resolved_struct != RESOLVED_RECEIVING_STRUCT || targs.len() != 1 {
                    return Err(command_argument_error(
                        CommandArgumentError::TypeMismatch,
                        idx,
                    ));
                }
            }
        }
        Ok(())
    }

    fn to_identifier(
        context: &mut ExecutionContext<'_, '_, '_>,
        ident: String,
    ) -> Result<Identifier, ExecutionError> {
        if context.protocol_config.validate_identifier_inputs() {
            Identifier::new(ident).map_err(|e| {
                ExecutionError::new_with_source(
                    ExecutionErrorKind::VMInvariantViolation,
                    e.to_string(),
                )
            })
        } else {
            // SAFETY: Preserving existing behaviour for identifier deserialization.
            Ok(unsafe { Identifier::new_unchecked(ident) })
        }
    }

    // Convert a type input which may refer to a type by multiple different IDs and convert it to a
    // TypeTag that only uses defining IDs.
    //
    // It's suboptimal to traverse the type, load, and then go back to a typetag to resolve to
    // defining IDs in the typetag, but it's the cleanest solution ATM without adding in additional
    // machinery. With the new linkage resolution that we will be adding this will
    // be much cleaner however, we'll hold off on adding that in here, and instead add it in the
    // new execution code.
    fn to_type_tag(
        context: &mut ExecutionContext<'_, '_, '_>,
        type_input: TypeInput,
        idx: usize,
    ) -> Result<TypeTag, ExecutionError> {
        let type_tag_no_def_ids = to_type_tag_(context, type_input, idx)?;
        if context
            .protocol_config
            .resolve_type_input_ids_to_defining_id()
        {
            let ix = if context
                .protocol_config
                .better_adapter_type_resolution_errors()
            {
                idx
            } else {
                0
            };

            let ty = context
                .load_type(&type_tag_no_def_ids)
                .map_err(|e| context.convert_type_argument_error(ix, e))?;
            context.get_type_tag(&ty)
        } else {
            Ok(type_tag_no_def_ids)
        }
    }

    fn to_type_tag_(
        context: &mut ExecutionContext<'_, '_, '_>,
        type_input: TypeInput,
        idx: usize,
    ) -> Result<TypeTag, ExecutionError> {
        use TypeInput as I;
        use TypeTag as T;
        Ok(match type_input {
            I::Bool => T::Bool,
            I::U8 => T::U8,
            I::U16 => T::U16,
            I::U32 => T::U32,
            I::U64 => T::U64,
            I::U128 => T::U128,
            I::U256 => T::U256,
            I::Address => T::Address,
            I::Signer => T::Signer,
            I::Vector(t) => T::Vector(Box::new(to_type_tag_(context, *t, idx)?)),
            I::Struct(s) => {
                let StructInput {
                    address,
                    module,
                    name,
                    type_params,
                } = *s;
                let type_params = type_params
                    .into_iter()
                    .map(|t| to_type_tag_(context, t, idx))
                    .collect::<Result<_, _>>()?;
                let (module, name) = resolve_datatype_names(context, address, module, name, idx)?;
                T::Struct(Box::new(StructTag {
                    address,
                    module,
                    name,
                    type_params,
                }))
            }
        })
    }

    fn resolve_datatype_names(
        context: &ExecutionContext<'_, '_, '_>,
        addr: AccountAddress,
        module: String,
        name: String,
        idx: usize,
    ) -> Result<(Identifier, Identifier), ExecutionError> {
        let validate_identifiers = context.protocol_config.validate_identifier_inputs();
        let better_resolution_errors = context
            .protocol_config
            .better_adapter_type_resolution_errors();

        let to_ident = |s| {
            if validate_identifiers {
                Identifier::new(s).map_err(|e| {
                    ExecutionError::new_with_source(
                        ExecutionErrorKind::VMInvariantViolation,
                        e.to_string(),
                    )
                })
            } else {
                // SAFETY: Preserving existing behaviour for identifier deserialization within type
                // tags and inputs.
                unsafe { Ok(Identifier::new_unchecked(s)) }
            }
        };

        let module_ident = to_ident(module.clone())?;
        let name_ident = to_ident(name.clone())?;

        if better_resolution_errors
            && context
                .linkage_view
                .get_package(&addr.into())
                .ok()
                .flatten()
                .is_none_or(|pkg| !pkg.type_origin_map().contains_key(&(module, name)))
        {
            return Err(ExecutionError::from_kind(
                ExecutionErrorKind::TypeArgumentError {
                    argument_idx: idx as u16,
                    kind: TypeArgumentError::TypeNotFound,
                },
            ));
        }

        Ok((module_ident, name_ident))
    }

    fn get_datatype_ident(s: &CachedDatatype) -> (&AccountAddress, &IdentStr, &IdentStr) {
        let module_id = &s.defining_id;
        let struct_name = &s.name;
        (
            module_id.address(),
            module_id.name(),
            struct_name.as_ident_str(),
        )
    }

    // Returns Some(kind) if the type is a reference to the TxnContext. kind being Mutable with
    // a MutableReference, and Immutable otherwise.
    // Returns None for all other types
    pub fn is_tx_context(
        context: &mut ExecutionContext<'_, '_, '_>,
        t: &Type,
    ) -> Result<TxContextKind, ExecutionError> {
        let (is_mut, inner) = match t {
            Type::MutableReference(inner) => (true, inner),
            Type::Reference(inner) => (false, inner),
            _ => return Ok(TxContextKind::None),
        };
        let Type::Datatype(idx) = &**inner else {
            return Ok(TxContextKind::None);
        };
        let Some(s) = context.vm.get_runtime().get_type(*idx) else {
            invariant_violation!("Loaded struct not found")
        };
        let (module_addr, module_name, struct_name) = get_datatype_ident(&s);
        let is_tx_context_type = module_addr == &SUI_FRAMEWORK_ADDRESS
            && module_name == TX_CONTEXT_MODULE_NAME
            && struct_name == TX_CONTEXT_STRUCT_NAME;
        Ok(if is_tx_context_type {
            if is_mut {
                TxContextKind::Mutable
            } else {
                TxContextKind::Immutable
            }
        } else {
            TxContextKind::None
        })
    }

    /// Returns Some(layout) iff it is a primitive, an ID, a String, or an option/vector of a valid type
    fn primitive_serialization_layout(
        context: &mut ExecutionContext<'_, '_, '_>,
        param_ty: &Type,
    ) -> Result<Option<PrimitiveArgumentLayout>, ExecutionError> {
        Ok(match param_ty {
            Type::Signer => return Ok(None),
            Type::Reference(_) | Type::MutableReference(_) | Type::TyParam(_) => {
                invariant_violation!("references and type parameters should be checked elsewhere")
            }
            Type::Bool => Some(PrimitiveArgumentLayout::Bool),
            Type::U8 => Some(PrimitiveArgumentLayout::U8),
            Type::U16 => Some(PrimitiveArgumentLayout::U16),
            Type::U32 => Some(PrimitiveArgumentLayout::U32),
            Type::U64 => Some(PrimitiveArgumentLayout::U64),
            Type::U128 => Some(PrimitiveArgumentLayout::U128),
            Type::U256 => Some(PrimitiveArgumentLayout::U256),
            Type::Address => Some(PrimitiveArgumentLayout::Address),

            Type::Vector(inner) => {
                let info_opt = primitive_serialization_layout(context, inner)?;
                info_opt.map(|layout| PrimitiveArgumentLayout::Vector(Box::new(layout)))
            }
            Type::DatatypeInstantiation(inst) => {
                let (idx, targs) = &**inst;
                let Some(s) = context.vm.get_runtime().get_type(*idx) else {
                    invariant_violation!("Loaded struct not found")
                };
                let resolved_struct = get_datatype_ident(&s);
                // is option of a string
                if resolved_struct == RESOLVED_STD_OPTION && targs.len() == 1 {
                    let info_opt = primitive_serialization_layout(context, &targs[0])?;
                    info_opt.map(|layout| PrimitiveArgumentLayout::Option(Box::new(layout)))
                } else {
                    None
                }
            }
            Type::Datatype(idx) => {
                let Some(s) = context.vm.get_runtime().get_type(*idx) else {
                    invariant_violation!("Loaded struct not found")
                };
                let resolved_struct = get_datatype_ident(&s);
                if resolved_struct == RESOLVED_SUI_ID {
                    Some(PrimitiveArgumentLayout::Address)
                } else if resolved_struct == RESOLVED_ASCII_STR {
                    Some(PrimitiveArgumentLayout::Ascii)
                } else if resolved_struct == RESOLVED_UTF8_STR {
                    Some(PrimitiveArgumentLayout::UTF8)
                } else {
                    None
                }
            }
        })
    }

    // We use a `OnceCell` for two reasons. One to cache the ability set for the type so that it
    // is not recomputed for each element of the vector. And two, to avoid computing the abilities
    // in the case where `max_ptb_value_size_v2` is false--this removes any case of diverging
    // based on the result of `get_type_abilities`.
    fn amplification_bound<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        param_ty: &Type,
        abilities: &OnceCell<AbilitySet>,
    ) -> Result<Option<u64>, ExecutionError> {
        if context.protocol_config.max_ptb_value_size_v2() {
            if abilities.get().is_none() {
                abilities
                    .set(context.get_type_abilities(param_ty)?)
                    .unwrap();
            }
            if !abilities.get().unwrap().has_copy() {
                return Ok(None);
            }
        }
        amplification_bound_::<Mode>(context, param_ty)
    }

    fn amplification_bound_<Mode: ExecutionMode>(
        context: &mut ExecutionContext<'_, '_, '_>,
        param_ty: &Type,
    ) -> Result<Option<u64>, ExecutionError> {
        // Do not cap size for epoch change/genesis
        if Mode::packages_are_predefined() {
            return Ok(None);
        }

        let Some(bound) = context.protocol_config.max_ptb_value_size_as_option() else {
            return Ok(None);
        };

        fn amplification(prim_layout: &PrimitiveArgumentLayout) -> Result<u64, ExecutionError> {
            use PrimitiveArgumentLayout as PAL;
            Ok(match prim_layout {
                PAL::Option(inner_layout) => 1u64 + amplification(inner_layout)?,
                PAL::Vector(inner_layout) => amplification(inner_layout)?,
                PAL::Ascii | PAL::UTF8 => 2,
                PAL::Bool | PAL::U8 | PAL::U16 | PAL::U32 | PAL::U64 => 1,
                PAL::U128 | PAL::U256 | PAL::Address => 2,
            })
        }

        let mut amplification = match primitive_serialization_layout(context, param_ty)? {
            // No primitive type layout was able to be determined for the type. Assume the worst
            // and the value is of maximal depth.
            None => context.protocol_config.max_move_value_depth(),
            Some(layout) => amplification(&layout)?,
        };

        // Computed amplification should never be zero
        debug_assert!(amplification != 0);
        // We assume here that any value that can be created must be bounded by the max move value
        // depth so assert that this invariant holds.
        debug_assert!(
            context.protocol_config.max_move_value_depth()
                >= context.protocol_config.max_type_argument_depth() as u64
        );
        assert_ne!(context.protocol_config.max_move_value_depth(), 0);
        if amplification == 0 {
            amplification = context.protocol_config.max_move_value_depth();
        }
        Ok(Some(bound / amplification))
    }

    /***************************************************************************************************
     * Special serialization formats
     **************************************************************************************************/

    /// Special enum for values that need additional validation, in other words
    /// There is validation to do on top of the BCS layout. Currently only needed for
    /// strings
    #[derive(Debug)]
    pub enum PrimitiveArgumentLayout {
        /// An option
        Option(Box<PrimitiveArgumentLayout>),
        /// A vector
        Vector(Box<PrimitiveArgumentLayout>),
        /// An ASCII encoded string
        Ascii,
        /// A UTF8 encoded string
        UTF8,
        // needed for Option validation
        Bool,
        U8,
        U16,
        U32,
        U64,
        U128,
        U256,
        Address,
    }

    impl PrimitiveArgumentLayout {
        /// returns true iff all BCS compatible bytes are actually values for this type.
        /// For example, this function returns false for Option and Strings since they need additional
        /// validation.
        pub fn bcs_only(&self) -> bool {
            match self {
                // have additional restrictions past BCS
                PrimitiveArgumentLayout::Option(_)
                | PrimitiveArgumentLayout::Ascii
                | PrimitiveArgumentLayout::UTF8 => false,
                // Move primitives are BCS compatible and do not need additional validation
                PrimitiveArgumentLayout::Bool
                | PrimitiveArgumentLayout::U8
                | PrimitiveArgumentLayout::U16
                | PrimitiveArgumentLayout::U32
                | PrimitiveArgumentLayout::U64
                | PrimitiveArgumentLayout::U128
                | PrimitiveArgumentLayout::U256
                | PrimitiveArgumentLayout::Address => true,
                // vector only needs validation if it's inner type does
                PrimitiveArgumentLayout::Vector(inner) => inner.bcs_only(),
            }
        }
    }

    /// Checks the bytes against the `SpecialArgumentLayout` using `bcs`. It does not actually generate
    /// the deserialized value, only walks the bytes. While not necessary if the layout does not contain
    /// special arguments (e.g. Option or String) we check the BCS bytes for predictability
    pub fn bcs_argument_validate(
        bytes: &[u8],
        idx: u16,
        layout: PrimitiveArgumentLayout,
    ) -> Result<(), ExecutionError> {
        bcs::from_bytes_seed(&layout, bytes).map_err(|_| {
            ExecutionError::new_with_source(
                ExecutionErrorKind::command_argument_error(
                    CommandArgumentError::InvalidBCSBytes,
                    idx,
                ),
                format!("Function expects {layout} but provided argument's value does not match",),
            )
        })
    }

    impl<'d> serde::de::DeserializeSeed<'d> for &PrimitiveArgumentLayout {
        type Value = ();
        fn deserialize<D: serde::de::Deserializer<'d>>(
            self,
            deserializer: D,
        ) -> Result<Self::Value, D::Error> {
            use serde::de::Error;
            match self {
                PrimitiveArgumentLayout::Ascii => {
                    let s: &str = serde::Deserialize::deserialize(deserializer)?;
                    if !s.is_ascii() {
                        Err(D::Error::custom("not an ascii string"))
                    } else {
                        Ok(())
                    }
                }
                PrimitiveArgumentLayout::UTF8 => {
                    deserializer.deserialize_string(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::Option(layout) => {
                    deserializer.deserialize_option(OptionElementVisitor(layout))
                }
                PrimitiveArgumentLayout::Vector(layout) => {
                    deserializer.deserialize_seq(VectorElementVisitor(layout))
                }
                // primitive move value cases, which are hit to make sure the correct number of bytes
                // are removed for elements of an option/vector
                PrimitiveArgumentLayout::Bool => {
                    deserializer.deserialize_bool(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::U8 => {
                    deserializer.deserialize_u8(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::U16 => {
                    deserializer.deserialize_u16(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::U32 => {
                    deserializer.deserialize_u32(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::U64 => {
                    deserializer.deserialize_u64(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::U128 => {
                    deserializer.deserialize_u128(serde::de::IgnoredAny)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::U256 => {
                    U256::deserialize(deserializer)?;
                    Ok(())
                }
                PrimitiveArgumentLayout::Address => {
                    SuiAddress::deserialize(deserializer)?;
                    Ok(())
                }
            }
        }
    }

    struct VectorElementVisitor<'a>(&'a PrimitiveArgumentLayout);

    impl<'d> serde::de::Visitor<'d> for VectorElementVisitor<'_> {
        type Value = ();

        fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
            formatter.write_str("Vector")
        }

        fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
        where
            A: serde::de::SeqAccess<'d>,
        {
            while seq.next_element_seed(self.0)?.is_some() {}
            Ok(())
        }
    }

    struct OptionElementVisitor<'a>(&'a PrimitiveArgumentLayout);

    impl<'d> serde::de::Visitor<'d> for OptionElementVisitor<'_> {
        type Value = ();

        fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
            formatter.write_str("Option")
        }

        fn visit_none<E>(self) -> Result<Self::Value, E>
        where
            E: serde::de::Error,
        {
            Ok(())
        }

        fn visit_some<D>(self, deserializer: D) -> Result<Self::Value, D::Error>
        where
            D: serde::Deserializer<'d>,
        {
            self.0.deserialize(deserializer)
        }
    }

    impl fmt::Display for PrimitiveArgumentLayout {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            match self {
                PrimitiveArgumentLayout::Vector(inner) => {
                    write!(f, "vector<{inner}>")
                }
                PrimitiveArgumentLayout::Option(inner) => {
                    write!(f, "std::option::Option<{inner}>")
                }
                PrimitiveArgumentLayout::Ascii => {
                    write!(f, "std::{}::{}", RESOLVED_ASCII_STR.1, RESOLVED_ASCII_STR.2)
                }
                PrimitiveArgumentLayout::UTF8 => {
                    write!(f, "std::{}::{}", RESOLVED_UTF8_STR.1, RESOLVED_UTF8_STR.2)
                }
                PrimitiveArgumentLayout::Bool => write!(f, "bool"),
                PrimitiveArgumentLayout::U8 => write!(f, "u8"),
                PrimitiveArgumentLayout::U16 => write!(f, "u16"),
                PrimitiveArgumentLayout::U32 => write!(f, "u32"),
                PrimitiveArgumentLayout::U64 => write!(f, "u64"),
                PrimitiveArgumentLayout::U128 => write!(f, "u128"),
                PrimitiveArgumentLayout::U256 => write!(f, "u256"),
                PrimitiveArgumentLayout::Address => write!(f, "address"),
            }
        }
    }
}

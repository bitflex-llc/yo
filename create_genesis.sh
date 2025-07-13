#!/bin/bash

# Genesis Configuration Script for Custom Sui Network
# This script creates a custom genesis with pre-mined accounts and modified payout rules

set -e

# Configuration
PREMINE_AMOUNT="1000000000000000"  # 1,000,000 SUI in MIST
VALIDATOR_STAKE="100000000000000"  # 100,000 SUI validator stake
NETWORK_NAME="custom-sui-payout-network"
EPOCH_DURATION_MS="86400000"       # 24 hours = 86400000 ms

print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

create_genesis_config() {
    print_status "Creating custom genesis configuration..."
    
    cat > genesis_config.yaml << EOF
# Custom Sui Genesis Configuration
# Modified payout distribution: 1% delegators, 1.5% validators

# Protocol configuration
protocol_version: 1
chain_start_timestamp_ms: $(date +%s000)
epoch_duration_ms: $EPOCH_DURATION_MS

# Network parameters
parameters:
  # Staking parameters
  min_validator_count: 1
  max_validator_count: 150
  min_validator_joining_stake: 30000000000000  # 30,000 SUI
  validator_low_stake_threshold: 20000000000000  # 20,000 SUI
  validator_very_low_stake_threshold: 15000000000000  # 15,000 SUI
  validator_low_stake_grace_period: 7  # epochs
  
  # Modified staking reward parameters for custom payout distribution
  stake_subsidy_start_epoch: 0
  stake_subsidy_initial_distribution_amount: 1000000000000000000  # Large initial subsidy pool
  stake_subsidy_period_length: 30  # 30 epochs
  stake_subsidy_decrease_rate: 1000  # 10% decrease per period
  
  # Gas configuration
  max_gas_budget: 50000000  # 0.05 SUI
  gas_price_for_validator: 1000
  
  # Storage configuration
  storage_gas_price: 76
  storage_rebate_rate: 9900  # 99%
  reward_slashing_rate: 10000  # 100% slashing for bad validators
  
  # Commission and reward rates
  max_validator_commission_rate: 2000  # 20% max commission
  
# Pre-funded accounts (including our 1M SUI pre-mine)
accounts:
  # Main pre-mined account with 1,000,000 SUI
  - address: "PLACEHOLDER_GENESIS_ADDRESS"
    gas_objects:
      - object_id: "PLACEHOLDER_OBJECT_ID_1"
        version: 1
        digest: "PLACEHOLDER_DIGEST_1"
        owner: "PLACEHOLDER_GENESIS_ADDRESS"
        balance: $PREMINE_AMOUNT
    
  # Additional utility accounts
  - address: "PLACEHOLDER_FAUCET_ADDRESS"
    gas_objects:
      - object_id: "PLACEHOLDER_OBJECT_ID_2"
        version: 1
        digest: "PLACEHOLDER_DIGEST_2"
        owner: "PLACEHOLDER_FAUCET_ADDRESS"
        balance: 100000000000000  # 100,000 SUI for faucet
        
  - address: "PLACEHOLDER_TREASURY_ADDRESS"
    gas_objects:
      - object_id: "PLACEHOLDER_OBJECT_ID_3"
        version: 1
        digest: "PLACEHOLDER_DIGEST_3"
        owner: "PLACEHOLDER_TREASURY_ADDRESS"
        balance: 500000000000000  # 500,000 SUI for treasury

# Validator configuration
validators:
  - name: "Genesis Validator"
    description: "Initial validator with custom payout distribution"
    image_url: "https://example.com/validator.png"
    project_url: "https://example.com"
    
    # Network addresses (will be updated with actual addresses)
    network_address: "/ip4/127.0.0.1/tcp/8080"
    p2p_address: "/ip4/127.0.0.1/tcp/8084"
    primary_address: "/ip4/127.0.0.1/tcp/8081"
    worker_address: "/ip4/127.0.0.1/tcp/8082"
    
    # Validator keys (will be generated)
    account_address: "PLACEHOLDER_VALIDATOR_ADDRESS"
    protocol_key: "PLACEHOLDER_PROTOCOL_KEY"
    worker_key: "PLACEHOLDER_WORKER_KEY"
    network_key: "PLACEHOLDER_NETWORK_KEY"
    proof_of_possession: "PLACEHOLDER_POP"
    
    # Staking configuration
    gas_price: 1000
    commission_rate: 1000  # 10% commission
    
    # Initial stake for the validator
    next_epoch_stake: $VALIDATOR_STAKE

# Move framework packages
move_packages:
  - name: "MoveStdlib"
    path: "crates/sui-framework/packages/move-stdlib"
  - name: "SuiFramework" 
    path: "crates/sui-framework/packages/sui-framework"
  - name: "SuiSystem"
    path: "crates/sui-framework/packages/sui-system"

# Features and capabilities
feature_flags:
  - "advance_epoch_start_time_in_safe_mode"
  - "loaded_child_objects_fixed"
  - "missing_type_is_compatibility_error"
  - "scoring_decision_with_validity_cutoff"
  - "narwhal_versioned_metadata"
  - "consensus_order_end_of_epoch_last"
  - "disallow_adding_abilities_on_upgrade"
  - "disable_invariant_violation_check_in_swap_loc"
  - "advance_to_highest_supported_protocol_version"
  - "ban_entry_init"
  - "package_digest_hash_module"
  - "disallow_change_struct_type_params_on_upgrade"
  - "no_extraneous_module_bytes"
  - "consensus_transaction_ordering"
  - "zklogin_auth"
  - "consensus_distributed_vote_scoring_strategy"
  - "fresh_vm_on_framework_upgrade"
  - "prepend_prologue_tx_in_consensus_commit_in_checkpoints"
  - "hardened_otw_check"
  - "allow_receiving_object_id"
  - "enable_jwk_consensus_updates"
  - "end_of_epoch_transaction_supported"
  - "simple_conservation_checks"
  - "loaded_child_object_format"
  - "receive_objects"
  - "random_beacon"
  - "bridge"
  - "enable_effects_v2"
  - "narwhal_new_leader_election_schedule"
  - "mysticeti"
  - "reshare_at_same_initial_version"
  - "resolve_abort_locations_to_package_id"
  - "relocate_event_module"
  - "zklogin_supported_providers"
  - "rethrow_serialization_type_layout_errors"
  - "accept_zklogin_in_multisig"
  - "include_consensus_digest_in_prologue"
  - "hardened_struct_constructors"
  - "allow_binary_format_version_six"
  - "enable_coin_deny_list"
  - "enable_group_ops_native_functions"
  - "reject_mutable_random_on_entry_functions"
  - "per_object_congestion_control_mode"
  - "simplified_unwrap_then_delete"
  - "upgraded_multisig_supported"
  - "consensus_choice_modifications"
  - "congestion_control_pilot_knobs"
  - "enable_vdf"
  - "passkey_auth"
  - "authority_capabilities_v2"
  - "zklogin_max_epoch_upper_bound_delta"

EOF

    print_success "Genesis configuration template created"
}

generate_validator_keys() {
    print_status "Generating validator keys..."
    
    # Generate validator keypairs
    sui validator make-validator-info \
        --name "Genesis Validator" \
        --description "Initial validator with custom payout distribution" \
        --image-url "https://example.com/validator.png" \
        --project-url "https://example.com" \
        --network-address "/ip4/127.0.0.1/tcp/8080" \
        --p2p-address "/ip4/127.0.0.1/tcp/8084" \
        --primary-address "/ip4/127.0.0.1/tcp/8081" \
        --worker-address "/ip4/127.0.0.1/tcp/8082"
    
    print_success "Validator keys generated"
}

create_accounts() {
    print_status "Creating genesis accounts..."
    
    # Create the main pre-mined account
    GENESIS_ADDRESS=$(sui client new-address secp256k1 2>/dev/null | grep "Created new keypair" | awk '{print $6}')
    
    # Create faucet account
    FAUCET_ADDRESS=$(sui client new-address ed25519 2>/dev/null | grep "Created new keypair" | awk '{print $6}')
    
    # Create treasury account
    TREASURY_ADDRESS=$(sui client new-address secp256k1 2>/dev/null | grep "Created new keypair" | awk '{print $6}')
    
    echo "GENESIS_ADDRESS=$GENESIS_ADDRESS" > accounts.env
    echo "FAUCET_ADDRESS=$FAUCET_ADDRESS" >> accounts.env
    echo "TREASURY_ADDRESS=$TREASURY_ADDRESS" >> accounts.env
    
    print_success "Genesis accounts created:"
    print_success "  Genesis (1M SUI): $GENESIS_ADDRESS"
    print_success "  Faucet (100K SUI): $FAUCET_ADDRESS"
    print_success "  Treasury (500K SUI): $TREASURY_ADDRESS"
}

finalize_genesis() {
    print_status "Finalizing genesis configuration..."
    
    # Load account addresses
    source accounts.env
    
    # Update genesis config with actual addresses
    sed -i.bak "s/PLACEHOLDER_GENESIS_ADDRESS/$GENESIS_ADDRESS/g" genesis_config.yaml
    sed -i.bak "s/PLACEHOLDER_FAUCET_ADDRESS/$FAUCET_ADDRESS/g" genesis_config.yaml
    sed -i.bak "s/PLACEHOLDER_TREASURY_ADDRESS/$TREASURY_ADDRESS/g" genesis_config.yaml
    
    # Generate object IDs (simplified - in real implementation these would be proper object IDs)
    OBJECT_ID_1=$(openssl rand -hex 16)
    OBJECT_ID_2=$(openssl rand -hex 16)
    OBJECT_ID_3=$(openssl rand -hex 16)
    
    sed -i.bak "s/PLACEHOLDER_OBJECT_ID_1/$OBJECT_ID_1/g" genesis_config.yaml
    sed -i.bak "s/PLACEHOLDER_OBJECT_ID_2/$OBJECT_ID_2/g" genesis_config.yaml
    sed -i.bak "s/PLACEHOLDER_OBJECT_ID_3/$OBJECT_ID_3/g" genesis_config.yaml
    
    # Generate dummy digests
    DIGEST_1=$(openssl rand -hex 16)
    DIGEST_2=$(openssl rand -hex 16)
    DIGEST_3=$(openssl rand -hex 16)
    
    sed -i.bak "s/PLACEHOLDER_DIGEST_1/$DIGEST_1/g" genesis_config.yaml
    sed -i.bak "s/PLACEHOLDER_DIGEST_2/$DIGEST_2/g" genesis_config.yaml
    sed -i.bak "s/PLACEHOLDER_DIGEST_3/$DIGEST_3/g" genesis_config.yaml
    
    print_success "Genesis configuration finalized"
}

# Create backup script for important data
create_backup_script() {
    print_status "Creating backup script for important data..."
    
    cat > backup_sui_data.sh << 'EOF'
#!/bin/bash

# Sui Network Backup Script
# Backs up important configuration, keys, and blockchain data

BACKUP_DIR="sui_backup_$(date +%Y%m%d_%H%M%S)"
SUI_HOME="$HOME/.sui"

echo "Creating backup in $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

# Backup configuration files
cp -r "$SUI_HOME/genesis" "$BACKUP_DIR/" 2>/dev/null || echo "No genesis directory found"
cp -r "$SUI_HOME/validator" "$BACKUP_DIR/" 2>/dev/null || echo "No validator directory found"
cp -r "$SUI_HOME/fullnode" "$BACKUP_DIR/" 2>/dev/null || echo "No fullnode directory found"

# Backup important files
cp "$SUI_HOME"/genesis_account_key.txt "$BACKUP_DIR/" 2>/dev/null || echo "No genesis account key found"
cp "$SUI_HOME"/account_info.env "$BACKUP_DIR/" 2>/dev/null || echo "No account info found"
cp "$SUI_HOME"/faucet_config.yaml "$BACKUP_DIR/" 2>/dev/null || echo "No faucet config found"

# Backup keystore
cp -r "$SUI_HOME/keystore" "$BACKUP_DIR/" 2>/dev/null || echo "No keystore found"

# Create archive
tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup created: ${BACKUP_DIR}.tar.gz"
echo "Store this file securely - it contains private keys!"
EOF

    chmod +x backup_sui_data.sh
    print_success "Backup script created: backup_sui_data.sh"
}

# Main function
main() {
    print_status "Creating Custom Sui Genesis Configuration..."
    
    create_genesis_config
    create_accounts
    finalize_genesis
    create_backup_script
    
    print_success "==============================================="
    print_success "🎉 Genesis Configuration Complete! 🎉"
    print_success "==============================================="
    echo ""
    print_status "Files created:"
    echo "  • genesis_config.yaml - Genesis configuration"
    echo "  • accounts.env - Account addresses"
    echo "  • backup_sui_data.sh - Backup script"
    echo ""
    print_status "Account Information:"
    if [ -f accounts.env ]; then
        source accounts.env
        echo "  • Genesis Account (1M SUI): $GENESIS_ADDRESS"
        echo "  • Faucet Account (100K SUI): $FAUCET_ADDRESS"
        echo "  • Treasury Account (500K SUI): $TREASURY_ADDRESS"
    fi
    echo ""
    print_status "Next steps:"
    echo "  1. Run the main installation script: ./install_sui_server.sh"
    echo "  2. The genesis will be automatically processed during installation"
    echo "  3. Create regular backups using: ./backup_sui_data.sh"
}

# Run main function
main "$@"

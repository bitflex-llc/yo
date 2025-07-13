# Sui Framework Payout Distribution Changes

## Overview
Modified the Sui blockchain's payout distribution system to implement fixed daily percentage rates:
- **Delegators**: 1% per day
- **Validators**: 1.5% per day

## Files Modified
- `/crates/sui-framework/packages/sui-system/sources/validator_set.move`

## Changes Made

### 1. `compute_unadjusted_reward_distribution()` function
**Before**: Rewards were distributed proportionally based on voting power and total available rewards (gas fees + stake subsidies).

**After**: Rewards are calculated as fixed daily percentages:
- All stake in validator pools receives 1% daily rewards
- This replaces the previous voting power-based proportional distribution

### 2. `distribute_reward()` function  
**Before**: Validators received only commission-based rewards from the staking pool.

**After**: Validators receive additional 0.5% daily bonus to reach the 1.5% target:
- Base 1% daily from staking pool (shared with delegators)
- Additional 0.5% daily bonus (validator-only)
- Original commission structure remains intact

## Implementation Details

### Reward Calculation Constants
```move
const DAILY_REWARD_RATE: u64 = 100; // 1% in basis points (100/10000)
const ADDITIONAL_VALIDATOR_BONUS: u64 = 50; // 0.5% in basis points (50/10000)
```

### Logic Flow
1. Each validator's staking pool receives 1% daily rewards based on total stake
2. These rewards are distributed to all stakers (delegators + validator) through the existing staking pool mechanism
3. Validators receive an additional 0.5% daily bonus directly
4. Final result: Delegators get 1%/day, Validators get 1.5%/day

## Technical Notes

### Limitations Addressed
- The current Sui framework doesn't easily distinguish between validator's own stake vs delegated stake
- Solution: Apply base rate to all stake, then add validator bonus separately
- This ensures the correct rates while working with existing data structures

### Compatibility
- Changes are backwards compatible with existing staking mechanisms
- Commission rates continue to work as before
- Storage fund rewards remain unchanged
- Slashing and tallying rules continue to apply normally

## Testing Recommendations
When testing these changes:
1. Verify delegators receive approximately 1% daily rewards
2. Verify validators receive approximately 1.5% daily rewards  
3. Ensure commission rates still function correctly
4. Test with different stake amounts and validator configurations
5. Verify rewards compound correctly over multiple epochs

## Security Considerations
- Fixed percentage rates replace market-driven reward distribution
- May require monitoring of total reward sustainability
- Consider implementing rate adjustment mechanisms if needed
- Ensure adequate balance exists for bonus validator rewards

## Future Improvements
1. Implement more sophisticated stake tracking to distinguish validator vs delegator stakes
2. Add dynamic rate adjustment based on network conditions
3. Consider implementing different rates for different stake tiers
4. Add governance mechanisms for rate updates

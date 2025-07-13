#!/bin/bash

# Sui Custom Network Health Check and Verification Script
# Comprehensive testing of the deployed network

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Configuration
SUI_HOME="$HOME/.sui"
RPC_URL="http://localhost:9000"
FAUCET_URL="http://localhost:5003"
EXPLORER_URL="http://localhost:3000"

check_services() {
    print_header "=== Service Status Check ==="
    
    local services=("sui-fullnode" "sui-validator" "sui-faucet" "sui-explorer")
    local all_running=true
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_success "✓ $service is running"
        else
            print_error "✗ $service is not running"
            all_running=false
        fi
    done
    
    if [ "$all_running" = true ]; then
        print_success "All services are running correctly"
    else
        print_warning "Some services need attention"
    fi
    echo ""
}

check_network_connectivity() {
    print_header "=== Network Connectivity Check ==="
    
    local endpoints=(
        "$RPC_URL:RPC API"
        "$FAUCET_URL:Faucet"
        "$EXPLORER_URL:Block Explorer"
        "http://localhost:9184:Metrics"
    )
    
    for endpoint_info in "${endpoints[@]}"; do
        local url=$(echo "$endpoint_info" | cut -d: -f1-2)
        local name=$(echo "$endpoint_info" | cut -d: -f3)
        
        if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            print_success "✓ $name ($url) is accessible"
        else
            print_error "✗ $name ($url) is not responding"
        fi
    done
    echo ""
}

test_rpc_api() {
    print_header "=== RPC API Testing ==="
    
    # Test basic RPC calls
    local rpc_tests=(
        "sui_getChainIdentifier:Chain ID"
        "suix_getCurrentEpoch:Current Epoch"
        "suix_getLatestSuiSystemState:System State"
    )
    
    for test_info in "${rpc_tests[@]}"; do
        local method=$(echo "$test_info" | cut -d: -f1)
        local name=$(echo "$test_info" | cut -d: -f2)
        
        local response=$(curl -s -X POST "$RPC_URL" \
            -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":[]}" 2>/dev/null)
        
        if echo "$response" | jq -e '.result' >/dev/null 2>&1; then
            print_success "✓ $name test passed"
        else
            print_error "✗ $name test failed"
            echo "Response: $response"
        fi
    done
    echo ""
}

check_genesis_account() {
    print_header "=== Genesis Account Verification ==="
    
    if [ -f "$SUI_HOME/account_info.env" ]; then
        source "$SUI_HOME/account_info.env"
        
        if [ -n "$GENESIS_ACCOUNT_ADDRESS" ]; then
            print_status "Genesis account address: $GENESIS_ACCOUNT_ADDRESS"
            
            # Check balance via RPC
            local balance_response=$(curl -s -X POST "$RPC_URL" \
                -H "Content-Type: application/json" \
                -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"suix_getBalance\",\"params\":[\"$GENESIS_ACCOUNT_ADDRESS\"]}" 2>/dev/null)
            
            if echo "$balance_response" | jq -e '.result.totalBalance' >/dev/null 2>&1; then
                local balance=$(echo "$balance_response" | jq -r '.result.totalBalance')
                local balance_sui=$((balance / 1000000000))
                print_success "✓ Genesis account balance: ${balance_sui} SUI"
                
                if [ "$balance_sui" -ge 1000000 ]; then
                    print_success "✓ Pre-mine verification successful (≥1M SUI)"
                else
                    print_warning "⚠ Pre-mine amount lower than expected"
                fi
            else
                print_error "✗ Could not retrieve genesis account balance"
            fi
        else
            print_error "✗ Genesis account address not found"
        fi
    else
        print_error "✗ Account info file not found"
    fi
    echo ""
}

test_faucet() {
    print_header "=== Faucet Testing ==="
    
    # Create a temporary test address
    local test_address=$(sui client new-address secp256k1 2>/dev/null | grep "Created new keypair" | awk '{print $6}' || echo "")
    
    if [ -n "$test_address" ]; then
        print_status "Created test address: $test_address"
        
        # Test faucet request
        local faucet_response=$(curl -s -X POST "$FAUCET_URL/gas" \
            -H "Content-Type: application/json" \
            -d "{\"recipient\":\"$test_address\"}" 2>/dev/null)
        
        if echo "$faucet_response" | jq -e '.transferredGasObjects' >/dev/null 2>&1; then
            print_success "✓ Faucet request successful"
            
            # Check if balance was updated
            sleep 3
            local balance_response=$(curl -s -X POST "$RPC_URL" \
                -H "Content-Type: application/json" \
                -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"suix_getBalance\",\"params\":[\"$test_address\"]}" 2>/dev/null)
            
            if echo "$balance_response" | jq -e '.result.totalBalance' >/dev/null 2>&1; then
                local balance=$(echo "$balance_response" | jq -r '.result.totalBalance')
                if [ "$balance" -gt 0 ]; then
                    print_success "✓ Test address funded successfully"
                else
                    print_warning "⚠ Test address balance is zero"
                fi
            fi
        else
            print_error "✗ Faucet request failed"
            echo "Response: $faucet_response"
        fi
    else
        print_error "✗ Could not create test address"
    fi
    echo ""
}

check_validator_status() {
    print_header "=== Validator Status Check ==="
    
    local system_state_response=$(curl -s -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"suix_getLatestSuiSystemState","params":[]}' 2>/dev/null)
    
    if echo "$system_state_response" | jq -e '.result' >/dev/null 2>&1; then
        local epoch=$(echo "$system_state_response" | jq -r '.result.epoch')
        local validator_count=$(echo "$system_state_response" | jq -r '.result.activeValidators | length')
        local total_stake=$(echo "$system_state_response" | jq -r '.result.totalStake')
        
        print_success "✓ Current epoch: $epoch"
        print_success "✓ Active validators: $validator_count"
        print_success "✓ Total stake: $((total_stake / 1000000000)) SUI"
        
        # Check if our validator is active
        if [ -f "$SUI_HOME/account_info.env" ]; then
            source "$SUI_HOME/account_info.env"
            if [ -n "$VALIDATOR_ADDRESS" ]; then
                local validator_active=$(echo "$system_state_response" | jq -r --arg addr "$VALIDATOR_ADDRESS" '.result.activeValidators[] | select(.suiAddress == $addr) | .suiAddress')
                if [ -n "$validator_active" ]; then
                    print_success "✓ Custom validator is active"
                else
                    print_warning "⚠ Custom validator not found in active set"
                fi
            fi
        fi
    else
        print_error "✗ Could not retrieve validator information"
    fi
    echo ""
}

test_payout_modifications() {
    print_header "=== Payout Modification Verification ==="
    
    print_status "Checking validator_set.move for custom payout logic..."
    
    local validator_file="crates/sui-framework/packages/sui-system/sources/validator_set.move"
    
    if [ -f "$validator_file" ]; then
        # Check for our custom modifications
        if grep -q "1%.*day\|delegator.*1%" "$validator_file" && grep -q "1.5%.*day\|validator.*1.5%" "$validator_file"; then
            print_success "✓ Custom payout rates found in source code"
        else
            print_warning "⚠ Custom payout rate comments not found (code may still be modified)"
        fi
        
        # Check for modified functions
        if grep -q "compute_unadjusted_reward_distribution" "$validator_file" && grep -q "distribute_reward" "$validator_file"; then
            print_success "✓ Required payout functions are present"
        else
            print_error "✗ Required payout functions not found"
        fi
        
        # Check for our custom logic patterns
        if grep -q "0\.01\|1%" "$validator_file" && grep -q "0\.005\|0\.5%" "$validator_file"; then
            print_success "✓ Custom rate calculations detected in code"
        else
            print_warning "⚠ Custom rate patterns not clearly detected"
        fi
    else
        print_error "✗ validator_set.move file not found"
    fi
    echo ""
}

check_logs_for_errors() {
    print_header "=== Log Analysis ==="
    
    local services=("sui-fullnode" "sui-validator" "sui-faucet" "sui-explorer")
    
    for service in "${services[@]}"; do
        print_status "Checking $service logs for errors..."
        
        local error_count=$(journalctl -u "$service" --since "1 hour ago" --no-pager | grep -i error | wc -l)
        local warning_count=$(journalctl -u "$service" --since "1 hour ago" --no-pager | grep -i warning | wc -l)
        
        if [ "$error_count" -eq 0 ]; then
            print_success "✓ No errors in $service logs"
        else
            print_warning "⚠ $error_count errors found in $service logs"
        fi
        
        if [ "$warning_count" -gt 0 ]; then
            print_status "ℹ $warning_count warnings in $service logs (may be normal)"
        fi
    done
    echo ""
}

performance_check() {
    print_header "=== Performance Check ==="
    
    # Check system resources
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    print_status "System Performance:"
    echo "  • Memory usage: ${memory_usage}%"
    echo "  • Disk usage: ${disk_usage}%"
    echo "  • Load average: ${load_avg}"
    
    # Performance warnings
    if [ "${memory_usage%.*}" -gt 80 ]; then
        print_warning "⚠ High memory usage detected"
    fi
    
    if [ "$disk_usage" -gt 90 ]; then
        print_warning "⚠ High disk usage detected"
    fi
    
    # Check database sizes
    if [ -d "$SUI_HOME" ]; then
        local sui_dir_size=$(du -sh "$SUI_HOME" 2>/dev/null | cut -f1)
        print_status "Sui data directory size: $sui_dir_size"
    fi
    echo ""
}

generate_health_report() {
    print_header "=== Health Report Generation ==="
    
    local report_file="sui_health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Sui Custom Network Health Report
Generated: $(date)
================================

NETWORK INFORMATION:
- Modified payout rates: 1% delegators, 1.5% validators
- Genesis account with 1,000,000 SUI pre-mine
- Custom block explorer and faucet

SERVICE STATUS:
$(systemctl is-active sui-fullnode && echo "✓ Full Node: Running" || echo "✗ Full Node: Stopped")
$(systemctl is-active sui-validator && echo "✓ Validator: Running" || echo "✗ Validator: Stopped")
$(systemctl is-active sui-faucet && echo "✓ Faucet: Running" || echo "✗ Faucet: Stopped")
$(systemctl is-active sui-explorer && echo "✓ Explorer: Running" || echo "✗ Explorer: Stopped")

NETWORK ENDPOINTS:
- RPC: $RPC_URL
- Faucet: $FAUCET_URL  
- Explorer: $EXPLORER_URL
- Metrics: http://localhost:9184

ACCOUNT INFORMATION:
$([ -f "$SUI_HOME/account_info.env" ] && source "$SUI_HOME/account_info.env" && echo "- Genesis Account: $GENESIS_ACCOUNT_ADDRESS" || echo "- Genesis Account: Not found")
$([ -f "$SUI_HOME/account_info.env" ] && source "$SUI_HOME/account_info.env" && echo "- Validator Address: $VALIDATOR_ADDRESS" || echo "- Validator Address: Not found")

RECENT ACTIVITY:
$(journalctl -u sui-fullnode --since "1 hour ago" --no-pager -q | tail -5)

RECOMMENDATIONS:
- Monitor disk space regularly
- Create backups of private keys
- Check service logs for any issues
- Verify payout distributions after epoch changes
EOF

    print_success "Health report generated: $report_file"
    echo ""
}

show_summary() {
    print_header "=== Verification Summary ==="
    
    print_status "🔍 Verification completed!"
    echo ""
    print_status "Quick commands for ongoing monitoring:"
    echo "• Check services: sudo systemctl status sui-fullnode sui-validator sui-faucet sui-explorer"
    echo "• View logs: sudo journalctl -u sui-fullnode -f"
    echo "• Network status: ~/.sui/check_sui_status.sh"
    echo "• Create backup: ./backup_sui_data.sh"
    echo ""
    print_status "🌐 Access your network:"
    echo "• Block Explorer: $EXPLORER_URL"
    echo "• RPC API: $RPC_URL"
    echo "• Faucet: $FAUCET_URL/gas"
    echo ""
    print_warning "💡 If you found any issues, check the logs and restart services if needed"
    echo ""
}

# Main function
main() {
    echo -e "${PURPLE}"
    echo "=================================================================="
    echo "     🔍 Sui Custom Network Health Check & Verification 🔍"
    echo "=================================================================="
    echo -e "${NC}"
    
    check_services
    check_network_connectivity
    test_rpc_api
    check_genesis_account
    test_faucet
    check_validator_status
    test_payout_modifications
    check_logs_for_errors
    performance_check
    generate_health_report
    show_summary
}

# Run main function
main "$@"

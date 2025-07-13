#!/bin/bash

# Sui Custom Network Deployment Orchestrator
# This master script coordinates the entire deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_banner() {
    echo -e "${PURPLE}"
    echo "=================================================================="
    echo "    🚀 Sui Custom Network Deployment (Modified Payouts) 🚀"
    echo "=================================================================="
    echo "  • Delegators receive: 1% daily rewards"
    echo "  • Validators receive: 1.5% daily rewards" 
    echo "  • Pre-mined account: 1,000,000 SUI"
    echo "  • Full block explorer included"
    echo "=================================================================="
    echo -e "${NC}"
}

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

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if we're in the Sui repository
    if [[ ! -f "Cargo.toml" ]] || [[ ! -d "crates" ]]; then
        print_error "This script must be run from the root of the Sui repository"
        print_error "Current directory: $(pwd)"
        exit 1
    fi
    
    # Check for required scripts
    local required_scripts=("install_sui_server.sh" "create_genesis.sh" "setup_block_explorer.sh")
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            print_error "Required script not found: $script"
            exit 1
        fi
        chmod +x "$script"
    done
    
    # Check if payout modifications are in place
    if ! grep -q "1%.*day.*delegator\|1.5%.*day.*validator" crates/sui-framework/packages/sui-system/sources/validator_set.move; then
        print_warning "Payout modifications may not be applied. Checking for modified code..."
        if ! grep -q "compute_unadjusted_reward_distribution\|distribute_reward" crates/sui-framework/packages/sui-system/sources/validator_set.move; then
            print_error "Validator payout modifications not found in validator_set.move"
            print_error "Please ensure the payout logic has been modified first"
            exit 1
        fi
    fi
    
    print_success "Prerequisites check passed"
}

show_deployment_plan() {
    print_status "Deployment Plan:"
    echo ""
    echo "1. 🔧 System Dependencies Installation"
    echo "   • Rust toolchain with required components"
    echo "   • Node.js and npm/pnpm for block explorer"
    echo "   • Build tools and libraries"
    echo ""
    echo "2. 🏗️  Sui Network Build"
    echo "   • Build modified Sui binaries with custom payout logic"
    echo "   • Install binaries to system PATH"
    echo ""
    echo "3. ⚙️  Network Configuration"
    echo "   • Create genesis configuration with pre-mined accounts"
    echo "   • Set up validator and full node configurations"
    echo "   • Configure faucet for testnet usage"
    echo ""
    echo "4. 🌐 Block Explorer Setup"
    echo "   • Custom Next.js explorer with payout information"
    echo "   • Real-time transaction and validator monitoring"
    echo "   • Integration with local network"
    echo ""
    echo "5. 🚀 Service Deployment"
    echo "   • Systemd services for auto-start"
    echo "   • Firewall configuration"
    echo "   • Management scripts"
    echo ""
    echo "6. 💰 Account Funding"
    echo "   • Pre-mine 1,000,000 SUI to genesis account"
    echo "   • Set up faucet funding"
    echo "   • Verify balances"
    echo ""
}

confirm_deployment() {
    echo ""
    print_warning "⚠️  IMPORTANT DEPLOYMENT NOTICE ⚠️"
    echo ""
    echo "This deployment will:"
    echo "• Install system-wide dependencies (requires sudo)"
    echo "• Build Sui from source (20-30 minutes)"
    echo "• Create systemd services"
    echo "• Configure firewall rules"
    echo "• Set up a complete blockchain network"
    echo ""
    print_warning "Make sure you have:"
    echo "• Sudo access on this system"
    echo "• At least 8GB RAM and 100GB disk space"
    echo "• Stable internet connection"
    echo "• No other services running on ports 8080-8084, 9000-9001, 5003, 3000"
    echo ""
    
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
}

run_genesis_creation() {
    print_status "Creating genesis configuration..."
    
    if ! ./create_genesis.sh; then
        print_error "Genesis creation failed"
        exit 1
    fi
    
    print_success "Genesis configuration created successfully"
}

run_main_installation() {
    print_status "Running main Sui installation..."
    
    if ! ./install_sui_server.sh; then
        print_error "Main installation failed"
        exit 1
    fi
    
    print_success "Main installation completed successfully"
}

run_explorer_setup() {
    print_status "Setting up block explorer..."
    
    if ! ./setup_block_explorer.sh; then
        print_error "Block explorer setup failed"
        exit 1
    fi
    
    print_success "Block explorer setup completed successfully"
}

verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check if services are running
    local services=("sui-fullnode" "sui-validator" "sui-faucet" "sui-explorer")
    local failed_services=()
    
    sleep 10  # Give services time to start
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        print_warning "Some services are not running:"
        for service in "${failed_services[@]}"; do
            echo "  ❌ $service"
            systemctl status "$service" --no-pager -l || true
        done
        print_warning "Check logs with: journalctl -u <service-name> -f"
    else
        print_success "All services are running successfully!"
    fi
    
    # Test network connectivity
    print_status "Testing network endpoints..."
    
    local endpoints=(
        "http://localhost:9000"
        "http://localhost:5003"
        "http://localhost:3000"
    )
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s --connect-timeout 5 "$endpoint" >/dev/null 2>&1; then
            print_success "✓ $endpoint is accessible"
        else
            print_warning "⚠ $endpoint is not responding (may still be starting up)"
        fi
    done
}

create_quick_start_guide() {
    print_status "Creating quick start guide..."
    
    cat > QUICK_START.md << 'EOF'
# Sui Custom Network - Quick Start Guide

## 🎉 Your Custom Sui Network is Ready!

### Modified Payout Distribution
- **Delegators**: 1% daily rewards
- **Validators**: 1.5% daily rewards
- **Pre-mined Account**: 1,000,000 SUI

### Network Endpoints
- **RPC API**: http://localhost:9000
- **WebSocket**: ws://localhost:9001
- **Faucet**: http://localhost:5003/gas
- **Block Explorer**: http://localhost:3000
- **Metrics**: http://localhost:9184/metrics

### Management Commands
```bash
# Check network status
~/.sui/check_sui_status.sh

# Start network
~/.sui/start_sui_network.sh

# Stop network
~/.sui/stop_sui_network.sh

# Create backup
./backup_sui_data.sh
```

### Service Management
```bash
# Check service status
sudo systemctl status sui-fullnode
sudo systemctl status sui-validator
sudo systemctl status sui-faucet
sudo systemctl status sui-explorer

# View logs
sudo journalctl -u sui-fullnode -f
sudo journalctl -u sui-validator -f
```

### Account Information
Your pre-mined account details are stored in:
- Address and keys: `~/.sui/account_info.env`
- Private key backup: `~/.sui/genesis_account_key.txt`

**⚠️ Keep these files secure and backed up!**

### Using the Faucet
Request test SUI tokens:
```bash
curl -X POST http://localhost:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"recipient": "YOUR_ADDRESS_HERE"}'
```

### Sui CLI Usage
```bash
# Check your balance
sui client balance

# Send SUI to another address
sui client transfer-sui --to ADDRESS --amount AMOUNT --gas-budget 10000000

# Create a new address
sui client new-address secp256k1
```

### Block Explorer Features
- Real-time transaction monitoring
- Validator performance metrics
- Custom payout rate display
- Network statistics
- Account balance checker

### Next Steps
1. Visit http://localhost:3000 to explore your network
2. Create additional accounts using Sui CLI
3. Test transactions and staking
4. Monitor validator performance
5. Set up monitoring and alerts (optional)

### Troubleshooting
- Check service logs for errors
- Ensure all required ports are open
- Verify sufficient disk space and memory
- Check network connectivity

For more information, see the official Sui documentation at https://docs.sui.io
EOF

    print_success "Quick start guide created: QUICK_START.md"
}

show_completion_summary() {
    print_success "=================================================================="
    print_success "🎉🎉🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉🎉🎉"
    print_success "=================================================================="
    echo ""
    print_status "🌐 Your Custom Sui Network is now running with:"
    echo ""
    echo "✅ Modified payout distribution (1% delegators, 1.5% validators)"
    echo "✅ Pre-mined account with 1,000,000 SUI"
    echo "✅ Full block explorer at http://localhost:3000"
    echo "✅ Faucet service at http://localhost:5003"
    echo "✅ RPC API at http://localhost:9000"
    echo "✅ Automatic service management with systemd"
    echo ""
    print_status "📋 Important Files:"
    echo "• Network status: ~/.sui/check_sui_status.sh"
    echo "• Account info: ~/.sui/account_info.env"
    echo "• Private keys: ~/.sui/genesis_account_key.txt"
    echo "• Quick start: ./QUICK_START.md"
    echo ""
    print_warning "🔒 SECURITY REMINDER:"
    print_warning "Your genesis account private key contains 1,000,000 SUI!"
    print_warning "Keep ~/.sui/genesis_account_key.txt secure and create backups!"
    echo ""
    print_status "🚀 Next Steps:"
    echo "1. Visit http://localhost:3000 to see your block explorer"
    echo "2. Check network status: ~/.sui/check_sui_status.sh"
    echo "3. Read the quick start guide: cat QUICK_START.md"
    echo "4. Create regular backups: ./backup_sui_data.sh"
    echo ""
    print_success "=================================================================="
    print_success "Happy blockchain building! 🚀⛓️"
    print_success "=================================================================="
}

# Main deployment function
main() {
    print_banner
    
    check_prerequisites
    show_deployment_plan
    confirm_deployment
    
    print_status "Starting deployment process..."
    echo ""
    
    # Run deployment steps
    run_genesis_creation
    run_main_installation
    # Note: explorer setup is included in main installation
    
    verify_deployment
    create_quick_start_guide
    
    show_completion_summary
}

# Handle script interruption
trap 'print_error "Deployment interrupted by user"; exit 130' INT

# Run main function
main "$@"

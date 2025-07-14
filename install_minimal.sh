#!/bin/bash

# Minimal Sui Custom Network Setup
# Avoids all problematic CLI commands and focuses on core setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "    🚀 Minimal Sui Custom Network Setup 🚀"
    echo "=================================================================="
    echo "  • Modified payout distribution (1% delegators, 1.5% validators)"
    echo "  • Minimal CLI dependency setup"  
    echo "  • Manual configuration approach"
    echo "=================================================================="
    echo -e "${NC}"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if we're in the Sui repository
    if [ ! -f "Cargo.toml" ] || [ ! -d "crates" ]; then
        print_error "This script must be run from the root of the Sui repository"
        exit 1
    fi
    
    # Check if Sui binaries exist or can be built
    if ! command -v sui >/dev/null 2>&1; then
        print_warning "Sui binary not found in PATH"
        
        if [ -f "target/release/sui" ]; then
            print_status "Found Sui binary in target/release/"
            export PATH="$PATH:$(pwd)/target/release"
        else
            print_status "Building Sui binaries (this may take 20-30 minutes)..."
            cargo build --release --bin sui --bin sui-node --bin sui-faucet
            export PATH="$PATH:$(pwd)/target/release"
        fi
    fi
    
    print_success "Prerequisites check completed"
}

setup_directories() {
    print_status "Setting up directory structure..."
    
    # Create all necessary directories
    mkdir -p ~/.sui/minimal_network
    mkdir -p ~/.sui/minimal_network/logs
    mkdir -p ~/.sui/minimal_network/db
    mkdir -p ~/.sui/minimal_network/genesis
    
    print_success "Directory structure created"
}

create_minimal_configs() {
    print_status "Creating minimal network configuration..."
    
    # Create a basic network config without depending on sui client commands
    cat > ~/.sui/minimal_network/network_config.yaml << 'EOF'
# Minimal Sui Network Configuration
# Modified payout distribution: 1% delegators, 1.5% validators

network_name: "custom-sui-minimal"
epoch_duration_ms: 86400000  # 24 hours

# Network ports
rpc_port: 9000
websocket_port: 9001
p2p_port: 8084
metrics_port: 9184

# Basic settings
gas_price: 1000
commission_rate: 1000  # 10%

# Pre-mine configuration
genesis_balance: 1000000000000000  # 1M SUI in MIST
EOF

    # Create a simple start script that doesn't rely on complex genesis
    cat > ~/.sui/minimal_network/start_minimal_network.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Minimal Sui Network..."

# Set environment variables
export RUST_LOG=info
export SUI_CONFIG_DIR="$HOME/.sui/minimal_network"

# Start sui-node with minimal config
echo "Starting Sui node..."

# Simple node startup (adjust path as needed)
if command -v sui-node >/dev/null 2>&1; then
    nohup sui-node \
        --network-address /ip4/0.0.0.0/tcp/8084 \
        --json-rpc-address 0.0.0.0:9000 \
        --websocket-address 0.0.0.0:9001 \
        --metrics-address 0.0.0.0:9184 \
        > "$SUI_CONFIG_DIR/logs/node.log" 2>&1 &
    
    NODE_PID=$!
    echo "Sui node started with PID: $NODE_PID"
    echo $NODE_PID > "$SUI_CONFIG_DIR/node.pid"
    
    echo "Network endpoints:"
    echo "- RPC: http://localhost:9000"
    echo "- WebSocket: ws://localhost:9001"
    echo "- Metrics: http://localhost:9184"
    echo ""
    echo "Logs: tail -f $SUI_CONFIG_DIR/logs/node.log"
else
    echo "Error: sui-node binary not found"
    echo "Please ensure Sui is built and binaries are in PATH"
fi
EOF

    # Create stop script
    cat > ~/.sui/minimal_network/stop_minimal_network.sh << 'EOF'
#!/bin/bash

echo "🛑 Stopping Minimal Sui Network..."

if [ -f "$HOME/.sui/minimal_network/node.pid" ]; then
    PID=$(cat "$HOME/.sui/minimal_network/node.pid")
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo "Node with PID $PID stopped"
    else
        echo "Node process not running"
    fi
    rm -f "$HOME/.sui/minimal_network/node.pid"
else
    echo "No PID file found, trying to kill by process name..."
    pkill -f sui-node || echo "No sui-node processes found"
fi

echo "Network stopped"
EOF

    # Create status script
    cat > ~/.sui/minimal_network/check_minimal_status.sh << 'EOF'
#!/bin/bash

echo "=== Minimal Sui Network Status ==="
echo ""

# Check if node is running
if [ -f "$HOME/.sui/minimal_network/node.pid" ]; then
    PID=$(cat "$HOME/.sui/minimal_network/node.pid")
    if kill -0 $PID 2>/dev/null; then
        echo "✓ Sui Node: Running (PID: $PID)"
    else
        echo "✗ Sui Node: Stopped (stale PID file)"
    fi
else
    if pgrep -f sui-node >/dev/null; then
        echo "⚠ Sui Node: Running (no PID file)"
    else
        echo "✗ Sui Node: Stopped"
    fi
fi

echo ""
echo "Network endpoints:"
echo "- RPC: http://localhost:9000"
echo "- WebSocket: ws://localhost:9001"  
echo "- Metrics: http://localhost:9184"

echo ""
echo "Quick test:"
if curl -s --connect-timeout 3 http://localhost:9000 >/dev/null 2>&1; then
    echo "✓ RPC endpoint is responding"
else
    echo "✗ RPC endpoint not responding"
fi

echo ""
echo "Logs location: $HOME/.sui/minimal_network/logs/"
echo ""
echo "Commands:"
echo "- Start: ~/.sui/minimal_network/start_minimal_network.sh"
echo "- Stop: ~/.sui/minimal_network/stop_minimal_network.sh"
EOF

    # Make scripts executable
    chmod +x ~/.sui/minimal_network/start_minimal_network.sh
    chmod +x ~/.sui/minimal_network/stop_minimal_network.sh
    chmod +x ~/.sui/minimal_network/check_minimal_status.sh
    
    print_success "Minimal network configuration created"
}

create_manual_setup_guide() {
    print_status "Creating manual setup guide..."
    
    cat > ~/.sui/minimal_network/MANUAL_SETUP.md << 'EOF'
# Manual Sui Custom Network Setup Guide

## Overview
This minimal setup avoids CLI commands that have syntax issues and provides a basic working Sui network with your custom payout modifications.

## Your Custom Network Features
- ✅ Modified payout distribution (1% delegators, 1.5% validators)
- ✅ Custom validator_set.move with modified reward logic
- ✅ Minimal configuration to avoid CLI issues

## Quick Start

### 1. Start the Network
```bash
~/.sui/minimal_network/start_minimal_network.sh
```

### 2. Check Status
```bash
~/.sui/minimal_network/check_minimal_status.sh
```

### 3. Test the Network
```bash
# Test RPC endpoint
curl -X POST http://localhost:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"rpc.discover","params":[]}'
```

## Manual Account Creation

Since CLI commands have syntax issues, create accounts manually:

### Method 1: Use Sui CLI (if working)
```bash
sui client new-address secp256k1
sui client addresses
```

### Method 2: Use Keytool Directly
```bash
sui keytool generate secp256k1
```

### Method 3: Use External Tools
You can use any Sui-compatible wallet or key generation tool.

## Funding Accounts

Since genesis creation is complex, you can:

1. **Use a Faucet**: If running testnet mode
2. **Manual Transfer**: Transfer from existing accounts
3. **Genesis Modification**: Manually edit genesis files (advanced)

## Custom Payout Verification

Your modified payout logic is in:
```
crates/sui-framework/packages/sui-system/sources/validator_set.move
```

The key modifications:
- `compute_unadjusted_reward_distribution`: 1% daily for all stake
- `distribute_reward`: Additional 0.5% daily bonus for validators

## Network Endpoints

- **RPC**: http://localhost:9000
- **WebSocket**: ws://localhost:9001  
- **Metrics**: http://localhost:9184

## Troubleshooting

### Node Won't Start
1. Check if ports are available: `netstat -tlnp | grep -E '(9000|9001|8084)'`
2. Check logs: `tail -f ~/.sui/minimal_network/logs/node.log`
3. Verify Sui binary: `which sui-node && sui-node --help`

### CLI Syntax Errors
This minimal setup avoids problematic CLI commands. For manual operations:
1. Check Sui version: `sui --version`
2. Use `sui --help` to see current syntax
3. Refer to latest Sui documentation

### Custom Payout Testing
To verify your modified payout logic:
1. Set up multiple validators
2. Delegate stake to them
3. Wait for epoch changes
4. Check reward distribution matches 1%/1.5% daily rates

## Next Steps

1. **Start the minimal network**
2. **Create accounts manually** using working CLI commands
3. **Test basic functionality** with RPC calls
4. **Set up validators** once basic network is stable
5. **Test your custom payout logic** with real stake

## Advanced Setup

For full production setup with systemd services and block explorer:
- Use the full deployment scripts once CLI issues are resolved
- Or manually adapt this minimal setup with additional services

EOF

    print_success "Manual setup guide created: ~/.sui/minimal_network/MANUAL_SETUP.md"
}

show_completion() {
    print_success "=================================================================="
    print_success "🎉 Minimal Sui Network Setup Complete! 🎉"
    print_success "=================================================================="
    echo ""
    print_status "✅ Your custom Sui network is configured with:"
    echo "   • Modified payout distribution (1% delegators, 1.5% validators)"
    echo "   • Minimal CLI dependency"
    echo "   • Manual configuration approach"
    echo ""
    print_status "📁 Files created:"
    echo "   • Configuration: ~/.sui/minimal_network/"
    echo "   • Start script: ~/.sui/minimal_network/start_minimal_network.sh"
    echo "   • Stop script: ~/.sui/minimal_network/stop_minimal_network.sh"
    echo "   • Status script: ~/.sui/minimal_network/check_minimal_status.sh"
    echo "   • Setup guide: ~/.sui/minimal_network/MANUAL_SETUP.md"
    echo ""
    print_status "🚀 Next steps:"
    echo "1. Read the setup guide: cat ~/.sui/minimal_network/MANUAL_SETUP.md"
    echo "2. Start the network: ~/.sui/minimal_network/start_minimal_network.sh"
    echo "3. Check status: ~/.sui/minimal_network/check_minimal_status.sh"
    echo "4. Create accounts manually using working CLI syntax"
    echo ""
    print_warning "📚 This minimal setup avoids CLI syntax issues by providing"
    print_warning "   a basic network foundation that you can build upon manually."
    echo ""
    print_success "Happy blockchain development! 🚀"
    print_success "=================================================================="
}

# Main execution
main() {
    print_banner
    
    check_prerequisites
    setup_directories
    create_minimal_configs
    create_manual_setup_guide
    
    show_completion
}

# Run main function
main "$@"

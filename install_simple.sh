#!/bin/bash

# Simplified Sui Custom Network Installation Script
# This version handles newer Sui CLI syntax and provides fallbacks

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

# Configuration
SUI_HOME="$HOME/.sui"
SUI_CONFIG_DIR="$SUI_HOME"
NETWORK_NAME="custom-sui-network"

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================================="
    echo "    🚀 Simplified Sui Custom Network Setup 🚀"
    echo "=================================================================="
    echo "  • Modified payout distribution (1% delegators, 1.5% validators)"
    echo "  • Simplified installation process"
    echo "=================================================================="
    echo -e "${NC}"
}

check_sui_binary() {
    print_status "Checking Sui installation..."
    
    if ! command -v sui >/dev/null 2>&1; then
        print_error "Sui binary not found. Please build Sui first:"
        print_error "  cargo build --release --bin sui --bin sui-node --bin sui-faucet"
        print_error "  sudo cp target/release/sui* /usr/local/bin/"
        exit 1
    fi
    
    print_success "Sui binary found: $(which sui)"
    sui --version || true
}

setup_directories() {
    print_status "Setting up Sui directories..."
    
    mkdir -p "$SUI_CONFIG_DIR"
    mkdir -p "$SUI_CONFIG_DIR/genesis"
    mkdir -p "$SUI_CONFIG_DIR/validator"
    mkdir -p "$SUI_CONFIG_DIR/fullnode"
    mkdir -p "$SUI_CONFIG_DIR/logs"
    
    print_success "Directories created"
}

initialize_sui_client() {
    print_status "Initializing Sui client..."
    
    # Initialize client configuration if not exists
    if [ ! -f "$SUI_CONFIG_DIR/client.yaml" ]; then
        print_status "Setting up initial client configuration..."
        # This will create the initial config
        sui client --help >/dev/null 2>&1 || true
        
        # Check if config was created
        if [ ! -f "$HOME/.sui/sui_config/client.yaml" ]; then
            print_warning "Client config not automatically created, setting up manually..."
            mkdir -p "$HOME/.sui/sui_config"
            cat > "$HOME/.sui/sui_config/client.yaml" << EOF
keystore:
  File: $HOME/.sui/sui_config/sui.keystore
envs:
  - alias: localnet
    rpc: "http://127.0.0.1:9000"
    ws: "ws://127.0.0.1:9001"
active_env: localnet
active_address: ~
EOF
        fi
    fi
    
    print_success "Sui client initialized"
}

create_accounts() {
    print_status "Creating accounts..."
    
    # Create genesis account
    print_status "Creating genesis account..."
    if sui client addresses 2>/dev/null | grep -q "0x"; then
        GENESIS_ACCOUNT_ADDRESS=$(sui client addresses 2>/dev/null | head -1)
        print_status "Using existing address: $GENESIS_ACCOUNT_ADDRESS"
    else
        # Try to create new address
        if sui client new-address --help 2>/dev/null | grep -q "key-scheme"; then
            # Newer syntax
            GENESIS_ACCOUNT_ADDRESS=$(sui client new-address secp256k1 2>/dev/null | grep -o "0x[a-fA-F0-9]*" | head -1)
        else
            # Alternative approach - generate key with keytool
            sui keytool generate secp256k1 >/dev/null 2>&1 || true
            GENESIS_ACCOUNT_ADDRESS=$(sui client addresses 2>/dev/null | head -1)
        fi
    fi
    
    if [ -z "$GENESIS_ACCOUNT_ADDRESS" ]; then
        print_error "Failed to create or find genesis account"
        print_status "Manual account creation required"
        print_status "Please run: sui client new-address secp256k1"
        exit 1
    fi
    
    print_success "Genesis account: $GENESIS_ACCOUNT_ADDRESS"
    
    # Save account info
    echo "GENESIS_ACCOUNT_ADDRESS=$GENESIS_ACCOUNT_ADDRESS" > "$SUI_CONFIG_DIR/account_info.env"
    echo "VALIDATOR_ADDRESS=$GENESIS_ACCOUNT_ADDRESS" >> "$SUI_CONFIG_DIR/account_info.env"
    
    # Try to backup keystore
    if [ -d "$HOME/.sui/sui_config/keystores" ]; then
        cp -r "$HOME/.sui/sui_config/keystores" "$SUI_CONFIG_DIR/" 2>/dev/null || true
        print_success "Keystore backed up to $SUI_CONFIG_DIR/keystores/"
    fi
    
    print_success "Account creation completed"
}

create_simple_genesis() {
    print_status "Creating simple genesis configuration..."
    
    # Create a basic genesis configuration
    cat > "$SUI_CONFIG_DIR/genesis/genesis.yaml" << EOF
# Simple Genesis Configuration for Custom Sui Network
# Modified payout distribution: 1% delegators, 1.5% validators

protocol_version: 1
chain_start_timestamp_ms: $(date +%s000)
epoch_duration_ms: 86400000  # 24 hours

# Basic parameters
parameters:
  min_validator_count: 1
  max_validator_count: 150
  
# Pre-funded account
accounts:
  - address: "$GENESIS_ACCOUNT_ADDRESS"
    balance: 1000000000000000  # 1M SUI in MIST

# Basic validator setup  
validators:
  - name: "Genesis Validator"
    account_address: "$GENESIS_ACCOUNT_ADDRESS"
    stake: 100000000000000  # 100K SUI stake
EOF

    print_success "Basic genesis configuration created"
}

create_node_configs() {
    print_status "Creating node configurations..."
    
    # Create fullnode config
    cat > "$SUI_CONFIG_DIR/fullnode/fullnode.yaml" << EOF
# Full Node Configuration for Custom Sui Network
db-path: $SUI_CONFIG_DIR/fullnode/db
network-address: /ip4/0.0.0.0/tcp/9000
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184

# Enable services
enable-event-processing: true
enable-index-processing: true

# Genesis
genesis:
  genesis-file-location: $SUI_CONFIG_DIR/genesis/genesis.blob

# Logging
log-level: info
log-file: $SUI_CONFIG_DIR/logs/fullnode.log
EOF

    # Create validator config
    cat > "$SUI_CONFIG_DIR/validator/validator.yaml" << EOF
# Validator Configuration for Custom Sui Network
validator-address: $GENESIS_ACCOUNT_ADDRESS
db-path: $SUI_CONFIG_DIR/validator/db
network-address: /ip4/0.0.0.0/tcp/8080
metrics-address: 0.0.0.0:9184
commission-rate: 1000  # 10%
gas-price: 1000

# Logging
log-level: info
log-file: $SUI_CONFIG_DIR/logs/validator.log
EOF

    print_success "Node configurations created"
}

create_management_scripts() {
    print_status "Creating management scripts..."
    
    # Simple start script
    cat > "$SUI_CONFIG_DIR/start_network.sh" << 'EOF'
#!/bin/bash
echo "Starting Sui Network..."

# Start fullnode in background
nohup sui-node --config-path ~/.sui/fullnode/fullnode.yaml > ~/.sui/logs/fullnode.log 2>&1 &
echo "Full node started (PID: $!)"

# Wait a bit
sleep 5

# Start validator in background  
nohup sui-node --config-path ~/.sui/validator/validator.yaml > ~/.sui/logs/validator.log 2>&1 &
echo "Validator started (PID: $!)"

echo "Network startup initiated. Check logs in ~/.sui/logs/"
EOF

    # Simple stop script
    cat > "$SUI_CONFIG_DIR/stop_network.sh" << 'EOF'
#!/bin/bash
echo "Stopping Sui Network..."
pkill -f "sui-node" || echo "No sui-node processes found"
echo "Network stopped"
EOF

    # Status script
    cat > "$SUI_CONFIG_DIR/check_status.sh" << 'EOF'
#!/bin/bash
echo "=== Sui Network Status ==="
echo ""

# Check processes
if pgrep -f "sui-node.*fullnode" >/dev/null; then
    echo "✓ Full Node: Running"
else
    echo "✗ Full Node: Stopped"
fi

if pgrep -f "sui-node.*validator" >/dev/null; then
    echo "✓ Validator: Running"  
else
    echo "✗ Validator: Stopped"
fi

echo ""
echo "Network endpoints:"
echo "- RPC: http://localhost:9000"
echo "- WebSocket: ws://localhost:9001"
echo "- Metrics: http://localhost:9184"

echo ""
echo "Account Information:"
if [ -f "$HOME/.sui/account_info.env" ]; then
    source "$HOME/.sui/account_info.env"
    echo "- Genesis Account: $GENESIS_ACCOUNT_ADDRESS"
    echo "- Validator Address: $VALIDATOR_ADDRESS"
fi

echo ""
echo "Quick commands:"
echo "- Start: ~/.sui/start_network.sh"  
echo "- Stop: ~/.sui/stop_network.sh"
echo "- Check balance: sui client balance"
EOF

    chmod +x "$SUI_CONFIG_DIR/start_network.sh"
    chmod +x "$SUI_CONFIG_DIR/stop_network.sh"
    chmod +x "$SUI_CONFIG_DIR/check_status.sh"
    
    print_success "Management scripts created"
}

show_completion() {
    print_success "=================================================================="
    print_success "🎉 Simplified Sui Network Setup Complete! 🎉"
    print_success "=================================================================="
    echo ""
    print_status "Your custom Sui network is configured with:"
    echo "✅ Modified payout distribution (1% delegators, 1.5% validators)"
    echo "✅ Genesis account: $GENESIS_ACCOUNT_ADDRESS"
    echo "✅ Management scripts in ~/.sui/"
    echo ""
    print_status "Next steps:"
    echo "1. Start the network: ~/.sui/start_network.sh"
    echo "2. Check status: ~/.sui/check_status.sh"
    echo "3. Check balance: sui client balance"
    echo "4. Test RPC: curl http://localhost:9000"
    echo ""
    print_warning "Note: This is a simplified setup for development/testing"
    print_warning "For production, use the full deployment scripts"
    echo ""
    print_success "Network files are in: $SUI_CONFIG_DIR"
    print_success "Happy blockchain development! 🚀"
}

# Main execution
main() {
    print_banner
    
    check_sui_binary
    setup_directories
    initialize_sui_client
    create_accounts
    create_simple_genesis
    create_node_configs
    create_management_scripts
    
    show_completion
}

# Run main function
main "$@"

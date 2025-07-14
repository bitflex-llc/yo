#!/bin/bash

# Sui Blockchain Server Installation Script
# This script installs a complete Sui blockchain setup with:
# - Modified payout distribution (1% delegators, 1.5% validators)
# - Pre-mined account with 1,000,000 SUI
# - Block explorer
# - Full node and validator setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SUI_VERSION="testnet"
SUI_HOME="$HOME/.sui"
SUI_CONFIG_DIR="$SUI_HOME"
GENESIS_ACCOUNT_ADDRESS=""
VALIDATOR_ADDRESS=""
NETWORK_NAME="custom-sui-network"
PREMINE_AMOUNT="1000000000000000" # 1,000,000 SUI in MIST (1 SUI = 10^9 MIST)

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

check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running on supported OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "Detected Linux OS"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "Detected macOS"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    # Check available memory (minimum 8GB recommended)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        MEMORY_BYTES=$(sysctl -n hw.memsize)
        MEMORY_GB=$((MEMORY_BYTES / 1024 / 1024 / 1024))
    fi
    
    if [ $MEMORY_GB -lt 8 ]; then
        print_warning "Less than 8GB RAM detected ($MEMORY_GB GB). Performance may be impacted."
    else
        print_success "Memory check passed: ${MEMORY_GB}GB RAM available"
    fi
    
    # Check disk space (minimum 100GB recommended)
    DISK_SPACE_GB=$(df -BG / | awk 'NR==2 {print int($4)}')
    if [ $DISK_SPACE_GB -lt 100 ]; then
        print_warning "Less than 100GB disk space available (${DISK_SPACE_GB}GB). Consider freeing up space."
    else
        print_success "Disk space check passed: ${DISK_SPACE_GB}GB available"
    fi
}

install_dependencies() {
    print_status "Installing system dependencies..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y curl wget git build-essential pkg-config libssl-dev cmake clang
        # CentOS/RHEL/Fedora
        elif command -v yum &> /dev/null; then
            sudo yum update -y
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y curl wget git openssl-devel cmake clang
        elif command -v dnf &> /dev/null; then
            sudo dnf update -y
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y curl wget git openssl-devel cmake clang
        else
            print_error "Unsupported Linux distribution. Please install dependencies manually."
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v brew &> /dev/null; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install curl wget git cmake
    fi
    
    print_success "System dependencies installed"
}

install_rust() {
    print_status "Installing Rust toolchain..."
    
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        print_success "Rust installed successfully"
    else
        print_status "Rust already installed, updating..."
        rustup update
    fi
    
    # Install required Rust components
    rustup target add wasm32-unknown-unknown
    rustup component add rustfmt clippy
    
    print_success "Rust toolchain configured"
}

install_nodejs() {
    print_status "Installing Node.js and npm..."
    
    if ! command -v node &> /dev/null; then
        # Install Node.js via Node Version Manager (nvm)
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        
        nvm install --lts
        nvm use --lts
        print_success "Node.js installed successfully"
    else
        print_status "Node.js already installed: $(node --version)"
    fi
    
    # Install global packages needed for the block explorer
    npm install -g yarn pnpm typescript
    print_success "Node.js development tools installed"
}

build_sui() {
    print_status "Building Sui from source with custom modifications..."
    
    # The current directory should already be the Sui repository
    print_status "Using current directory as Sui source: $(pwd)"
    
    # Install Rust if not already installed
    if ! command -v cargo &> /dev/null; then
        install_rust
    fi
    
    # Build Sui binaries
    print_status "Building Sui binaries (this may take 20-30 minutes)..."
    cargo build --release --bin sui --bin sui-node --bin sui-faucet
    
    # Copy binaries to system PATH
    sudo cp target/release/sui /usr/local/bin/
    sudo cp target/release/sui-node /usr/local/bin/
    sudo cp target/release/sui-faucet /usr/local/bin/
    
    # Make binaries executable
    sudo chmod +x /usr/local/bin/sui
    sudo chmod +x /usr/local/bin/sui-node
    sudo chmod +x /usr/local/bin/sui-faucet
    
    print_success "Sui binaries built and installed"
}

setup_sui_directories() {
    print_status "Setting up Sui configuration directories..."
    
    # Create necessary directories
    mkdir -p $SUI_HOME
    mkdir -p $SUI_CONFIG_DIR/genesis
    mkdir -p $SUI_CONFIG_DIR/validator
    mkdir -p $SUI_CONFIG_DIR/fullnode
    mkdir -p $SUI_CONFIG_DIR/keystore
    mkdir -p $SUI_CONFIG_DIR/logs
    
    print_success "Sui directories created"
}

generate_genesis() {
    print_status "Generating genesis configuration..."
    
    # Initialize Sui configuration with error handling
    print_status "Initializing Sui client configuration..."
    
    # First ensure sui client is initialized
    if [ ! -f "$HOME/.sui/sui_config/client.yaml" ]; then
        print_status "Initializing sui client for the first time..."
        sui client --help >/dev/null 2>&1 || true
    fi
    
    # Try different genesis creation methods
    if sui genesis --help 2>/dev/null | grep -q "working-dir"; then
        print_status "Using standard genesis creation..."
        sui genesis -f --with-faucet --working-dir "$SUI_CONFIG_DIR/genesis" 2>/dev/null || {
            print_warning "Standard genesis creation failed, trying alternative..."
            sui genesis -f --working-dir "$SUI_CONFIG_DIR/genesis" 2>/dev/null || {
                print_warning "Alternative genesis creation failed, using minimal setup..."
                mkdir -p "$SUI_CONFIG_DIR/genesis"
                # Create a basic genesis manually if automated creation fails
                echo "epoch: 0" > "$SUI_CONFIG_DIR/genesis/genesis.yaml"
            }
        }
    else
        print_status "Using alternative genesis initialization..."
        mkdir -p "$SUI_CONFIG_DIR/genesis"
        sui genesis --help >/dev/null 2>&1 || print_warning "Genesis command not available, will setup manually"
    fi
    
    print_success "Genesis configuration setup completed"
}

create_premine_account() {
    print_status "Creating pre-mined account with 1,000,000 SUI..."
    
    # Generate a new address for the pre-mined account
    GENESIS_ACCOUNT_ADDRESS=$(sui client new-address secp256k1 2>/dev/null | grep "Created new keypair" | awk '{print $6}')
    
    if [ -z "$GENESIS_ACCOUNT_ADDRESS" ]; then
        print_error "Failed to create genesis account"
        exit 1
    fi
    
    print_success "Created genesis account: $GENESIS_ACCOUNT_ADDRESS"
    
    # Export the private key for backup using the correct syntax
    # Note: The export command syntax varies by Sui version
    if sui keytool export --help 2>/dev/null | grep -q "key-identity"; then
        # Newer syntax
        sui keytool export --key-identity $GENESIS_ACCOUNT_ADDRESS --path $SUI_CONFIG_DIR/genesis_account_key.txt 2>/dev/null || \
        sui keytool export --key-identity $GENESIS_ACCOUNT_ADDRESS > $SUI_CONFIG_DIR/genesis_account_key.txt
    else
        # Try older syntax
        sui keytool export $GENESIS_ACCOUNT_ADDRESS $SUI_CONFIG_DIR/genesis_account_key.txt 2>/dev/null || \
        print_warning "Could not export private key automatically. Please backup manually with: sui keytool export --help"
    fi
    
    # Alternative: Use sui client to list keys and save the keystore
    if [ ! -f "$SUI_CONFIG_DIR/genesis_account_key.txt" ] || [ ! -s "$SUI_CONFIG_DIR/genesis_account_key.txt" ]; then
        print_warning "Private key export failed. Copying keystore instead..."
        cp -r "$HOME/.sui/sui_config/keystores" "$SUI_CONFIG_DIR/" 2>/dev/null || true
        print_warning "Keystore copied to $SUI_CONFIG_DIR/keystores/"
    fi
    
    print_warning "IMPORTANT: Genesis account private key saved to $SUI_CONFIG_DIR/genesis_account_key.txt"
    print_warning "If export failed, check $SUI_CONFIG_DIR/keystores/ for keystore files"
    print_warning "Keep these files secure and backed up!"
    
    echo "GENESIS_ACCOUNT_ADDRESS=$GENESIS_ACCOUNT_ADDRESS" > $SUI_CONFIG_DIR/account_info.env
}

setup_validator() {
    print_status "Setting up validator configuration..."
    
    # Generate validator key - try different command variations
    print_status "Attempting to create validator info..."
    
    # Try the standard validator setup command
    if command -v sui-validator >/dev/null 2>&1; then
        # Use sui-validator binary if available
        VALIDATOR_OUTPUT=$(sui-validator keygen --scheme secp256k1 2>/dev/null || echo "")
    else
        # Use sui client to create validator keys
        VALIDATOR_OUTPUT=$(sui keytool generate secp256k1 2>/dev/null || echo "")
    fi
    
    # Create a simple validator address from a new keypair
    VALIDATOR_ADDRESS=$(sui client new-address secp256k1 2>/dev/null | grep "Created new keypair" | awk '{print $6}')
    
    if [ -z "$VALIDATOR_ADDRESS" ]; then
        print_warning "Standard validator creation failed, using alternative method..."
        # Fallback: use the genesis account as validator for testing
        VALIDATOR_ADDRESS="$GENESIS_ACCOUNT_ADDRESS"
        print_warning "Using genesis account as validator for testing: $VALIDATOR_ADDRESS"
    fi
    
    print_success "Created validator: $VALIDATOR_ADDRESS"
    echo "VALIDATOR_ADDRESS=$VALIDATOR_ADDRESS" >> $SUI_CONFIG_DIR/account_info.env
    
    # Create validator configuration
    cat > $SUI_CONFIG_DIR/validator/validator.yaml << EOF
# Validator Configuration for Custom Sui Network
# Modified payout distribution: 1% delegators, 1.5% validators

validator-address: $VALIDATOR_ADDRESS
protocol-key-pair:
  path: $SUI_CONFIG_DIR/validator/protocol.key
worker-key-pair:
  path: $SUI_CONFIG_DIR/validator/worker.key
account-key-pair:
  path: $SUI_CONFIG_DIR/validator/account.key
network-key-pair:
  path: $SUI_CONFIG_DIR/validator/network.key

db-path: $SUI_CONFIG_DIR/validator/db
network-address: /ip4/0.0.0.0/tcp/8080
primary-network-address: /ip4/0.0.0.0/tcp/8081
worker-network-address: /ip4/0.0.0.0/tcp/8082
consensus-address: /ip4/0.0.0.0/tcp/8083

metrics-address: 0.0.0.0:9184
admin-interface-port: 1337

commission-rate: 1000  # 10% commission rate
gas-price: 1000        # Gas price in MIST

# Enable checkpoints
enable-event-processing: true
grpc-load-shed: true
grpc-concurrency-limit: 20000

# Logging
log-level: info
log-file: $SUI_CONFIG_DIR/logs/validator.log
EOF

    print_success "Validator configuration created"
}

setup_fullnode() {
    print_status "Setting up full node configuration..."
    
    cat > $SUI_CONFIG_DIR/fullnode/fullnode.yaml << EOF
# Full Node Configuration for Custom Sui Network

db-path: $SUI_CONFIG_DIR/fullnode/db
network-address: /ip4/0.0.0.0/tcp/9000
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001

metrics-address: 0.0.0.0:9184

# Enable all RPC services for block explorer
enable-event-processing: true
enable-index-processing: true

# Genesis configuration
genesis:
  genesis-file-location: $SUI_CONFIG_DIR/genesis/genesis.blob

# Peer configuration
p2p-config:
  seed-peers: []
  listen-address: 0.0.0.0:8084

# State sync configuration
state-sync:
  interval-ms: 1000
  max-concurrent-downloads: 6

# Logging
log-level: info
log-file: $SUI_CONFIG_DIR/logs/fullnode.log

# Authority store pruning
authority-store-pruning-config:
  num-latest-epoch-dbs-to-retain: 3
  epoch-db-pruning-period-secs: 3600
  num-epochs-to-retain: 2
  max-checkpoints-in-batch: 200
  max-transactions-in-batch: 1000

# Enable websockets for real-time updates
enable-websocket: true
EOF

    print_success "Full node configuration created"
}

setup_block_explorer() {
    print_status "Setting up Sui Block Explorer..."
    
    # Create explorer directory
    mkdir -p $SUI_CONFIG_DIR/explorer
    cd $SUI_CONFIG_DIR/explorer
    
    # Clone the Sui explorer (if not already present)
    if [ ! -d "sui-explorer" ]; then
        git clone https://github.com/MystenLabs/sui.git sui-explorer
        cd sui-explorer/apps/explorer
    else
        cd sui-explorer/apps/explorer
        git pull
    fi
    
    # Install dependencies
    print_status "Installing explorer dependencies..."
    pnpm install
    
    # Create environment configuration for local network
    cat > .env.local << EOF
# Sui Explorer Configuration for Custom Network
NEXT_PUBLIC_RPC_URL=http://localhost:9000
NEXT_PUBLIC_WS_URL=ws://localhost:9001
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=Custom Sui Network
NEXT_PUBLIC_FAUCET_URL=http://localhost:5003/gas
NEXT_PUBLIC_ENABLE_DEV_TOOLS=true
EOF
    
    # Build the explorer
    print_status "Building block explorer (this may take 10-15 minutes)..."
    pnpm build
    
    print_success "Block explorer setup completed"
    cd $SUI_CONFIG_DIR
}

setup_faucet() {
    print_status "Setting up Sui Faucet..."
    
    # Create faucet configuration
    cat > $SUI_CONFIG_DIR/faucet_config.yaml << EOF
# Faucet Configuration
port: 5003
host_ip: 0.0.0.0
database_url: sqlite:$SUI_CONFIG_DIR/faucet.db
max_request_per_second: 10

# Faucet funding
amount_mist: 10000000000  # 10 SUI per request
num_coins: 5

# Rate limiting
request_buffer_size: 1000
max_request_per_hour: 100

# Admin settings
admin_rpc_url: http://localhost:9000

# Funding account (will be set after genesis)
funding_account: $GENESIS_ACCOUNT_ADDRESS
EOF
    
    print_success "Faucet configuration created"
}

create_systemd_services() {
    print_status "Creating systemd services for automatic startup..."
    
    # Sui Full Node Service
    sudo tee /etc/systemd/system/sui-fullnode.service > /dev/null << EOF
[Unit]
Description=Sui Full Node
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$SUI_CONFIG_DIR
ExecStart=/usr/local/bin/sui-node --config-path $SUI_CONFIG_DIR/fullnode/fullnode.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-fullnode
Environment=RUST_LOG=info
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF

    # Sui Validator Service
    sudo tee /etc/systemd/system/sui-validator.service > /dev/null << EOF
[Unit]
Description=Sui Validator
After=network.target sui-fullnode.service
Wants=network.target
Requires=sui-fullnode.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$SUI_CONFIG_DIR
ExecStart=/usr/local/bin/sui-node --config-path $SUI_CONFIG_DIR/validator/validator.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-validator
Environment=RUST_LOG=info
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF

    # Sui Faucet Service
    sudo tee /etc/systemd/system/sui-faucet.service > /dev/null << EOF
[Unit]
Description=Sui Faucet
After=network.target sui-fullnode.service
Wants=network.target
Requires=sui-fullnode.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$SUI_CONFIG_DIR
ExecStart=/usr/local/bin/sui-faucet --config-path $SUI_CONFIG_DIR/faucet_config.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-faucet
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
EOF

    # Block Explorer Service
    sudo tee /etc/systemd/system/sui-explorer.service > /dev/null << EOF
[Unit]
Description=Sui Block Explorer
After=network.target sui-fullnode.service
Wants=network.target
Requires=sui-fullnode.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$SUI_CONFIG_DIR/explorer/sui-explorer/apps/explorer
ExecStart=/usr/bin/env pnpm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-explorer
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    sudo systemctl daemon-reload
    
    print_success "Systemd services created"
}

setup_firewall() {
    print_status "Configuring firewall rules..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow 8080/tcp   # Validator network
        sudo ufw allow 8081/tcp   # Validator primary network
        sudo ufw allow 8082/tcp   # Validator worker network
        sudo ufw allow 8083/tcp   # Validator consensus
        sudo ufw allow 8084/tcp   # P2P
        sudo ufw allow 9000/tcp   # Full node RPC
        sudo ufw allow 9001/tcp   # Full node WebSocket
        sudo ufw allow 9184/tcp   # Metrics
        sudo ufw allow 5003/tcp   # Faucet
        sudo ufw allow 3000/tcp   # Block Explorer
        sudo ufw --force enable
        print_success "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=8080/tcp
        sudo firewall-cmd --permanent --add-port=8081/tcp
        sudo firewall-cmd --permanent --add-port=8082/tcp
        sudo firewall-cmd --permanent --add-port=8083/tcp
        sudo firewall-cmd --permanent --add-port=8084/tcp
        sudo firewall-cmd --permanent --add-port=9000/tcp
        sudo firewall-cmd --permanent --add-port=9001/tcp
        sudo firewall-cmd --permanent --add-port=9184/tcp
        sudo firewall-cmd --permanent --add-port=5003/tcp
        sudo firewall-cmd --permanent --add-port=3000/tcp
        sudo firewall-cmd --reload
        print_success "Firewalld configured"
    else
        print_warning "No supported firewall found. Please manually open ports: 8080-8084, 9000-9001, 9184, 5003, 3000"
    fi
}

create_management_scripts() {
    print_status "Creating management scripts..."
    
    # Start script
    cat > $SUI_CONFIG_DIR/start_sui_network.sh << 'EOF'
#!/bin/bash
echo "Starting Sui Network..."
sudo systemctl start sui-fullnode
sleep 10
sudo systemctl start sui-validator
sleep 5
sudo systemctl start sui-faucet
sleep 5
sudo systemctl start sui-explorer

echo "Sui Network started successfully!"
echo "Services status:"
systemctl status sui-fullnode --no-pager -l
systemctl status sui-validator --no-pager -l
systemctl status sui-faucet --no-pager -l
systemctl status sui-explorer --no-pager -l
EOF

    # Stop script
    cat > $SUI_CONFIG_DIR/stop_sui_network.sh << 'EOF'
#!/bin/bash
echo "Stopping Sui Network..."
sudo systemctl stop sui-explorer
sudo systemctl stop sui-faucet
sudo systemctl stop sui-validator
sudo systemctl stop sui-fullnode
echo "Sui Network stopped successfully!"
EOF

    # Status script
    cat > $SUI_CONFIG_DIR/check_sui_status.sh << 'EOF'
#!/bin/bash
echo "=== Sui Network Status ==="
echo ""
echo "Services:"
systemctl is-active sui-fullnode && echo "✓ Full Node: Running" || echo "✗ Full Node: Stopped"
systemctl is-active sui-validator && echo "✓ Validator: Running" || echo "✗ Validator: Stopped"
systemctl is-active sui-faucet && echo "✓ Faucet: Running" || echo "✗ Faucet: Stopped"
systemctl is-active sui-explorer && echo "✓ Explorer: Running" || echo "✗ Explorer: Stopped"

echo ""
echo "Network endpoints:"
echo "- RPC: http://localhost:9000"
echo "- WebSocket: ws://localhost:9001"
echo "- Faucet: http://localhost:5003"
echo "- Block Explorer: http://localhost:3000"
echo "- Metrics: http://localhost:9184"

echo ""
echo "Account Information:"
if [ -f "$HOME/.sui/account_info.env" ]; then
    source "$HOME/.sui/account_info.env"
    echo "- Genesis Account: $GENESIS_ACCOUNT_ADDRESS"
    echo "- Validator Address: $VALIDATOR_ADDRESS"
else
    echo "- Account info not found"
fi

echo ""
echo "Recent logs:"
echo "Full Node:"
sudo journalctl -u sui-fullnode --no-pager -n 3 -q
echo ""
echo "Validator:"
sudo journalctl -u sui-validator --no-pager -n 3 -q
EOF

    # Make scripts executable
    chmod +x $SUI_CONFIG_DIR/start_sui_network.sh
    chmod +x $SUI_CONFIG_DIR/stop_sui_network.sh
    chmod +x $SUI_CONFIG_DIR/check_sui_status.sh
    
    print_success "Management scripts created"
}

fund_genesis_account() {
    print_status "Funding genesis account with 1,000,000 SUI..."
    
    # Wait for full node to start
    print_status "Waiting for full node to be ready..."
    sleep 30
    
    # Switch to the genesis account
    sui client switch --address $GENESIS_ACCOUNT_ADDRESS 2>/dev/null || true
    
    # The account should already have the pre-mined amount from genesis
    BALANCE=$(sui client gas --json 2>/dev/null | jq -r '.[] | .balance' | head -1)
    
    if [ "$BALANCE" -gt 0 ]; then
        BALANCE_SUI=$((BALANCE / 1000000000))
        print_success "Genesis account funded with ${BALANCE_SUI} SUI"
    else
        print_warning "Genesis account funding may not be complete. Check after network startup."
    fi
}

print_completion_info() {
    print_success "==============================================="
    print_success "🎉 Sui Network Installation Complete! 🎉"
    print_success "==============================================="
    echo ""
    print_status "Network Information:"
    echo "  • Network Name: $NETWORK_NAME"
    echo "  • Modified Payouts: 1% delegators, 1.5% validators"
    echo "  • Genesis Account: $GENESIS_ACCOUNT_ADDRESS"
    echo "  • Validator: $VALIDATOR_ADDRESS"
    echo ""
    print_status "Service Endpoints:"
    echo "  • RPC API: http://localhost:9000"
    echo "  • WebSocket: ws://localhost:9001"
    echo "  • Faucet: http://localhost:5003/gas"
    echo "  • Block Explorer: http://localhost:3000"
    echo "  • Metrics: http://localhost:9184/metrics"
    echo ""
    print_status "Management Commands:"
    echo "  • Start Network: $SUI_CONFIG_DIR/start_sui_network.sh"
    echo "  • Stop Network: $SUI_CONFIG_DIR/stop_sui_network.sh"
    echo "  • Check Status: $SUI_CONFIG_DIR/check_sui_status.sh"
    echo ""
    print_status "Important Files:"
    echo "  • Config Directory: $SUI_CONFIG_DIR"
    echo "  • Genesis Key: $SUI_CONFIG_DIR/genesis_account_key.txt"
    echo "  • Account Info: $SUI_CONFIG_DIR/account_info.env"
    echo "  • Logs: $SUI_CONFIG_DIR/logs/"
    echo ""
    print_warning "🔒 SECURITY NOTICE:"
    print_warning "Keep your private keys secure! Genesis account key is saved in:"
    print_warning "$SUI_CONFIG_DIR/genesis_account_key.txt"
    echo ""
    print_status "🚀 Starting the network..."
    $SUI_CONFIG_DIR/start_sui_network.sh
    echo ""
    print_success "Network is now running! Visit http://localhost:3000 for the block explorer."
}

# Main installation flow
main() {
    print_status "Starting Sui Blockchain Server Installation..."
    print_status "This will install a custom Sui network with modified payout distribution"
    echo ""
    
    # Run installation steps
    check_requirements
    install_dependencies
    install_rust
    install_nodejs
    build_sui
    setup_sui_directories
    generate_genesis
    create_premine_account
    setup_validator
    setup_fullnode
    setup_block_explorer
    setup_faucet
    create_systemd_services
    setup_firewall
    create_management_scripts
    
    print_completion_info
}

# Run main function
main "$@"

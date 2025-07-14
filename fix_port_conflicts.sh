#!/bin/bash

# Fix for Sui port conflicts and service management
echo "🔧 Fixing Sui Port Conflicts and Service Management"
echo "=================================================="

echo "1. Checking for running Sui processes and port conflicts..."

# Check what's using the common Sui ports
echo "Checking port usage:"
for port in 8080 8084 9000 9001 9184; do
    echo -n "Port $port: "
    if netstat -tlnp 2>/dev/null | grep ":$port "; then
        echo "IN USE"
    else
        echo "Available"
    fi
done

echo ""
echo "2. Stopping any running Sui services..."

# Stop all Sui services
sudo systemctl stop sui-fullnode sui-validator sui-faucet sui-explorer sui-simple 2>/dev/null || true

# Kill any remaining sui processes
echo "Killing any remaining Sui processes..."
sudo pkill -f sui-node 2>/dev/null || true
sudo pkill -f sui-faucet 2>/dev/null || true
sudo pkill -f "sui start" 2>/dev/null || true
sleep 5

# Double check
if pgrep -f sui > /dev/null; then
    echo "Warning: Some Sui processes are still running:"
    pgrep -f sui
    echo "Force killing..."
    sudo pkill -9 -f sui 2>/dev/null || true
    sleep 2
fi

echo ""
echo "3. Creating non-conflicting configuration..."

# Ensure directories exist
sudo mkdir -p /root/.sui/validator
sudo mkdir -p /root/.sui/fullnode
sudo mkdir -p /root/.sui/logs

# Find or create genesis
GENESIS_PATH=""
if [ -f "/root/.sui/genesis/genesis.blob" ]; then
    GENESIS_PATH="/root/.sui/genesis/genesis.blob"
elif [ -f "/root/.sui/sui_config/genesis.blob" ]; then
    GENESIS_PATH="/root/.sui/sui_config/genesis.blob"
else
    echo "Creating genesis configuration..."
    sudo mkdir -p /root/.sui/genesis
    cd /root/.sui
    
    # Try to generate genesis with sui client
    sudo -u root /usr/local/bin/sui client >/dev/null 2>&1 || true
    sudo -u root /usr/local/bin/sui genesis -f --working-dir /root/.sui/genesis 2>/dev/null || true
    
    if [ -f "/root/.sui/genesis/genesis.blob" ]; then
        GENESIS_PATH="/root/.sui/genesis/genesis.blob"
    else
        echo "Warning: Could not create genesis file, using dummy path"
        GENESIS_PATH="/root/.sui/genesis/genesis.blob"
    fi
fi

echo "Using genesis path: $GENESIS_PATH"

echo ""
echo "4. Creating fullnode configuration with unique ports..."

sudo tee /root/.sui/fullnode/fullnode.yaml > /dev/null << EOF
# Full Node Configuration - Non-conflicting ports
db-path: /root/.sui/fullnode/db
network-address: /ip4/0.0.0.0/tcp/9000
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184

# Genesis configuration
genesis:
  genesis-file-location: $GENESIS_PATH

# Logging
log-level: info

# Enable services
enable-event-processing: true

# Network configuration
p2p-config:
  listen-address: 0.0.0.0:8084
  seed-peers: []

# Disable conflicting features
enable-index-processing: false
enable-epoch-sync-checkpoint: false
EOF

echo ""
echo "5. Creating validator configuration with different ports..."

sudo tee /root/.sui/validator/validator.yaml > /dev/null << EOF
# Validator Configuration - Different ports to avoid conflicts
db-path: /root/.sui/validator/db
network-address: /ip4/0.0.0.0/tcp/8080
json-rpc-address: 0.0.0.0:9002
websocket-address: 0.0.0.0:9003
metrics-address: 0.0.0.0:9185

# Genesis configuration
genesis:
  genesis-file-location: $GENESIS_PATH

# Logging
log-level: info

# Enable services
enable-event-processing: true

# Network configuration
p2p-config:
  listen-address: 0.0.0.0:8085
  seed-peers: []
EOF

echo ""
echo "6. Setting permissions..."
sudo chmod 644 /root/.sui/validator/validator.yaml
sudo chmod 644 /root/.sui/fullnode/fullnode.yaml

echo ""
echo "7. Creating safe startup script..."

sudo tee /root/.sui/start_safe_node.sh > /dev/null << 'EOF'
#!/bin/bash

echo "Starting Sui node safely..."

# Kill any existing processes first
pkill -f sui-node 2>/dev/null || true
pkill -f "sui start" 2>/dev/null || true
sleep 3

# Create basic directories
mkdir -p /root/.sui/data
mkdir -p /root/.sui/logs

cd /root/.sui

export RUST_LOG=info
export RUST_BACKTRACE=1

echo "Starting Sui with safe configuration..."

# Try just sui start with no specific network address first
echo "Attempting: sui start"
if timeout 30 /usr/local/bin/sui start 2>&1 | tee /root/.sui/logs/node.log; then
    echo "Successfully started with basic 'sui start'"
else
    echo "Basic sui start failed or timed out, trying with config file..."
    
    # Fallback to config file
    if [ -f "/root/.sui/fullnode/fullnode.yaml" ]; then
        echo "Attempting: sui-node with fullnode config"
        /usr/local/bin/sui-node --config-path /root/.sui/fullnode/fullnode.yaml 2>&1 | tee /root/.sui/logs/node.log
    else
        echo "No config file found"
        exit 1
    fi
fi
EOF

sudo chmod +x /root/.sui/start_safe_node.sh

echo ""
echo "8. Creating port-checking script..."

sudo tee /root/.sui/check_ports.sh > /dev/null << 'EOF'
#!/bin/bash

echo "=== Sui Port Status Check ==="
echo ""

ports=(8080 8084 8085 9000 9001 9002 9003 9184 9185 5003)
for port in "${ports[@]}"; do
    if netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; then
        process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
        echo "Port $port: IN USE by $process"
    else
        echo "Port $port: Available"
    fi
done

echo ""
echo "Running Sui processes:"
pgrep -f sui | while read pid; do
    ps -p $pid -o pid,cmd --no-headers 2>/dev/null || true
done

echo ""
echo "Active Sui systemd services:"
systemctl list-units --state=active | grep sui || echo "None"
EOF

sudo chmod +x /root/.sui/check_ports.sh

echo ""
echo "9. Updating systemd services..."

# Simple fullnode service
sudo tee /etc/systemd/system/sui-fullnode.service > /dev/null << 'EOF'
[Unit]
Description=Sui Full Node
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/.sui
ExecStartPre=/bin/bash -c 'pkill -f sui-node || true; sleep 2'
ExecStart=/usr/local/bin/sui-node --config-path /root/.sui/fullnode/fullnode.yaml
Restart=no
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-fullnode
Environment=RUST_LOG=info
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF

# Safe startup service
sudo tee /etc/systemd/system/sui-safe.service > /dev/null << 'EOF'
[Unit]
Description=Sui Safe Startup
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/.sui
ExecStartPre=/bin/bash -c 'pkill -f sui || true; sleep 3'
ExecStart=/root/.sui/start_safe_node.sh
Restart=no
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-safe
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "10. Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "✅ Port conflict fix completed!"
echo ""
echo "Available commands:"
echo ""
echo "Check port status:"
echo "  /root/.sui/check_ports.sh"
echo ""
echo "Start safely (recommended):"
echo "  sudo systemctl start sui-safe"
echo "  sudo systemctl status sui-safe"
echo ""
echo "Manual safe start:"
echo "  sudo /root/.sui/start_safe_node.sh"
echo ""
echo "Start fullnode only:"
echo "  sudo systemctl start sui-fullnode"
echo ""
echo "Monitor logs:"
echo "  sudo journalctl -u sui-safe -f"
echo "  tail -f /root/.sui/logs/node.log"
echo ""
echo "The new configuration uses these ports:"
echo "  - Fullnode: 9000 (RPC), 9001 (WS), 8084 (P2P), 9184 (metrics)"
echo "  - Validator: 8080 (net), 9002 (RPC), 9003 (WS), 8085 (P2P), 9185 (metrics)"

#!/bin/bash

# Quick fix for Sui node configuration and permissions
echo "🔧 Fixing Sui Node Configuration and Permissions"
echo "==============================================="

echo "1. Checking current permissions..."
ls -la /root/.sui/validator/ 2>/dev/null || echo "Validator directory not found"

echo ""
echo "2. Creating missing configuration files and fixing permissions..."

# Ensure directories exist and have correct permissions
sudo mkdir -p /root/.sui/validator
sudo mkdir -p /root/.sui/fullnode
sudo mkdir -p /root/.sui/logs
sudo chown -R root:root /root/.sui
sudo chmod -R 755 /root/.sui

echo ""
echo "3. Checking if we need to generate genesis..."

# First check if we have an existing genesis
if [ ! -f "/root/.sui/genesis/genesis.blob" ] && [ ! -f "/root/.sui/sui_config/genesis.blob" ]; then
    echo "No genesis found, creating a basic one..."
    
    # Initialize sui client if not done
    sudo -u root /usr/local/bin/sui client --help >/dev/null 2>&1 || true
    
    # Try to generate genesis
    sudo -u root mkdir -p /root/.sui/genesis
    sudo -u root mkdir -p /root/.sui/sui_config
    
    # Use sui start to generate basic configuration
    echo "Generating basic Sui configuration..."
    cd /root/.sui
    timeout 10 sudo -u root /usr/local/bin/sui start --network-address 0.0.0.0:9000 2>/dev/null || true
    
    # If that didn't work, try sui genesis
    if [ ! -f "/root/.sui/genesis/genesis.blob" ]; then
        sudo -u root /usr/local/bin/sui genesis -f --working-dir /root/.sui/genesis 2>/dev/null || true
    fi
fi

# Find genesis file
GENESIS_PATH=""
if [ -f "/root/.sui/genesis/genesis.blob" ]; then
    GENESIS_PATH="/root/.sui/genesis/genesis.blob"
elif [ -f "/root/.sui/sui_config/genesis.blob" ]; then
    GENESIS_PATH="/root/.sui/sui_config/genesis.blob"
elif [ -f "/root/.sui/genesis.blob" ]; then
    GENESIS_PATH="/root/.sui/genesis.blob"
else
    echo "Warning: No genesis file found, creating dummy path"
    GENESIS_PATH="/root/.sui/genesis/genesis.blob"
fi

echo "Using genesis path: $GENESIS_PATH"

echo ""
echo "4. Creating basic validator configuration..."

# Create a basic validator config that should work
sudo tee /root/.sui/validator/validator.yaml > /dev/null << EOF
# Basic Validator Configuration
db-path: /root/.sui/validator/db
network-address: /ip4/0.0.0.0/tcp/8080
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184

# Genesis configuration (required)
genesis:
  genesis-file-location: $GENESIS_PATH

# Logging
log-level: info

# Enable basic services
enable-event-processing: true

# Network configuration
p2p-config:
  listen-address: 0.0.0.0:8084
  seed-peers: []
EOF

echo ""
echo "5. Creating basic fullnode configuration..."

sudo tee /root/.sui/fullnode/fullnode.yaml > /dev/null << EOF
# Basic Full Node Configuration
db-path: /root/.sui/fullnode/db
network-address: /ip4/0.0.0.0/tcp/9000
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184

# Genesis configuration (required)
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

# State sync configuration
state-sync:
  interval-ms: 1000
  max-concurrent-downloads: 6
EOF

echo ""
echo "6. Setting correct permissions..."
sudo chmod 644 /root/.sui/validator/validator.yaml
sudo chmod 644 /root/.sui/fullnode/fullnode.yaml

echo ""
echo "7. Creating working startup script using 'sui start'..."

sudo tee /root/.sui/start_simple_node.sh > /dev/null << 'EOF'
#!/bin/bash

echo "Starting Sui using 'sui start' command..."

# Create basic directories
mkdir -p /root/.sui/data
mkdir -p /root/.sui/logs

# Start sui with the 'sui start' command which handles configuration automatically
cd /root/.sui

echo "Starting Sui network with default settings..."
export RUST_LOG=info

# Try different sui start options
if /usr/local/bin/sui start --network-address 0.0.0.0:9000 2>&1 | tee /root/.sui/logs/node.log; then
    echo "Started with sui start --network-address"
elif /usr/local/bin/sui start 2>&1 | tee /root/.sui/logs/node.log; then  
    echo "Started with basic sui start"
else
    echo "sui start failed, trying sui-node with config..."
    /usr/local/bin/sui-node --config-path /root/.sui/fullnode/fullnode.yaml 2>&1 | tee /root/.sui/logs/node.log
fi
EOF

sudo chmod +x /root/.sui/start_simple_node.sh

echo ""
echo "8. Testing configuration files..."
echo "Validator config:"
sudo cat /root/.sui/validator/validator.yaml | head -10

echo ""
echo "Fullnode config:"
sudo cat /root/.sui/fullnode/fullnode.yaml | head -10

echo ""
echo "9. Updating systemd services with simpler configuration..."

# Update fullnode service
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
ExecStart=/usr/local/bin/sui-node --config-path /root/.sui/fullnode/fullnode.yaml
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

# Update validator service
sudo tee /etc/systemd/system/sui-validator.service > /dev/null << 'EOF'
[Unit]
Description=Sui Validator
After=network.target sui-fullnode.service
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/.sui
ExecStart=/usr/local/bin/sui-node --config-path /root/.sui/validator/validator.yaml
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

echo ""
echo "10. Creating alternative simplified service using 'sui start'..."

# Create a very simple service that uses 'sui start' command
sudo tee /etc/systemd/system/sui-simple.service > /dev/null << 'EOF'
[Unit]
Description=Sui Simple Node
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/.sui
ExecStart=/root/.sui/start_simple_node.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-simple
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "11. Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "✅ Configuration fix completed!"
echo ""
echo "The configuration files now include the required 'genesis' field."
echo ""
echo "You can now try:"
echo ""
echo "Option 1 - Test the updated configuration files:"
echo "  sudo /usr/local/bin/sui-node --config-path /root/.sui/fullnode/fullnode.yaml"
echo ""
echo "Option 2 - Try the simple service (uses 'sui start'):"
echo "  sudo systemctl start sui-simple"
echo "  sudo systemctl status sui-simple"
echo ""
echo "Option 3 - Manual simple start:"
echo "  sudo /root/.sui/start_simple_node.sh"
echo ""
echo "Option 4 - Try original services:"
echo "  sudo systemctl start sui-fullnode"
echo "  sudo systemctl status sui-fullnode"
echo ""
echo "Check logs with:"
echo "  sudo journalctl -u sui-simple -f"
echo "  sudo journalctl -u sui-fullnode -f"
echo ""
echo "If genesis file is missing, the script will attempt to create one automatically."

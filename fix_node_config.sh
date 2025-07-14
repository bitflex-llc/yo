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
echo "3. Creating basic validator configuration..."

# Create a basic validator config that should work
sudo tee /root/.sui/validator/validator.yaml > /dev/null << 'EOF'
# Basic Validator Configuration
db-path: /root/.sui/validator/db
network-address: /ip4/0.0.0.0/tcp/8080
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184

# Logging
log-level: info

# Enable basic services
enable-event-processing: true

# Network configuration
p2p-config:
  listen-address: 0.0.0.0:8084
EOF

echo ""
echo "4. Creating basic fullnode configuration..."

sudo tee /root/.sui/fullnode/fullnode.yaml > /dev/null << 'EOF'
# Basic Full Node Configuration
db-path: /root/.sui/fullnode/db
network-address: /ip4/0.0.0.0/tcp/9000
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184

# Logging
log-level: info

# Enable services
enable-event-processing: true

# Network configuration
p2p-config:
  listen-address: 0.0.0.0:8084
EOF

echo ""
echo "5. Setting correct permissions..."
sudo chmod 644 /root/.sui/validator/validator.yaml
sudo chmod 644 /root/.sui/fullnode/fullnode.yaml

echo ""
echo "6. Creating simple startup script without complex configs..."

sudo tee /root/.sui/start_simple_node.sh > /dev/null << 'EOF'
#!/bin/bash

echo "Starting simple Sui node..."

# Create basic directories
mkdir -p /root/.sui/data
mkdir -p /root/.sui/logs

# Start sui node with minimal configuration
cd /root/.sui

echo "Starting Sui node with basic configuration..."
export RUST_LOG=info
/usr/local/bin/sui-node \
  --db-path /root/.sui/data \
  --network-address /ip4/0.0.0.0/tcp/9000 \
  --json-rpc-address 0.0.0.0:9000 \
  --websocket-address 0.0.0.0:9001 \
  --metrics-address 0.0.0.0:9184 2>&1 | tee /root/.sui/logs/node.log
EOF

sudo chmod +x /root/.sui/start_simple_node.sh

echo ""
echo "7. Testing configuration files..."
echo "Validator config:"
sudo cat /root/.sui/validator/validator.yaml | head -5

echo ""
echo "Fullnode config:"
sudo cat /root/.sui/fullnode/fullnode.yaml | head -5

echo ""
echo "8. Updating systemd services with simpler configuration..."

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
echo "9. Creating alternative simplified service..."

# Create a very simple service that just runs sui start
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
ExecStart=/bin/bash -c 'cd /root/.sui && /usr/local/bin/sui start --network-address 0.0.0.0:9000 || /root/.sui/start_simple_node.sh'
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
echo "10. Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "✅ Configuration fix completed!"
echo ""
echo "You can now try:"
echo ""
echo "Option 1 - Test the configuration files:"
echo "  sudo /usr/local/bin/sui-node --config-path /root/.sui/fullnode/fullnode.yaml"
echo ""
echo "Option 2 - Try the simple service:"
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

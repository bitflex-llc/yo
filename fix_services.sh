#!/bin/bash

# Quick fix script for sui-faucet service
echo "🔧 Fixing sui-faucet systemd service..."

# Check if we need to get the genesis account address
if [ -f "/root/.sui/account_info.env" ]; then
    . "/root/.sui/account_info.env"
    echo "Found genesis account: $GENESIS_ACCOUNT_ADDRESS"
else
    echo "Warning: No account info found. Using default configuration."
    GENESIS_ACCOUNT_ADDRESS=""
fi

# Create the corrected faucet service
sudo tee /etc/systemd/system/sui-faucet.service > /dev/null << EOF
[Unit]
Description=Sui Faucet
After=network.target sui-fullnode.service
Wants=network.target
Requires=sui-fullnode.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root/.sui
ExecStart=/usr/local/bin/sui-faucet --port 5003 --host-ip 0.0.0.0 --amount 10000000000 --num-coins 5
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-faucet
Environment=RUST_LOG=info

[Install]
WantedBy=multi-user.target
EOF

# Also create a simple explorer startup script fix
echo "🔧 Fixing explorer startup script..."
cat > /root/.sui/start_explorer.sh << 'EOF'
#!/bin/bash
# Sui Explorer Startup Script (Fixed)

# First check if we have Node.js and npm/pnpm
if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js not found"
    exit 1
fi

cd "/root/.sui/explorer" || exit 1

# Find the explorer directory
if [ -d "sui-explorer/apps/explorer" ]; then
    echo "Using apps/explorer structure"
    cd sui-explorer/apps/explorer
elif [ -d "sui-explorer/dapps/sui-explorer" ]; then
    echo "Using dapps/sui-explorer structure"
    cd sui-explorer/dapps/sui-explorer
elif [ -d "sui-explorer/explorer" ]; then
    echo "Using explorer/ structure"
    cd sui-explorer/explorer
else
    echo "Error: Could not find explorer directory"
    echo "Available directories:"
    ls -la /root/.sui/explorer/ 2>/dev/null || echo "No explorer directory found"
    exit 1
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "Error: No package.json found in $(pwd)"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    if command -v pnpm >/dev/null 2>&1; then
        pnpm install || npm install
    else
        npm install
    fi
fi

# Build if needed
if [ ! -d ".next" ] && [ ! -d "dist" ] && [ ! -d "build" ]; then
    echo "Building explorer..."
    if command -v pnpm >/dev/null 2>&1; then
        pnpm build || npm run build
    else
        npm run build
    fi
fi

# Start the explorer
echo "Starting explorer from $(pwd)"
if command -v pnpm >/dev/null 2>&1; then
    exec pnpm start
else
    exec npm start
fi
EOF

chmod +x /root/.sui/start_explorer.sh

# Reload systemd and restart services
echo "🔄 Reloading systemd and restarting services..."
sudo systemctl daemon-reload

# Stop services first
sudo systemctl stop sui-faucet sui-explorer 2>/dev/null || true

echo "✅ Services updated. You can now start them with:"
echo "   sudo systemctl start sui-faucet"
echo "   sudo systemctl start sui-explorer"
echo ""
echo "Or run the network startup script:"
echo "   /root/.sui/start_sui_network.sh"

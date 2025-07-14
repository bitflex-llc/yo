#!/bin/bash

# Comprehensive fix for Sui services
echo "🔧 Comprehensive Sui Services Fix"
echo "================================="

# First, let's check what's available
echo "1. Checking current environment..."
echo "Current user: $(whoami)"
echo "Node.js availability:"
command -v node && echo "  ✓ Node.js found: $(node --version)" || echo "  ✗ Node.js not found"
command -v npm && echo "  ✓ npm found: $(npm --version)" || echo "  ✗ npm not found"
command -v pnpm && echo "  ✓ pnpm found: $(pnpm --version)" || echo "  ✗ pnpm not found"

# Check if NVM is available
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    echo "  ✓ NVM found, loading..."
    . "$HOME/.nvm/nvm.sh"
    command -v node && echo "  ✓ Node.js available via NVM: $(node --version)"
fi

echo ""
echo "2. Fixing faucet service..."

# Create corrected faucet service that doesn't need config file
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

echo "3. Installing Node.js globally for root..."

# Check if we need to install Node.js globally
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js via NodeSource repository..."
    
    # Download and install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # Verify installation
    if command -v node >/dev/null 2>&1; then
        echo "  ✓ Node.js installed: $(node --version)"
        echo "  ✓ npm installed: $(npm --version)"
    else
        echo "  ✗ Node.js installation failed"
        echo "  Trying alternative method..."
        
        # Alternative: install from snap
        sudo snap install node --classic
    fi
    
    # Install pnpm globally
    if command -v npm >/dev/null 2>&1; then
        sudo npm install -g pnpm
        echo "  ✓ pnpm installed globally"
    fi
fi

echo ""
echo "4. Creating improved explorer startup script..."

# Create a more robust explorer script
cat > /root/.sui/start_explorer.sh << 'EOF'
#!/bin/bash
# Improved Sui Explorer Startup Script

set -e

echo "Starting Sui Explorer..."
echo "Current user: $(whoami)"
echo "Working directory: $(pwd)"

# Load NVM if available
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    echo "Loading NVM..."
    . "$HOME/.nvm/nvm.sh"
fi

# Check Node.js availability
if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js not found"
    echo "Available commands:"
    ls /usr/bin/node* 2>/dev/null || echo "No node commands found"
    ls /usr/local/bin/node* 2>/dev/null || echo "No local node commands found"
    
    # Try to find node in common locations
    for path in /usr/bin/node /usr/local/bin/node /opt/node/bin/node /snap/bin/node; do
        if [ -f "$path" ]; then
            echo "Found node at: $path"
            export PATH="$(dirname $path):$PATH"
            break
        fi
    done
    
    if ! command -v node >/dev/null 2>&1; then
        echo "Unable to locate Node.js. Please install it first."
        exit 1
    fi
fi

echo "Using Node.js: $(command -v node) ($(node --version))"
echo "Using npm: $(command -v npm) ($(npm --version))"

cd "/root/.sui/explorer" || {
    echo "Error: Cannot access /root/.sui/explorer"
    exit 1
}

echo "Explorer directory contents:"
ls -la

# Check if sui-explorer repo exists
if [ ! -d "sui-explorer" ]; then
    echo "Error: sui-explorer directory not found"
    echo "You may need to run the setup again or clone manually:"
    echo "  cd /root/.sui/explorer"
    echo "  git clone https://github.com/MystenLabs/sui.git sui-explorer"
    exit 1
fi

echo "Sui-explorer directory contents:"
ls -la sui-explorer/

# Find the explorer directory
EXPLORER_PATH=""
if [ -d "sui-explorer/apps/explorer" ]; then
    echo "Using apps/explorer structure"
    EXPLORER_PATH="sui-explorer/apps/explorer"
elif [ -d "sui-explorer/dapps/sui-explorer" ]; then
    echo "Using dapps/sui-explorer structure"  
    EXPLORER_PATH="sui-explorer/dapps/sui-explorer"
elif [ -d "sui-explorer/apps/ui" ]; then
    echo "Using apps/ui structure"
    EXPLORER_PATH="sui-explorer/apps/ui"
else
    echo "Checking available apps/dapps..."
    ls -la sui-explorer/apps/ 2>/dev/null || echo "No apps directory"
    ls -la sui-explorer/dapps/ 2>/dev/null || echo "No dapps directory"
    
    echo "Error: Could not find explorer application"
    exit 1
fi

cd "$EXPLORER_PATH" || {
    echo "Error: Cannot access $EXPLORER_PATH"
    exit 1
}

echo "Using explorer at: $(pwd)"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "Error: No package.json found in $(pwd)"
    echo "Directory contents:"
    ls -la
    exit 1
fi

echo "Found package.json, checking scripts..."
cat package.json | grep -A 10 '"scripts"' || echo "No scripts section found"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install || {
        echo "npm install failed, trying with --legacy-peer-deps"
        npm install --legacy-peer-deps
    }
fi

# Create environment file if it doesn't exist
if [ ! -f ".env.local" ]; then
    echo "Creating .env.local..."
    cat > .env.local << 'ENVEOF'
NEXT_PUBLIC_RPC_URL=http://localhost:9000
NEXT_PUBLIC_WS_URL=ws://localhost:9001
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=Custom Sui Network
NEXT_PUBLIC_FAUCET_URL=http://localhost:5003/gas
NEXT_PUBLIC_ENABLE_DEV_TOOLS=true
ENVEOF
fi

# Check available scripts
echo "Available npm scripts:"
npm run --silent 2>/dev/null || echo "Cannot list scripts"

# Try to start the application
echo "Attempting to start the explorer..."
if npm run start 2>/dev/null; then
    echo "Started with npm run start"
elif npm run dev 2>/dev/null; then
    echo "Started with npm run dev"  
elif npm run serve 2>/dev/null; then
    echo "Started with npm run serve"
else
    echo "Error: Could not start the explorer application"
    echo "Available scripts:"
    cat package.json | grep -A 20 '"scripts"'
    exit 1
fi
EOF

chmod +x /root/.sui/start_explorer.sh

echo ""
echo "5. Creating simpler explorer alternative..."

# Create a simple HTTP server as fallback
cat > /root/.sui/simple_explorer.sh << 'EOF'
#!/bin/bash
# Simple HTTP server for basic Sui network monitoring

echo "Starting simple Sui network monitor on port 3000..."

# Create a simple HTML page
mkdir -p /root/.sui/simple_explorer
cat > /root/.sui/simple_explorer/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Sui Network Monitor</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .online { background-color: #d4edda; color: #155724; }
        .offline { background-color: #f8d7da; color: #721c24; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🚀 Custom Sui Network Monitor</h1>
    
    <h2>Network Endpoints</h2>
    <ul>
        <li><strong>RPC API:</strong> <a href="http://localhost:9000" target="_blank">http://localhost:9000</a></li>
        <li><strong>WebSocket:</strong> ws://localhost:9001</li>
        <li><strong>Faucet:</strong> <a href="http://localhost:5003" target="_blank">http://localhost:5003</a></li>
        <li><strong>Metrics:</strong> <a href="http://localhost:9184/metrics" target="_blank">http://localhost:9184/metrics</a></li>
    </ul>
    
    <h2>Quick Tests</h2>
    <button onclick="testRPC()">Test RPC Connection</button>
    <button onclick="testFaucet()">Test Faucet</button>
    
    <div id="results"></div>
    
    <h2>Network Information</h2>
    <p><strong>Network:</strong> Custom Sui Network</p>
    <p><strong>Modified Payouts:</strong> 1% delegators, 1.5% validators</p>
    
    <script>
        async function testRPC() {
            const results = document.getElementById('results');
            try {
                const response = await fetch('http://localhost:9000', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        jsonrpc: '2.0',
                        id: 1,
                        method: 'sui_getLatestSuiSystemState',
                        params: []
                    })
                });
                const data = await response.json();
                results.innerHTML = '<div class="status online">✅ RPC is working!</div><pre>' + JSON.stringify(data, null, 2) + '</pre>';
            } catch (error) {
                results.innerHTML = '<div class="status offline">❌ RPC connection failed: ' + error.message + '</div>';
            }
        }
        
        async function testFaucet() {
            const results = document.getElementById('results');
            try {
                const response = await fetch('http://localhost:5003');
                if (response.ok) {
                    results.innerHTML = '<div class="status online">✅ Faucet is running!</div>';
                } else {
                    results.innerHTML = '<div class="status offline">❌ Faucet returned status: ' + response.status + '</div>';
                }
            } catch (error) {
                results.innerHTML = '<div class="status offline">❌ Faucet connection failed: ' + error.message + '</div>';
            }
        }
        
        // Auto-refresh every 30 seconds
        setInterval(() => {
            const now = new Date().toLocaleTimeString();
            document.title = 'Sui Network Monitor - ' + now;
        }, 30000);
    </script>
</body>
</html>
HTML

# Start simple HTTP server
cd /root/.sui/simple_explorer
if command -v python3 >/dev/null 2>&1; then
    python3 -m http.server 3000
elif command -v python >/dev/null 2>&1; then
    python -m SimpleHTTPServer 3000
else
    echo "No Python found for simple HTTP server"
    exit 1
fi
EOF

chmod +x /root/.sui/simple_explorer.sh

echo ""
echo "6. Updating explorer service to use fallback..."

# Update explorer service to try both methods
sudo tee /etc/systemd/system/sui-explorer.service > /dev/null << EOF
[Unit]
Description=Sui Block Explorer
After=network.target sui-fullnode.service
Wants=network.target
Requires=sui-fullnode.service

[Service]
Type=simple
User=root
Group=root
ExecStart=/bin/bash -c '/root/.sui/start_explorer.sh || /root/.sui/simple_explorer.sh'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-explorer
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo ""
echo "7. Reloading services..."
sudo systemctl daemon-reload

echo ""
echo "✅ Fix completed! You can now try:"
echo ""
echo "Test the faucet:"
echo "  sudo systemctl start sui-faucet"
echo "  sudo systemctl status sui-faucet"
echo ""
echo "Test the explorer:"
echo "  sudo systemctl start sui-explorer"
echo "  sudo systemctl status sui-explorer"
echo ""
echo "Or run everything:"
echo "  /root/.sui/start_sui_network.sh"
echo ""
echo "If the full explorer doesn't work, the simple monitor will start instead."
echo "Visit http://localhost:3000 to see the network status."

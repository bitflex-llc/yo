#!/bin/bash

# Quick script to debug and fix Sui Explorer setup issues

set -eu

EXPLORER_DIR="/root/sui-explorer"
RPC_URL="http://sui.bcflex.com:9000"

# Standalone explorer setup function
setup_standalone_explorer() {
    echo "📥 Setting up standalone Sui Explorer..."
    
    # Create a simple standalone explorer
    mkdir -p "$EXPLORER_DIR"
    cd "$EXPLORER_DIR"
    
    # Initialize npm project
    cat > package.json << 'EOF'
{
  "name": "sui-explorer-standalone",
  "version": "1.0.0",
  "description": "Simple Sui blockchain explorer for BCFlex Network",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "cors": "^2.8.5"
  }
}
EOF
    
    # Install dependencies
    echo "📦 Installing explorer dependencies..."
    npm install
    
    # Create simple web explorer server
    cat > server.js << EOF
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || '$RPC_URL';

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// API endpoint to get latest system state
app.get('/api/system-state', async (req, res) => {
    try {
        const response = await axios.post(RPC_URL, {
            jsonrpc: '2.0',
            method: 'sui_getLatestSuiSystemState',
            params: [],
            id: 1
        }, { timeout: 5000 });
        res.json(response.data);
    } catch (error) {
        console.error('RPC Error:', error.message);
        res.status(500).json({ 
            error: 'Failed to fetch system state', 
            rpc_url: RPC_URL,
            details: error.message 
        });
    }
});

// API endpoint to get chain identifier
app.get('/api/chain-info', async (req, res) => {
    try {
        const response = await axios.post(RPC_URL, {
            jsonrpc: '2.0',
            method: 'sui_getChainIdentifier',
            params: [],
            id: 1
        }, { timeout: 5000 });
        res.json(response.data);
    } catch (error) {
        console.error('RPC Error:', error.message);
        res.status(500).json({ 
            error: 'Failed to fetch chain info', 
            rpc_url: RPC_URL,
            details: error.message 
        });
    }
});

// API endpoint to get latest transactions
app.get('/api/transactions', async (req, res) => {
    try {
        const response = await axios.post(RPC_URL, {
            jsonrpc: '2.0',
            method: 'suix_queryTransactionBlocks',
            params: [{
                filter: null,
                options: {
                    showInput: true,
                    showEffects: true,
                    showEvents: true
                },
                limit: 10,
                order: 'descending'
            }],
            id: 1
        }, { timeout: 10000 });
        res.json(response.data);
    } catch (error) {
        console.error('Transaction query error:', error.message);
        res.status(500).json({ 
            error: 'Failed to fetch transactions', 
            rpc_url: RPC_URL,
            details: error.message 
        });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(), 
        rpc_url: RPC_URL,
        version: '1.0.0'
    });
});

// Serve main page
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(\`🌐 BCFlex Sui Explorer running on port \${PORT}\`);
    console.log(\`🔗 RPC URL: \${RPC_URL}\`);
    console.log(\`📍 Access: http://localhost:\${PORT}\`);
});
EOF
    
    # Create public directory and HTML file
    mkdir -p public
    cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BCFlex Sui Blockchain Explorer</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
            overflow-x: hidden;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            padding: 30px;
            backdrop-filter: blur(10px);
        }
        .logo {
            font-size: 3em;
            font-weight: bold;
            margin-bottom: 10px;
            background: linear-gradient(45deg, #4facfe, #00f2fe);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
            margin-bottom: 20px;
        }
        .card {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 25px;
            margin: 20px 0;
            border: 1px solid rgba(255, 255, 255, 0.2);
            backdrop-filter: blur(10px);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .stat {
            text-align: center;
            padding: 20px;
        }
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            background: linear-gradient(45deg, #4facfe, #00f2fe);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
        }
        .stat-label {
            opacity: 0.8;
            font-size: 1.1em;
        }
        .btn {
            background: linear-gradient(45deg, #4facfe, #00f2fe);
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            color: white;
            font-weight: bold;
            cursor: pointer;
            margin: 10px 5px;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(79, 172, 254, 0.3);
        }
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(79, 172, 254, 0.4);
        }
        .info-box {
            background: rgba(0, 255, 127, 0.2);
            border-left: 4px solid #00ff7f;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .warning-box {
            background: rgba(255, 193, 7, 0.2);
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .error-box {
            background: rgba(220, 53, 69, 0.2);
            border-left: 4px solid #dc3545;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        #status {
            text-align: center;
            margin: 20px 0;
            padding: 15px;
            border-radius: 10px;
            font-weight: bold;
        }
        .loading {
            display: inline-block;
            animation: pulse 1.5s ease-in-out infinite;
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        .success { color: #00ff7f; }
        .error { color: #ff6b6b; }
        .warning { color: #ffc107; }
        
        .transactions-section {
            margin-top: 30px;
        }
        .transaction-item {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 10px;
            padding: 15px;
            margin: 10px 0;
            border-left: 3px solid #4facfe;
        }
        .transaction-hash {
            font-family: monospace;
            font-size: 0.9em;
            background: rgba(0, 0, 0, 0.2);
            padding: 5px 10px;
            border-radius: 5px;
            margin: 5px 0;
            word-break: break-all;
        }
        .footer {
            text-align: center;
            margin-top: 50px;
            padding: 20px;
            opacity: 0.7;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🌐 BCFlex Sui Explorer</div>
            <div class="subtitle">Custom Sui Blockchain with Enhanced Validator Rewards</div>
            <div>
                <button class="btn" onclick="fetchData()">🔄 Refresh Data</button>
                <button class="btn" onclick="testRPC()">🧪 Test RPC</button>
                <button class="btn" onclick="testFaucet()">💧 Test Faucet</button>
            </div>
        </div>
        
        <div class="card">
            <h2 style="text-align: center; margin-bottom: 20px;">📊 Network Statistics</h2>
            <div class="grid">
                <div class="stat">
                    <div class="stat-number" id="chainId">Loading...</div>
                    <div class="stat-label">Chain ID</div>
                </div>
                <div class="stat">
                    <div class="stat-number" id="epoch">Loading...</div>
                    <div class="stat-label">Current Epoch</div>
                </div>
                <div class="stat">
                    <div class="stat-number" id="validators">Loading...</div>
                    <div class="stat-label">Active Validators</div>
                </div>
                <div class="stat">
                    <div class="stat-number" id="totalStake">Loading...</div>
                    <div class="stat-label">Total Stake (SUI)</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h2 style="margin-bottom: 15px;">🔍 Connection Status</h2>
            <div id="status" class="loading">Testing connections...</div>
            <div id="testResults"></div>
        </div>

        <div class="card transactions-section">
            <h2 style="margin-bottom: 15px;">📋 Recent Transactions</h2>
            <div id="transactions">
                <div class="loading">Loading transactions...</div>
            </div>
        </div>

        <div class="info-box">
            <h3>💡 About BCFlex Sui Network</h3>
            <p>This is a custom Sui blockchain network with modified validator economics:</p>
            <ul style="margin: 10px 0 0 20px;">
                <li><strong>Delegators:</strong> 1% daily rewards (365% APY)</li>
                <li><strong>Validators:</strong> 1.5% daily rewards (547% APY)</li>
                <li><strong>RPC Endpoint:</strong> http://sui.bcflex.com:9000</li>
                <li><strong>Faucet:</strong> http://sui.bcflex.com:5003</li>
            </ul>
        </div>

        <div class="footer">
            <p>BCFlex Sui Network Explorer v1.0 | Built with ❤️ for the Sui ecosystem</p>
            <p>Last updated: <span id="lastUpdate">Never</span></p>
        </div>
    </div>

    <script>
        async function fetchData() {
            document.getElementById('lastUpdate').textContent = new Date().toLocaleString();
            
            try {
                // Fetch chain info
                const chainResponse = await fetch('/api/chain-info');
                const chainData = await chainResponse.json();
                
                if (chainData.result) {
                    document.getElementById('chainId').textContent = chainData.result;
                } else {
                    document.getElementById('chainId').textContent = 'Unknown';
                }
            } catch (error) {
                document.getElementById('chainId').textContent = 'Error';
                console.error('Chain info error:', error);
            }

            try {
                // Fetch system state
                const systemResponse = await fetch('/api/system-state');
                const systemData = await systemResponse.json();
                
                if (systemData.result) {
                    const system = systemData.result;
                    document.getElementById('epoch').textContent = system.epoch || 'Unknown';
                    document.getElementById('validators').textContent = 
                        system.activeValidators ? system.activeValidators.length : 'Unknown';
                    
                    if (system.totalStake) {
                        const stakeInSui = (parseInt(system.totalStake) / 1000000000).toFixed(2);
                        document.getElementById('totalStake').textContent = stakeInSui;
                    } else {
                        document.getElementById('totalStake').textContent = 'Unknown';
                    }
                } else {
                    document.getElementById('epoch').textContent = 'Error';
                    document.getElementById('validators').textContent = 'Error';
                    document.getElementById('totalStake').textContent = 'Error';
                }
            } catch (error) {
                document.getElementById('epoch').textContent = 'Error';
                document.getElementById('validators').textContent = 'Error';
                document.getElementById('totalStake').textContent = 'Error';
                console.error('System state error:', error);
            }

            // Fetch transactions
            try {
                const txResponse = await fetch('/api/transactions');
                const txData = await txResponse.json();
                
                const txContainer = document.getElementById('transactions');
                
                if (txData.result && txData.result.data && txData.result.data.length > 0) {
                    txContainer.innerHTML = txData.result.data.map(tx => 
                        '<div class="transaction-item">' +
                        '<div><strong>Transaction:</strong></div>' +
                        '<div class="transaction-hash">' + tx.digest + '</div>' +
                        '<div><strong>Checkpoint:</strong> ' + (tx.checkpoint || 'Pending') + '</div>' +
                        '</div>'
                    ).join('');
                } else {
                    txContainer.innerHTML = '<div class="warning-box">No recent transactions found</div>';
                }
            } catch (error) {
                document.getElementById('transactions').innerHTML = 
                    '<div class="error-box">Failed to load transactions: ' + error.message + '</div>';
                console.error('Transaction error:', error);
            }
        }

        async function testRPC() {
            const results = document.getElementById('testResults');
            results.innerHTML = '<div class="loading">Testing RPC connection...</div>';
            
            try {
                const response = await fetch('/api/chain-info');
                const data = await response.json();
                
                if (data.result) {
                    results.innerHTML = '<div class="success">✅ RPC Connection: Working perfectly!</div>';
                } else if (data.error) {
                    results.innerHTML = '<div class="error">❌ RPC Connection: ' + data.error + '</div>';
                } else {
                    results.innerHTML = '<div class="warning">⚠️ RPC Connection: Unexpected response</div>';
                }
            } catch (error) {
                results.innerHTML = '<div class="error">❌ RPC Connection: Network Error - ' + error.message + '</div>';
            }
        }

        async function testFaucet() {
            const results = document.getElementById('testResults');
            results.innerHTML = '<div class="loading">Testing Faucet connection...</div>';
            
            try {
                const response = await fetch('http://sui.bcflex.com:5003/health');
                if (response.ok) {
                    results.innerHTML = '<div class="success">✅ Faucet: Available and responding</div>';
                } else {
                    results.innerHTML = '<div class="error">❌ Faucet: Not responding (HTTP ' + response.status + ')</div>';
                }
            } catch (error) {
                // Try fallback without /health endpoint
                try {
                    const response2 = await fetch('http://sui.bcflex.com:5003');
                    if (response2.ok) {
                        results.innerHTML = '<div class="success">✅ Faucet: Available</div>';
                    } else {
                        results.innerHTML = '<div class="error">❌ Faucet: Not responding</div>';
                    }
                } catch (error2) {
                    results.innerHTML = '<div class="error">❌ Faucet: Not available - ' + error.message + '</div>';
                }
            }
        }

        // Initial status
        document.getElementById('status').innerHTML = 
            '<div class="success">🟢 Explorer is running and ready!</div>';

        // Load data on page load
        document.addEventListener('DOMContentLoaded', fetchData);
        
        // Auto-refresh every 30 seconds
        setInterval(fetchData, 30000);
    </script>
</body>
</html>
EOF
            opacity: 0.6;
        }
        .error {
            color: #ff6b6b;
        }
        .success {
            color: #00ff7f;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">⚡ BCFlex Sui Explorer</div>
            <p>Custom Sui Blockchain Network Explorer</p>
            <p><small>RPC: $RPC_URL</small></p>
        </div>

        <div id="status">
            <button class="btn" onclick="refreshData()">🔄 Refresh Data</button>
        </div>

        <div class="info-box">
            <strong>🎯 BCFlex Custom Network Features:</strong><br>
            • 1% daily rewards for delegators<br>
            • 1.5% daily rewards for validators<br>
            • Custom payout logic implemented<br>
            • RPC endpoint: $RPC_URL
        </div>

        <div class="grid">
            <div class="card">
                <div class="stat">
                    <div class="stat-number" id="chainId">Loading...</div>
                    <div class="stat-label">Chain ID</div>
                </div>
            </div>
            
            <div class="card">
                <div class="stat">
                    <div class="stat-number" id="epoch">Loading...</div>
                    <div class="stat-label">Current Epoch</div>
                </div>
            </div>
            
            <div class="card">
                <div class="stat">
                    <div class="stat-number" id="validators">Loading...</div>
                    <div class="stat-label">Active Validators</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h3>🔗 BCFlex Network Endpoints</h3>
            <p><strong>RPC:</strong> $RPC_URL</p>
            <p><strong>WebSocket:</strong> ws://sui.bcflex.com:9001</p>
            <p><strong>Faucet:</strong> http://sui.bcflex.com:5003</p>
            <p><strong>Metrics:</strong> http://sui.bcflex.com:9184</p>
            <p><strong>Explorer:</strong> https://sui.bcflex.com</p>
        </div>

        <div class="card">
            <h3>🧪 Connection Tests</h3>
            <button class="btn" onclick="testRPC()">Test RPC Connection</button>
            <button class="btn" onclick="testFaucet()">Test Faucet</button>
            <div id="testResults" style="margin-top: 15px;"></div>
        </div>

        <div id="rpcStatus" class="warning-box" style="display: none;">
            <strong>⚠️ RPC Connection Status:</strong>
            <div id="rpcDetails"></div>
        </div>
    </div>

    <script>
        async function fetchData() {
            try {
                // Fetch chain info
                const chainResponse = await fetch('/api/chain-info');
                const chainData = await chainResponse.json();
                if (chainData.result) {
                    document.getElementById('chainId').textContent = chainData.result;
                    document.getElementById('chainId').className = 'stat-number success';
                } else {
                    document.getElementById('chainId').textContent = 'Error';
                    document.getElementById('chainId').className = 'stat-number error';
                    showRPCStatus('Chain ID fetch failed: ' + (chainData.error || 'Unknown error'));
                }

                // Fetch system state
                const systemResponse = await fetch('/api/system-state');
                const systemData = await systemResponse.json();
                if (systemData.result) {
                    const state = systemData.result;
                    document.getElementById('epoch').textContent = state.epoch || 'N/A';
                    document.getElementById('epoch').className = 'stat-number success';
                    document.getElementById('validators').textContent = 
                        state.activeValidators ? state.activeValidators.length : 'N/A';
                    document.getElementById('validators').className = 'stat-number success';
                    hideRPCStatus();
                } else {
                    document.getElementById('epoch').textContent = 'Error';
                    document.getElementById('epoch').className = 'stat-number error';
                    document.getElementById('validators').textContent = 'Error';
                    document.getElementById('validators').className = 'stat-number error';
                    showRPCStatus('System state fetch failed: ' + (systemData.error || 'Unknown error'));
                }
            } catch (error) {
                console.error('Error fetching data:', error);
                document.getElementById('chainId').textContent = 'Error';
                document.getElementById('chainId').className = 'stat-number error';
                document.getElementById('epoch').textContent = 'Error';
                document.getElementById('epoch').className = 'stat-number error';
                document.getElementById('validators').textContent = 'Error';
                document.getElementById('validators').className = 'stat-number error';
                showRPCStatus('Network error: ' + error.message);
            }
        }

        function showRPCStatus(message) {
            document.getElementById('rpcStatus').style.display = 'block';
            document.getElementById('rpcDetails').innerHTML = message + '<br><small>RPC URL: $RPC_URL</small>';
        }

        function hideRPCStatus() {
            document.getElementById('rpcStatus').style.display = 'none';
        }

        function refreshData() {
            document.querySelector('.container').classList.add('loading');
            fetchData().finally(() => {
                document.querySelector('.container').classList.remove('loading');
            });
        }

        async function testRPC() {
            const results = document.getElementById('testResults');
            results.innerHTML = 'Testing RPC connection to $RPC_URL...';
            
            try {
                const response = await fetch('/api/system-state');
                const data = await response.json();
                if (data.result) {
                    results.innerHTML = '<span class="success">✅ RPC Connection: OK</span>';
                } else {
                    results.innerHTML = '<span class="error">❌ RPC Connection: Failed - ' + (data.error || 'Unknown error') + '</span>';
                }
            } catch (error) {
                results.innerHTML = '<span class="error">❌ RPC Connection: Network Error - ' + error.message + '</span>';
            }
        }

        async function testFaucet() {
            const results = document.getElementById('testResults');
            results.innerHTML = 'Testing Faucet connection...';
            
            try {
                const response = await fetch('http://sui.bcflex.com:5003');
                if (response.ok) {
                    results.innerHTML = '<span class="success">✅ Faucet: Available</span>';
                } else {
                    results.innerHTML = '<span class="error">❌ Faucet: Not responding (HTTP ' + response.status + ')</span>';
                }
            } catch (error) {
                results.innerHTML = '<span class="error">❌ Faucet: Not available - ' + error.message + '</span>';
            }
        }

        // Load data on page load
        document.addEventListener('DOMContentLoaded', fetchData);
        
        // Auto-refresh every 30 seconds
        setInterval(fetchData, 30000);
    </script>
</body>
</html>
EOF
    
    echo "✅ Standalone explorer setup completed"
}

echo "🔍 Debugging Sui Explorer Setup"
echo "==============================="

# Check if explorer directory exists
if [ ! -d "$EXPLORER_DIR" ]; then
    echo "❌ Explorer directory not found: $EXPLORER_DIR"
    echo "💡 Run the main installer first: sudo ./install_and_setup_explorer.sh"
    exit 1
fi

cd "$EXPLORER_DIR"

echo "📁 Current directory: $(pwd)"
echo "📋 Directory contents:"
ls -la | head -20

# Check package.json
if [ -f "package.json" ]; then
    echo ""
    echo "📦 Package.json found:"
    echo "📋 Available scripts:"
    grep -A 20 '"scripts"' package.json 2>/dev/null || echo "Could not read scripts section"
    
    echo ""
    echo "📋 Dependencies:"
    grep -A 10 '"dependencies"' package.json 2>/dev/null | head -15 || echo "Could not read dependencies"
else
    echo "❌ No package.json found"
fi

# Check if it's a Next.js app
if grep -q "next" package.json 2>/dev/null; then
    echo "✅ This appears to be a Next.js application"
elif grep -q "react" package.json 2>/dev/null; then
    echo "✅ This appears to be a React application"
elif grep -q "vite" package.json 2>/dev/null; then
    echo "✅ This appears to be a Vite application"
else
    echo "⚠️  Unknown application type"
fi

# Check node_modules
if [ -d "node_modules" ]; then
    echo "✅ node_modules directory exists"
else
    echo "⚠️  node_modules not found - running npm install"
    npm install
fi

# Try different commands to see what works
echo ""
echo "🧪 Testing available commands:"

if npm run 2>&1 | grep -q "start"; then
    echo "✅ 'npm start' is available"
else
    echo "❌ 'npm start' not available"
fi

if npm run 2>&1 | grep -q "dev"; then
    echo "✅ 'npm run dev' is available"
else
    echo "❌ 'npm run dev' not available"
fi

if npm run 2>&1 | grep -q "build"; then
    echo "✅ 'npm run build' is available"
else
    echo "❌ 'npm run build' not available"
fi

if npm run 2>&1 | grep -q "serve"; then
    echo "✅ 'npm run serve' is available"
else
    echo "❌ 'npm run serve' not available"
fi

# Check if .env.local exists
echo ""
echo "⚙️  Environment configuration:"
if [ -f ".env.local" ]; then
    echo "✅ .env.local exists:"
    cat .env.local
else
    echo "⚠️  .env.local not found, creating it..."
    cat > .env.local << EOF
# Sui Explorer Configuration
NEXT_PUBLIC_RPC_URL=$RPC_URL
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
PORT=3000
NODE_ENV=production

# Custom network configuration
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
NEXT_PUBLIC_API_ENDPOINT=$RPC_URL
EOF
    echo "✅ Created .env.local"
fi

# Try to start the explorer in test mode
echo ""
echo "🧪 Quick start test:"

# Find the best start command
START_CMD=""
if npm run 2>&1 | grep -q "dev"; then
    START_CMD="npm run dev"
elif npm run 2>&1 | grep -q "start"; then
    START_CMD="npm start"
else
    echo "❌ No suitable start command found in official explorer"
    echo "📋 Available scripts:"
    npm run 2>&1 || echo "Could not list scripts"
    echo ""
    echo "💡 The official Sui Explorer appears to be missing standard scripts."
    echo "🔄 Switching to standalone explorer setup..."
    
    # Remove the problematic explorer
    cd /
    rm -rf "$EXPLORER_DIR"
    
    # Set up standalone explorer
    setup_standalone_explorer
    
    # Update variables for the rest of the script
    START_CMD="npm start"
    cd "$EXPLORER_DIR"
    
    echo "✅ Standalone explorer setup completed!"
    echo "✅ Continuing with tests using standalone explorer..."
fi

echo "🚀 Using command: $START_CMD"

# Start in background and test
$START_CMD &
EXPLORER_PID=$!

echo "⏳ Waiting 15 seconds for explorer to start..."
sleep 15

# Test if it's working
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Explorer is responding on port 3000!"
    echo "🌐 Test: curl -I http://localhost:3000"
    curl -I http://localhost:3000 2>/dev/null | head -5
else
    echo "❌ Explorer not responding on port 3000"
fi

# Kill the test process
kill $EXPLORER_PID 2>/dev/null || echo "Process already stopped"

echo ""
echo "🎯 RECOMMENDATIONS:"
echo "=================="

echo "1. 📝 Update systemd service to use: $START_CMD"
echo "2. 🔄 Restart the explorer service:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl restart sui-explorer"
echo ""
echo "3. 📋 Check explorer logs:"
echo "   sudo journalctl -u sui-explorer -f"
echo ""
echo "4. 🧪 Test manually:"
echo "   cd $EXPLORER_DIR"
echo "   $START_CMD"

# Create a fixed systemd service
echo ""
echo "🔧 Creating fixed systemd service..."
cat > /tmp/sui-explorer-fixed.service << EOF
[Unit]
Description=Sui Block Explorer
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$EXPLORER_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=NEXT_PUBLIC_RPC_URL=$RPC_URL
Environment=NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
Environment=NEXT_PUBLIC_NETWORK=custom
Environment=NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
Environment=NEXT_PUBLIC_API_ENDPOINT=$RPC_URL
ExecStart=/usr/bin/$START_CMD
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-explorer

# Resource limits
LimitNOFILE=65536
MemoryMax=2G

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Fixed service file created at: /tmp/sui-explorer-fixed.service"
echo "💡 To apply the fix:"
echo "   sudo cp /tmp/sui-explorer-fixed.service /etc/systemd/system/sui-explorer.service"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl restart sui-explorer"

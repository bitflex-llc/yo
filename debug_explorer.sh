#!/bin/bash

# Quick script to debug and fix Sui Explorer setup issues

set -eu

EXPLORER_DIR="/root/sui-explorer"
RPC_URL="http://sui.bcflex.com:9000"

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
echo "💡 Trying to start explorer in background for 10 seconds..."

# Find the best start command
START_CMD=""
if npm run 2>&1 | grep -q "dev"; then
    START_CMD="npm run dev"
elif npm run 2>&1 | grep -q "start"; then
    START_CMD="npm start"
else
    echo "❌ No suitable start command found"
    echo "📋 Available scripts:"
    npm run 2>&1 || echo "Could not list scripts"
    exit 1
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

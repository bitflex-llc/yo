#!/bin/bash

# Quick Sui Network Starter
echo "🚀 Quick Sui Network Startup"
echo "============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "1. Cleaning up any existing processes..."

# Kill all sui processes
sudo pkill -9 -f sui 2>/dev/null || true
sleep 3

# Stop all systemd services
sudo systemctl stop sui-* 2>/dev/null || true
sleep 2

echo -e "${GREEN}✓ Cleanup completed${NC}"

echo ""
echo "2. Starting Sui network with simple approach..."

# Create basic directories
sudo mkdir -p /root/.sui/data
sudo mkdir -p /root/.sui/logs

# Change to sui directory
cd /root/.sui

echo ""
echo "3. Attempting to start Sui..."

# Try the simplest approach first - just 'sui start'
echo "Method 1: Basic sui start..."
if timeout 20 sudo -u root /usr/local/bin/sui start 2>&1 | tee /root/.sui/logs/startup.log &
then
    STARTUP_PID=$!
    echo "Started with PID: $STARTUP_PID"
    
    # Wait a bit and check if it's working
    sleep 10
    
    if kill -0 $STARTUP_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Sui appears to be starting successfully!${NC}"
        echo ""
        echo "Testing connection..."
        sleep 5
        
        # Test if RPC is responding
        if curl -s -X POST http://localhost:9000 -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"sui_getLatestSuiSystemState","params":[],"id":1}' | grep -q "result\|error"; then
            echo -e "${GREEN}✓ RPC is responding on port 9000!${NC}"
        else
            echo -e "${YELLOW}⚠ RPC not yet responding, but process is running${NC}"
        fi
        
        echo ""
        echo "=== SUCCESS ==="
        echo "Sui network is starting up!"
        echo ""
        echo "🌐 Network Endpoints:"
        echo "  • RPC: http://localhost:9000"
        echo "  • WebSocket: ws://localhost:9001"
        echo ""
        echo "📊 Monitor startup:"
        echo "  tail -f /root/.sui/logs/startup.log"
        echo ""
        echo "🔍 Test RPC:"
        echo "  curl -X POST http://localhost:9000 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"sui_getLatestSuiSystemState\",\"params\":[],\"id\":1}'"
        echo ""
        echo "🛑 To stop:"
        echo "  sudo pkill -f sui"
        echo ""
        echo "Process is running in background. Check logs for details."
        
        exit 0
    else
        echo -e "${RED}✗ Process died, checking logs...${NC}"
        echo "Last few lines of startup log:"
        tail -10 /root/.sui/logs/startup.log 2>/dev/null || echo "No logs found"
    fi
else
    echo -e "${RED}✗ Basic sui start failed${NC}"
fi

echo ""
echo "Method 2: Manual network setup..."

# Create a minimal genesis if needed
if [ ! -f "/root/.sui/genesis/genesis.blob" ]; then
    echo "Creating genesis configuration..."
    sudo mkdir -p /root/.sui/genesis
    cd /root/.sui
    
    # Try to create genesis
    sudo -u root /usr/local/bin/sui genesis -f --working-dir /root/.sui/genesis 2>/dev/null || {
        echo "Genesis creation with sui genesis failed, trying sui client..."
        sudo -u root /usr/local/bin/sui client 2>/dev/null || true
    }
fi

# Try with a basic configuration file
echo "Creating minimal configuration..."
sudo tee /root/.sui/simple_config.yaml > /dev/null << 'EOF'
db-path: /root/.sui/data
network-address: /ip4/0.0.0.0/tcp/9000
json-rpc-address: 0.0.0.0:9000
websocket-address: 0.0.0.0:9001
metrics-address: 0.0.0.0:9184
log-level: info
enable-event-processing: true
p2p-config:
  listen-address: 0.0.0.0:8084
  seed-peers: []
EOF

if [ -f "/root/.sui/genesis/genesis.blob" ]; then
    echo "genesis:" >> /root/.sui/simple_config.yaml
    echo "  genesis-file-location: /root/.sui/genesis/genesis.blob" >> /root/.sui/simple_config.yaml
fi

sudo chmod 644 /root/.sui/simple_config.yaml

echo "Trying with configuration file..."
if sudo -u root /usr/local/bin/sui-node --config-path /root/.sui/simple_config.yaml 2>&1 | tee /root/.sui/logs/node_config.log &
then
    CONFIG_PID=$!
    echo "Started with config, PID: $CONFIG_PID"
    
    sleep 10
    
    if kill -0 $CONFIG_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Node started with configuration file!${NC}"
        echo ""
        echo "=== SUCCESS ==="
        echo "Sui node is running with config file!"
        echo ""
        echo "🌐 Network Endpoints:"
        echo "  • RPC: http://localhost:9000"
        echo "  • WebSocket: ws://localhost:9001"
        echo "  • Metrics: http://localhost:9184"
        echo ""
        echo "📊 Monitor:"
        echo "  tail -f /root/.sui/logs/node_config.log"
        echo ""
        echo "🛑 To stop:"
        echo "  sudo pkill -f sui-node"
        
        exit 0
    else
        echo -e "${RED}✗ Config-based startup failed${NC}"
        echo "Error logs:"
        tail -10 /root/.sui/logs/node_config.log 2>/dev/null || echo "No logs found"
    fi
else
    echo -e "${RED}✗ Failed to start with config${NC}"
fi

echo ""
echo -e "${RED}=== TROUBLESHOOTING ===${NC}"
echo ""
echo "Both startup methods failed. Here's what to check:"
echo ""
echo "1. Check if Sui is properly built:"
echo "   /usr/local/bin/sui --version"
echo "   /usr/local/bin/sui-node --help"
echo ""
echo "2. Check logs:"
echo "   tail -20 /root/.sui/logs/startup.log"
echo "   tail -20 /root/.sui/logs/node_config.log"
echo ""
echo "3. Try manual debugging:"
echo "   cd /root/.sui"
echo "   sudo -u root /usr/local/bin/sui start"
echo ""
echo "4. Check for missing dependencies:"
echo "   ldd /usr/local/bin/sui"
echo "   ldd /usr/local/bin/sui-node"
echo ""
echo "5. Try rebuilding Sui:"
echo "   cd $(pwd)"
echo "   cargo clean"
echo "   cargo build --release --bin sui --bin sui-node --bin sui-faucet"
echo ""

exit 1

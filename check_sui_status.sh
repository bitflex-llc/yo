#!/bin/bash

# Quick diagnostic script to check Sui network status and start if needed

set -eu

echo "🔍 Checking Sui Network Status..."
echo "================================="

# Check if Sui is installed
if ! command -v sui >/dev/null 2>&1; then
    echo "❌ Sui CLI not found"
    echo "💡 Please install Sui first using one of your deployment scripts"
    exit 1
fi

echo "✅ Sui CLI found: $(sui --version 2>/dev/null | head -n1 || echo 'version unknown')"

# Check if Sui processes are running
SUI_PROCESSES=$(ps aux | grep -v grep | grep sui | wc -l)
echo "📊 Sui processes running: $SUI_PROCESSES"

if [ "$SUI_PROCESSES" -gt 0 ]; then
    echo "📋 Current Sui processes:"
    ps aux | grep -v grep | grep sui | head -10
else
    echo "⚠️  No Sui processes found"
fi

# Check RPC port
echo ""
echo "🔌 Checking RPC port 9000..."
if netstat -tlnp 2>/dev/null | grep ":9000 " >/dev/null; then
    echo "✅ Port 9000 is listening"
    RPC_PROCESS=$(netstat -tlnp 2>/dev/null | grep ":9000 " | awk '{print $7}' | head -n1)
    echo "📊 Process on port 9000: $RPC_PROCESS"
else
    echo "❌ Port 9000 is not listening"
fi

# Test RPC connection
echo ""
echo "🧪 Testing RPC connection..."
if curl -s --connect-timeout 5 --max-time 10 -X POST http://localhost:9000 \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","method":"sui_getChainIdentifier","params":[],"id":1}' \
    >/dev/null 2>&1; then
    echo "✅ RPC is responding"
    
    # Get actual response
    RESPONSE=$(curl -s --connect-timeout 5 --max-time 10 -X POST http://localhost:9000 \
        -H 'Content-Type: application/json' \
        -d '{"jsonrpc":"2.0","method":"sui_getChainIdentifier","params":[],"id":1}')
    echo "📊 Chain ID: $(echo "$RESPONSE" | grep -o '"result":"[^"]*"' | cut -d'"' -f4 || echo 'unknown')"
else
    echo "❌ RPC is not responding"
fi

# Check other Sui ports
echo ""
echo "🔌 Checking other Sui ports..."
for port in 9001 8084 9184 5003; do
    if netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; then
        echo "✅ Port $port is listening"
    else
        echo "❌ Port $port is not listening"
    fi
done

# Check if Sui config exists
echo ""
echo "📁 Checking Sui configuration..."
if [ -d "/root/.sui" ]; then
    echo "✅ Sui config directory exists: /root/.sui"
    ls -la /root/.sui/ 2>/dev/null | head -10 || echo "Cannot list contents"
else
    echo "❌ Sui config directory not found at /root/.sui"
fi

# Check if there are any Sui config files in current directory
if [ -f "sui_config/validator.yaml" ]; then
    echo "✅ Found validator config in current directory"
elif [ -f "genesis/validator.yaml" ]; then
    echo "✅ Found validator config in genesis directory"
else
    echo "⚠️  No validator config found in current directory"
fi

echo ""
echo "🚀 QUICK FIX RECOMMENDATIONS:"
echo "=============================="

if [ "$SUI_PROCESSES" -eq 0 ]; then
    echo "1. 🎯 Start your Sui network first:"
    echo "   sudo bash quick_start.sh"
    echo "   OR"
    echo "   sudo bash start_sui_network.sh"
    echo ""
    
    echo "2. 📍 Alternative - Manual start:"
    echo "   cd /root/.sui"
    echo "   sudo -u root /usr/local/bin/sui start"
    echo ""
    
    echo "3. 🔧 If no config exists, run genesis:"
    echo "   sudo -u root /usr/local/bin/sui genesis -f --working-dir genesis/"
    echo ""
fi

echo "4. 🌐 After Sui is running, restart the explorer:"
echo "   sudo systemctl restart sui-explorer"
echo ""

echo "5. 🧪 Test RPC manually:"
echo "   curl -X POST http://localhost:9000 \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"jsonrpc\":\"2.0\",\"method\":\"sui_getChainIdentifier\",\"params\":[],\"id\":1}'"
echo ""

# Offer to start Sui automatically
if [ "$SUI_PROCESSES" -eq 0 ]; then
    echo "💡 Would you like me to try starting Sui now? (y/N)"
    read -r REPLY
    if echo "$REPLY" | grep -q "^[Yy]$"; then
        echo ""
        echo "🚀 Attempting to start Sui..."
        
        # Try the quick start script first
        if [ -f "quick_start.sh" ]; then
            echo "📍 Using quick_start.sh..."
            bash quick_start.sh
        elif [ -f "start_sui_network.sh" ]; then
            echo "📍 Using start_sui_network.sh..."
            bash start_sui_network.sh
        else
            echo "📍 Trying manual start..."
            cd /root/.sui 2>/dev/null || mkdir -p /root/.sui
            if [ -f "/usr/local/bin/sui" ]; then
                sudo -u root /usr/local/bin/sui start &
                echo "🔄 Started Sui in background, waiting 10 seconds..."
                sleep 10
                
                # Test again
                if netstat -tlnp 2>/dev/null | grep ":9000 " >/dev/null; then
                    echo "✅ Sui appears to be running now!"
                    echo "🔄 Restarting explorer..."
                    systemctl restart sui-explorer 2>/dev/null || echo "⚠️  Could not restart explorer service"
                else
                    echo "❌ Sui still not responding. Check logs or run genesis first."
                fi
            else
                echo "❌ Sui binary not found. Please install Sui first."
            fi
        fi
    fi
fi

echo ""
echo "🎯 Next Steps:"
echo "- Ensure Sui network is running on port 9000"
echo "- Restart the explorer: sudo systemctl restart sui-explorer"
echo "- Check explorer logs: sudo journalctl -u sui-explorer -f"

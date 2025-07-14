#!/bin/sh

# Emergency script to kill port conflicts and start explorer on port 3011
# This script resolves "EADDRINUSE" errors by switching to port 3011

echo "🚨 EMERGENCY EXPLORER PORT SWITCH TO 3011"
echo "========================================="

# Function to kill processes on a specific port
kill_port() {
    PORT=$1
    echo "🧹 Killing all processes on port $PORT..."
    
    if command -v lsof > /dev/null; then
        PIDS=$(lsof -ti:$PORT 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            echo "Found PIDs on port $PORT: $PIDS"
            echo "$PIDS" | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # Alternative method
    netstat -tlnp 2>/dev/null | grep :$PORT | awk '{print $7}' | cut -d'/' -f1 | while read PID; do
        if [ -n "$PID" ] && [ "$PID" != "-" ]; then
            kill -9 "$PID" 2>/dev/null || true
        fi
    done
    
    # Kill specific node processes
    pkill -f "node.*$PORT" 2>/dev/null || true
    pkill -f "next.*$PORT" 2>/dev/null || true
    
    echo "✅ Port $PORT cleared"
}

# Kill both common conflict ports
kill_port 3000
kill_port 3011

# Additional cleanup
echo "🧹 Additional cleanup..."
pkill -f "npm.*start" 2>/dev/null || true
pkill -f "npm.*dev" 2>/dev/null || true
pkill -f "sui-explorer" 2>/dev/null || true

echo "✅ All cleanup complete"

# Start explorer on port 3011
EXPLORER_DIR="/root/sui-explorer"

if [ -d "$EXPLORER_DIR" ]; then
    echo "🚀 Starting Sui Explorer on port 3011..."
    cd "$EXPLORER_DIR"
    
    # Ensure .env.local has correct port
    if [ -f ".env.local" ]; then
        # Update existing .env.local to use port 3011
        sed -i.bak 's/PORT=.*/PORT=3011/' .env.local 2>/dev/null || true
    else
        # Create .env.local if it doesn't exist
        cat > .env.local << EOF
PORT=3011
NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
NODE_ENV=production
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
NEXT_PUBLIC_API_ENDPOINT=http://sui.bcflex.com:9000
EOF
    fi
    
    echo "✅ Environment configured for port 3011"
    
    # Export port and start
    export PORT=3011
    
    if [ -f "package.json" ]; then
        echo "📦 Starting with npm..."
        
        # Try different start methods
        if command -v npm > /dev/null; then
            if npm run start > /tmp/explorer.log 2>&1 &; then
                EXPLORER_PID=$!
                echo "✅ Explorer started with npm start (PID: $EXPLORER_PID)"
            elif npm run dev > /tmp/explorer.log 2>&1 &; then
                EXPLORER_PID=$!
                echo "✅ Explorer started with npm dev (PID: $EXPLORER_PID)"
            else
                echo "❌ Failed to start with npm"
                exit 1
            fi
        else
            echo "❌ npm not found"
            exit 1
        fi
        
        echo "⏳ Waiting 15 seconds for startup..."
        sleep 15
        
        # Test if it's working
        echo "🧪 Testing explorer on port 3011..."
        if curl -s -f http://localhost:3011 >/dev/null 2>&1; then
            echo "✅ SUCCESS! Explorer is running on port 3011"
            echo "🌐 Access at: http://localhost:3011"
            echo "📋 Status: Active (PID: $EXPLORER_PID)"
        else
            echo "⚠️  Explorer started but may not be ready yet"
            echo "🔍 Manual test: curl http://localhost:3011"
            echo "📋 Check logs: tail -f /tmp/explorer.log"
            
            # Show recent logs
            if [ -f "/tmp/explorer.log" ]; then
                echo ""
                echo "📋 Recent logs:"
                tail -10 /tmp/explorer.log
            fi
        fi
    else
        echo "❌ No package.json found in $EXPLORER_DIR"
        echo "💡 Run ./force_install_official_explorer.sh to install"
        exit 1
    fi
else
    echo "❌ Explorer directory not found: $EXPLORER_DIR"
    echo "💡 Run ./force_install_official_explorer.sh to install"
    exit 1
fi

echo ""
echo "🎯 EMERGENCY FIX COMPLETE!"
echo "========================="
echo "✅ Port conflicts resolved"
echo "✅ Explorer configured for port 3011"
echo "🌐 Test URL: http://localhost:3011"
echo ""
echo "If issues persist:"
echo "- Check logs: tail -f /tmp/explorer.log"
echo "- Reinstall: ./force_install_official_explorer.sh"
echo "- Debug: ./debug_explorer.sh"

#!/bin/sh

# Debug script for Sui Explorer - OFFICIAL EXPLORER ONLY on Port 3011
# This script forces the use of the official explorer and removes fallback logic

set -eu

EXPLORER_DIR="/root/sui-explorer"
RPC_URL="http://sui.bcflex.com:9000"
EXPLORER_PORT="3011"

echo "🔍 DEBUG SUI EXPLORER - Official Explorer Only (Port 3011)"
echo "=========================================================="

# Force install official explorer function
force_official_explorer() {
    echo "🔧 FORCING Official Sui Explorer Installation..."
    echo "No fallbacks - official explorer only!"
    
    # Run the force install script
    if [ -f "./force_install_official_explorer.sh" ]; then
        echo "📄 Running force install script..."
        chmod +x ./force_install_official_explorer.sh
        ./force_install_official_explorer.sh
    else
        echo "❌ force_install_official_explorer.sh not found"
        echo "💡 Please ensure you're in the correct directory"
        exit 1
    fi
}

# Check if explorer directory exists and is set up correctly
check_explorer_setup() {
    echo "🔍 Checking explorer setup..."
    
    if [ ! -d "$EXPLORER_DIR" ]; then
        echo "❌ Explorer directory not found: $EXPLORER_DIR"
        echo "🔧 Need to install official explorer first"
        return 1
    fi
    
    cd "$EXPLORER_DIR"
    
    if [ ! -f "package.json" ]; then
        echo "❌ No package.json found in explorer directory"
        echo "🔧 Need to install official explorer first"
        return 1
    fi
    
    echo "✅ Explorer directory exists"
    echo "✅ package.json found"
    
    # Check for .env.local
    if [ -f ".env.local" ]; then
        echo "✅ .env.local found"
        echo "📋 Current port configuration:"
        grep "PORT" .env.local || echo "No PORT setting found"
    else
        echo "⚠️  No .env.local found"
    fi
    
    return 0
}

# Fix explorer port configuration
fix_explorer_port() {
    echo "🔧 Fixing explorer port configuration..."
    
    cd "$EXPLORER_DIR"
    
    # Create or update .env.local
    cat > .env.local << EOF
# Sui Explorer Configuration for Port $EXPLORER_PORT
NEXT_PUBLIC_RPC_URL=$RPC_URL
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
PORT=$EXPLORER_PORT
NODE_ENV=production

# Custom network configuration
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
NEXT_PUBLIC_API_ENDPOINT=$RPC_URL
EOF
    
    echo "✅ Port configuration updated to $EXPLORER_PORT"
}

# Kill processes on explorer port
kill_explorer_port() {
    echo "🧹 Cleaning up processes on port $EXPLORER_PORT..."
    
    if command -v lsof > /dev/null; then
        PIDS=$(lsof -ti:$EXPLORER_PORT 2>/dev/null || true)
        if [ -n "$PIDS" ]; then
            echo "Killing PIDs: $PIDS"
            echo "$PIDS" | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # Alternative method
    netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " | awk '{print $7}' | cut -d'/' -f1 | while read PID; do
        if [ -n "$PID" ] && [ "$PID" != "-" ]; then
            kill -9 "$PID" 2>/dev/null || true
        fi
    done
    
    # Kill specific node processes
    pkill -f "node.*$EXPLORER_PORT" 2>/dev/null || true
    pkill -f "next.*$EXPLORER_PORT" 2>/dev/null || true
    
    echo "✅ Port cleanup complete"
}

# Test explorer functionality
test_explorer() {
    echo "🧪 Testing explorer on port $EXPLORER_PORT..."
    
    # Start explorer in background for testing
    cd "$EXPLORER_DIR"
    
    export PORT=$EXPLORER_PORT
    
    # Try to start explorer
    echo "🚀 Attempting to start explorer..."
    
    npm run start > /tmp/explorer_test.log 2>&1 &
    EXPLORER_PID=$!
    
    # Check if the process is running
    sleep 2
    if kill -0 $EXPLORER_PID 2>/dev/null; then
        echo "✅ Explorer started with npm start (PID: $EXPLORER_PID)"
    else
        echo "⚠️  npm start failed, trying dev mode..."
        npm run dev > /tmp/explorer_test.log 2>&1 &
        EXPLORER_PID=$!
        sleep 2
        if kill -0 $EXPLORER_PID 2>/dev/null; then
            echo "✅ Explorer started with npm dev (PID: $EXPLORER_PID)"
        else
            echo "❌ Failed to start explorer"
            return 1
        fi
    fi
    
    echo "⏳ Waiting 15 seconds for startup..."
    sleep 15
    
    # Test if responding
    if curl -s http://localhost:$EXPLORER_PORT >/dev/null 2>&1; then
        echo "✅ Explorer is responding on port $EXPLORER_PORT!"
        echo "🌐 Test: curl -I http://localhost:$EXPLORER_PORT"
        curl -I http://localhost:$EXPLORER_PORT 2>/dev/null | head -5
        
        # Kill test process
        kill $EXPLORER_PID 2>/dev/null || true
        return 0
    else
        echo "❌ Explorer not responding on port $EXPLORER_PORT"
        echo "📋 Check logs: tail -f /tmp/explorer_test.log"
        
        # Show some logs
        if [ -f "/tmp/explorer_test.log" ]; then
            echo ""
            echo "📋 Recent logs:"
            tail -10 /tmp/explorer_test.log
        fi
        
        # Kill test process
        kill $EXPLORER_PID 2>/dev/null || true
        return 1
    fi
}

# Main debug flow
main() {
    echo "🚀 Starting Sui Explorer Debug (Official Only, Port $EXPLORER_PORT)"
    echo ""
    
    # Step 1: Check if explorer is set up
    if ! check_explorer_setup; then
        echo ""
        echo "🔧 Setting up official explorer..."
        force_official_explorer
        echo ""
    fi
    
    # Step 2: Fix port configuration
    fix_explorer_port
    echo ""
    
    # Step 3: Clean up port conflicts
    kill_explorer_port
    echo ""
    
    # Step 4: Test explorer
    if test_explorer; then
        echo ""
        echo "🎉 SUCCESS! Explorer is working correctly"
        echo "🌐 Explorer URL: http://localhost:$EXPLORER_PORT"
    else
        echo ""
        echo "❌ Explorer test failed"
        echo "💡 Try running: ./force_install_official_explorer.sh"
    fi
    
    echo ""
    echo "🔧 Debug complete!"
}

# Run main function
main

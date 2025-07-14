#!/bin/bash

# Immediate fix for port 3000 conflict

echo "🔧 Fixing Port 3000 Conflict - QUICK FIX"
echo "========================================"

echo "1. 🔍 Finding what's using port 3000..."

# Check what's using port 3000
if command -v lsof >/dev/null 2>&1; then
    echo "Processes using port 3000:"
    lsof -i :3000 2>/dev/null || echo "No lsof results"
fi

if command -v netstat >/dev/null 2>&1; then
    echo "Network connections on port 3000:"
    netstat -tulpn | grep :3000 2>/dev/null || echo "No netstat results"
fi

echo ""
echo "2. 🛑 Killing all processes on port 3000..."

# Method 1: Use lsof to find and kill specific PIDs
if command -v lsof >/dev/null 2>&1; then
    PORT_PIDS=$(lsof -t -i :3000 2>/dev/null | tr '\n' ' ')
    if [ -n "$PORT_PIDS" ]; then
        echo "Found PIDs using port 3000: $PORT_PIDS"
        for pid in $PORT_PIDS; do
            echo "Killing PID $pid..."
            sudo kill -9 "$pid" 2>/dev/null || echo "Could not kill $pid"
        done
    fi
fi

# Method 2: Use fuser (more aggressive)
if command -v fuser >/dev/null 2>&1; then
    echo "Using fuser to kill port 3000..."
    sudo fuser -k 3000/tcp 2>/dev/null || echo "fuser: no processes found"
fi

# Method 3: Kill common Node.js processes that might be using port 3000
echo "Killing common Node.js processes..."
sudo pkill -f "node.*3000" 2>/dev/null || true
sudo pkill -f "next.*dev" 2>/dev/null || true
sudo pkill -f "npm.*start" 2>/dev/null || true
sudo pkill -f "npm.*dev" 2>/dev/null || true
sudo pkill -f "sui.*explorer" 2>/dev/null || true

# Method 4: Kill all Node.js processes (nuclear option)
echo "Killing all Node.js processes (as backup)..."
sudo pkill -f "node" 2>/dev/null || true

echo ""
echo "3. ⏳ Waiting for port to be freed..."
sleep 5

# Verify port 3000 is now free
echo "4. ✅ Verifying port 3000 is free..."
if command -v lsof >/dev/null 2>&1; then
    if lsof -i :3000 >/dev/null 2>&1; then
        echo "⚠️  WARNING: Port 3000 still in use!"
        lsof -i :3000
        echo "Trying one more aggressive kill..."
        sudo kill -9 $(lsof -t -i :3000) 2>/dev/null || true
        sleep 3
    else
        echo "✅ Port 3000 is now FREE!"
    fi
fi

echo ""
echo "5. 🚀 Now starting Sui Explorer on port 3000..."

EXPLORER_DIR="/root/sui-explorer"

if [ -d "$EXPLORER_DIR" ]; then
    cd "$EXPLORER_DIR"
    
    # Make sure environment is set
    export PORT=3000
    export NODE_ENV=production
    export NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
    
    echo "Starting explorer with npm run dev..."
    npm run dev &
    EXPLORER_PID=$!
    
    echo "Explorer started with PID: $EXPLORER_PID"
    echo "⏳ Waiting 20 seconds for startup..."
    
    # Monitor startup
    for i in {1..20}; do
        sleep 1
        if ! kill -0 $EXPLORER_PID 2>/dev/null; then
            echo "❌ Explorer process died after $i seconds"
            break
        fi
        
        if [ $i -eq 10 ]; then
            echo "⏳ Still starting... ($i/20 seconds)"
        fi
        
        # Test if it's responding
        if [ $i -gt 10 ] && curl -s http://localhost:3000 >/dev/null 2>&1; then
            echo "✅ Explorer is responding after $i seconds!"
            break
        fi
    done
    
    # Final check
    if kill -0 $EXPLORER_PID 2>/dev/null; then
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            echo ""
            echo "🎉 SUCCESS!"
            echo "✅ Sui Explorer is running on port 3000"
            echo "🌐 Access: http://localhost:3000"
            echo "📋 Process ID: $EXPLORER_PID"
            echo ""
            echo "📊 To monitor logs:"
            echo "   tail -f ~/.npm/_logs/*.log"
            echo ""
            echo "🛑 To stop:"
            echo "   kill $EXPLORER_PID"
        else
            echo "⚠️  Process running but not responding to HTTP requests"
            echo "Process status: RUNNING (PID $EXPLORER_PID)"
            echo "Try waiting a bit longer or check logs"
        fi
    else
        echo "❌ Explorer process has died"
        echo "Check the error above or try manual start:"
        echo "   cd $EXPLORER_DIR"
        echo "   npm run dev"
    fi
    
else
    echo "❌ Explorer directory not found: $EXPLORER_DIR"
    echo "Run the installation script first"
fi

echo ""
echo "🎯 Port 3000 fix attempt complete!"

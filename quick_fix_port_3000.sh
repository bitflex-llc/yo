#!/bin/bash

# Quick fix for port 3000 conflict - kill processes and restart explorer

echo "🔧 Quick Fix: Port 3000 Conflict"
echo "================================"

echo "1. 🛑 Stopping all processes on port 3000..."

# Find and kill processes using port 3000
if command -v lsof >/dev/null 2>&1; then
    PORT_PIDS=$(lsof -t -i :3000 2>/dev/null || true)
    if [ -n "$PORT_PIDS" ]; then
        echo "Found processes using port 3000: $PORT_PIDS"
        echo "$PORT_PIDS" | xargs sudo kill -9 2>/dev/null || true
        echo "✅ Killed processes on port 3000"
    else
        echo "✅ No processes found on port 3000"
    fi
else
    # Fallback method using netstat and manual kill
    echo "Using fallback method to find processes..."
    sudo pkill -f ":3000" 2>/dev/null || true
    sudo pkill -f "port.*3000" 2>/dev/null || true
    sudo pkill -f "next.*dev" 2>/dev/null || true
    sudo pkill -f "npm.*start" 2>/dev/null || true
fi

echo ""
echo "2. 🔍 Verifying port 3000 is free..."
sleep 2

if command -v lsof >/dev/null 2>&1 && lsof -i :3000 >/dev/null 2>&1; then
    echo "⚠️  Port 3000 still in use. Trying force kill..."
    sudo fuser -k 3000/tcp 2>/dev/null || true
    sleep 2
fi

if command -v lsof >/dev/null 2>&1 && ! lsof -i :3000 >/dev/null 2>&1; then
    echo "✅ Port 3000 is now free!"
elif command -v netstat >/dev/null 2>&1 && ! netstat -tulpn | grep -q :3000; then
    echo "✅ Port 3000 appears to be free!"
else
    echo "⚠️  Unable to verify port status, continuing anyway..."
fi

echo ""
echo "3. 🚀 Starting Sui Explorer..."

EXPLORER_DIR="/root/sui-explorer"

if [ -d "$EXPLORER_DIR" ]; then
    cd "$EXPLORER_DIR"
    
    # Make sure .env.local has correct port
    if [ -f ".env.local" ]; then
        if ! grep -q "PORT=3000" .env.local; then
            echo "PORT=3000" >> .env.local
        fi
    else
        echo "Creating .env.local..."
        cat > .env.local << 'EOF'
PORT=3000
NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
NODE_ENV=production
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
NEXT_PUBLIC_API_ENDPOINT=http://sui.bcflex.com:9000
EOF
    fi
    
    echo "Starting explorer in background..."
    
    # Try different start methods
    if npm run dev > /tmp/explorer_start.log 2>&1 &
    then
        EXPLORER_PID=$!
        echo "Started with 'npm run dev', PID: $EXPLORER_PID"
    elif npm start > /tmp/explorer_start.log 2>&1 &
    then
        EXPLORER_PID=$!
        echo "Started with 'npm start', PID: $EXPLORER_PID"
    else
        echo "❌ Failed to start explorer"
        echo "Logs:"
        cat /tmp/explorer_start.log 2>/dev/null || echo "No logs available"
        exit 1
    fi
    
    echo "⏳ Waiting 15 seconds for explorer to start..."
    sleep 15
    
    # Check if it's working
    if kill -0 $EXPLORER_PID 2>/dev/null; then
        echo "✅ Explorer process is running!"
        
        # Test HTTP response
        if curl -s http://localhost:3000 >/dev/null 2>&1; then
            echo "✅ Explorer is responding on http://localhost:3000"
            echo ""
            echo "🎉 SUCCESS!"
            echo "🌐 Explorer is now running at: http://localhost:3000"
            echo "📋 Process ID: $EXPLORER_PID"
            echo ""
            echo "📊 To monitor logs:"
            echo "   tail -f /tmp/explorer_start.log"
            echo ""
            echo "🛑 To stop:"
            echo "   kill $EXPLORER_PID"
            echo "   # Or:"
            echo "   sudo pkill -f 'npm.*dev'"
            
        else
            echo "⚠️  Explorer process running but not responding on port 3000"
            echo "Checking what might be wrong..."
            
            # Check if it's using a different port
            if netstat -tulpn 2>/dev/null | grep -q "$EXPLORER_PID"; then
                echo "Process is listening on:"
                netstat -tulpn 2>/dev/null | grep "$EXPLORER_PID"
            fi
            
            echo "Recent logs:"
            tail -10 /tmp/explorer_start.log 2>/dev/null || echo "No logs available"
        fi
    else
        echo "❌ Explorer process died"
        echo "Error logs:"
        cat /tmp/explorer_start.log 2>/dev/null || echo "No logs available"
        exit 1
    fi
    
else
    echo "❌ Explorer directory not found: $EXPLORER_DIR"
    echo "💡 Run the installation script first:"
    echo "   sudo ./force_install_official_explorer.sh"
    exit 1
fi

echo ""
echo "✅ Port 3000 conflict resolved and explorer started!"

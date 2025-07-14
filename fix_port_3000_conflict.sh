#!/bin/bash

# Fix port 3000 conflict for Sui Explorer

set -eu

echo "🔍 Diagnosing Port 3000 Conflict"
echo "================================="

# Check what's using port 3000
echo "1. Checking what's using port 3000..."
echo ""

if command -v lsof >/dev/null 2>&1; then
    echo "📋 Processes using port 3000:"
    lsof -i :3000 || echo "No processes found using lsof"
else
    echo "⚠️  lsof not available, trying netstat..."
fi

echo ""
if command -v netstat >/dev/null 2>&1; then
    echo "📋 Network connections on port 3000:"
    netstat -tulpn | grep :3000 || echo "No connections found using netstat"
else
    echo "⚠️  netstat not available, trying ss..."
fi

echo ""
if command -v ss >/dev/null 2>&1; then
    echo "📋 Socket connections on port 3000:"
    ss -tulpn | grep :3000 || echo "No connections found using ss"
fi

echo ""
echo "📋 All Node.js processes:"
ps aux | grep -i node | grep -v grep || echo "No Node.js processes found"

echo ""
echo "📋 All processes with 'sui' in name:"
ps aux | grep -i sui | grep -v grep || echo "No Sui processes found"

echo ""
echo "2. Solution Options:"
echo "==================="

# Check if it's a Sui explorer process
if pgrep -f "sui.*explorer\|explorer.*sui\|next.*dev\|npm.*start" >/dev/null 2>&1; then
    echo "🔍 Found Sui Explorer or Next.js processes running"
    echo ""
    echo "Option 1: Kill existing explorer processes"
    echo "   sudo pkill -f 'sui.*explorer'"
    echo "   sudo pkill -f 'next.*dev'"
    echo "   sudo pkill -f 'npm.*start'"
    echo ""
    echo "Would you like me to kill these processes? (recommended)"
    read -p "Kill existing explorer processes? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo "🛑 Stopping existing explorer processes..."
        sudo pkill -f 'sui.*explorer' 2>/dev/null || true
        sudo pkill -f 'next.*dev' 2>/dev/null || true
        sudo pkill -f 'npm.*start' 2>/dev/null || true
        sudo pkill -f 'node.*3000' 2>/dev/null || true
        sleep 3
        
        echo "✅ Processes stopped. Checking port 3000 again..."
        if lsof -i :3000 >/dev/null 2>&1; then
            echo "⚠️  Port 3000 still in use. Trying force kill..."
            PORT_PID=$(lsof -t -i :3000)
            if [ -n "$PORT_PID" ]; then
                sudo kill -9 $PORT_PID
                echo "✅ Force killed process $PORT_PID"
            fi
        else
            echo "✅ Port 3000 is now free!"
        fi
    fi
elif pgrep -f ":3000" >/dev/null 2>&1; then
    echo "🔍 Found other processes using port 3000"
    echo ""
    echo "Option 1: Kill processes using port 3000"
    PORT_PIDS=$(lsof -t -i :3000 2>/dev/null || true)
    if [ -n "$PORT_PIDS" ]; then
        echo "PIDs using port 3000: $PORT_PIDS"
        read -p "Kill these processes? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            echo "🛑 Stopping processes on port 3000..."
            echo "$PORT_PIDS" | xargs sudo kill -9
            echo "✅ Processes stopped"
        fi
    fi
fi

echo ""
echo "Option 2: Configure explorer to use a different port"
echo ""

# Offer to change the port
read -p "Would you like to change explorer port to 3001? [Y/n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    EXPLORER_DIR="/root/sui-explorer"
    NEW_PORT="3001"
    
    if [ -d "$EXPLORER_DIR" ]; then
        cd "$EXPLORER_DIR"
        
        # Update .env.local
        if [ -f ".env.local" ]; then
            echo "🔧 Updating .env.local to use port $NEW_PORT..."
            sed -i "s/PORT=3000/PORT=$NEW_PORT/" .env.local
            sed -i "s/PORT=.*/PORT=$NEW_PORT/" .env.local
            echo "✅ Updated .env.local"
        else
            echo "🔧 Creating .env.local with port $NEW_PORT..."
            cat > .env.local << EOF
PORT=$NEW_PORT
NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
NODE_ENV=production
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
NEXT_PUBLIC_API_ENDPOINT=http://sui.bcflex.com:9000
EOF
            echo "✅ Created .env.local with port $NEW_PORT"
        fi
        
        # Update systemd service if it exists
        if [ -f "/etc/systemd/system/sui-explorer.service" ]; then
            echo "🔧 Updating systemd service to use port $NEW_PORT..."
            sudo sed -i "s/PORT=3000/PORT=$NEW_PORT/" /etc/systemd/system/sui-explorer.service
            sudo sed -i "s/localhost:3000/localhost:$NEW_PORT/" /etc/systemd/system/sui-explorer.service
            sudo systemctl daemon-reload
            echo "✅ Updated systemd service"
        fi
        
        # Update nginx config if it exists
        if [ -f "/etc/nginx/sites-available/sui.bcflex.com" ]; then
            echo "🔧 Updating nginx proxy to use port $NEW_PORT..."
            sudo sed -i "s/localhost:3000/localhost:$NEW_PORT/" /etc/nginx/sites-available/sui.bcflex.com
            sudo nginx -t && sudo systemctl reload nginx
            echo "✅ Updated nginx configuration"
        fi
        
        echo ""
        echo "✅ Explorer configured to use port $NEW_PORT"
        echo "🌐 Explorer will be available at: http://localhost:$NEW_PORT"
        
    else
        echo "❌ Explorer directory not found: $EXPLORER_DIR"
        echo "Please run the explorer installation script first"
    fi
fi

echo ""
echo "3. Testing port availability..."
echo "==============================="

# Test if port 3000 is now free
if ! lsof -i :3000 >/dev/null 2>&1; then
    echo "✅ Port 3000 is now available"
else
    echo "⚠️  Port 3000 is still in use"
    echo "📋 Current usage:"
    lsof -i :3000
fi

# Test if new port is free (if we changed it)
if [ "${NEW_PORT:-}" ]; then
    if ! lsof -i :$NEW_PORT >/dev/null 2>&1; then
        echo "✅ Port $NEW_PORT is available"
    else
        echo "⚠️  Port $NEW_PORT is also in use"
        echo "📋 Current usage:"
        lsof -i :$NEW_PORT
    fi
fi

echo ""
echo "4. Next steps:"
echo "=============="

if [ -d "/root/sui-explorer" ]; then
    echo "🚀 To start the explorer:"
    echo "   cd /root/sui-explorer"
    if [ "${NEW_PORT:-}" ]; then
        echo "   PORT=$NEW_PORT npm run dev"
        echo "   # Or:"
        echo "   PORT=$NEW_PORT npm start"
    else
        echo "   npm run dev"
        echo "   # Or:"
        echo "   npm start"
    fi
    echo ""
    echo "🔧 To start via systemd service:"
    echo "   sudo systemctl start sui-explorer"
    echo "   sudo systemctl status sui-explorer"
    echo ""
    echo "📋 To monitor:"
    echo "   sudo journalctl -u sui-explorer -f"
else
    echo "❌ Explorer not installed. Run installation script first:"
    echo "   sudo ./force_install_official_explorer.sh"
fi

echo ""
echo "🎯 Port conflict resolution complete!"

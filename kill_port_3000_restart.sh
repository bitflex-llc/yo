#!/bin/bash
# One-liner to kill port 3000 and restart explorer

echo "🔧 Quick Fix: Killing port 3000 and restarting explorer..."

# Kill everything on port 3000
sudo lsof -t -i :3000 2>/dev/null | xargs -r sudo kill -9
sudo fuser -k 3000/tcp 2>/dev/null || true
sudo pkill -f "node.*3000\|next.*dev\|npm.*start\|npm.*dev" 2>/dev/null || true

echo "✅ Port 3000 cleared"

# Wait and restart
sleep 3

if [ -d "/root/sui-explorer" ]; then
    cd /root/sui-explorer
    echo "🚀 Starting explorer..."
    PORT=3000 npm run dev &
    echo "✅ Explorer started! Access: http://localhost:3000"
else
    echo "❌ Explorer directory not found"
fi

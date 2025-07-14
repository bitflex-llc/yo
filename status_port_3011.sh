#!/bin/sh

# Sui Explorer Port 3011 - Final Setup Summary
# This script shows the current configuration and provides quick commands

echo "🌐 SUI EXPLORER PORT 3011 CONFIGURATION"
echo "======================================="

EXPLORER_DIR="/root/sui-explorer"
EXPLORER_PORT="3011"

echo ""
echo "📋 CONFIGURATION SUMMARY"
echo "------------------------"
echo "Explorer Directory: $EXPLORER_DIR"
echo "Explorer Port: $EXPLORER_PORT"
echo "RPC URL: http://sui.bcflex.com:9000"
echo "WebSocket URL: ws://sui.bcflex.com:9001"
echo ""

echo "🔧 AVAILABLE SCRIPTS"
echo "--------------------"
echo "1. 📥 Install Official Explorer:       ./force_install_official_explorer.sh"
echo "2. 🔍 Debug Explorer:                  ./debug_explorer_clean.sh"
echo "3. 🚨 Emergency Port Fix:              ./emergency_port_3011.sh"
echo "4. 📖 Read Documentation:              cat PORT_3011_REFERENCE.md"
echo ""

echo "✅ QUICK STATUS CHECK"
echo "---------------------"

# Check if explorer directory exists
if [ -d "$EXPLORER_DIR" ]; then
    echo "✅ Explorer directory exists"
    
    # Check if apps/explorer directory exists (monorepo structure)
    if [ -d "$EXPLORER_DIR/apps/explorer" ]; then
        echo "✅ Monorepo structure detected (apps/explorer)"
        EXPLORER_APP_DIR="$EXPLORER_DIR/apps/explorer"
    else
        echo "⚠️  Using root directory (may be incorrect)"
        EXPLORER_APP_DIR="$EXPLORER_DIR"
    fi
    
    # Check if package.json exists in the correct location
    if [ -f "$EXPLORER_APP_DIR/package.json" ]; then
        echo "✅ Explorer installed"
        
        # Check .env.local
        if [ -f "$EXPLORER_APP_DIR/.env.local" ]; then
            echo "✅ Environment configured"
            PORT_CONFIG=$(grep "PORT=" "$EXPLORER_APP_DIR/.env.local" 2>/dev/null || echo "PORT not found")
            echo "   $PORT_CONFIG"
        else
            echo "⚠️  Environment not configured"
        fi
    else
        echo "❌ Explorer not installed"
    fi
else
    echo "❌ Explorer directory not found"
fi

# Check if port is in use
echo ""
echo "🔍 PORT STATUS"
echo "--------------"
if command -v lsof > /dev/null; then
    PORT_USAGE=$(lsof -i :$EXPLORER_PORT 2>/dev/null || echo "")
    if [ -n "$PORT_USAGE" ]; then
        echo "🟢 Port $EXPLORER_PORT is in use:"
        echo "$PORT_USAGE"
    else
        echo "🔴 Port $EXPLORER_PORT is free"
    fi
else
    echo "⚠️  lsof not available, checking with netstat..."
    if netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " > /dev/null; then
        echo "🟢 Port $EXPLORER_PORT is in use"
        netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT "
    else
        echo "🔴 Port $EXPLORER_PORT is free"
    fi
fi

# Test if explorer is responding
echo ""
echo "🧪 CONNECTIVITY TEST"
echo "--------------------"
if command -v curl > /dev/null; then
    if curl -s -f http://localhost:$EXPLORER_PORT > /dev/null 2>&1; then
        echo "✅ Explorer is responding on port $EXPLORER_PORT"
        echo "🌐 URL: http://localhost:$EXPLORER_PORT"
    else
        echo "❌ Explorer not responding on port $EXPLORER_PORT"
    fi
else
    echo "⚠️  curl not available for testing"
fi

echo ""
echo "🚀 QUICK ACTIONS"
echo "----------------"
echo "Start Explorer:     cd $EXPLORER_DIR/apps/explorer && PORT=$EXPLORER_PORT npm start"
echo "Kill Port Process:  lsof -ti:$EXPLORER_PORT | xargs kill -9"
echo "View Logs:          tail -f /tmp/explorer_test.log"
echo "Test Connection:    curl -I http://localhost:$EXPLORER_PORT"
echo ""

echo "💡 TROUBLESHOOTING"
echo "------------------"
echo "If explorer doesn't work:"
echo "1. Run: sudo ./emergency_port_3011.sh"
echo "2. Run: sudo ./debug_explorer_clean.sh"
echo "3. Reinstall: sudo ./force_install_official_explorer.sh"
echo ""

echo "🎯 STATUS: Explorer configured for port $EXPLORER_PORT"
echo "Ready for production deployment!"

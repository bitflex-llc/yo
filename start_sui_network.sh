#!/bin/bash

# Master Sui Network Startup Script
echo "🚀 Starting Custom Sui Network"
echo "=============================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
print_status "Step 1: Checking prerequisites..."

# Check if sui binaries exist
if ! command -v sui >/dev/null 2>&1; then
    print_error "Sui CLI not found! Please build and install Sui first."
    echo "Run: cargo build --release --bin sui --bin sui-node --bin sui-faucet"
    exit 1
fi

if ! command -v sui-node >/dev/null 2>&1; then
    print_error "sui-node not found! Please build and install Sui first."
    exit 1
fi

print_success "Sui binaries found"

echo ""
print_status "Step 2: Applying fixes and preparing configuration..."

# Run the fix scripts if they exist
if [ -f "./fix_port_conflicts.sh" ]; then
    print_status "Running port conflict fix..."
    bash ./fix_port_conflicts.sh
else
    print_warning "Port conflict fix script not found, skipping..."
fi

echo ""
print_status "Step 3: Starting the network components..."

echo ""
print_status "🔧 Option 1: Try the simple automated approach"
echo "This uses 'sui start' which should handle most configuration automatically:"
echo ""
echo "sudo systemctl start sui-safe"
echo "sudo systemctl status sui-safe"
echo ""

echo ""
print_status "🔧 Option 2: Try the manual step-by-step approach"
echo ""

read -p "Which option would you like to try? (1/2/manual): " choice

case $choice in
    1)
        print_status "Starting with automated approach..."
        
        # Check if sui-safe service exists
        if systemctl list-unit-files | grep -q sui-safe.service; then
            sudo systemctl start sui-safe
            sleep 5
            
            if systemctl is-active --quiet sui-safe; then
                print_success "Sui network started successfully!"
                echo ""
                print_status "Network status:"
                sudo systemctl status sui-safe --no-pager -l
                echo ""
                print_status "View logs with: sudo journalctl -u sui-safe -f"
                echo ""
                print_status "Network endpoints:"
                echo "  • RPC API: http://localhost:9000"
                echo "  • WebSocket: ws://localhost:9001"
                echo "  • Metrics: http://localhost:9184"
            else
                print_error "Failed to start sui-safe service"
                echo "Check logs with: sudo journalctl -u sui-safe -n 20"
                echo ""
                print_status "Trying option 2..."
                choice=2
            fi
        else
            print_warning "sui-safe service not found, trying option 2..."
            choice=2
        fi
        ;;
    2)
        print_status "Starting with step-by-step approach..."
        ;;
    *)
        print_status "Manual setup selected..."
        echo ""
        print_status "Here are the commands to run manually:"
        echo ""
        echo "1. Fix any issues first:"
        echo "   bash ./fix_port_conflicts.sh"
        echo ""
        echo "2. Start the network:"
        echo "   sudo /root/.sui/start_safe_node.sh"
        echo ""
        echo "3. Or try systemd services:"
        echo "   sudo systemctl start sui-fullnode"
        echo "   sudo systemctl start sui-faucet"
        echo ""
        echo "4. Check status:"
        echo "   /root/.sui/check_ports.sh"
        echo "   sudo systemctl status sui-fullnode"
        echo ""
        exit 0
        ;;
esac

if [ "$choice" = "2" ]; then
    echo ""
    print_status "Step-by-step startup:"
    echo ""
    
    print_status "1. Checking ports..."
    if [ -f "/root/.sui/check_ports.sh" ]; then
        /root/.sui/check_ports.sh
    else
        netstat -tlnp | grep -E ':(8080|8084|9000|9001|9184|5003) '
    fi
    
    echo ""
    print_status "2. Starting fullnode..."
    
    if sudo systemctl start sui-fullnode; then
        print_success "Fullnode service started"
        sleep 5
        
        if systemctl is-active --quiet sui-fullnode; then
            print_success "Fullnode is running"
        else
            print_error "Fullnode failed to start"
            echo "Check logs: sudo journalctl -u sui-fullnode -n 10"
        fi
    else
        print_warning "Systemd service failed, trying manual start..."
        
        if [ -f "/root/.sui/start_safe_node.sh" ]; then
            print_status "Running manual startup script..."
            sudo /root/.sui/start_safe_node.sh &
            MANUAL_PID=$!
            sleep 10
            
            if kill -0 $MANUAL_PID 2>/dev/null; then
                print_success "Manual startup appears to be working"
                print_status "Process running with PID: $MANUAL_PID"
            else
                print_error "Manual startup also failed"
                print_status "Check logs in: /root/.sui/logs/node.log"
            fi
        else
            print_error "No startup script found"
        fi
    fi
    
    echo ""
    print_status "3. Starting faucet..."
    
    if sudo systemctl start sui-faucet; then
        print_success "Faucet service started"
        sleep 3
        
        if systemctl is-active --quiet sui-faucet; then
            print_success "Faucet is running on port 5003"
        else
            print_error "Faucet failed to start"
            echo "Check logs: sudo journalctl -u sui-faucet -n 10"
        fi
    else
        print_warning "Faucet service failed to start"
    fi
    
    echo ""
    print_status "4. Checking explorer..."
    
    if systemctl list-unit-files | grep -q sui-explorer.service; then
        if sudo systemctl start sui-explorer; then
            print_success "Explorer service started"
            sleep 5
            
            if systemctl is-active --quiet sui-explorer; then
                print_success "Explorer is running on port 3000"
            else
                print_warning "Explorer failed to start (this is optional)"
            fi
        else
            print_warning "Explorer service failed to start (this is optional)"
        fi
    else
        print_warning "Explorer service not found (this is optional)"
    fi
fi

echo ""
print_success "========================================="
print_success "🎉 Sui Network Startup Completed! 🎉"
print_success "========================================="

echo ""
print_status "Network Endpoints:"
echo "  • RPC API: http://localhost:9000"
echo "  • WebSocket: ws://localhost:9001"
echo "  • Faucet: http://localhost:5003"
echo "  • Block Explorer: http://localhost:3000 (if running)"
echo "  • Metrics: http://localhost:9184"

echo ""
print_status "Quick Tests:"
echo "  • Test RPC: curl -X POST http://localhost:9000 -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"method\":\"sui_getLatestSuiSystemState\",\"params\":[],\"id\":1}'"
echo "  • Test Faucet: curl http://localhost:5003"
echo "  • View Metrics: curl http://localhost:9184/metrics"

echo ""
print_status "Management Commands:"
echo "  • Check Status: /root/.sui/check_ports.sh"
echo "  • View Logs: sudo journalctl -u sui-safe -f"
echo "  • Stop Network: sudo systemctl stop sui-safe sui-fullnode sui-faucet sui-explorer"

echo ""
print_status "Account Information:"
if [ -f "/root/.sui/account_info.env" ]; then
    . "/root/.sui/account_info.env"
    echo "  • Genesis Account: $GENESIS_ACCOUNT_ADDRESS"
    echo "  • Validator: $VALIDATOR_ADDRESS"
    echo "  • Private Keys: /root/.sui/keystores/"
else
    echo "  • Run original install to create accounts"
fi

echo ""
print_warning "🔒 SECURITY REMINDER:"
print_warning "This is a local development network. Keep private keys secure!"

echo ""
print_status "If you see any errors, check the logs and run fix scripts as needed."

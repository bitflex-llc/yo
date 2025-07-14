# 🚀 How to Start Your Custom Sui Network

## Quick Start (Recommended)

The simplest way to get your Sui network running:

```bash
# 1. Run the quick start script
sudo bash quick_start.sh
```

This script will:
- Clean up any existing processes
- Try the simplest `sui start` command first
- Fall back to configuration-based startup if needed
- Show you exactly what's happening

## Step-by-Step Manual Start

If the quick start doesn't work, try these steps manually:

### Step 1: Clean Up
```bash
# Kill any existing Sui processes
sudo pkill -9 -f sui
sleep 3

# Stop systemd services
sudo systemctl stop sui-* 2>/dev/null || true
```

### Step 2: Basic Start (Easiest)
```bash
# Go to sui directory
cd /root/.sui

# Try the simplest approach
sudo -u root /usr/local/bin/sui start
```

### Step 3: Test Connection
```bash
# Test if RPC is working (in another terminal)
curl -X POST http://localhost:9000 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"sui_getLatestSuiSystemState","params":[],"id":1}'
```

### Step 4: Add Faucet (Optional)
```bash
# Start faucet in another terminal
sudo -u root /usr/local/bin/sui-faucet --port 5003 --host-ip 0.0.0.0
```

## Network Endpoints

Once running, your network will be available at:

- **🌐 RPC API**: http://localhost:9000
- **🔌 WebSocket**: ws://localhost:9001  
- **💧 Faucet**: http://localhost:5003
- **📊 Metrics**: http://localhost:9184

## Quick Tests

### Test RPC Connection
```bash
curl -X POST http://localhost:9000 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"sui_getLatestSuiSystemState","params":[],"id":1}'
```

### Test Faucet
```bash
curl http://localhost:5003
```

### Get Network Info
```bash
curl -X POST http://localhost:9000 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"sui_getChainIdentifier","params":[],"id":1}'
```

## Account Information

Your pre-mined account information should be in:
```bash
cat /root/.sui/account_info.env
```

Private keys are backed up in:
```bash
ls -la /root/.sui/keystores/
```

## Troubleshooting

### If Nothing Starts
1. **Check Sui is built**: `/usr/local/bin/sui --version`
2. **Check logs**: `tail -f /root/.sui/logs/startup.log`
3. **Try manual start**: `cd /root/.sui && sudo -u root /usr/local/bin/sui start`

### If Ports Are Busy
```bash
# Check what's using ports
netstat -tlnp | grep -E ':(9000|9001|8084|9184)'

# Kill specific processes
sudo lsof -ti:9000 | xargs sudo kill -9
```

### If Genesis Issues
```bash
# Recreate genesis
cd /root/.sui
sudo rm -rf genesis/ sui_config/
sudo -u root /usr/local/bin/sui genesis -f --working-dir genesis/
```

## Management Commands

### Start Network
```bash
sudo bash quick_start.sh
```

### Stop Network  
```bash
sudo pkill -f sui
```

### Check Status
```bash
# Check processes
ps aux | grep sui

# Check ports
netstat -tlnp | grep -E ':(9000|9001|8084|9184)'

# Test RPC
curl -s http://localhost:9000 -X POST \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"sui_getLatestSuiSystemState","params":[],"id":1}' \
  | python3 -m json.tool
```

### View Logs
```bash
tail -f /root/.sui/logs/startup.log
```

## Important Notes

- 🔒 **Security**: This is a local development network. Keep private keys secure!
- 💰 **Pre-mined Account**: You have 1,000,000 SUI in your genesis account
- ⚙️ **Modified Payouts**: 1% delegators, 1.5% validators (as requested)
- 🌐 **Network**: Local only - not connected to mainnet or testnet

## Need Help?

If you're still having issues:

1. **Check build**: Make sure Sui compiled successfully
2. **Check dependencies**: Run `ldd /usr/local/bin/sui`
3. **Check logs**: Look at `/root/.sui/logs/` for error messages
4. **Try rebuilding**: `cargo clean && cargo build --release`

The `quick_start.sh` script should handle most common issues automatically!

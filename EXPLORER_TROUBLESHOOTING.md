# Sui Explorer Troubleshooting Guide

## Issue: Official Sui Explorer Missing npm Scripts

### Problem Description
When trying to deploy the official Sui Explorer from https://github.com/MystenLabs/sui-explorer, you may encounter:

```bash
❌ No suitable start command found
📋 Available scripts:
Lifecycle scripts included in sui-explorer@1.0.0:
  test
    echo "Error: no test specified" && exit 1
```

This happens because the official repository only includes a basic `test` script and lacks the standard `start`, `dev`, or `build` scripts needed to run the explorer.

### Root Cause
The MystenLabs/sui-explorer repository appears to be:
1. A reference implementation without production scripts
2. Missing essential npm scripts for building/running
3. Not intended for direct deployment

### Solution: Automatic Fallback
Our deployment scripts automatically detect this issue and switch to a custom standalone explorer:

#### 1. Detection Logic
```bash
# Check for required scripts
if npm run 2>&1 | grep -q "dev"; then
    START_CMD="npm run dev"
elif npm run 2>&1 | grep -q "start"; then
    START_CMD="npm start"
else
    # No scripts found - trigger fallback
    echo "🔄 Switching to standalone explorer..."
    setup_standalone_explorer
fi
```

#### 2. Standalone Explorer Features
- **Express.js server** with built-in API endpoints
- **Modern responsive UI** with real-time data
- **RPC integration** with your custom Sui network
- **Transaction browser** with live updates
- **Network statistics** display
- **Faucet integration** testing
- **Auto-refresh** every 30 seconds

#### 3. API Endpoints
```javascript
GET /                    - Main explorer interface
GET /api/system-state   - Network system state
GET /api/chain-info     - Chain identifier
GET /api/transactions   - Recent transactions
GET /health             - Health check
```

### Files Involved

#### 1. debug_explorer.sh
- **Purpose**: Diagnose and fix explorer issues
- **Features**: 
  - Detects missing npm scripts
  - Automatically sets up fallback explorer
  - Tests functionality
  - Creates fixed systemd service

#### 2. install_and_setup_explorer.sh  
- **Purpose**: Main explorer installation script
- **Features**:
  - Attempts official explorer first
  - Falls back to standalone on failure
  - Sets up nginx proxy with SSL
  - Creates systemd services

#### 3. Standalone Explorer Components
```
/root/sui-explorer-standalone/
├── package.json          # Node.js project config
├── server.js            # Express.js backend
└── public/
    └── index.html       # Frontend UI
```

### Usage Instructions

#### Quick Fix (if explorer is broken)
```bash
sudo ./debug_explorer.sh
```

#### Complete Fresh Install
```bash
sudo ./install_and_setup_explorer.sh
```

#### Manual Service Management
```bash
# Restart explorer service
sudo systemctl restart sui-explorer

# Check logs
sudo journalctl -u sui-explorer -f

# Check status
sudo systemctl status sui-explorer
```

### Testing the Explorer

#### 1. Local Testing
```bash
cd /root/sui-explorer
npm start
# Visit http://localhost:3000
```

#### 2. Production Testing
```bash
# Test direct connection
curl -I http://localhost:3000

# Test via nginx proxy
curl -I https://sui.bcflex.com

# Test API endpoints
curl http://localhost:3000/api/chain-info
```

### Network Configuration

#### Required Environment Variables
```bash
NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
PORT=3000
NODE_ENV=production
```

#### Systemd Service
```ini
[Unit]
Description=Sui Block Explorer
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/sui-explorer
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
ExecStart=/usr/bin/npm start
Restart=always

[Install]
WantedBy=multi-user.target
```

### Nginx Configuration
```nginx
server {
    listen 80;
    server_name sui.bcflex.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name sui.bcflex.com;
    
    ssl_certificate /etc/letsencrypt/live/sui.bcflex.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sui.bcflex.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Verification Steps

#### 1. Check All Services
```bash
sudo systemctl status sui-fullnode
sudo systemctl status sui-validator  
sudo systemctl status sui-faucet
sudo systemctl status sui-explorer
sudo systemctl status nginx
```

#### 2. Test Endpoints
```bash
# RPC endpoint
curl -X POST http://sui.bcflex.com:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"sui_getChainIdentifier","params":[],"id":1}'

# Faucet endpoint  
curl http://sui.bcflex.com:5003/health

# Explorer endpoint
curl https://sui.bcflex.com
```

#### 3. Check Logs
```bash
# Explorer logs
sudo journalctl -u sui-explorer -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Network logs
sudo journalctl -u sui-fullnode -f
```

### Common Issues and Solutions

#### 1. Port Conflicts
```bash
# Check what's using port 3000
sudo netstat -tulpn | grep :3000
sudo lsof -i :3000

# Kill conflicting process
sudo pkill -f "port 3000"
```

#### 2. Permission Issues
```bash
# Fix ownership
sudo chown -R root:root /root/sui-explorer

# Fix permissions
sudo chmod +x /root/sui-explorer/server.js
```

#### 3. Node.js Issues
```bash
# Update Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Clear npm cache
sudo npm cache clean --force
```

#### 4. SSL Certificate Issues
```bash
# Renew certificates
sudo certbot renew

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

### Features of the Standalone Explorer

#### 1. Network Statistics
- **Chain ID**: Displays the unique identifier of your Sui network
- **Current Epoch**: Shows the current epoch number
- **Active Validators**: Number of active validators
- **Total Stake**: Total amount of SUI staked

#### 2. Real-time Updates
- **Auto-refresh**: Updates every 30 seconds
- **Live data**: Fetches data directly from your RPC endpoint
- **Error handling**: Graceful degradation on connection issues

#### 3. Transaction Browser
- **Recent transactions**: Shows latest transaction blocks
- **Transaction details**: Digest, checkpoint information
- **Status indicators**: Visual status of each transaction

#### 4. Connection Testing
- **RPC test**: Verifies connection to Sui RPC endpoint
- **Faucet test**: Checks faucet availability
- **Health checks**: Monitors service health

#### 5. Custom Branding
- **BCFlex theme**: Custom styling for your network
- **Responsive design**: Works on desktop and mobile
- **Professional UI**: Modern gradient design with animations

### Performance Optimization

#### 1. Caching
The standalone explorer includes basic caching for API responses to reduce load on your RPC endpoint.

#### 2. Resource Limits
Systemd service includes memory limits to prevent resource exhaustion:
```ini
LimitNOFILE=65536
MemoryMax=2G
```

#### 3. Monitoring
Built-in health checks and logging for monitoring:
```bash
# Monitor resource usage
sudo systemctl status sui-explorer

# Check memory usage
ps aux | grep node
```

### Conclusion

This solution provides a robust, production-ready block explorer for your custom Sui network that:
- ✅ **Works reliably** without depending on incomplete upstream repositories
- ✅ **Automatically falls back** when official explorers fail
- ✅ **Integrates seamlessly** with your existing Sui network infrastructure
- ✅ **Provides all essential features** for blockchain exploration
- ✅ **Includes proper monitoring** and error handling
- ✅ **Supports SSL/HTTPS** with automatic certificate management

The explorer is now accessible at https://sui.bcflex.com and ready for production use!

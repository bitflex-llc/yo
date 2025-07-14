# BCFlex Sui Network - Official Explorer Only

## Overview

This deployment uses **ONLY** the official MystenLabs Sui Explorer. All fallback and standalone alternatives have been removed to ensure a clean, professional installation.

## Key Features

- ✅ Official MystenLabs Sui Explorer
- ✅ Configured for port 3011 (avoids conflicts)
- ✅ No fallback alternatives
- ✅ Clean, professional setup
- ✅ Production-ready configuration

## Installation Scripts

### 1. `force_install_official_explorer.sh`
- **Purpose**: Force installs the official Sui Explorer
- **Port**: 3011
- **Directory**: /root/sui-explorer/apps/explorer (monorepo structure)
- **Features**: 
  - Clones from MystenLabs/sui-explorer
  - Builds from apps/explorer subdirectory
  - Configures for BCFlex network
  - Sets up systemd service
  - No fallbacks

### 2. `debug_explorer.sh`
- **Purpose**: Debug official explorer only
- **Features**:
  - Checks explorer setup
  - Fixes port configuration
  - Tests functionality
  - No fallback logic

### 3. `emergency_port_3011.sh`
- **Purpose**: Emergency port conflict resolution
- **Features**:
  - Kills port conflicts
  - Restarts explorer on port 3011
  - Quick fix for EADDRINUSE errors

### 4. `install_official_explorer_only.sh`
- **Purpose**: Simple wrapper for official installation
- **Features**:
  - Calls force_install_official_explorer.sh
  - Provides clear messaging about no fallbacks

## Configuration

### Port 3011
- Main explorer port: 3011
- Avoids common conflicts with port 3000
- Properly configured in all scripts

### Environment Variables
```bash
PORT=3011
NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
NODE_ENV=production
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
```

### Systemd Service
- Service name: `sui-explorer`
- User: root
- Working directory: `/root/sui-explorer/apps/explorer`
- Port: 3011

## Usage

### Install Explorer
```bash
sudo ./force_install_official_explorer.sh
```

### Debug Issues
```bash
sudo ./debug_explorer.sh
```

### Emergency Fix
```bash
sudo ./emergency_port_3011.sh
```

### Check Status
```bash
sudo ./status_port_3011.sh
```

## Troubleshooting

### Common Issues

1. **Port 3000 conflicts**: Use emergency_port_3011.sh
2. **Explorer not starting**: Run debug_explorer.sh
3. **Service not running**: Check systemctl status sui-explorer

### Manual Commands

```bash
# Navigate to explorer app directory
cd /root/sui-explorer/apps/explorer

# Check port usage
lsof -i :3011

# Kill port processes
lsof -ti:3011 | xargs kill -9

# Start explorer manually
PORT=3011 npm start

# Test explorer
curl -I http://localhost:3011

# Check logs
journalctl -u sui-explorer -f
```

## Benefits of Official Explorer Only

1. **Clean Installation**: No confusion with multiple versions
2. **Professional Setup**: Uses official MystenLabs code
3. **Better Maintenance**: Single codebase to maintain
4. **Proper Updates**: Can pull updates from official repo
5. **No Dependencies**: Eliminates custom fallback dependencies

## Removed Components

The following fallback/standalone components have been **completely removed**:

- ❌ Standalone explorer setup
- ❌ Fallback HTML pages
- ❌ Custom express servers
- ❌ Alternative installation paths
- ❌ Mixed installation logic

## Production Deployment

1. Run installation: `sudo ./force_install_official_explorer.sh`
2. Configure nginx proxy for port 3011
3. Set up monitoring for port 3011
4. Configure firewall if needed

### Nginx Example
```nginx
location /explorer/ {
    proxy_pass http://localhost:3011/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

**Status**: ✅ All fallback components removed  
**Explorer**: Official MystenLabs only  
**Port**: 3011  
**Ready**: Production deployment

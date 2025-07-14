# Sui Explorer Port 3011 Configuration - Quick Reference

## Summary of Changes

The Sui Explorer has been configured to run on **port 3011** instead of port 3000 to avoid common conflicts.

## Key Files Updated

### 1. `force_install_official_explorer.sh`
- ✅ Added `EXPLORER_PORT="3011"` variable
- ✅ Updated .env.local to use `PORT=3011`
- ✅ Added port conflict detection and cleanup for port 3011
- ✅ Updated systemd service to use port 3011
- ✅ Updated all test URLs to use port 3011
- ✅ Updated final output messages to show port 3011

### 2. `debug_explorer.sh`
- ✅ Added `EXPLORER_PORT="3011"` variable
- ✅ Removed fallback to standalone explorer (forces official only)
- ✅ Updated all port references to use port 3011
- ✅ Updated test URLs to use port 3011

### 3. `emergency_port_3011.sh` (NEW)
- ✅ Emergency script to kill port conflicts and start explorer on 3011
- ✅ Kills processes on both port 3000 and 3011
- ✅ Updates .env.local to use port 3011
- ✅ Starts explorer with proper port configuration
- ✅ Tests explorer availability on port 3011

## How to Use

### Quick Start on Port 3011
```bash
sudo ./force_install_official_explorer.sh
```

### Emergency Port Conflict Resolution
```bash
sudo ./emergency_port_3011.sh
```

### Debug Explorer Issues
```bash
sudo ./debug_explorer.sh
```

## Port Configuration

### Environment Variables
- `PORT=3011` in .env.local
- `EXPLORER_PORT="3011"` in scripts

### Systemd Service
- Service configured to run on port 3011
- Environment variables set correctly

### URLs
- Local access: `http://localhost:3011`
- Public access: `https://sui.bcflex.com` (via nginx proxy)

## Troubleshooting

### Common Issues
1. **"EADDRINUSE: address already in use :::3000"**
   - Solution: Run `./emergency_port_3011.sh`

2. **"EADDRINUSE: address already in use :::3011"**
   - Solution: Run `./emergency_port_3011.sh` (clears both ports)

3. **Explorer not responding**
   - Check: `curl http://localhost:3011`
   - Debug: `./debug_explorer.sh`
   - Logs: `tail -f /tmp/explorer.log`

### Manual Port Check
```bash
# Check what's using port 3011
lsof -i :3011

# Kill process on port 3011
lsof -ti:3011 | xargs kill -9

# Check if explorer is running
curl -I http://localhost:3011
```

## Next Steps

### For Production Deployment
1. Update nginx configuration to proxy port 3011
2. Update firewall rules if needed
3. Update monitoring to check port 3011
4. Update documentation for team

### Nginx Configuration Example
```nginx
location /explorer/ {
    proxy_pass http://localhost:3011/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Benefits of Port 3011

1. **Avoids Conflicts**: Port 3000 commonly used by other services
2. **Stable Operation**: Dedicated port for explorer
3. **Easy Debugging**: Clear separation from other services
4. **Production Ready**: Professional port management

---

**Last Updated**: Port configuration migrated from 3000 to 3011
**Status**: ✅ Ready for deployment

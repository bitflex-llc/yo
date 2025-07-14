# Complete Sui Explorer Troubleshooting Guide

## Quick Emergency Fixes

### Import/Build Errors
```bash
# If you see import errors like "Cannot resolve component"
cd /root/sui-explorer/apps/explorer
./emergency_cleanup_config.sh
pnpm install
pnpm run dev -- --host 0.0.0.0 --port 3011
```

### Port Conflicts
```bash
# Emergency port cleanup
./emergency_port_3011.sh
```

### Git Conflicts
```bash
# Fix git conflicts
./fix_git_conflict.sh
```

## Common Error Patterns

### 1. Import Resolution Errors
**Symptoms:**
- "Cannot resolve module '@/components/...'"
- "Module not found: Can't resolve 'src/...'"
- Build fails with component import errors

**Cause:** Custom pages/structure conflicting with official explorer

**Fix:**
```bash
cd /root/sui-explorer/apps/explorer
rm -rf pages/ src/pages/ app/ 2>/dev/null || true
git checkout -- . 2>/dev/null || true
./emergency_cleanup_config.sh
```

### 2. Workspace Dependency Errors
**Symptoms:**
- "workspace:* not found"
- npm install fails with workspace errors
- Dependencies not resolving

**Cause:** Using npm instead of pnpm

**Fix:**
```bash
cd /root/sui-explorer
rm -rf node_modules apps/explorer/node_modules
pnpm install
```

### 3. Host/Network Errors
**Symptoms:**
- "Invalid Host header"
- Cannot access from external domain
- Vite blocks external connections

**Fix:**
```bash
cd /root/sui-explorer/apps/explorer
cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    host: '0.0.0.0',
    port: 3011,
    cors: true,
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      'sui.bcflex.com',
      '.bcflex.com',
      '.vercel.app'
    ]
  }
})
EOF
```

### 4. Port Conflicts
**Symptoms:**
- "Port 3011 already in use"
- EADDRINUSE errors
- Cannot start server

**Fix:**
```bash
./emergency_port_3011.sh
```

### 5. Configuration Conflicts
**Symptoms:**
- Build fails after config changes
- Unexpected behavior after customization
- Explorer doesn't match official version

**Fix:**
```bash
./emergency_cleanup_config.sh
# Only create .env.local, nothing else
```

## Step-by-Step Complete Recovery

### 1. Nuclear Option - Complete Reset
```bash
cd /root
rm -rf sui-explorer
./force_install_official_explorer.sh
```

### 2. Surgical Fix - Keep Git History
```bash
cd /root/sui-explorer
git stash
git checkout main
git pull origin main
cd apps/explorer
./emergency_cleanup_config.sh
pnpm install
```

### 3. Minimal Fix - Clean Configs Only
```bash
cd /root/sui-explorer/apps/explorer
./emergency_cleanup_config.sh
# Re-create only .env.local
cat > .env.local << EOF
NEXT_PUBLIC_RPC_URL=http://sui.bcflex.com:9000
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
PORT=3011
HOST=0.0.0.0
EOF
```

## Safe Customization Guidelines

### ✅ SAFE to Create/Modify
- `.env.local` - Environment variables
- `.env` - Environment variables  
- `vite.config.ts` - Host allowlist only
- External service files (`/etc/systemd/system/sui-explorer.service`)

### ❌ NEVER Create/Modify
- `next.config.js` - Use official version
- `package.json` - Use official version
- `pages/` directory - Use official structure
- `src/` directory - Use official structure
- `app/` directory - Use official structure
- Any React components

### 🔧 Required Commands
- **Install:** `pnpm install` (not npm)
- **Build:** `pnpm run build`
- **Start:** `pnpm run dev -- --host 0.0.0.0 --port 3011`
- **Production:** `pnpm start`

## Validation Checklist

### Before Starting Explorer
- [ ] No custom `next.config.js` exists
- [ ] No custom `pages/` directory exists
- [ ] Using `pnpm` (not npm)
- [ ] Port 3011 is available
- [ ] Git status is clean or conflicts resolved

### Testing Commands
```bash
# Check structure
ls -la src/ pages/ app/ 2>/dev/null | grep -v "No such file"

# Check dependencies  
grep "workspace:" package.json

# Check port
lsof -i :3011

# Check configs
ls -la *.config.*
```

### Success Indicators
- `pnpm run dev` starts without errors
- Explorer accessible on port 3011
- No import resolution errors in console
- Official Sui Explorer UI appears (not custom pages)

## Emergency Contacts & Scripts

### Available Scripts
- `./force_install_official_explorer.sh` - Complete installation
- `./emergency_port_3011.sh` - Port conflict resolution
- `./emergency_cleanup_config.sh` - Remove conflicting configs
- `./fix_git_conflict.sh` - Git conflict resolution
- `./debug_explorer.sh` - Debug and status check

### Log Locations
- Installation: Check script output
- Runtime: `journalctl -u sui-explorer -f`
- Development: Terminal output from `pnpm run dev`

### Quick Status Check
```bash
./status_port_3011.sh
```

This will show:
- Port usage
- Process status
- Service status
- Configuration status

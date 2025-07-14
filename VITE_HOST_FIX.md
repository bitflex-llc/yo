# VITE HOST ALLOWLIST FIX

## Problem Fixed
The error `Blocked request. This host ("sui.bcflex.com") is not allowed. To allow this host, add "sui.bcflex.com" to server.allowedHosts in vite.config.js` occurred because Vite's dev server blocks requests from non-localhost hosts by default for security.

## Root Cause
The official Sui Explorer uses Vite as the development server, and Vite has a security feature that blocks requests from external hosts unless they're explicitly allowed in the configuration.

## Solution Applied

### 1. Created Vite Configuration
Added `vite.config.ts` with allowed hosts:
```typescript
export default defineConfig({
  plugins: [react()],
  server: {
    allowedHosts: [
      'sui.bcflex.com',
      'localhost', 
      '127.0.0.1',
      '0.0.0.0',
      '.bcflex.com'  // Allow all bcflex.com subdomains
    ],
    host: '0.0.0.0',  // Allow external connections
    port: parseInt(process.env.PORT) || 3011,
    strictPort: false
  }
})
```

### 2. Updated Environment Variables
Added Vite-specific environment variables:
```bash
# Vite-specific configuration
VITE_RPC_URL=http://sui.bcflex.com:9000
VITE_WS_URL=ws://sui.bcflex.com:9001
VITE_NETWORK=custom
VITE_NETWORK_NAME=BCFlex Sui Network
VITE_API_ENDPOINT=http://sui.bcflex.com:9000

# Development server configuration
HOST=0.0.0.0
HOSTNAME=0.0.0.0
```

### 3. Updated Development Commands
Changed dev commands to include host settings:
```bash
# Old command
pnpm run dev

# New command  
pnpm run dev -- --host 0.0.0.0 --port 3011
```

### 4. Updated All Scripts
- **force_install_official_explorer.sh**: Creates Vite config, sets environment variables
- **debug_explorer.sh**: Ensures Vite config exists, uses proper dev command
- **emergency_port_3011.sh**: Updated to work with Vite dev server

## Why This Fix is Needed

1. **Security Feature**: Vite blocks external hosts by default to prevent malicious requests
2. **Development vs Production**: This affects development mode (`pnpm run dev`) more than production (`pnpm start`)
3. **Custom Domain**: Using `sui.bcflex.com` instead of localhost triggers the security check
4. **External Access**: Allows the explorer to be accessed from external IPs/domains

## Files Modified

### New Files Created
- `vite.config.ts` - Vite configuration with allowed hosts
- `.env` - Production environment variables
- Updated `.env.local` - Development environment variables

### Modified Scripts
- `force_install_official_explorer.sh` - Added Vite config creation
- `debug_explorer.sh` - Added Vite config check and host settings
- Both now use `--host 0.0.0.0 --port 3011` for dev commands

## Testing the Fix

After running the updated script:
```bash
sudo ./force_install_official_explorer.sh
```

The explorer should start without the "Blocked request" error and be accessible on:
- `http://localhost:3011`
- `http://sui.bcflex.com:3011` (if DNS is configured)
- `http://[server-ip]:3011`

## Additional Benefits

1. **External Access**: Server can be accessed from other machines
2. **Subdomain Support**: Supports all `.bcflex.com` subdomains
3. **Flexible Ports**: Uses environment PORT variable with fallback
4. **Production Ready**: Includes both dev and production configurations

---

**Status**: ✅ Vite host blocking issue resolved  
**Access**: External hosts now allowed  
**Port**: 3011 with host 0.0.0.0  
**Configuration**: vite.config.ts created

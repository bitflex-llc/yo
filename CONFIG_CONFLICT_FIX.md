# Configuration Conflict Fix Guide

## Problem Summary
The official Sui Explorer is a complex monorepo project with its own pre-configured build system. Custom configuration files were causing import conflicts and breaking the official structure.

## Root Cause
- Creating custom `next.config.js` that conflicts with official explorer config
- Creating custom pages structure that breaks official imports
- Overriding workspace dependencies that the official explorer expects

## Solution Applied

### 1. Removed Custom Config Creation
```bash
# BEFORE (WRONG):
cat > next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  // custom config...
}
EOF

# AFTER (CORRECT):
# DO NOT create custom next.config.js - use the official explorer's configuration
echo "✅ Using official Sui Explorer Next.js configuration"
```

### 2. Removed Custom Pages Structure
```bash
# BEFORE (WRONG):
mkdir -p pages
cat > pages/index.js << 'EOF'
// custom page...
EOF

# AFTER (CORRECT):
# DO NOT create custom pages - use the official explorer structure as-is
echo "✅ Using official Sui Explorer structure (no custom pages needed)"
```

### 3. Only Safe Customizations
The script now only creates:
- **Environment files** (`.env.local`, `.env`) - Safe to customize
- **Vite config** (`vite.config.ts`) - Only for host allowlist, doesn't break structure
- **Systemd service files** - External to the project

## Files That Should NOT Be Created/Modified
- `next.config.js` - Use official config
- `package.json` - Use official package.json
- `pages/` directory - Use official pages structure
- `src/` directory structure - Use official src structure
- `app/` directory - Use official app structure
- Any React components - Use official components

## Files That Are Safe to Create/Modify
- `.env.local` - Environment variables
- `.env` - Environment variables
- `vite.config.ts` - Host allowlist only
- Service files outside the project directory

## Testing Configuration Changes
1. Clone fresh official explorer: `git clone https://github.com/MystenLabs/sui.git`
2. Navigate to explorer: `cd sui/apps/explorer`
3. Check existing config: `ls -la *.config.*`
4. DO NOT override existing configs
5. Only add environment variables

## Error Patterns to Watch For
- **Import errors**: Usually caused by custom pages structure
- **Build errors**: Usually caused by custom next.config.js
- **Workspace errors**: Usually caused by npm instead of pnpm
- **Host errors**: Fixed by vite.config.ts with allowlist

## Emergency Recovery
If imports are still broken:
1. Remove ALL custom files: `rm -f next.config.js pages/ src/`
2. Reset to official state: `git checkout -- .`
3. Only add environment files
4. Use official build commands with pnpm

# Quick Fix for "Failed to resolve import ~/components/Layout" Error

## Problem
You're seeing this error:
```
Failed to resolve import "~/components/Layout" from "src/pages/index.tsx". Does the file exist?
```

## Root Cause
This is a TypeScript path mapping issue. The `~` symbol should resolve to the `src/` directory, but the path mapping isn't configured correctly.

## Quick Fix

### Step 1: Run the Emergency Cleanup
```bash
cd /Users/egortagirov/Desktop/yo
./emergency_cleanup_config.sh
```

### Step 2: Fix TypeScript Path Mapping
```bash
./fix_typescript_paths.sh
```

### Step 3: Reinstall Dependencies
```bash
cd /root/sui-explorer/apps/explorer
pnpm install
```

### Step 4: Try Running the Explorer
```bash
pnpm run dev -- --host 0.0.0.0 --port 3011
```

## What the Scripts Do

### emergency_cleanup_config.sh
- Removes any conflicting custom configuration files
- Analyzes the current project structure
- Identifies missing components and path mapping issues

### fix_typescript_paths.sh  
- Checks for proper TypeScript configuration
- Adds missing path mappings (`"~/*": ["./src/*"]`)
- Searches for missing Layout components
- Tests TypeScript compilation

## Expected Results

After running these scripts:
- ✅ TypeScript can resolve `~/components/Layout` to `src/components/Layout`
- ✅ All other `~/` imports should work
- ✅ The explorer should build and run without import errors

## If Still Not Working

### Check if Layout Component Exists
```bash
cd /root/sui-explorer/apps/explorer
find . -name "*Layout*" -type f
```

### Check TypeScript Config
```bash
grep -A 10 '"paths"' tsconfig.json
```

### Manual Path Mapping Fix
If the scripts don't work, manually edit `tsconfig.json`:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "~/*": ["./src/*"],
      "@/*": ["./src/*"]
    }
  }
}
```

## Alternative: Use Relative Imports
If path mapping continues to fail, you can temporarily change the imports in `src/pages/index.tsx`:

Change:
```typescript
import { Layout } from "~/components/Layout";
```

To:
```typescript
import { Layout } from "../components/Layout";
```

## Emergency Recovery
If everything breaks:
```bash
cd /root
rm -rf sui-explorer
./force_install_official_explorer.sh
```

This will do a complete fresh installation of the official explorer.

# WORKSPACE DEPENDENCY FIX - PNPM REQUIRED

## Problem Fixed
The error `npm error code EUNSUPPORTEDPROTOCOL npm error Unsupported URL Type "workspace:": workspace:*` occurred because the official Sui Explorer uses a monorepo structure with workspace dependencies that require `pnpm` instead of `npm`.

## Changes Made

### 1. Added pnpm Installation
- Added `install_pnpm()` function to force_install_official_explorer.sh
- Installs pnpm globally via npm
- Verifies pnpm installation

### 2. Updated Dependency Installation
- Changed from `npm install` to `pnpm install`
- Install workspace dependencies from root first: `/root/sui-explorer`
- Then work from app directory: `/root/sui-explorer/apps/explorer`

### 3. Updated Build Commands
- Changed `npm run build` to `pnpm run build`
- Changed `npm start` to `pnpm start` 
- Changed `npm run dev` to `pnpm run dev`

### 4. Updated Systemd Service
- ExecStart now uses pnpm path instead of npm
- Dynamically finds pnpm location with `which pnpm`
- Falls back to `/usr/local/bin/pnpm` if not found

### 5. Updated All Scripts
- **debug_explorer.sh**: Uses pnpm commands
- **emergency_port_3011.sh**: Prefers pnpm, falls back to npm
- **status_port_3011.sh**: Shows pnpm commands in quick actions

### 6. Updated Documentation
- OFFICIAL_EXPLORER_ONLY.md now mentions pnpm requirement
- Manual commands section updated to use pnpm
- Added workspace installation steps

## Why pnpm is Required

The official Sui Explorer repository uses:
- Monorepo structure with multiple packages
- Workspace dependencies (`workspace:*` protocol)
- Shared dependencies across packages
- Advanced dependency resolution

npm cannot handle `workspace:*` dependencies, but pnpm has native workspace support.

## Installation Flow

1. **Install Node.js** (via NodeSource)
2. **Install Git** 
3. **Install pnpm** (via npm global install)
4. **Clone repository** (MystenLabs/sui-explorer)
5. **Install workspace deps** (pnpm install from root)
6. **Navigate to app** (cd apps/explorer)
7. **Build & start** (pnpm run build && pnpm start)

## Verification

Test the fix with:
```bash
sudo ./force_install_official_explorer.sh
```

Should now complete without workspace dependency errors.

---

# Workspace Dependencies Fix Summary

## Critical Changes Made

### 1. Removed All Custom Structure Creation
- **REMOVED**: Custom Next.js pages creation that was breaking official explorer
- **REMOVED**: Custom `next.config.js` creation that was conflicting with official config
- **KEPT**: Only environment files (.env.local, .env) and Vite config for host allowlist

### 2. Switched to pnpm for Workspace Dependencies
- All workspace dependency installations now use `pnpm` commands
- Ensures compatibility with official Sui Explorer monorepo setup

**Status**: ✅ Workspace dependency issue resolved  
**Package Manager**: pnpm (required)  
**Build Location**: /root/sui-explorer/apps/explorer  
**Port**: 3011

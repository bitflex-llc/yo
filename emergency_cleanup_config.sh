#!/bin/bash
set -e

# Emergency Configuration Cleanup Script
# This script removes any custom configurations that might conflict with the official Sui Explorer

echo "🚨 Emergency Configuration Cleanup for Official Sui Explorer"
echo "==============================================================="

EXPLORER_DIR="/root/sui-explorer"
EXPLORER_APP_DIR="$EXPLORER_DIR/apps/explorer"

# Check if we're in the right location
if [ ! -d "$EXPLORER_APP_DIR" ]; then
    echo "❌ Explorer directory not found at $EXPLORER_APP_DIR"
    echo "Please run this script after the explorer has been cloned"
    exit 1
fi

cd "$EXPLORER_APP_DIR"
echo "📍 Working in: $(pwd)"

echo ""
echo "🧹 Removing potentially conflicting custom files..."

# Remove custom config files that might conflict
if [ -f "next.config.custom.js" ]; then
    echo "📧 Removing custom next.config.js..."
    rm -f next.config.custom.js
fi

if [ -f "next.config.override.js" ]; then
    echo "📧 Removing override next.config.js..."
    rm -f next.config.override.js
fi

# Check for custom pages directory
if [ -d "pages" ]; then
    if [ -f "pages/index.js" ] && grep -q "BCFlex\|custom\|Daily rewards" pages/index.js 2>/dev/null; then
        echo "📄 Removing custom pages directory..."
        rm -rf pages/
    elif [ -f "pages/index.tsx" ] && grep -q "BCFlex\|custom\|Daily rewards" pages/index.tsx 2>/dev/null; then
        echo "📄 Removing custom pages directory..."
        rm -rf pages/
    else
        echo "ℹ️  Pages directory exists but appears to be official, keeping it"
    fi
fi

# Remove any backup config files that might be restored incorrectly
echo "🗑️  Removing backup config files that might cause confusion..."
rm -f next.config.backup* 2>/dev/null || true
rm -f vite.config.backup* 2>/dev/null || true
rm -f package.json.backup* 2>/dev/null || true

# Check for any modified package.json with custom scripts
if [ -f "package.json" ] && grep -q "BCFlex\|custom.*explorer" package.json 2>/dev/null; then
    echo "⚠️  Package.json appears to have custom modifications"
    echo "Consider restoring original with: git checkout -- package.json"
fi

echo ""
echo "🔄 Checking current state..."

# Show what configs currently exist
echo "📋 Current configuration files:"
ls -la *.config.* 2>/dev/null || echo "No .config files found"

echo ""
echo "📋 Current package.json scripts:"
if [ -f "package.json" ]; then
    node -e "
        const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
        if (pkg.scripts) {
            Object.keys(pkg.scripts).forEach(script => {
                console.log(\`  \${script}: \${pkg.scripts[script]}\`);
            });
        } else {
            console.log('  No scripts found');
        }
    " 2>/dev/null || echo "  Could not parse package.json"
else
    echo "  No package.json found"
fi

echo ""
echo "📋 Current structure check:"
if [ -f "src/pages/index.tsx" ]; then
    echo "✅ Official src/pages structure detected"
elif [ -f "src/app/page.tsx" ]; then
    echo "✅ Official src/app structure detected"
elif [ -f "pages/index.tsx" ] && ! grep -q "BCFlex\|custom" pages/index.tsx 2>/dev/null; then
    echo "✅ Official pages structure detected"
else
    echo "⚠️  No clear official structure detected"
    echo "Available React files:"
    find . -name "*.tsx" -o -name "*.jsx" | head -10
fi

echo ""
echo "🔍 Checking for workspace dependencies..."
if grep -q "workspace:" package.json 2>/dev/null; then
    echo "✅ Workspace dependencies detected (use pnpm)"
else
    echo "ℹ️  No workspace dependencies found"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "🔧 Recommended next steps:"
echo "1. Use only official configurations"
echo "2. Run: pnpm install"
echo "3. Create only .env.local for environment variables"
echo "4. Run: pnpm run dev -- --host 0.0.0.0 --port 3011"
echo ""
echo "🚫 DO NOT create:"
echo "- Custom next.config.js"
echo "- Custom pages directory"
echo "- Modified package.json scripts"
echo ""

echo ""
echo "🔍 Detailed structure analysis for import path debugging..."

# Check TypeScript configuration
echo "📋 TypeScript configuration:"
if [ -f "tsconfig.json" ]; then
    echo "✅ tsconfig.json found"
    if grep -q '"~"' tsconfig.json 2>/dev/null; then
        echo "✅ Path mapping for '~' found in tsconfig.json"
        echo "Path mappings:"
        grep -A 5 -B 5 '"~"' tsconfig.json 2>/dev/null || echo "Could not extract path mapping details"
    else
        echo "❌ No '~' path mapping found in tsconfig.json"
    fi
else
    echo "❌ No tsconfig.json found"
fi

# Check for Layout component
echo ""
echo "📋 Searching for Layout component:"
if [ -d "src/components" ]; then
    echo "✅ src/components directory exists"
    find src/components -name "*Layout*" -type f 2>/dev/null || echo "No Layout component found in src/components"
else
    echo "❌ src/components directory not found"
fi

# Check for any Layout components anywhere
echo "📋 All Layout components in project:"
find . -name "*Layout*" -type f 2>/dev/null | head -10 || echo "No Layout components found anywhere"

# Check the problematic file
echo ""
echo "📋 Analyzing src/pages/index.tsx import issues:"
if [ -f "src/pages/index.tsx" ]; then
    echo "✅ src/pages/index.tsx exists"
    echo "Import statements in src/pages/index.tsx:"
    grep "^import" src/pages/index.tsx | head -10 2>/dev/null || echo "Could not read import statements"
    
    echo ""
    echo "Problematic imports using '~' path:"
    grep "from.*~" src/pages/index.tsx 2>/dev/null || echo "No '~' imports found"
else
    echo "❌ src/pages/index.tsx not found"
fi

# Check root-level tsconfig for workspace
echo ""
echo "📋 Checking workspace-level TypeScript config:"
if [ -f "../../tsconfig.json" ]; then
    echo "✅ Workspace tsconfig.json found"
    cd ../..
    if grep -q '"~"' tsconfig.json 2>/dev/null; then
        echo "✅ Workspace-level path mapping found"
    else
        echo "❌ No workspace-level path mapping found"
    fi
    cd apps/explorer
else
    echo "ℹ️  No workspace tsconfig.json found"
fi

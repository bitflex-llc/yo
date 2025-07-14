#!/bin/bash
set -e

# Simple TypeScript Path Fix for Sui Explorer Import Issues
# Fixes "Cannot resolve import ~/components/Layout" errors

echo "🔧 TypeScript Import Path Fixer"
echo "================================"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found. Please run this from the explorer app directory."
    echo "Expected location: /root/sui-explorer/apps/explorer"
    exit 1
fi

echo "📍 Working in: $(pwd)"

# Check if tsconfig.json exists
if [ ! -f "tsconfig.json" ]; then
    echo "❌ tsconfig.json not found!"
    echo "This might not be a TypeScript project or configuration is missing."
    exit 1
fi

echo "✅ Found tsconfig.json"

# Backup the original tsconfig.json
echo "📄 Backing up original tsconfig.json..."
cp tsconfig.json "tsconfig.json.backup.$(date +%Y%m%d_%H%M%S)"

# Check current path mappings
echo "🔍 Checking current path mappings..."
if grep -q '"paths"' tsconfig.json; then
    echo "📋 Current path mappings found:"
    grep -A 10 '"paths"' tsconfig.json | head -15
else
    echo "❌ No path mappings found in tsconfig.json"
fi

# Create a Node.js script to safely update tsconfig.json
echo "🔧 Creating path mappings for ~ imports..."

cat > update_tsconfig.js << 'EOF'
const fs = require('fs');

try {
    const tsconfigPath = 'tsconfig.json';
    const tsconfig = JSON.parse(fs.readFileSync(tsconfigPath, 'utf8'));
    
    // Ensure compilerOptions exists
    if (!tsconfig.compilerOptions) {
        tsconfig.compilerOptions = {};
    }
    
    // Set baseUrl if not present
    if (!tsconfig.compilerOptions.baseUrl) {
        tsconfig.compilerOptions.baseUrl = '.';
    }
    
    // Add or update paths
    if (!tsconfig.compilerOptions.paths) {
        tsconfig.compilerOptions.paths = {};
    }
    
    // Add the specific path mappings needed for Sui Explorer
    const pathMappings = {
        "~/*": ["./src/*"],
        "@/*": ["./src/*"],
        "~/components/*": ["./src/components/*"],
        "~/pages/*": ["./src/pages/*"],
        "~/lib/*": ["./src/lib/*"],
        "~/utils/*": ["./src/utils/*"],
        "~/types/*": ["./src/types/*"],
        "~/hooks/*": ["./src/hooks/*"],
        "~/stores/*": ["./src/stores/*"]
    };
    
    // Merge with existing paths
    Object.assign(tsconfig.compilerOptions.paths, pathMappings);
    
    // Write back to file
    fs.writeFileSync(tsconfigPath, JSON.stringify(tsconfig, null, 2));
    
    console.log('✅ TypeScript path mappings updated successfully');
    console.log('Added mappings:');
    Object.keys(pathMappings).forEach(key => {
        console.log(`  ${key} -> ${pathMappings[key][0]}`);
    });
    
} catch (error) {
    console.error('❌ Error updating tsconfig.json:', error.message);
    process.exit(1);
}
EOF

# Run the update script
echo "📝 Updating tsconfig.json with path mappings..."
node update_tsconfig.js

# Clean up the temporary script
rm -f update_tsconfig.js

echo ""
echo "🔍 Checking if Layout component exists..."

# Simple check for Layout component
LAYOUT_FOUND=false

if [ -f "src/components/Layout.tsx" ]; then
    echo "✅ Found Layout component at: src/components/Layout.tsx"
    LAYOUT_FOUND=true
elif [ -f "src/components/Layout/index.tsx" ]; then
    echo "✅ Found Layout component at: src/components/Layout/index.tsx"
    LAYOUT_FOUND=true
elif [ -f "src/components/layout/Layout.tsx" ]; then
    echo "✅ Found Layout component at: src/components/layout/Layout.tsx"
    LAYOUT_FOUND=true
else
    echo "🔍 Searching for Layout component..."
    LAYOUT_FILES=$(find src -name "*Layout*" -type f 2>/dev/null | head -5)
    if [ -n "$LAYOUT_FILES" ]; then
        echo "📄 Found Layout-related files:"
        echo "$LAYOUT_FILES"
        LAYOUT_FOUND=true
    else
        echo "❌ No Layout component found!"
        echo "This might indicate:"
        echo "  1. Wrong branch/version of Sui Explorer"
        echo "  2. Incomplete git clone"
        echo "  3. Layout component has different name/location"
    fi
fi

echo ""
echo "🔍 Checking if this is a Vite project..."

if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    echo "✅ Vite project detected"
    echo "🔧 Updating Vite configuration for path aliases..."
    
    # Backup existing vite config
    if [ -f "vite.config.ts" ]; then
        cp vite.config.ts "vite.config.ts.backup.$(date +%Y%m%d_%H%M%S)"
        VITE_CONFIG="vite.config.ts"
    else
        cp vite.config.js "vite.config.js.backup.$(date +%Y%m%d_%H%M%S)"
        VITE_CONFIG="vite.config.js"
    fi
    
    # Create updated Vite config with path aliases
    cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '~': path.resolve(__dirname, './src'),
      '@': path.resolve(__dirname, './src'),
      '~/components': path.resolve(__dirname, './src/components'),
      '~/pages': path.resolve(__dirname, './src/pages'),
      '~/lib': path.resolve(__dirname, './src/lib'),
      '~/utils': path.resolve(__dirname, './src/utils'),
      '~/types': path.resolve(__dirname, './src/types'),
      '~/hooks': path.resolve(__dirname, './src/hooks'),
      '~/stores': path.resolve(__dirname, './src/stores')
    }
  },
  server: {
    host: '0.0.0.0',
    port: parseInt(process.env.PORT) || 3011,
    strictPort: false,
    allowedHosts: [
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      'sui.bcflex.com',
      '.bcflex.com'
    ]
  },
  define: {
    'process.env.NEXT_PUBLIC_RPC_URL': JSON.stringify(process.env.NEXT_PUBLIC_RPC_URL || 'http://sui.bcflex.com:9000'),
    'process.env.NEXT_PUBLIC_WS_URL': JSON.stringify(process.env.NEXT_PUBLIC_WS_URL || 'ws://sui.bcflex.com:9001'),
    'process.env.NEXT_PUBLIC_NETWORK': JSON.stringify('custom'),
    'process.env.NEXT_PUBLIC_NETWORK_NAME': JSON.stringify('BCFlex Sui Network')
  }
})
EOF
    
    echo "✅ Vite configuration updated with path aliases"
else
    echo "ℹ️  Not a Vite project (using Next.js/Webpack)"
fi

echo ""
echo "🧹 Clearing any cached builds..."
rm -rf node_modules/.cache .next dist .vite 2>/dev/null || true

echo ""
echo "✅ TypeScript path configuration complete!"
echo ""
echo "🔧 Next steps:"
echo "1. Run: pnpm install"
echo "2. Clear cache: rm -rf node_modules/.cache"
echo "3. Try: pnpm run dev -- --host 0.0.0.0 --port 3011"
echo ""

if [ "$LAYOUT_FOUND" = false ]; then
    echo "⚠️  Layout component was not found!"
    echo "You may need to:"
    echo "1. Check if you're using the correct branch: git branch"
    echo "2. Ensure complete clone: git status"
    echo "3. Look for alternative component imports in the official code"
    echo ""
fi

echo "📋 Configuration summary:"
echo "✅ TypeScript path mappings added to tsconfig.json"
if [ -f "vite.config.ts" ]; then
    echo "✅ Vite path aliases configured"
fi
echo "📄 Backup files created with timestamp"
echo ""
echo "🔍 To verify the fix worked:"
echo "pnpm run dev"
echo "# Look for import resolution errors in the output"

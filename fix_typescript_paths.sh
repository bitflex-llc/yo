#!/bin/bash
set -e

# Fix TypeScript Path Mapping Issues in Official Sui Explorer
# This script diagnoses and fixes import path resolution problems

echo "🔧 TypeScript Import Path Fixer for Official Sui Explorer"
echo "==========================================================="

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
echo "🔍 Analyzing import path issues..."

# Function to check if Layout component exists
find_layout_component() {
    echo "📋 Searching for Layout component..."
    
    # Search in common locations
    LAYOUT_LOCATIONS=(
        "src/components/Layout.tsx"
        "src/components/Layout/index.tsx"
        "src/components/layout/Layout.tsx"
        "src/components/ui/Layout.tsx"
        "components/Layout.tsx"
        "components/Layout/index.tsx"
    )
    
    for location in "${LAYOUT_LOCATIONS[@]}"; do
        if [ -f "$location" ]; then
            echo "✅ Found Layout component at: $location"
            return 0
        fi
    done
    
    # Search anywhere in the project
    echo "🔍 Searching for Layout component anywhere in project..."
    FOUND_LAYOUTS=$(find . -name "*Layout*" -type f 2>/dev/null | grep -E '\.(tsx|ts|jsx|js)$' | head -5)
    
    if [ -n "$FOUND_LAYOUTS" ]; then
        echo "📄 Found Layout-related files:"
        echo "$FOUND_LAYOUTS"
        return 0
    else
        echo "❌ No Layout component found anywhere in project"
        return 1
    fi
}

# Function to check TypeScript configuration
check_typescript_config() {
    echo ""
    echo "📋 Checking TypeScript configuration..."
    
    if [ -f "tsconfig.json" ]; then
        echo "✅ tsconfig.json found"
        
        # Check for path mapping
        if grep -q '"paths"' tsconfig.json 2>/dev/null; then
            echo "✅ Path mappings found in tsconfig.json"
            echo "Current path mappings:"
            grep -A 10 '"paths"' tsconfig.json 2>/dev/null | grep -E '(~|@)' || echo "No ~ or @ mappings found"
        else
            echo "❌ No path mappings found in tsconfig.json"
            return 1
        fi
        
        # Check baseUrl
        if grep -q '"baseUrl"' tsconfig.json 2>/dev/null; then
            echo "✅ baseUrl found in tsconfig.json"
            BASE_URL=$(grep '"baseUrl"' tsconfig.json | cut -d'"' -f4)
            echo "Base URL: $BASE_URL"
        else
            echo "❌ No baseUrl found in tsconfig.json"
            return 1
        fi
    else
        echo "❌ No tsconfig.json found"
        return 1
    fi
    
    return 0
}

# Function to fix TypeScript configuration
fix_typescript_config() {
    echo ""
    echo "🔧 Fixing TypeScript configuration..."
    
    if [ ! -f "tsconfig.json" ]; then
        echo "❌ No tsconfig.json to fix!"
        return 1
    fi
    
    # Backup original
    cp tsconfig.json tsconfig.json.backup.$(date +%s)
    echo "📄 Backed up original tsconfig.json"
    
    # Check if we need to add path mappings
    if ! grep -q '"paths"' tsconfig.json; then
        echo "🔧 Adding path mappings to tsconfig.json..."
        
        # Create a temp file with path mappings
        python3 << 'PYTHON_EOF'
import json
import sys

try:
    with open('tsconfig.json', 'r') as f:
        config = json.load(f)
    
    # Ensure compilerOptions exists
    if 'compilerOptions' not in config:
        config['compilerOptions'] = {}
    
    # Add baseUrl if not present
    if 'baseUrl' not in config['compilerOptions']:
        config['compilerOptions']['baseUrl'] = '.'
    
    # Add or update paths
    if 'paths' not in config['compilerOptions']:
        config['compilerOptions']['paths'] = {}
    
    # Add common path mappings used by Sui Explorer
    config['compilerOptions']['paths'].update({
        "~/*": ["./src/*"],
        "@/*": ["./src/*"],
        "~/components/*": ["./src/components/*"],
        "~/pages/*": ["./src/pages/*"],
        "~/lib/*": ["./src/lib/*"],
        "~/utils/*": ["./src/utils/*"],
        "~/types/*": ["./src/types/*"]
    })
    
    # Write back
    with open('tsconfig.json', 'w') as f:
        json.dump(config, f, indent=2)
    
    print("✅ TypeScript path mappings added successfully")
    
except Exception as e:
    print(f"❌ Error updating tsconfig.json: {e}")
    sys.exit(1)
PYTHON_EOF
        
        if [ $? -eq 0 ]; then
            echo "✅ TypeScript configuration updated"
        else
            echo "❌ Failed to update TypeScript configuration"
            return 1
        fi
    else
        echo "ℹ️  Path mappings already exist"
    fi
}

# Function to analyze import errors
analyze_import_errors() {
    echo ""
    echo "🔍 Analyzing import errors in src/pages/index.tsx..."
    
    if [ ! -f "src/pages/index.tsx" ]; then
        echo "❌ src/pages/index.tsx not found"
        return 1
    fi
    
    echo "📄 Problematic imports using '~' path:"
    PROBLEMATIC_IMPORTS=$(grep "from.*~" src/pages/index.tsx 2>/dev/null || echo "")
    
    if [ -n "$PROBLEMATIC_IMPORTS" ]; then
        echo "$PROBLEMATIC_IMPORTS"
        
        echo ""
        echo "🔧 Checking if these files exist:"
        echo "$PROBLEMATIC_IMPORTS" | while read -r line; do
            if [[ $line =~ from[[:space:]]+[\"\'](~/[^\"\']+) ]]; then
                IMPORT_PATH="${BASH_REMATCH[1]}"
                # Convert ~ to src/
                ACTUAL_PATH="${IMPORT_PATH/#\~\//src/}"
                
                echo "Checking: $IMPORT_PATH -> $ACTUAL_PATH"
                if [ -f "$ACTUAL_PATH" ] || [ -f "$ACTUAL_PATH.tsx" ] || [ -f "$ACTUAL_PATH.ts" ] || [ -f "$ACTUAL_PATH/index.tsx" ] || [ -f "$ACTUAL_PATH/index.ts" ]; then
                    echo "  ✅ File exists"
                else
                    echo "  ❌ File missing: $ACTUAL_PATH"
                fi
            fi
        done
    else
        echo "No problematic imports found"
    fi
}

# Function to check if this is actually a Vite project
check_project_type() {
    echo ""
    echo "🔍 Checking project type and build system..."
    
    if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
        echo "✅ Vite project detected"
        USING_VITE=true
        
        # Check Vite config for path aliases
        if grep -q "alias" vite.config.* 2>/dev/null; then
            echo "✅ Vite aliases found"
            echo "Current Vite aliases:"
            grep -A 10 "alias" vite.config.* 2>/dev/null || echo "Could not extract aliases"
        else
            echo "❌ No Vite aliases found"
        fi
    else
        echo "ℹ️  Not a Vite project (using Next.js/Webpack)"
        USING_VITE=false
    fi
    
    if [ -f "next.config.js" ] || [ -f "next.config.ts" ]; then
        echo "✅ Next.js project detected"
        USING_NEXTJS=true
    else
        echo "ℹ️  Not a Next.js project"
        USING_NEXTJS=false
    fi
}

# Function to fix Vite configuration
fix_vite_config() {
    if [ "$USING_VITE" = true ]; then
        echo ""
        echo "🔧 Fixing Vite configuration for path aliases..."
        
        # Update vite.config.ts to include proper path aliases
        if [ -f "vite.config.ts" ]; then
            # Backup original
            cp vite.config.ts vite.config.ts.backup.$(date +%s)
            
            # Check if aliases already exist
            if ! grep -q "alias" vite.config.ts; then
                echo "Adding path aliases to vite.config.ts..."
                
                # Create updated Vite config with aliases
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
      '~/types': path.resolve(__dirname, './src/types')
    }
  },
  server: {
    allowedHosts: [
      'sui.bcflex.com',
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      '.bcflex.com'
    ],
    host: '0.0.0.0',
    port: parseInt(process.env.PORT) || 3011,
    strictPort: false
  },
  define: {
    'process.env.NEXT_PUBLIC_RPC_URL': JSON.stringify(process.env.NEXT_PUBLIC_RPC_URL || 'http://sui.bcflex.com:9000'),
    'process.env.NEXT_PUBLIC_WS_URL': JSON.stringify(process.env.NEXT_PUBLIC_WS_URL || 'ws://sui.bcflex.com:9001'),
    'process.env.NEXT_PUBLIC_NETWORK': JSON.stringify('custom'),
    'process.env.NEXT_PUBLIC_NETWORK_NAME': JSON.stringify('BCFlex Sui Network'),
    'process.env.NEXT_PUBLIC_API_ENDPOINT': JSON.stringify(process.env.NEXT_PUBLIC_RPC_URL || 'http://sui.bcflex.com:9000')
  },
  build: {
    outDir: 'dist',
    sourcemap: true
  }
})
EOF
                echo "✅ Vite configuration updated with path aliases"
            else
                echo "ℹ️  Vite aliases already exist"
            fi
        fi
    fi
}

# Main execution
echo "🚀 Starting TypeScript import path analysis and fixes..."

find_layout_component
check_project_type
check_typescript_config

if [ $? -ne 0 ]; then
    echo "🔧 TypeScript config issues found, attempting to fix..."
    fix_typescript_config
fi

fix_vite_config
analyze_import_errors

echo ""
echo "✅ TypeScript path fixing complete!"
echo ""
echo "🔧 Next steps:"
echo "1. Clear any build cache: rm -rf node_modules/.cache .next dist 2>/dev/null || true"
echo "2. Reinstall dependencies: pnpm install"
echo "3. Try building: pnpm run build"
echo "4. If still failing, check specific missing components"
echo ""
echo "🔍 If Layout component is still missing:"
echo "1. Check if this is the correct branch/version of Sui Explorer"
echo "2. Look for alternative component locations"
echo "3. Check if the import should be different (relative path)"

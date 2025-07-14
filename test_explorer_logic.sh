#!/bin/bash

# Test script to verify explorer setup logic
echo "🧪 Testing Explorer Setup Logic"
echo "==============================="

# Create test directory structure
TEST_DIR="/tmp/sui_explorer_test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "1. Testing missing explorer directory:"
mkdir -p sui-explorer
echo "   Created: sui-explorer/"

# Test the directory detection logic
if [ -d "sui-explorer/apps/explorer" ]; then
    echo "   ✓ Found apps/explorer"
elif [ -d "sui-explorer/dapps/sui-explorer" ]; then
    echo "   ✓ Found dapps/sui-explorer"
elif [ -d "sui-explorer/explorer" ]; then
    echo "   ✓ Found explorer/"
else
    echo "   ✗ No explorer directory found (expected)"
fi

echo ""
echo "2. Testing apps/explorer structure:"
mkdir -p sui-explorer/apps/explorer
echo '{"name": "test"}' > sui-explorer/apps/explorer/package.json

if [ -d "sui-explorer/apps/explorer" ]; then
    echo "   ✓ Found apps/explorer"
    if [ -f "sui-explorer/apps/explorer/package.json" ]; then
        echo "   ✓ Found package.json"
    fi
elif [ -d "sui-explorer/dapps/sui-explorer" ]; then
    echo "   Found dapps/sui-explorer"
elif [ -d "sui-explorer/explorer" ]; then
    echo "   Found explorer/"
else
    echo "   ✗ No explorer directory found"
fi

echo ""
echo "3. Testing dapps/sui-explorer structure:"
rm -rf sui-explorer/apps
mkdir -p sui-explorer/dapps/sui-explorer
echo '{"name": "test"}' > sui-explorer/dapps/sui-explorer/package.json

if [ -d "sui-explorer/apps/explorer" ]; then
    echo "   Found apps/explorer"
elif [ -d "sui-explorer/dapps/sui-explorer" ]; then
    echo "   ✓ Found dapps/sui-explorer"
    if [ -f "sui-explorer/dapps/sui-explorer/package.json" ]; then
        echo "   ✓ Found package.json"
    fi
elif [ -d "sui-explorer/explorer" ]; then
    echo "   Found explorer/"
else
    echo "   ✗ No explorer directory found"
fi

echo ""
echo "4. Testing explorer/ structure:"
rm -rf sui-explorer/dapps
mkdir -p sui-explorer/explorer
echo '{"name": "test"}' > sui-explorer/explorer/package.json

if [ -d "sui-explorer/apps/explorer" ]; then
    echo "   Found apps/explorer"
elif [ -d "sui-explorer/dapps/sui-explorer" ]; then
    echo "   Found dapps/sui-explorer"
elif [ -d "sui-explorer/explorer" ]; then
    echo "   ✓ Found explorer/"
    if [ -f "sui-explorer/explorer/package.json" ]; then
        echo "   ✓ Found package.json"
    fi
else
    echo "   ✗ No explorer directory found"
fi

echo ""
echo "✅ Explorer setup logic test completed"
echo "Cleaning up test directory..."
rm -rf "$TEST_DIR"
echo "Done!"

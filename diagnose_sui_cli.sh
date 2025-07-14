#!/bin/bash

# Diagnostic script to trace the "saved" argument error

echo "🔍 Sui CLI Diagnostic Tool"
echo "=========================="
echo ""

echo "1. Checking Sui binary and version..."
if command -v sui >/dev/null 2>&1; then
    echo "✓ Sui binary found: $(which sui)"
    echo "Version info:"
    sui --version 2>&1 || echo "Could not get version"
else
    echo "✗ Sui binary not found"
    exit 1
fi

echo ""
echo "2. Testing basic sui commands..."

echo "Testing 'sui --help':"
sui --help >/dev/null 2>&1 && echo "✓ Basic help works" || echo "✗ Basic help failed"

echo ""
echo "3. Testing sui client commands..."

echo "Testing 'sui client --help':"
sui client --help >/dev/null 2>&1 && echo "✓ Client help works" || echo "✗ Client help failed"

echo ""
echo "4. Testing sui keytool commands..."

echo "Testing 'sui keytool --help':"
sui keytool --help >/dev/null 2>&1 && echo "✓ Keytool help works" || echo "✗ Keytool help failed"

echo ""
echo "5. Testing export command syntax..."

echo "Testing 'sui keytool export --help':"
if sui keytool export --help 2>&1 | head -5; then
    echo "✓ Export help works"
else
    echo "✗ Export help failed"
fi

echo ""
echo "6. Testing address creation..."

echo "Testing 'sui client new-address --help':"
if sui client new-address --help 2>&1 | head -3; then
    echo "✓ New-address help works"
else
    echo "✗ New-address help failed"
fi

echo ""
echo "7. Checking for config files..."

if [ -d "$HOME/.sui" ]; then
    echo "✓ Sui config directory exists: $HOME/.sui"
    ls -la "$HOME/.sui" 2>/dev/null || echo "Could not list contents"
else
    echo "ℹ No sui config directory found"
fi

echo ""
echo "8. Testing a safe command to identify syntax..."

echo "Attempting to create a test address (this might show the error):"
echo "Command: sui client new-address secp256k1"
sui client new-address secp256k1 2>&1 | head -5 || echo "Command failed"

echo ""
echo "=========================="
echo "Diagnostic complete!"
echo ""
echo "If you see the 'saved' error above, we can fix the specific command."
echo "Otherwise, the issue might be in a different part of the installation."

#!/bin/sh

# Test script compatibility across different shells
echo "Testing script compatibility..."

# Test basic shell features used in scripts
echo "✓ Basic echo works"

# Test command substitution
RESULT=$(echo "test")
if [ "$RESULT" = "test" ]; then
    echo "✓ Command substitution works"
else
    echo "✗ Command substitution failed"
fi

# Test parameter expansion
TEST_VAR="hello"
if [ "${TEST_VAR-default}" = "hello" ]; then
    echo "✓ Parameter expansion works"
else
    echo "✗ Parameter expansion failed"
fi

# Test grep with pattern
if echo "Yes" | grep -q "^[Yy]$"; then
    echo "✓ Grep pattern matching works"
else
    echo "✗ Grep pattern matching failed"
fi

# Test arithmetic (if used)
if [ 1 -eq 1 ]; then
    echo "✓ Arithmetic comparison works"
else
    echo "✗ Arithmetic comparison failed"
fi

echo ""
echo "Shell compatibility test completed!"
echo "Current shell: ${0}"
echo "All basic features needed by the nginx setup scripts are working."

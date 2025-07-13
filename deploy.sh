#!/bin/sh

# Simple wrapper to ensure deploy_sui_custom.sh runs with bash
# This fixes the "sudo sh deploy_sui_custom.sh" issue

echo "🚀 Starting Sui Custom Network Deployment..."
echo "Ensuring bash compatibility..."

# Check if bash is available
if ! command -v bash >/dev/null 2>&1; then
    echo "Error: bash is required but not found"
    echo "Please install bash and try again"
    exit 1
fi

# Run the deployment script with bash
if [ "$(id -u)" = "0" ]; then
    # Running as root, use bash directly
    exec bash "$(dirname "$0")/deploy_sui_custom.sh" "$@"
else
    # Not running as root, check if sudo is needed
    echo "Note: This deployment requires sudo access for system installation"
    echo "Running with bash..."
    exec bash "$(dirname "$0")/deploy_sui_custom.sh" "$@"
fi

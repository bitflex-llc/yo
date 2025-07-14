#!/bin/sh

# Install and Setup Official Sui Explorer ONLY - No Fallbacks
# This script forces the use of the official MystenLabs explorer

set -eu

EXPLORER_DIR="/root/sui-explorer"
RPC_URL="http://sui.bcflex.com:9000"
EXPLORER_PORT="3011"

echo "🌐 INSTALLING OFFICIAL SUI EXPLORER - NO FALLBACKS"
echo "=================================================="

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

echo "🔧 This script will ONLY install the official MystenLabs Sui Explorer"
echo "🚫 No fallback or standalone alternatives will be created"
echo ""

# Force run the official explorer installer
if [ -f "./force_install_official_explorer.sh" ]; then
    echo "📄 Running official explorer installer..."
    chmod +x ./force_install_official_explorer.sh
    ./force_install_official_explorer.sh
else
    echo "❌ force_install_official_explorer.sh not found"
    echo "💡 Please ensure you're in the correct directory with the installer"
    exit 1
fi

echo ""
echo "🎯 OFFICIAL EXPLORER INSTALLATION COMPLETE!"
echo "============================================"
echo ""
echo "✅ Official MystenLabs Sui Explorer installed"
echo "✅ Configured for port $EXPLORER_PORT"
echo "✅ No fallbacks or alternatives created"
echo ""
echo "🌐 Explorer available at: http://localhost:$EXPLORER_PORT"
echo ""
echo "📋 Management commands:"
echo "   Start:    systemctl start sui-explorer"
echo "   Stop:     systemctl stop sui-explorer"
echo "   Status:   systemctl status sui-explorer"
echo "   Logs:     journalctl -u sui-explorer -f"
echo ""
echo "🔧 Troubleshooting:"
echo "   Debug:    ./debug_explorer_clean.sh"
echo "   Emergency: ./emergency_port_3011.sh"

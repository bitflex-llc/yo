#!/bin/sh

# Deployment wrapper for Sui Custom Network
# Offers both full and simplified installation options

echo "🚀 Sui Custom Network Deployment Options 🚀"
echo ""
echo "Due to recent Sui CLI changes, we offer two installation methods:"
echo ""
echo "1) FULL DEPLOYMENT (Advanced)"
echo "   • Complete systemd services setup"
echo "   • Block explorer included"
echo "   • Production-ready configuration"
echo "   • May require CLI syntax fixes"
echo ""
echo "2) SIMPLIFIED DEPLOYMENT (Recommended)"
echo "   • Works with current Sui CLI"
echo "   • Basic network setup"
echo "   • Manual process management"
echo "   • Faster and more reliable"
echo ""
echo "3) Exit"
echo ""

read -p "Choose installation method (1/2/3): " choice

case "$choice" in
    1)
        echo "Starting full deployment with bash..."
        if ! command -v bash >/dev/null 2>&1; then
            echo "Error: bash is required for full deployment"
            exit 1
        fi
        exec bash "$(dirname "$0")/deploy_sui_custom.sh" "$@"
        ;;
    2)
        echo "Starting simplified deployment..."
        exec bash "$(dirname "$0")/install_simple.sh" "$@"
        ;;
    3)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

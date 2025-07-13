#!/bin/bash

# Simple launcher script for Sui Custom Network deployment

echo "🚀 Sui Custom Network Deployment Options 🚀"
echo ""
echo "Select an option:"
echo "1) Full deployment (recommended for first-time setup)"
echo "2) Genesis configuration only"
echo "3) Main installation only"
echo "4) Block explorer setup only"
echo "5) Verify existing deployment"
echo "6) Show deployment status"
echo "7) Exit"
echo ""

read -p "Enter your choice (1-7): " choice

case $choice in
    1)
        echo "Starting full deployment..."
        ./deploy_sui_custom.sh
        ;;
    2)
        echo "Creating genesis configuration..."
        ./create_genesis.sh
        ;;
    3)
        echo "Running main installation..."
        ./install_sui_server.sh
        ;;
    4)
        echo "Setting up block explorer..."
        ./setup_block_explorer.sh
        ;;
    5)
        echo "Verifying deployment..."
        ./verify_deployment.sh
        ;;
    6)
        echo "Checking deployment status..."
        if [ -f "$HOME/.sui/check_sui_status.sh" ]; then
            $HOME/.sui/check_sui_status.sh
        else
            echo "No deployment found. Please run full deployment first."
        fi
        ;;
    7)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

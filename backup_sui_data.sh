#!/bin/bash

# Sui Network Backup Script
# Backs up important configuration, keys, and blockchain data

BACKUP_DIR="sui_backup_$(date +%Y%m%d_%H%M%S)"
SUI_HOME="$HOME/.sui"

echo "Creating backup in $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

# Backup configuration files
cp -r "$SUI_HOME/genesis" "$BACKUP_DIR/" 2>/dev/null || echo "No genesis directory found"
cp -r "$SUI_HOME/validator" "$BACKUP_DIR/" 2>/dev/null || echo "No validator directory found"
cp -r "$SUI_HOME/fullnode" "$BACKUP_DIR/" 2>/dev/null || echo "No fullnode directory found"

# Backup important files
cp "$SUI_HOME"/genesis_account_key.txt "$BACKUP_DIR/" 2>/dev/null || echo "No genesis account key found"
cp "$SUI_HOME"/account_info.env "$BACKUP_DIR/" 2>/dev/null || echo "No account info found"
cp "$SUI_HOME"/faucet_config.yaml "$BACKUP_DIR/" 2>/dev/null || echo "No faucet config found"

# Backup keystore
cp -r "$SUI_HOME/keystore" "$BACKUP_DIR/" 2>/dev/null || echo "No keystore found"

# Create archive
tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup created: ${BACKUP_DIR}.tar.gz"
echo "Store this file securely - it contains private keys!"

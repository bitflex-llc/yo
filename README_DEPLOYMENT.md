# Sui Custom Network with Modified Payout Distribution

This repository contains a complete deployment solution for a custom Sui blockchain network with modified staking rewards and a pre-mined account.

## 🎯 Features

### Modified Payout Distribution
- **Delegators**: 1% daily rewards (365% APY)
- **Validators**: 1.5% daily rewards (1,378% APY)
- **Custom reward calculation logic** in the Sui Framework

### Pre-configured Network
- **Pre-mined account**: 1,000,000 SUI tokens
- **Full node** and **validator** setup
- **Faucet service** for testnet functionality
- **Custom block explorer** with payout information
- **Automatic service management** with systemd

## 📁 File Structure

```
sui-custom-network/
├── deploy_sui_custom.sh          # Master deployment orchestrator
├── install_sui_server.sh         # Main installation script
├── create_genesis.sh             # Genesis configuration
├── setup_block_explorer.sh       # Block explorer setup
├── verify_deployment.sh          # Health check and verification
├── PAYOUT_CHANGES.md             # Documentation of modifications
└── README.md                     # This file
```

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04+ or macOS
- 8GB+ RAM, 100GB+ disk space
- Sudo access
- Internet connection

### One-Command Deployment
```bash
chmod +x deploy_sui_custom.sh
./deploy_sui_custom.sh
```

This will automatically:
1. Install all dependencies
2. Build the modified Sui binaries
3. Create genesis configuration
4. Set up validator and full node
5. Deploy block explorer
6. Start all services

### Manual Step-by-Step Deployment
If you prefer manual control:

```bash
# 1. Create genesis configuration
./create_genesis.sh

# 2. Install and configure Sui network
./install_sui_server.sh

# 3. Verify deployment
./verify_deployment.sh
```

## 🔧 What Gets Modified

### Payout Logic Changes
The following file is modified to implement custom payout rates:
- `crates/sui-framework/packages/sui-system/sources/validator_set.move`

#### Key Changes:
1. **`compute_unadjusted_reward_distribution`**: Modified to distribute 1% daily rewards to all stake
2. **`distribute_reward`**: Enhanced to give validators an additional 0.5% daily bonus

### Services Installed
- **sui-fullnode**: Main blockchain node
- **sui-validator**: Validator node with custom payouts
- **sui-faucet**: Testnet token faucet
- **sui-explorer**: Custom block explorer

## 🌐 Network Endpoints

After deployment, your network will be accessible at:

| Service | URL | Description |
|---------|-----|-------------|
| Block Explorer | http://localhost:3000 | Web interface to browse the blockchain |
| RPC API | http://localhost:9000 | JSON-RPC endpoint for blockchain interaction |
| WebSocket | ws://localhost:9001 | Real-time blockchain events |
| Faucet | http://localhost:5003/gas | Request test SUI tokens |
| Metrics | http://localhost:9184/metrics | Prometheus metrics |

## 💰 Account Information

### Genesis Account
- **Balance**: 1,000,000 SUI (pre-mined)
- **Location**: Address stored in `~/.sui/account_info.env`
- **Private Key**: Backed up to `~/.sui/genesis_account_key.txt`

⚠️ **IMPORTANT**: Keep your private keys secure and create backups!

### Additional Accounts
- **Faucet Account**: 100,000 SUI for testnet distribution
- **Treasury Account**: 500,000 SUI for network operations

## 🎮 Usage Examples

### Using the Sui CLI
```bash
# Check your balance
sui client balance

# Send SUI to another address
sui client transfer-sui --to 0x... --amount 1000000000 --gas-budget 10000000

# Create a new address
sui client new-address secp256k1

# Switch to the genesis account
sui client switch --address $(source ~/.sui/account_info.env && echo $GENESIS_ACCOUNT_ADDRESS)
```

### Using the Faucet
```bash
# Request test tokens
curl -X POST http://localhost:5003/gas \
  -H "Content-Type: application/json" \
  -d '{"recipient": "YOUR_ADDRESS_HERE"}'
```

### RPC API Examples
```bash
# Get current epoch
curl -X POST http://localhost:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_getCurrentEpoch","params":[]}'

# Get validator information
curl -X POST http://localhost:9000 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_getLatestSuiSystemState","params":[]}'
```

## 🛠️ Management Scripts

### Service Management
```bash
# Check network status
~/.sui/check_sui_status.sh

# Start the network
~/.sui/start_sui_network.sh

# Stop the network
~/.sui/stop_sui_network.sh
```

### Individual Service Control
```bash
# Restart a specific service
sudo systemctl restart sui-fullnode

# Check service logs
sudo journalctl -u sui-validator -f

# Check all service status
sudo systemctl status sui-fullnode sui-validator sui-faucet sui-explorer
```

### Backup and Maintenance
```bash
# Create a complete backup
./backup_sui_data.sh

# Verify network health
./verify_deployment.sh

# Monitor disk usage
df -h ~/.sui
```

## 🔍 Monitoring and Troubleshooting

### Health Checks
Run the verification script to check system health:
```bash
./verify_deployment.sh
```

This checks:
- Service status
- Network connectivity
- Account balances
- Payout modifications
- Performance metrics

### Common Issues

#### Services Not Starting
```bash
# Check service status
sudo systemctl status sui-fullnode

# View detailed logs
sudo journalctl -u sui-fullnode -f

# Restart service
sudo systemctl restart sui-fullnode
```

#### Network Connectivity Issues
```bash
# Check if ports are open
netstat -tlnp | grep -E '(3000|5003|9000|9001)'

# Test RPC connectivity
curl -s http://localhost:9000 || echo "RPC not responding"
```

#### Low Disk Space
```bash
# Check disk usage
df -h

# Clean up old logs
sudo journalctl --vacuum-time=7d

# Archive old blockchain data (if needed)
sudo systemctl stop sui-fullnode
tar -czf sui-data-backup.tar.gz ~/.sui/fullnode/db
```

## 📊 Block Explorer Features

The custom block explorer includes:
- **Real-time transaction monitoring**
- **Validator performance metrics**
- **Custom payout rate display** (1% delegators, 1.5% validators)
- **Network statistics and charts**
- **Account balance checker**
- **Transaction search and details**

Access at: http://localhost:3000

## 🔒 Security Considerations

### Private Key Management
- Genesis account private key is stored in `~/.sui/genesis_account_key.txt`
- Create secure backups immediately after deployment
- Consider using hardware wallets for production use

### Network Security
- Firewall rules are automatically configured
- Only necessary ports are opened
- Services run with limited privileges

### Production Deployment
For production use, consider:
- Using TLS/SSL certificates
- Setting up proper monitoring and alerting
- Implementing proper backup strategies
- Using secure key management solutions

## 📈 Performance Optimization

### System Requirements
- **Minimum**: 8GB RAM, 100GB disk
- **Recommended**: 16GB RAM, 500GB SSD
- **Production**: 32GB RAM, 1TB NVMe SSD

### Configuration Tuning
Adjust settings in:
- `~/.sui/fullnode/fullnode.yaml`
- `~/.sui/validator/validator.yaml`

## 🤝 Contributing

To modify the payout logic:
1. Edit `crates/sui-framework/packages/sui-system/sources/validator_set.move`
2. Rebuild with `cargo build --release`
3. Restart services

## 📚 Additional Resources

- [Sui Documentation](https://docs.sui.io)
- [Sui GitHub Repository](https://github.com/MystenLabs/sui)
- [Sui Move Book](https://move-book.com/)
- [Sui TypeScript SDK](https://github.com/MystenLabs/sui/tree/main/sdk/typescript)

## 📝 License

This project follows the same license as the Sui blockchain project.

## ⚠️ Disclaimer

This is a modified version of Sui for educational and testing purposes. The custom payout rates (1% delegators, 1.5% validators daily) are significantly higher than typical blockchain rewards and are intended for testnet use only. Do not use these settings in a production environment without proper economic analysis.

---

## 🎉 Quick Start Summary

1. **Deploy**: `./deploy_sui_custom.sh`
2. **Verify**: `./verify_deployment.sh`
3. **Explore**: Visit http://localhost:3000
4. **Use**: Check `~/.sui/account_info.env` for your pre-mined account

Happy blockchain building! 🚀⛓️

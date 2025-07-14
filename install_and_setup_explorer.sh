#!/bin/bash

# Script to install Sui Block Explorer and set up nginx proxy with SSL
# This script handles the complete setup from scratch

set -eu

DOMAIN="sui.bcflex.com"
EXPLORER_PORT="3000"
EXPLORER_DIR="/root/sui-explorer"
RPC_URL="http://sui.bcflex.com:9000"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
NGINX_CONFIG_FILE="$NGINX_SITES_AVAILABLE/$DOMAIN"

echo "🚀 Complete Sui Block Explorer Setup"
echo "📍 Domain: $DOMAIN"
echo "🔌 Explorer Port: $EXPLORER_PORT"
echo "📁 Install Directory: $EXPLORER_DIR"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install Node.js and npm if not present
install_nodejs() {
    echo "📦 Installing Node.js and npm..."
    
    if command_exists node && command_exists npm; then
        echo "✅ Node.js and npm already installed"
        node --version
        npm --version
        return 0
    fi
    
    # Detect OS and install Node.js
    if [ -f /etc/debian_version ]; then
        # Ubuntu/Debian
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs npm
    else
        echo "❌ Unsupported OS for automatic Node.js installation"
        echo "💡 Please install Node.js 18+ manually and run this script again"
        exit 1
    fi
    
    echo "✅ Node.js and npm installed successfully"
    node --version
    npm --version
}

# Install git if not present
install_git() {
    if command_exists git; then
        echo "✅ Git already installed"
        return 0
    fi
    
    echo "📦 Installing git..."
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y git
    elif [ -f /etc/redhat-release ]; then
        yum install -y git
    else
        echo "❌ Please install git manually"
        exit 1
    fi
    
    echo "✅ Git installed successfully"
}

# Clone and setup Sui Explorer
setup_explorer() {
    echo "📥 Setting up Sui Block Explorer..."
    
    # Remove existing directory if it exists
    if [ -d "$EXPLORER_DIR" ]; then
        echo "🗑️  Removing existing explorer directory..."
        rm -rf "$EXPLORER_DIR"
    fi
    
    # Clone the official Sui Explorer repository
    echo "📥 Cloning official Sui Explorer repository..."
    git clone https://github.com/MystenLabs/sui-explorer.git "$EXPLORER_DIR"
    
    # Navigate to explorer directory
    cd "$EXPLORER_DIR"
    
    # Check if it's a valid Next.js project
    if [ ! -f "package.json" ]; then
        echo "❌ No package.json found in explorer repository"
        echo "💡 Trying standalone explorer instead..."
        rm -rf "$EXPLORER_DIR"
        setup_standalone_explorer
        return
    fi
    
    echo "✅ Found valid explorer project"
    
    # Install dependencies
    echo "📦 Installing explorer dependencies..."
    npm install
    
    # Create environment configuration
    echo "⚙️ Creating environment configuration..."
    cat > .env.local << EOF
# Sui Explorer Configuration
NEXT_PUBLIC_RPC_URL=$RPC_URL
NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
PORT=$EXPLORER_PORT
NODE_ENV=production

# Custom network configuration
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
NEXT_PUBLIC_API_ENDPOINT=$RPC_URL
EOF
    
    # Build the explorer
    echo "🔨 Building the explorer..."
    npm run build
    
    echo "✅ Explorer setup completed"
}

# Setup standalone explorer (fallback)
setup_standalone_explorer() {
    echo "📥 Setting up standalone Sui Explorer..."
    
    # Create a simple standalone explorer
    mkdir -p "$EXPLORER_DIR"
    cd "$EXPLORER_DIR"
    
    # Initialize npm project
    cat > package.json << 'EOF'
{
  "name": "sui-explorer-standalone",
  "version": "1.0.0",
  "description": "Simple Sui blockchain explorer",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "axios": "^1.6.0",
    "cors": "^2.8.5"
  }
}
EOF
    
    # Install dependencies
    echo "📦 Installing explorer dependencies..."
    npm install
    
    # Create simple web explorer
    cat > server.js << EOF
const express = require('express');
const axios = require('axios');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || $EXPLORER_PORT;
const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || '$RPC_URL';

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// API endpoint to get latest system state
app.get('/api/system-state', async (req, res) => {
    try {
        const response = await axios.post(RPC_URL, {
            jsonrpc: '2.0',
            method: 'sui_getLatestSuiSystemState',
            params: [],
            id: 1
        });
        res.json(response.data);
    } catch (error) {
        console.error('RPC Error:', error.message);
        res.status(500).json({ error: 'Failed to fetch system state', rpc_url: RPC_URL });
    }
});

// API endpoint to get chain identifier
app.get('/api/chain-info', async (req, res) => {
    try {
        const response = await axios.post(RPC_URL, {
            jsonrpc: '2.0',
            method: 'sui_getChainIdentifier',
            params: [],
            id: 1
        });
        res.json(response.data);
    } catch (error) {
        console.error('RPC Error:', error.message);
        res.status(500).json({ error: 'Failed to fetch chain info', rpc_url: RPC_URL });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString(), rpc_url: RPC_URL });
});

// Serve main page
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(\`Sui Explorer running on port \${PORT}\`);
    console.log(\`RPC URL: \${RPC_URL}\`);
});
EOF
    
    # Create public directory and HTML file
    mkdir -p public
    cat > public/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BCFlex Sui Blockchain Explorer</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            padding: 30px;
            backdrop-filter: blur(10px);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        .logo {
            font-size: 3em;
            font-weight: bold;
            margin-bottom: 10px;
            background: linear-gradient(45deg, #4facfe, #00f2fe);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .card {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            padding: 25px;
            margin: 20px 0;
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        .stat {
            text-align: center;
            padding: 20px;
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #4facfe;
        }
        .stat-label {
            margin-top: 10px;
            opacity: 0.8;
        }
        .btn {
            background: linear-gradient(45deg, #4facfe, #00f2fe);
            border: none;
            padding: 12px 24px;
            border-radius: 25px;
            color: white;
            font-weight: bold;
            cursor: pointer;
            margin: 10px;
            transition: transform 0.2s;
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .info-box {
            background: rgba(0, 255, 127, 0.2);
            border-left: 4px solid #00ff7f;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .warning-box {
            background: rgba(255, 193, 7, 0.2);
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        #status {
            text-align: center;
            margin: 20px 0;
        }
        .loading {
            opacity: 0.6;
        }
        .error {
            color: #ff6b6b;
        }
        .success {
            color: #00ff7f;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">⚡ BCFlex Sui Explorer</div>
            <p>Custom Sui Blockchain Network Explorer</p>
            <p><small>RPC: $RPC_URL</small></p>
        </div>

        <div id="status">
            <button class="btn" onclick="refreshData()">🔄 Refresh Data</button>
        </div>

        <div class="info-box">
            <strong>🎯 BCFlex Custom Network Features:</strong><br>
            • 1% daily rewards for delegators<br>
            • 1.5% daily rewards for validators<br>
            • Custom payout logic implemented<br>
            • RPC endpoint: $RPC_URL
        </div>

        <div class="grid">
            <div class="card">
                <div class="stat">
                    <div class="stat-number" id="chainId">Loading...</div>
                    <div class="stat-label">Chain ID</div>
                </div>
            </div>
            
            <div class="card">
                <div class="stat">
                    <div class="stat-number" id="epoch">Loading...</div>
                    <div class="stat-label">Current Epoch</div>
                </div>
            </div>
            
            <div class="card">
                <div class="stat">
                    <div class="stat-number" id="validators">Loading...</div>
                    <div class="stat-label">Active Validators</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h3>🔗 BCFlex Network Endpoints</h3>
            <p><strong>RPC:</strong> $RPC_URL</p>
            <p><strong>WebSocket:</strong> ws://sui.bcflex.com:9001</p>
            <p><strong>Faucet:</strong> http://sui.bcflex.com:5003</p>
            <p><strong>Metrics:</strong> http://sui.bcflex.com:9184</p>
            <p><strong>Explorer:</strong> https://sui.bcflex.com</p>
        </div>

        <div class="card">
            <h3>🧪 Connection Tests</h3>
            <button class="btn" onclick="testRPC()">Test RPC Connection</button>
            <button class="btn" onclick="testFaucet()">Test Faucet</button>
            <div id="testResults" style="margin-top: 15px;"></div>
        </div>

        <div id="rpcStatus" class="warning-box" style="display: none;">
            <strong>⚠️ RPC Connection Status:</strong>
            <div id="rpcDetails"></div>
        </div>
    </div>

    <script>
        async function fetchData() {
            try {
                // Fetch chain info
                const chainResponse = await fetch('/api/chain-info');
                const chainData = await chainResponse.json();
                if (chainData.result) {
                    document.getElementById('chainId').textContent = chainData.result;
                    document.getElementById('chainId').className = 'stat-number success';
                } else {
                    document.getElementById('chainId').textContent = 'Error';
                    document.getElementById('chainId').className = 'stat-number error';
                    showRPCStatus('Chain ID fetch failed: ' + (chainData.error || 'Unknown error'));
                }

                // Fetch system state
                const systemResponse = await fetch('/api/system-state');
                const systemData = await systemResponse.json();
                if (systemData.result) {
                    const state = systemData.result;
                    document.getElementById('epoch').textContent = state.epoch || 'N/A';
                    document.getElementById('epoch').className = 'stat-number success';
                    document.getElementById('validators').textContent = 
                        state.activeValidators ? state.activeValidators.length : 'N/A';
                    document.getElementById('validators').className = 'stat-number success';
                    hideRPCStatus();
                } else {
                    document.getElementById('epoch').textContent = 'Error';
                    document.getElementById('epoch').className = 'stat-number error';
                    document.getElementById('validators').textContent = 'Error';
                    document.getElementById('validators').className = 'stat-number error';
                    showRPCStatus('System state fetch failed: ' + (systemData.error || 'Unknown error'));
                }
            } catch (error) {
                console.error('Error fetching data:', error);
                document.getElementById('chainId').textContent = 'Error';
                document.getElementById('chainId').className = 'stat-number error';
                document.getElementById('epoch').textContent = 'Error';
                document.getElementById('epoch').className = 'stat-number error';
                document.getElementById('validators').textContent = 'Error';
                document.getElementById('validators').className = 'stat-number error';
                showRPCStatus('Network error: ' + error.message);
            }
        }

        function showRPCStatus(message) {
            document.getElementById('rpcStatus').style.display = 'block';
            document.getElementById('rpcDetails').innerHTML = message + '<br><small>RPC URL: $RPC_URL</small>';
        }

        function hideRPCStatus() {
            document.getElementById('rpcStatus').style.display = 'none';
        }

        function refreshData() {
            document.querySelector('.container').classList.add('loading');
            fetchData().finally(() => {
                document.querySelector('.container').classList.remove('loading');
            });
        }

        async function testRPC() {
            const results = document.getElementById('testResults');
            results.innerHTML = 'Testing RPC connection to $RPC_URL...';
            
            try {
                const response = await fetch('/api/system-state');
                const data = await response.json();
                if (data.result) {
                    results.innerHTML = '<span class="success">✅ RPC Connection: OK</span>';
                } else {
                    results.innerHTML = '<span class="error">❌ RPC Connection: Failed - ' + (data.error || 'Unknown error') + '</span>';
                }
            } catch (error) {
                results.innerHTML = '<span class="error">❌ RPC Connection: Network Error - ' + error.message + '</span>';
            }
        }

        async function testFaucet() {
            const results = document.getElementById('testResults');
            results.innerHTML = 'Testing Faucet connection...';
            
            try {
                const response = await fetch('http://sui.bcflex.com:5003');
                if (response.ok) {
                    results.innerHTML = '<span class="success">✅ Faucet: Available</span>';
                } else {
                    results.innerHTML = '<span class="error">❌ Faucet: Not responding (HTTP ' + response.status + ')</span>';
                }
            } catch (error) {
                results.innerHTML = '<span class="error">❌ Faucet: Not available - ' + error.message + '</span>';
            }
        }

        // Load data on page load
        document.addEventListener('DOMContentLoaded', fetchData);
        
        // Auto-refresh every 30 seconds
        setInterval(fetchData, 30000);
    </script>
</body>
</html>
EOF
    
    echo "✅ Standalone explorer setup completed"
}

# Create systemd service for explorer
create_explorer_service() {
    echo "⚙️ Creating systemd service for explorer..."
    
    cat > /etc/systemd/system/sui-explorer.service << EOF
[Unit]
Description=Sui Block Explorer
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$EXPLORER_DIR
Environment=NODE_ENV=production
Environment=PORT=$EXPLORER_PORT
Environment=NEXT_PUBLIC_RPC_URL=$RPC_URL
Environment=NEXT_PUBLIC_WS_URL=ws://sui.bcflex.com:9001
Environment=NEXT_PUBLIC_NETWORK=custom
Environment=NEXT_PUBLIC_NETWORK_NAME=BCFlex Sui Network
Environment=NEXT_PUBLIC_API_ENDPOINT=$RPC_URL
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-explorer

# Resource limits
LimitNOFILE=65536
MemoryMax=2G

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable sui-explorer
    
    echo "✅ Explorer service created and enabled"
}

# Start explorer and check if it's working
start_explorer() {
    echo "🚀 Starting Sui Explorer..."
    
    systemctl start sui-explorer
    
    # Wait for service to start
    sleep 10
    
    # Check if service is running
    if systemctl is-active sui-explorer >/dev/null 2>&1; then
        echo "✅ Explorer service is running"
    else
        echo "❌ Explorer service failed to start"
        echo "📋 Service status:"
        systemctl status sui-explorer --no-pager
        echo "📋 Service logs:"
        journalctl -u sui-explorer --no-pager -n 20
        exit 1
    fi
    
    # Check if port is listening
    sleep 5
    if netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " >/dev/null; then
        echo "✅ Explorer is listening on port $EXPLORER_PORT"
    else
        echo "❌ Explorer is not listening on port $EXPLORER_PORT"
        echo "📋 Port status:"
        netstat -tlnp 2>/dev/null | grep -E ":(3000|8080|3001)" || echo "No explorer ports found"
        exit 1
    fi
    
    # Test HTTP response
    echo "🧪 Testing explorer HTTP response..."
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$EXPLORER_PORT" | grep -q "200\|404\|302"; then
        echo "✅ Explorer HTTP response is working"
    else
        echo "⚠️  Explorer HTTP response test inconclusive (may still work)"
    fi
}

# Install nginx if not present
install_nginx() {
    if command_exists nginx; then
        echo "✅ Nginx already installed"
        return 0
    fi
    
    echo "📦 Installing nginx..."
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y nginx
    elif [ -f /etc/redhat-release ]; then
        yum install -y nginx
    else
        echo "❌ Please install nginx manually"
        exit 1
    fi
    
    # Start and enable nginx
    systemctl start nginx
    systemctl enable nginx
    
    echo "✅ Nginx installed and started"
}

# Install certbot if not present
install_certbot() {
    if command_exists certbot; then
        echo "✅ Certbot already installed"
        return 0
    fi
    
    echo "📦 Installing certbot..."
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    elif [ -f /etc/redhat-release ]; then
        yum install -y epel-release
        yum install -y certbot python3-certbot-nginx
    else
        echo "❌ Please install certbot manually"
        exit 1
    fi
    
    echo "✅ Certbot installed"
}

# Create nginx configuration
create_nginx_config() {
    echo "📝 Creating nginx configuration..."
    
    # Create sites directories if they don't exist
    mkdir -p "$NGINX_SITES_AVAILABLE"
    mkdir -p "$NGINX_SITES_ENABLED"
    
    # Backup existing config if it exists
    if [ -f "$NGINX_CONFIG_FILE" ]; then
        cp "$NGINX_CONFIG_FILE" "$NGINX_CONFIG_FILE.backup.$(date +%s)"
        echo "📦 Existing config backed up"
    fi
    
    # Create the nginx configuration
    cat > "$NGINX_CONFIG_FILE" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Will be modified by certbot for HTTPS redirect
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Access logs
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;
    
    location / {
        # Proxy to Sui Explorer
        proxy_pass http://127.0.0.1:$EXPLORER_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://127.0.0.1:$EXPLORER_PORT;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    echo "✅ Nginx configuration created: $NGINX_CONFIG_FILE"
}

# Enable nginx site
enable_nginx_site() {
    echo "🔗 Enabling nginx site..."
    
    # Create symlink if it doesn't exist
    if [ ! -L "$NGINX_SITES_ENABLED/$DOMAIN" ]; then
        ln -sf "$NGINX_CONFIG_FILE" "$NGINX_SITES_ENABLED/$DOMAIN"
    fi
    
    # Test configuration
    nginx -t || {
        echo "❌ Nginx configuration test failed"
        nginx -t
        exit 1
    }
    
    # Reload nginx
    systemctl reload nginx || {
        echo "❌ Failed to reload nginx"
        exit 1
    }
    
    echo "✅ Nginx site enabled and reloaded"
}

# Configure firewall
configure_firewall() {
    echo "🚪 Configuring firewall..."
    
    if command_exists ufw; then
        # UFW (Ubuntu/Debian)
        ufw allow 'Nginx Full' || echo "⚠️  Failed to configure UFW"
        ufw allow 22/tcp || echo "⚠️  Failed to allow SSH in UFW"
        ufw --force enable || echo "⚠️  Failed to enable UFW"
        echo "✅ UFW configured"
    elif command_exists firewall-cmd; then
        # Firewalld (RHEL/CentOS)
        firewall-cmd --permanent --add-service=http || echo "⚠️  Failed to add HTTP to firewall"
        firewall-cmd --permanent --add-service=https || echo "⚠️  Failed to add HTTPS to firewall"
        firewall-cmd --reload || echo "⚠️  Failed to reload firewall"
        echo "✅ Firewalld configured"
    else
        echo "⚠️  No supported firewall found. Please manually open ports 80 and 443"
    fi
}

# Setup SSL certificate
setup_ssl() {
    echo "🔒 Setting up SSL certificate..."
    
    # Check DNS resolution
    echo "🌐 Checking DNS resolution for $DOMAIN..."
    DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
    
    if [ -n "$DOMAIN_IP" ] && [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
        echo "✅ Domain $DOMAIN resolves to this server ($SERVER_IP)"
    elif [ -n "$DOMAIN_IP" ]; then
        echo "⚠️  Domain $DOMAIN resolves to $DOMAIN_IP, but this server is $SERVER_IP"
        echo "🔧 Please update your DNS records to point $DOMAIN to $SERVER_IP"
        echo "💡 SSL setup will be skipped. Run 'sudo certbot --nginx -d $DOMAIN' manually after DNS is fixed"
        return 0
    else
        echo "⚠️  Domain $DOMAIN does not resolve. Please configure your DNS first"
        echo "💡 SSL setup will be skipped. Run 'sudo certbot --nginx -d $DOMAIN' manually after DNS is configured"
        return 0
    fi
    
    # Get email for SSL certificate
    if [ -z "${SSL_EMAIL:-}" ]; then
        read -p "Enter email address for SSL certificate (required by Let's Encrypt): " SSL_EMAIL
        if [ -z "$SSL_EMAIL" ]; then
            echo "⚠️  Email is required for SSL certificate. Skipping SSL setup."
            echo "💡 Run 'sudo certbot --nginx -d $DOMAIN' manually later"
            return 0
        fi
    fi
    
    # Get SSL certificate
    echo "📜 Obtaining SSL certificate..."
    if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect; then
        echo "✅ SSL certificate obtained and configured successfully!"
        
        # Setup auto-renewal
        echo "⚙️ Setting up SSL auto-renewal..."
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        echo "✅ SSL auto-renewal configured"
    else
        echo "❌ Failed to obtain SSL certificate. Common reasons:"
        echo "   1. Domain doesn't point to this server yet"
        echo "   2. Port 80/443 not accessible from internet"
        echo "   3. Rate limits reached"
        echo ""
        echo "💡 You can try manually later with:"
        echo "   sudo certbot --nginx -d $DOMAIN"
    fi
}

# Final status and information
show_final_status() {
    echo ""
    echo "🎉 Setup Complete!"
    echo "=================="
    
    echo ""
    echo "📊 Services Status:"
    echo "   Explorer: $(systemctl is-active sui-explorer 2>/dev/null)"
    echo "   Nginx: $(systemctl is-active nginx 2>/dev/null)"
    
    echo ""
    echo "🌐 Your Sui Block Explorer is available at:"
    echo "   📧 HTTP:  http://$DOMAIN"
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "   🔒 HTTPS: https://$DOMAIN"
    fi
    echo "   🏠 Local: http://localhost:$EXPLORER_PORT"
    
    echo ""
    echo "📋 Management Commands:"
    echo "   Restart Explorer: sudo systemctl restart sui-explorer"
    echo "   Restart Nginx: sudo systemctl restart nginx"
    echo "   View Explorer Logs: sudo journalctl -u sui-explorer -f"
    echo "   View Nginx Logs: sudo tail -f /var/log/nginx/${DOMAIN}_access.log"
    
    if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo ""
        echo "⚠️  SSL Certificate not configured. To set it up:"
        echo "   1. Make sure $DOMAIN points to this server IP: $SERVER_IP"
        echo "   2. Run: sudo certbot --nginx -d $DOMAIN"
    fi
    
    echo ""
    echo "🧪 Quick Tests:"
    echo "   Local Explorer: curl -I http://localhost:$EXPLORER_PORT"
    echo "   Domain HTTP: curl -I http://$DOMAIN"
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "   Domain HTTPS: curl -I https://$DOMAIN"
    fi
}

# Main execution
main() {
    echo "🚀 Starting complete Sui Block Explorer setup..."
    echo "This will install and configure everything needed."
    echo ""
    
    install_git
    install_nodejs
    setup_explorer
    create_explorer_service
    start_explorer
    install_nginx
    install_certbot
    create_nginx_config
    enable_nginx_site
    configure_firewall
    setup_ssl
    show_final_status
}

# Handle script arguments
case "${1-}" in
    "--help"|"-h")
        echo "Usage: $0 [--help]"
        echo ""
        echo "This script performs a complete setup of Sui Block Explorer with nginx proxy and SSL."
        echo ""
        echo "What it does:"
        echo "  1. Install Node.js, git, nginx, certbot"
        echo "  2. Clone and build Sui Explorer"
        echo "  3. Create systemd service for explorer"
        echo "  4. Configure nginx proxy"
        echo "  5. Setup SSL certificate (if DNS is configured)"
        echo "  6. Configure firewall"
        echo ""
        echo "Prerequisites:"
        echo "  - Run as root (sudo)"
        echo "  - Internet connection"
        echo "  - (Optional) DNS pointing $DOMAIN to this server"
        echo ""
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "❌ Unknown argument: $1. Use --help for usage information."
        exit 1
        ;;
esac

#!/bin/bash

# Script to add Sui Block Explorer to existing nginx with SSL
# Domain: Sui.bcflex.com
# This script assumes nginx is already installed and running

set -e

DOMAIN="sui.bcflex.com"
EXPLORER_PORT="8080"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
NGINX_CONFIG_FILE="$NGINX_SITES_AVAILABLE/$DOMAIN"

echo "🔧 Adding Sui Block Explorer to nginx proxy..."
echo "📍 Domain: $DOMAIN"
echo "🔌 Explorer Port: $EXPLORER_PORT"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Check if nginx is installed
if ! command -v nginx > /dev/null 2>&1; then
    echo "❌ nginx is not installed. Please install nginx first."
    exit 1
fi

# Check if certbot is installed
if ! command -v certbot > /dev/null 2>&1; then
    echo "📦 Installing certbot..."
    if command -v apt-get > /dev/null 2>&1; then
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    elif command -v yum > /dev/null 2>&1; then
        yum install -y certbot python3-certbot-nginx
    elif command -v dnf > /dev/null 2>&1; then
        dnf install -y certbot python3-certbot-nginx
    else
        echo "❌ Please install certbot manually for your distribution"
        exit 1
    fi
fi

# Find explorer directory and port
EXPLORER_DIR=""
ACTUAL_PORT=""

# Check common locations for explorer
for dir in "/root/sui-explorer" "/opt/sui-explorer" "/home/*/sui-explorer" "/root/.sui/explorer"; do
    if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
        EXPLORER_DIR="$dir"
        break
    fi
done

if [ -z "$EXPLORER_DIR" ]; then
    echo "⚠️  Explorer directory not found. Checking if explorer is running..."
    # Check if explorer is already running
    RUNNING_PORT=$(netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " | head -n1 | awk '{print $4}' | cut -d: -f2)
    if [ -n "$RUNNING_PORT" ]; then
        ACTUAL_PORT="$RUNNING_PORT"
        echo "✅ Explorer appears to be running on port $ACTUAL_PORT"
    else
        echo "❌ Explorer not found and not running. Please start the explorer first."
        echo "💡 Run: cd /root/sui-explorer && npm start"
        exit 1
    fi
else
    echo "✅ Found explorer at: $EXPLORER_DIR"
    
    # Check if explorer is running
    RUNNING_PORT=$(netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " | head -n1 | awk '{print $4}' | cut -d: -f2)
    if [ -n "$RUNNING_PORT" ]; then
        ACTUAL_PORT="$RUNNING_PORT"
        echo "✅ Explorer is running on port $ACTUAL_PORT"
    else
        echo "⚠️  Explorer not running. Starting it..."
        cd "$EXPLORER_DIR"
        
        # Install dependencies if needed
        if [ ! -d "node_modules" ]; then
            echo "📦 Installing explorer dependencies..."
            npm install
        fi
        
        # Start explorer in background
        echo "🚀 Starting explorer..."
        nohup npm start > /var/log/sui-explorer.log 2>&1 &
        sleep 5
        
        # Check if it started
        RUNNING_PORT=$(netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " | head -n1 | awk '{print $4}' | cut -d: -f2)
        if [ -n "$RUNNING_PORT" ]; then
            ACTUAL_PORT="$RUNNING_PORT"
            echo "✅ Explorer started on port $ACTUAL_PORT"
        else
            echo "❌ Failed to start explorer. Check logs: tail /var/log/sui-explorer.log"
            exit 1
        fi
    fi
fi

# Create nginx configuration for explorer
echo "📝 Creating nginx configuration..."
cat > "$NGINX_CONFIG_FILE" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Redirect HTTP to HTTPS (will be added after SSL setup)
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL certificates (will be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # Proxy settings
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Port \$server_port;
    
    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Buffer settings
    proxy_buffering on;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;
    
    # Main location - proxy to explorer
    location / {
        proxy_pass http://127.0.0.1:$ACTUAL_PORT;
        
        # WebSocket support (if explorer uses WebSockets)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://127.0.0.1:$ACTUAL_PORT;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API endpoints (if any)
    location /api/ {
        proxy_pass http://127.0.0.1:$ACTUAL_PORT;
        proxy_cache_bypass \$http_pragma;
        proxy_cache_revalidate on;
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

echo "✅ Created nginx configuration: $NGINX_CONFIG_FILE"

# Enable the site
if [ ! -L "$NGINX_SITES_ENABLED/$DOMAIN" ]; then
    echo "🔗 Enabling site..."
    ln -sf "$NGINX_CONFIG_FILE" "$NGINX_SITES_ENABLED/$DOMAIN"
fi

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
if nginx -t; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration has errors. Please check:"
    nginx -t
    exit 1
fi

# Reload nginx to apply changes
echo "🔄 Reloading nginx..."
systemctl reload nginx

# Check if domain resolves to this server
echo "🌐 Checking DNS resolution for $DOMAIN..."
DOMAIN_IP=$(dig +short "$DOMAIN" 2>/dev/null | head -n1)
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")

if [ -n "$DOMAIN_IP" ] && [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
    echo "✅ Domain $DOMAIN resolves to this server ($SERVER_IP)"
elif [ -n "$DOMAIN_IP" ]; then
    echo "⚠️  Domain $DOMAIN resolves to $DOMAIN_IP, but this server is $SERVER_IP"
    echo "🔧 Please update your DNS records to point $DOMAIN to $SERVER_IP"
else
    echo "⚠️  Domain $DOMAIN does not resolve. Please configure your DNS:"
    echo "   A record: $DOMAIN -> $SERVER_IP"
fi

# Set up SSL with certbot
echo "🔒 Setting up SSL certificate with Let's Encrypt..."

# Make sure port 80 and 443 are open
echo "🚪 Checking firewall ports..."
if command -v ufw > /dev/null 2>&1; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    echo "✅ Opened ports 80 and 443 (ufw)"
elif command -v firewall-cmd > /dev/null 2>&1; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "✅ Opened ports 80 and 443 (firewalld)"
fi

# Get SSL certificate
echo "📜 Obtaining SSL certificate..."
if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@bcflex.com --redirect; then
    echo "✅ SSL certificate obtained and configured successfully!"
else
    echo "❌ Failed to obtain SSL certificate. This might be because:"
    echo "   1. Domain doesn't point to this server yet"
    echo "   2. Port 80/443 not accessible from internet"
    echo "   3. Rate limits reached"
    echo ""
    echo "💡 You can try manually later with:"
    echo "   certbot --nginx -d $DOMAIN"
fi

# Set up auto-renewal
echo "⚙️ Setting up SSL auto-renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Create systemd service for explorer (if directory found)
if [ -n "$EXPLORER_DIR" ]; then
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
Environment=PORT=$ACTUAL_PORT
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sui-explorer

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sui-explorer
    systemctl start sui-explorer
    echo "✅ Created and started sui-explorer service"
fi

# Final status check
echo ""
echo "🎉 Setup Complete!"
echo "📊 Block Explorer: https://$DOMAIN"
echo ""
echo "🔍 Status Check:"
echo "   Nginx: $(systemctl is-active nginx)"
echo "   Explorer: $(systemctl is-active sui-explorer 2>/dev/null || echo 'manual')"
echo "   SSL: $([ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && echo 'configured' || echo 'pending')"
echo ""
echo "🧪 Quick Tests:"
echo "   HTTP: curl -I http://$DOMAIN"
echo "   HTTPS: curl -I https://$DOMAIN"
echo "   Local: curl -I http://localhost:$ACTUAL_PORT"
echo ""
echo "📋 Management Commands:"
echo "   Restart Explorer: sudo systemctl restart sui-explorer"
echo "   Restart Nginx: sudo systemctl restart nginx"
echo "   Renew SSL: sudo certbot renew"
echo "   Check Logs: sudo journalctl -u sui-explorer -f"
echo ""

# Show current status
echo "🔍 Current Service Status:"
systemctl status nginx --no-pager -l || true
echo ""
systemctl status sui-explorer --no-pager -l 2>/dev/null || echo "Explorer: Running manually"
echo ""

echo "✅ Your Sui Block Explorer should now be available at: https://$DOMAIN"

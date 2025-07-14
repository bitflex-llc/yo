#!/bin/bash

# setup_nginx_explorer.sh
# Script to configure nginx proxy for Sui block explorer at Sui.bcflex.com with SSL

set -eu

# Configuration
DOMAIN="sui.bcflex.com"
EXPLORER_PORT="3000"
NGINX_SITES_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
CONFIG_FILE="$NGINX_SITES_DIR/$DOMAIN"
EMAIL="" # Will be prompted if not set

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

# Detect OS and package manager
detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
        PKG_MANAGER="yum"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
        PKG_MANAGER="pacman"
    else
        OS="unknown"
        warn "Unknown OS. Proceeding with assumptions..."
    fi
    log "Detected OS: $OS"
}

# Install required packages
install_dependencies() {
    log "Installing nginx and certbot..."
    
    case "$PKG_MANAGER" in
        "apt")
            apt update
            apt install -y nginx certbot python3-certbot-nginx ufw
            ;;
        "yum")
            yum install -y epel-release
            yum install -y nginx certbot python3-certbot-nginx firewalld
            ;;
        "pacman")
            pacman -Sy --noconfirm nginx certbot certbot-nginx ufw
            ;;
        *)
            warn "Unknown package manager. Please install nginx and certbot manually."
            ;;
    esac
}

# Check if nginx is installed and running
check_nginx() {
    if ! command -v nginx >/dev/null 2>&1; then
        warn "nginx not found. Installing..."
        install_dependencies
    fi
    
    # Start and enable nginx
    systemctl start nginx || error "Failed to start nginx"
    systemctl enable nginx || warn "Failed to enable nginx"
    
    # Test nginx configuration
    nginx -t || error "nginx configuration test failed"
    
    log "nginx is installed and running"
}

# Check if explorer is running
check_explorer() {
    log "Checking if Sui explorer is running on port $EXPLORER_PORT..."
    
    if ! netstat -tlnp 2>/dev/null | grep ":$EXPLORER_PORT " >/dev/null; then
        warn "No service found on port $EXPLORER_PORT"
        info "Make sure the Sui block explorer is running before configuring nginx"
        read -p "Continue anyway? (y/N): " -r
        if ! echo "$REPLY" | grep -q "^[Yy]$"; then
            exit 1
        fi
    else
        log "Service found on port $EXPLORER_PORT"
    fi
}

# Get email for certbot
get_email() {
    if [ -z "$EMAIL" ]; then
        read -p "Enter email address for SSL certificate (required by Let's Encrypt): " EMAIL
        if [ -z "$EMAIL" ]; then
            error "Email is required for SSL certificate"
        fi
    fi
    log "Using email: $EMAIL"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        # UFW (Ubuntu/Debian)
        ufw allow 'Nginx Full' || warn "Failed to configure UFW"
        ufw allow 22/tcp || warn "Failed to allow SSH in UFW"
        ufw --force enable || warn "Failed to enable UFW"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # Firewalld (RHEL/CentOS)
        firewall-cmd --permanent --add-service=http || warn "Failed to add HTTP to firewall"
        firewall-cmd --permanent --add-service=https || warn "Failed to add HTTPS to firewall"
        firewall-cmd --reload || warn "Failed to reload firewall"
    else
        warn "No supported firewall found. Please manually open ports 80 and 443"
    fi
}

# Create nginx configuration
create_nginx_config() {
    log "Creating nginx configuration for $DOMAIN..."
    
    # Backup existing config if it exists
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%s)"
        warn "Existing config backed up"
    fi
    
    # Create the nginx configuration
    cat > "$CONFIG_FILE" << EOF
# Sui Block Explorer Configuration for $DOMAIN
server {
    listen 80;
    server_name $DOMAIN;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;
    
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
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Block common attack vectors
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~* \.(txt|log)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF
    
    log "nginx configuration created at $CONFIG_FILE"
}

# Enable the site
enable_site() {
    log "Enabling nginx site..."
    
    # Create symlink if it doesn't exist
    if [ ! -L "$NGINX_ENABLED_DIR/$DOMAIN" ]; then
        ln -s "$CONFIG_FILE" "$NGINX_ENABLED_DIR/$DOMAIN"
    fi
    
    # Test configuration
    nginx -t || error "nginx configuration test failed"
    
    # Reload nginx
    systemctl reload nginx || error "Failed to reload nginx"
    
    log "Site enabled and nginx reloaded"
}

# Setup SSL with certbot
setup_ssl() {
    log "Setting up SSL certificate with Let's Encrypt..."
    
    # Check if certbot is available
    if ! command -v certbot >/dev/null 2>&1; then
        error "certbot not found. Please install it first."
    fi
    
    # Get certificate
    certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --domains "$DOMAIN" \
        --redirect || error "Failed to obtain SSL certificate"
    
    log "SSL certificate installed successfully"
    
    # Test auto-renewal
    certbot renew --dry-run || warn "SSL certificate auto-renewal test failed"
}

# Setup automatic renewal
setup_auto_renewal() {
    log "Setting up automatic SSL certificate renewal..."
    
    # Create systemd timer for renewal (if systemd is available)
    if command -v systemctl >/dev/null 2>&1; then
        # Check if timer already exists
        if ! systemctl is-enabled certbot.timer >/dev/null 2>&1; then
            systemctl enable certbot.timer || warn "Failed to enable certbot timer"
            systemctl start certbot.timer || warn "Failed to start certbot timer"
        fi
    fi
    
    # Also add a cron job as backup
    CRON_JOB="0 12 * * * /usr/bin/certbot renew --quiet && /usr/bin/systemctl reload nginx"
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "Added cron job for certificate renewal"
    fi
}

# Test the configuration
test_configuration() {
    log "Testing the configuration..."
    
    # Test nginx config
    nginx -t || error "nginx configuration test failed"
    
    # Test if site is accessible
    sleep 2
    if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN/health" | grep -q "200"; then
        log "HTTP health check passed"
    else
        warn "HTTP health check failed"
    fi
    
    # Test HTTPS if SSL is configured
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health" | grep -q "200"; then
            log "HTTPS health check passed"
        else
            warn "HTTPS health check failed"
        fi
    fi
}

# Display final information
show_final_info() {
    echo
    log "🎉 Setup completed successfully!"
    echo
    info "Your Sui block explorer is now available at:"
    info "  📧 HTTP:  http://$DOMAIN"
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        info "  🔒 HTTPS: https://$DOMAIN"
    fi
    echo
    info "Configuration files:"
    info "  📄 nginx: $CONFIG_FILE"
    info "  📄 SSL:   /etc/letsencrypt/live/$DOMAIN/"
    echo
    info "Log files:"
    info "  📄 Access: /var/log/nginx/${DOMAIN}_access.log"
    info "  📄 Error:  /var/log/nginx/${DOMAIN}_error.log"
    echo
    info "Management commands:"
    info "  🔄 Reload nginx: sudo systemctl reload nginx"
    info "  🔄 Renew SSL:    sudo certbot renew"
    info "  📊 Check SSL:    sudo certbot certificates"
    echo
    warn "Make sure your DNS points $DOMAIN to this server's IP address!"
    warn "Make sure the Sui explorer is running on port $EXPLORER_PORT!"
}

# Main execution
main() {
    log "Starting nginx configuration for Sui block explorer..."
    
    check_root
    detect_os
    check_nginx
    check_explorer
    get_email
    configure_firewall
    create_nginx_config
    enable_site
    setup_ssl
    setup_auto_renewal
    test_configuration
    show_final_info
}

# Handle script arguments
case "${1-}" in
    "--help"|"-h")
        echo "Usage: $0 [--help]"
        echo
        echo "This script configures nginx to proxy a Sui block explorer"
        echo "at $DOMAIN with SSL via Let's Encrypt."
        echo
        echo "Prerequisites:"
        echo "  - Run as root (sudo)"
        echo "  - DNS pointing $DOMAIN to this server"
        echo "  - Sui explorer running on port $EXPLORER_PORT"
        echo
        echo "The script will:"
        echo "  1. Install nginx and certbot (if needed)"
        echo "  2. Configure firewall"
        echo "  3. Create nginx virtual host"
        echo "  4. Obtain SSL certificate"
        echo "  5. Setup automatic renewal"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown argument: $1. Use --help for usage information."
        ;;
esac

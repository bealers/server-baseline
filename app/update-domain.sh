#!/bin/bash

# Script to update domain name for an existing LEMP setup
OLD_DOMAIN=${1:-""}
NEW_DOMAIN=${2:-""}
PHP_VERSION=${PHP_VERSION:-"8.4"}

if [ -z "$OLD_DOMAIN" ] || [ -z "$NEW_DOMAIN" ]; then
    echo "Usage: $0 old-domain.com new-domain.com"
    exit 1
fi

set -e
umask 022

# Check if new domain resolves to this server
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $NEW_DOMAIN)

echo "Server IP: $SERVER_IP"
echo "Domain IP: $DOMAIN_IP"

if [ -z "$DOMAIN_IP" ] || [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "Error: $NEW_DOMAIN does not resolve to this server's IP ($SERVER_IP)"
    echo "Please configure DNS before running this script"
    exit 1
fi

# Stop Nginx for certbot
systemctl stop nginx

# Get new SSL certificate
echo "Getting SSL certificate for $NEW_DOMAIN..."
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email ${EMAIL:-"your-email@example.com"} \
    --domain $NEW_DOMAIN \
    --preferred-challenges http

# Update Nginx configuration
echo "Updating Nginx configuration..."
if [ -f "/etc/nginx/sites-available/$OLD_DOMAIN" ]; then
    mv "/etc/nginx/sites-available/$OLD_DOMAIN" "/etc/nginx/sites-available/$NEW_DOMAIN"
    rm -f "/etc/nginx/sites-enabled/$OLD_DOMAIN"
    sed -i "s/$OLD_DOMAIN/$NEW_DOMAIN/g" "/etc/nginx/sites-available/$NEW_DOMAIN"
    ln -sf "/etc/nginx/sites-available/$NEW_DOMAIN" "/etc/nginx/sites-enabled/"
fi

# Move web root if it exists
if [ -d "/var/www/$OLD_DOMAIN" ]; then
    mv "/var/www/$OLD_DOMAIN" "/var/www/$NEW_DOMAIN"
fi

# Update database if using MySQL
if [ -f "/root/.${OLD_DOMAIN}_db_credentials" ]; then
    echo "Updating MySQL database and user..."
    OLD_DB_NAME=${OLD_DOMAIN//./_}
    NEW_DB_NAME=${NEW_DOMAIN//./_}
    OLD_DB_USER=${OLD_DOMAIN//./_}
    NEW_DB_USER=${NEW_DOMAIN//./_}
    
    # Get current password
    DB_PASS=$(grep DB_PASSWORD /root/.${OLD_DOMAIN}_db_credentials | cut -d= -f2)
    
    # Update database and user
    mysql -u root << EOF
RENAME DATABASE \`$OLD_DB_NAME\` TO \`$NEW_DB_NAME\`;
RENAME USER '$OLD_DB_USER'@'localhost' TO '$NEW_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    # Update credentials file
    mv "/root/.${OLD_DOMAIN}_db_credentials" "/root/.${NEW_DOMAIN}_db_credentials"
    sed -i "s/$OLD_DB_NAME/$NEW_DB_NAME/" "/root/.${NEW_DOMAIN}_db_credentials"
    sed -i "s/$OLD_DB_USER/$NEW_DB_USER/" "/root/.${NEW_DOMAIN}_db_credentials"
    
    echo "Database updated successfully."
fi

# Test Nginx config
echo "Testing Nginx configuration..."
nginx -t

# Start services
echo "Starting services..."
systemctl restart php$PHP_VERSION-fpm
systemctl restart nginx

echo "Domain update complete!"
echo "Your site is now available at: https://$NEW_DOMAIN"
[ -f "/root/.${NEW_DOMAIN}_db_credentials" ] && echo "Updated database credentials saved in /root/.${NEW_DOMAIN}_db_credentials"

# Cleanup
echo "Note: The old SSL certificate for $OLD_DOMAIN will be automatically removed during the next certbot cleanup" 
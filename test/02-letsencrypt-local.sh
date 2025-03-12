#!/bin/bash

# Local version of Let's Encrypt SSL setup for Nginx
# This script generates self-signed certificates for local testing
# Run this after 01-lemp.sh

# Use environment variables from setup.sh or set defaults if not provided
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
EMAIL=${EMAIL:-"your-email@example.com"}

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

echo "Setting up self-signed SSL for local testing:"
echo "Domain: $SITE_DOMAIN"
echo "Email: $EMAIL"

echo "Installing SSL tools..."
apt-get -qq update
apt-get -qq install -y openssl

echo "Checking if Nginx is properly configured for $SITE_DOMAIN..."
if ! grep -q "server_name $SITE_DOMAIN" /etc/nginx/sites-available/$SITE_DOMAIN; then
    echo "Error: Nginx configuration for $SITE_DOMAIN not found!"
    echo "Please run 01-lemp.sh first or check your domain configuration."
    exit 1
fi

# Create directory for certificates
echo "Creating directories for SSL certificates..."
mkdir -p /etc/letsencrypt/live/$SITE_DOMAIN

# Generate self-signed certificate
echo "Generating self-signed SSL certificate for $SITE_DOMAIN..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/letsencrypt/live/$SITE_DOMAIN/privkey.pem \
    -out /etc/letsencrypt/live/$SITE_DOMAIN/fullchain.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$SITE_DOMAIN/emailAddress=$EMAIL"

# Set proper permissions
chmod 600 /etc/letsencrypt/live/$SITE_DOMAIN/privkey.pem
chmod 644 /etc/letsencrypt/live/$SITE_DOMAIN/fullchain.pem

# Update Nginx configuration to use SSL
echo "Configuring Nginx to use SSL..."

# Uncomment the HTTPS server block
sed -i 's/# server {/server {/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)listen 443/\1listen 443/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)ssl_certificate/\1ssl_certificate/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)ssl_certificate_key/\1ssl_certificate_key/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)include \/etc\/nginx\/ssl\/ssl-params.conf/\1include \/etc\/nginx\/ssl\/ssl-params.conf/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)root/\1root/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)index/\1index/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)charset/\1charset/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)location \//\1location \//' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)try_files/\1try_files/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)location = \/favicon.ico/\1location = \/favicon.ico/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)location = \/robots.txt/\1location = \/robots.txt/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)error_page/\1error_page/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)location ~ \\\.php/\1location ~ \\\.php/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)fastcgi_pass/\1fastcgi_pass/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)fastcgi_param/\1fastcgi_param/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)include fastcgi_params/\1include fastcgi_params/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)location ~ \/\\\.(?!well-known)/\1location ~ \/\\\.(?!well-known)/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)deny all/\1deny all/' /etc/nginx/sites-available/$SITE_DOMAIN
sed -i 's/# \(.*\)}/\1}/' /etc/nginx/sites-available/$SITE_DOMAIN

# Update HTTP to HTTPS redirect
sed -i "s|return 301 http://\$host\$request_uri;|return 301 https://\$host\$request_uri;|" /etc/nginx/sites-available/$SITE_DOMAIN

# Replace placeholders in SSL configuration
sed -i "s|/etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem|/etc/letsencrypt/live/$SITE_DOMAIN/fullchain.pem|" /etc/nginx/sites-available/$SITE_DOMAIN
sed -i "s|/etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem|/etc/letsencrypt/live/$SITE_DOMAIN/privkey.pem|" /etc/nginx/sites-available/$SITE_DOMAIN

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Restart Nginx to apply changes
echo "Restarting Nginx..."
systemctl restart nginx

echo "Self-signed SSL setup complete for $SITE_DOMAIN!"
echo "Your site should now be accessible via https://$SITE_DOMAIN"
echo ""
echo "NOTE: Since this is a self-signed certificate, browsers will show a security warning."
echo "This is normal for local testing purposes." 
#!/bin/bash

# LEMP stack with SSL setup
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
PHP_VERSION=${PHP_VERSION:-"8.4"}
DB_TYPE=${DB_TYPE:-"mysql"}
EMAIL=${EMAIL:-"your-email@example.com"}

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

echo "Setting up LEMP stack for: $SITE_DOMAIN"

# Check if domain resolves to this server
SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $SITE_DOMAIN)

echo "Server IP: $SERVER_IP"
echo "Domain IP: $DOMAIN_IP"

if [ -z "$DOMAIN_IP" ] || [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "Error: $SITE_DOMAIN does not resolve to this server's IP ($SERVER_IP)"
    echo "Please configure DNS before running this script"
    exit 1
fi

# Install PHP and extensions
echo "Installing PHP $PHP_VERSION..."
apt -qq install -y \
    php$PHP_VERSION-fpm \
    php$PHP_VERSION-cli \
    php$PHP_VERSION-common \
    php$PHP_VERSION-zip \
    php$PHP_VERSION-gd \
    php$PHP_VERSION-mbstring \
    php$PHP_VERSION-curl \
    php$PHP_VERSION-xml \
    php$PHP_VERSION-bcmath

# Basic PHP config
echo "Configuring PHP..."
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 64M/" /etc/php/$PHP_VERSION/fpm/php.ini
sed -i "s/post_max_size = .*/post_max_size = 64M/" /etc/php/$PHP_VERSION/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php/$PHP_VERSION/fpm/php.ini

# Database setup
if [ "$DB_TYPE" = "mysql" ]; then
    echo "Setting up MySQL..."
    # Ensure MySQL is running
    systemctl start mysql
    systemctl enable mysql
    
    DB_NAME=${SITE_DOMAIN//./_}
    DB_USER=${SITE_DOMAIN//./_}
    DB_PASS=$(openssl rand -base64 12)
    
    # Create database and user
    mysql -u root << EOF || echo "MySQL setup failed, check /root/.${SITE_DOMAIN}_db_credentials_failed"
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        # Save credentials
        echo "DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASS" > /root/.${SITE_DOMAIN}_db_credentials
        chmod 600 /root/.${SITE_DOMAIN}_db_credentials
        echo "MySQL database and user created successfully."
    fi
fi

# Nginx configuration
echo "Configuring Nginx..."
rm -f /etc/nginx/sites-enabled/default

# SSL parameters
mkdir -p /etc/nginx/ssl
cat > /etc/nginx/ssl/ssl-params.conf << 'EOL'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header Strict-Transport-Security "max-age=63072000" always;
EOL

# Stop Nginx for certbot
systemctl stop nginx

# Get SSL certificate
echo "Getting SSL certificate..."
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domain $SITE_DOMAIN \
    --preferred-challenges http

# Site configuration
cat > /etc/nginx/sites-available/$SITE_DOMAIN << EOL
server {
    listen 80;
    listen [::]:80;
    server_name $SITE_DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name $SITE_DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$SITE_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$SITE_DOMAIN/privkey.pem;
    include /etc/nginx/ssl/ssl-params.conf;
    
    root /var/www/$SITE_DOMAIN/public;
    index index.php;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL

# Create required directories
mkdir -p /var/www/letsencrypt
mkdir -p /var/www/$SITE_DOMAIN/public
chown -R www-data:www-data /var/www

# Enable site
ln -sf /etc/nginx/sites-available/$SITE_DOMAIN /etc/nginx/sites-enabled/

# Test Nginx config
echo "Testing Nginx configuration..."
nginx -t

# Start services
echo "Starting services..."
systemctl enable --now php$PHP_VERSION-fpm
systemctl restart php$PHP_VERSION-fpm
systemctl restart nginx

echo "LEMP stack setup complete!"
echo "Your site is available at: https://$SITE_DOMAIN"
[ -f /root/.${SITE_DOMAIN}_db_credentials ] && echo "Database credentials saved in /root/.${SITE_DOMAIN}_db_credentials"

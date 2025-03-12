#!/bin/bash

# Purposely kept simple. Ready to install laravel or other PHP apps.
# TODO - Add SSL

# Use environment variables from setup.sh or set defaults if not provided
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
PHP_VERSION=${PHP_VERSION:-"8.3"}
DB_TYPE=${DB_TYPE:-"mysql"}

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

echo "Setting up LEMP stack with:"
echo "Domain: $SITE_DOMAIN"
echo "PHP Version: $PHP_VERSION"
echo "Database: $DB_TYPE"

# Install prerequisites
echo "Installing prerequisites..."
apt-get -qq update
apt-get -qq install -y software-properties-common

# Get current versions of PHP/Nginx
echo "Adding PHP and Nginx repositories..."
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx
apt -qq update

## Install Nginx
echo "Installing Nginx..."
apt -qq install -y nginx

# Install Certbot Nginx plugin
apt -qq install -y python3-certbot-nginx

# Install selected database
case $DB_TYPE in
    "mysql")
        echo "Installing MySQL..."
        apt -qq install -y mysql-server
        ;;
    "pgsql")
        echo "Installing PostgreSQL..."
        apt -qq install -y postgresql postgresql-contrib
        ;;
    "sqlite")
        echo "Installing SQLite..."
        apt -qq install -y sqlite3
        ;;
    *)
        echo "Unknown database type: $DB_TYPE. Defaulting to MySQL."
        apt -qq install -y mysql-server
        DB_TYPE="mysql"
        ;;
esac

rm -f /etc/nginx/sites-enabled/default

## Laravel friendly, with SSL ready configuration
cat > /etc/nginx/sites-available/$SITE_DOMAIN << 'EOL'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    
    # Let's Encrypt webroot authentication
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
    
    # All other requests redirect to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name DOMAIN_PLACEHOLDER;
    
    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    include /etc/nginx/ssl/ssl-params.conf;
    
    root /var/www/DOMAIN_PLACEHOLDER/public;
    index index.php;
    
    charset utf-8;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    error_page 404 /index.php;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/phpVERSION_PLACEHOLDER-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL

# Replace placeholders
sed -i "s/DOMAIN_PLACEHOLDER/$SITE_DOMAIN/g" /etc/nginx/sites-available/$SITE_DOMAIN
sed -i "s/VERSION_PLACEHOLDER/$PHP_VERSION/g" /etc/nginx/sites-available/$SITE_DOMAIN

# Ensure SSL directories exist
echo "Setting up SSL configuration..."
mkdir -p /etc/nginx/ssl
mkdir -p /var/www/letsencrypt
chmod 755 /var/www/letsencrypt

# Create SSL parameters file
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

## not very secure, placeholder
mkdir -p /var/www/${SITE_DOMAIN}/public
cat > /var/www/${SITE_DOMAIN}/public/index.php << "DELETE_ME"
<?php
phpinfo();

DELETE_ME

chown -R www-data:www-data /var/www/${SITE_DOMAIN}

## Enable site
ln -sf /etc/nginx/sites-available/$SITE_DOMAIN /etc/nginx/sites-enabled/

## Test and restart
nginx -t
systemctl restart nginx || {
    echo "Failed to restart Nginx. Check the configuration."
    exit 1
}

## PHP
echo "Installing PHP $PHP_VERSION and extensions..."
apt -qq install -y \
    php$PHP_VERSION-fpm \
    php$PHP_VERSION-cli \
    php$PHP_VERSION-common \
    php$PHP_VERSION-mbstring \
    php$PHP_VERSION-xml \
    php$PHP_VERSION-zip \
    php$PHP_VERSION-curl \
    php$PHP_VERSION-gd \
    php$PHP_VERSION-intl \
    php$PHP_VERSION-bcmath

# Install database-specific PHP extensions
case $DB_TYPE in
    "mysql")
        apt -qq install -y php$PHP_VERSION-mysql
        ;;
    "pgsql")
        apt -qq install -y php$PHP_VERSION-pgsql
        ;;
    "sqlite")
        apt -qq install -y php$PHP_VERSION-sqlite3
        ;;
esac

# PHP configuration
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/$PHP_VERSION/fpm/php.ini

systemctl restart php$PHP_VERSION-fpm || {
    echo "Failed to restart PHP-FPM. Check the configuration."
    exit 1
}

# Database setup
DB_NAME=${SITE_DOMAIN//./_}
DB_USER=${SITE_DOMAIN//./_}
DB_PASS=$(openssl rand -base64 12)

case $DB_TYPE in
    "mysql")
        echo "Setting up MySQL database..."
        mysql -u root << EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        echo "MySQL database and user created."
        echo "Database: $DB_NAME"
        echo "Username: $DB_USER"
        echo "Password: $DB_PASS"
        echo "Please save these credentials!"
        ;;
    "pgsql")
        echo "Setting up PostgreSQL database..."
        su - postgres -c "createuser -s www-data"
        su - postgres -c "createdb $DB_NAME"
        echo "PostgreSQL database created with www-data as owner."
        echo "Database: $DB_NAME"
        ;;
    "sqlite")
        echo "Setting up SQLite database..."
        mkdir -p /var/www/${SITE_DOMAIN}/database
        touch /var/www/${SITE_DOMAIN}/database/database.sqlite
        chown -R www-data:www-data /var/www/${SITE_DOMAIN}/database
        chmod 755 /var/www/${SITE_DOMAIN}/database
        chmod 644 /var/www/${SITE_DOMAIN}/database/database.sqlite
        echo "SQLite database file created at /var/www/${SITE_DOMAIN}/database/database.sqlite"
        ;;
esac

# Save database credentials to a file for reference
cat > /root/.${SITE_DOMAIN}_db_credentials << EOF
Database Type: $DB_TYPE
Database Name: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASS
EOF
chmod 600 /root/.${SITE_DOMAIN}_db_credentials

echo "LEMP stack installation complete!"
echo "Site available at: http://$SITE_DOMAIN"
echo "PHP version: $PHP_VERSION"
echo "Database: $DB_TYPE"
echo "Database credentials saved to /root/.${SITE_DOMAIN}_db_credentials"
echo ""
echo "The Nginx configuration is ready for SSL. Run the Let's Encrypt script next to enable HTTPS."

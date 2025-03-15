#!/bin/bash

# Step 3: Web Stack
# - Nginx
# - PHP
# - Database (MySQL/PostgreSQL/SQLite)
# - SSL/TLS

# Create log directory
mkdir -p /var/log/server-setup
LOGFILE="/var/log/server-setup/03-web-stack.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting web stack setup"

# Install Nginx
log "Installing Nginx"
apt-get update -qq
apt-get install -y -qq nginx

# Install certbot for Let's Encrypt
log "Installing Certbot for SSL/TLS"
apt-get install -y -qq certbot python3-certbot-nginx

# Install PHP
PHP_VERSION=${PHP_VERSION:-"8.2"}
log "Installing PHP $PHP_VERSION"

# Add PHP repository if not already added
if ! apt-key list | grep -q -i ondrej/php; then
    log "Adding PHP repository"
    apt-get install -y -qq software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update -qq
fi

# Install PHP and extensions
log "Installing PHP packages"
apt-get install -y -qq \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-intl

# Install and configure database
case "${DB_TYPE}" in
    mysql|mysqli)
        log "Installing MySQL"
        # Check if MySQL is already installed
        if ! which mysql >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mysql-server
            
            # Generate a random password for the database
            DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
            DB_NAME="${SITE_DOMAIN//[^a-zA-Z0-9]/_}"
            DB_USER="${SITE_DOMAIN//[^a-zA-Z0-9]/_}_user"
            
            # Create database and user
            log "Creating MySQL database: $DB_NAME"
            mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
            mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
            mysql -e "FLUSH PRIVILEGES;"
            
            # Save database credentials
            cat > "/root/.${SITE_DOMAIN}_db_credentials" << EOF
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF
            
            log "Database credentials saved to /root/.${SITE_DOMAIN}_db_credentials"
            
            # Secure MySQL
            log "Securing MySQL installation"
            mysql -e "DELETE FROM mysql.user WHERE User='';"
            mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
            mysql -e "DROP DATABASE IF EXISTS test;"
            mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
            mysql -e "FLUSH PRIVILEGES;"
        else
            log "MySQL is already installed"
        fi
        ;;
    pgsql)
        log "Installing PostgreSQL"
        # Check if PostgreSQL is already installed
        if ! which psql >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq postgresql postgresql-contrib
            
            # Generate a random password for the database
            DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
            DB_NAME="${SITE_DOMAIN//[^a-zA-Z0-9]/_}"
            DB_USER="${SITE_DOMAIN//[^a-zA-Z0-9]/_}_user"
            
            # Create database and user
            log "Creating PostgreSQL database: $DB_NAME"
            sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
            sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';"
            
            # Save database credentials
            cat > "/root/.${SITE_DOMAIN}_db_credentials" << EOF
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF
            
            log "Database credentials saved to /root/.${SITE_DOMAIN}_db_credentials"
        else
            log "PostgreSQL is already installed"
        fi
        ;;
    sqlite)
        log "Setting up SQLite"
        DB_PATH="/var/www/${SITE_DOMAIN}/database/database.sqlite"
        mkdir -p "/var/www/${SITE_DOMAIN}/database"
        touch "$DB_PATH"
        chown -R www-data:www-data "/var/www/${SITE_DOMAIN}/database"
        
        # Save database credentials
        cat > "/root/.${SITE_DOMAIN}_db_credentials" << EOF
DB_CONNECTION=sqlite
DB_DATABASE=$DB_PATH
EOF
        
        log "Database credentials saved to /root/.${SITE_DOMAIN}_db_credentials"
        ;;
    *)
        log "Unknown database type: $DB_TYPE"
        log "Supported types: mysql, pgsql, sqlite"
        exit 1
        ;;
esac

# Configure Nginx for the site
log "Configuring Nginx for $SITE_DOMAIN"

# Create web root directory if not exists
SITE_ROOT="/var/www/${SITE_DOMAIN}/public"
mkdir -p "$SITE_ROOT"

# Create a default index page if it doesn't exist
if [ ! -f "$SITE_ROOT/index.html" ] && [ ! -f "$SITE_ROOT/index.php" ]; then
    cat > "$SITE_ROOT/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $SITE_DOMAIN</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 50px;
            text-align: center;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Welcome to $SITE_DOMAIN</h1>
    <p>Your server is ready. Deploy your application to get started.</p>
    <p>Current time: $(date)</p>
</body>
</html>
EOF
fi

# Fix ownership
chown -R www-data:www-data "/var/www/${SITE_DOMAIN}"

# Create Nginx configuration
cat > "/etc/nginx/sites-available/${SITE_DOMAIN}" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${SITE_DOMAIN} www.${SITE_DOMAIN};
    root /var/www/${SITE_DOMAIN}/public;
    
    index index.php index.html index.htm;
    
    charset utf-8;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    error_page 404 /index.php;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

# Enable the site
if [ ! -L "/etc/nginx/sites-enabled/${SITE_DOMAIN}" ]; then
    ln -s "/etc/nginx/sites-available/${SITE_DOMAIN}" "/etc/nginx/sites-enabled/${SITE_DOMAIN}"
fi

# Remove default site if our site is enabled
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    rm "/etc/nginx/sites-enabled/default"
fi

# Test Nginx configuration
nginx -t
if [ $? -eq 0 ]; then
    log "Nginx configuration is valid, restarting"
    systemctl restart nginx
else
    log "ERROR: Nginx configuration test failed"
    exit 1
fi

# Set up SSL with Let's Encrypt
log "Setting up SSL with Let's Encrypt for $SITE_DOMAIN"
# Check if the domain is already configured with SSL
if [ ! -d "/etc/letsencrypt/live/${SITE_DOMAIN}" ]; then
    # Check if DNS is properly configured
    PUBLIC_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short ${SITE_DOMAIN})
    
    if [ "$PUBLIC_IP" = "$DOMAIN_IP" ]; then
        log "DNS is properly configured, proceeding with SSL setup"
        certbot --nginx -d ${SITE_DOMAIN} -d www.${SITE_DOMAIN} --non-interactive --agree-tos -m ${EMAIL} --redirect || {
            log "WARNING: Certbot automatic configuration failed. You may need to run it manually."
            log "You can run: certbot --nginx -d ${SITE_DOMAIN} -d www.${SITE_DOMAIN}"
        }
    else
        log "WARNING: DNS is not configured correctly. Cannot set up SSL."
        log "Public IP: $PUBLIC_IP, Domain IP: $DOMAIN_IP"
        log "Please configure DNS to point to your server's IP and then run:"
        log "certbot --nginx -d ${SITE_DOMAIN} -d www.${SITE_DOMAIN}"
    fi
else
    log "SSL certificates already exist for $SITE_DOMAIN"
fi

# Configure PHP
log "Configuring PHP $PHP_VERSION"
PHP_INI_PATH="/etc/php/${PHP_VERSION}/fpm/php.ini"

# Backup original PHP config
cp "$PHP_INI_PATH" "${PHP_INI_PATH}.bak"

# Update PHP settings
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" "$PHP_INI_PATH"
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" "$PHP_INI_PATH"
sed -i "s/post_max_size = 8M/post_max_size = 20M/" "$PHP_INI_PATH"
sed -i "s/memory_limit = 128M/memory_limit = 256M/" "$PHP_INI_PATH"

# Restart PHP-FPM
systemctl restart "php${PHP_VERSION}-fpm"

# Install Composer
if ! which composer >/dev/null 2>&1; then
    log "Installing Composer"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
else
    log "Composer is already installed"
fi

log "Web stack setup completed successfully"
exit 0 
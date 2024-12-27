#!/bin/bash

# TODO - Add SSL

SITE_DOMAIN="app.siftware.com"
PHP_VERSION="8.4"

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

# Get current versions of PHP/Nginx
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx
apt -qq update

# httpd
apt -qq install -y nginx

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Configure Nginx for PHP, Laravel friendly
cat > /etc/nginx/sites-available/$SITE_DOMAIN << "EOL"
server {
    listen 80;
    listen [::]:80;
    server_name ${SITE_DOMAIN};
    root /var/www/${SITE_DOMAIN}/public;
    index index.php;

    # add_header X-Frame-Options "SAMEORIGIN";
    # add_header X-XSS-Protection "1; mode=block";
    # add_header X-Content-Type-Options "nosniff";

    charset utf-8;

    # location = /favicon.ico { access_log off; log_not_found off; }
    # location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOL

# Create public directory
mkdir -p /var/www/${SITE_DOMAIN}/public

# Create index.php
cat > /var/www/${SITE_DOMAIN}/public/index.php << "PHPINFO"
<?php
phpinfo();
?>
PHPINFO

# Enable site
ln -sf /etc/nginx/sites-available/$SITE_DOMAIN /etc/nginx/sites-enabled/

# Test and restart Nginx
nginx -t
systemctl restart nginx

### PHP

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
    php$PHP_VERSION-bcmath \
    ## database drivers \
    php$PHP_VERSION-pgsql \
    #php$PHP_VERSION-mysql \
    #php$PHP_VERSION-sqlite3 \

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Configure PHP
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/$PHP_VERSION/fpm/php.ini

# Restart PHP-FPM
systemctl restart php$PHP_VERSION-fpm

#!/bin/bash

# Purposely kept simple. Ready to install laravel or other PHP apps.
# TODO - Add SSL

SITE_DOMAIN="abc123.siftware.com"
PHP_VERSION="8.3"

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

# Get current versions of PHP/Nginx
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx
apt -qq update

## httpd
apt -qq install -y nginx mysql-server

rm -f /etc/nginx/sites-enabled/default

## Laravel friendly, wip
cat > /etc/nginx/sites-available/$SITE_DOMAIN << 'EOL'
server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER;
    root /var/www/DOMAIN_PLACEHOLDER/public;
    index index.php;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

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

# There must be a better way to do this.
sed -i "s/DOMAIN_PLACEHOLDER/$SITE_DOMAIN/g" /etc/nginx/sites-available/$SITE_DOMAIN
sed -i "s/VERSION_PLACEHOLDER/$PHP_VERSION/g" /etc/nginx/sites-available/$SITE_DOMAIN

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
systemctl restart nginx

## PHP
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
    php$PHP_VERSION-mysql \
    #php$PHP_VERSION-pgsql \
    #php$PHP_VERSION-sqlite3

sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/$PHP_VERSION/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/$PHP_VERSION/fpm/php.ini

systemctl restart php$PHP_VERSION-fpm

# this might still need sudo to work?
mysql -u root -p << EOF
CREATE DATABASE abc123;
CREATE USER 'siftware'@'localhost' IDENTIFIED BY 'SOME_PASSWORD';
GRANT ALL PRIVILEGES ON abc123.* TO 'siftware'@'localhost';
FLUSH PRIVILEGES;
EOF

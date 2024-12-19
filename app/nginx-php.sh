#!/bin/bash

SITE_DOMAIN=foo.com

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

# Add PHP/Nginx repositories
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx
apt-get update

# httpd
apt-get install -y nginx

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Configure Nginx for PHP, Laravel friendly by default
cat > /etc/nginx/sites-available/$SITE_DOMAIN << 'EOL'
server {
    listen 80;
    listen [::]:80;
    server_name $SITE_DOMAIN;
    root /var/www/$SITE_DOMAIN/public;
    index index.php;

    # add_header X-Frame-Options "SAMEORIGIN";
    # add_header X-XSS-Protection "1; mode=block";
    # add_header X-Content-Type-Options "nosniff";

    charset utf-8;

    # location = /favicon.ico { access_log off; log_not_found off; }
    # location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

}
EOL

# Enable site
ln -sf /etc/nginx/sites-available/$SITE_DOMAIN /etc/nginx/sites-enabled/

# Test and restart Nginx
nginx -t
systemctl restart nginx

### PHP

apt-get install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-common \
    php8.4-mbstring \
    php8.4-xml \
    php8.4-zip \
    php8.4-curl \
    php8.4-gd \
    php8.4-intl \
    php8.4-bcmath \
    php8.4-pgsql \
    #php8.4-mysql \
    #php8.4-sqlite3 \

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Configure PHP
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 64M/' /etc/php/8.4/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 64M/' /etc/php/8.4/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/' /etc/php/8.4/fpm/php.ini

# Restart PHP-FPM
systemctl restart php8.4-fpm

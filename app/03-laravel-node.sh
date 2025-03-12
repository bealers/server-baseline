#!/bin/bash

# Production installs for Laravel + Node.js
# Standalone, but assumes 01-nginx-php.sh has been run first

# Use environment variables from setup.sh or set defaults if not provided
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
REPO_URL=${REPO_URL:-"https://github.com/yourusername/yourrepo.git"}
SITE_PATH=/var/www/${SITE_DOMAIN}

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

echo "Setting up Laravel and Node.js for: $SITE_DOMAIN"

# Install Composer globally
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Clone repository
rm -rf ${SITE_PATH}
git clone ${REPO_URL} ${SITE_PATH}
chown -R www-data:www-data ${SITE_PATH}

# Install dependencies and build
cd ${SITE_PATH}
su - www-data -c "cd ${SITE_PATH} && composer install --no-dev"
su - www-data -c "cd ${SITE_PATH} && npm install && npm run build"

# Laravel setup
su - www-data -c "cd ${SITE_PATH} && \
    cp .env.example .env && \
    php artisan key:generate && \
    php artisan storage:link && \
    php artisan optimize && \
    php artisan migrate --force"

echo "Laravel and Node.js setup complete!"

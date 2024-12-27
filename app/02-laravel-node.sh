#!/bin/bash

# Production installs for Laravel + Node.js
# Standalone, but assumes 01-nginx-php.sh has been run first

SITE_DOMAIN=abc123.siftware.com

# assumes repo is public
REPO_URL=https://github.com/siftware/foo.git
SITE_PATH=/var/www/${SITE_DOMAIN}

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

## Install Composer globally
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

## Install Node.js LTS from NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt -qq install -y nodejs

## Setup www-data as a proper deployment user
usermod -s /bin/bash www-data
mkdir -p /var/www/.npm
mkdir -p /var/www/.composer
chown -R www-data:www-data /var/www/

## Prepare site directory
rm -Rf ${SITE_PATH}
mkdir -p ${SITE_PATH}
chown www-data:www-data ${SITE_PATH}

echo "Cloning repository..."
su - www-data -c "git clone ${REPO_URL} ${SITE_PATH}"

echo "Installing composer dependencies..."
su - www-data -c "cd ${SITE_PATH} && composer update && composer install --no-dev"

echo "Installing npm dependencies..."
su - www-data -c "cd ${SITE_PATH} && npm install && npm run build"

echo "Setting up Laravel..."
su - www-data -c "cd ${SITE_PATH} && \
    cp .env.example .env && \
    php artisan key:generate && \
    php artisan storage:link && \
    php artisan optimize && \
    php artisan migrate --force"

## Verify versions and ownership
echo "Checking versions:"
node --version
npm --version
composer --version

echo "Checking file ownership:"
ls -la ${SITE_PATH}

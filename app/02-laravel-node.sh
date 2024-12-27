#!/bin/bash

# Production installs for Laravel + Node.js
# Standalone, but assumes 01-nginx-php.sh has been run first

SITE_DOMAIN=aiab.siftware.com
REPO_URL=https://github.com/siftware/lara-collab.git
WWW_USER=www-data
WWW_GROUP=www-data
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

## Prepare site directory
rm -Rf ${SITE_PATH}
mkdir -p ${SITE_PATH}
chown ${WWW_USER}:${WWW_GROUP} ${SITE_PATH}

## Clone and setup as www-data
su - ${WWW_USER} << 'EOWWW'
# Get variables from parent shell
SITE_PATH="${SITE_PATH}"
REPO_URL="${REPO_URL}"

# Clone repository
git clone ${REPO_URL} ${SITE_PATH}
cd ${SITE_PATH}

# Install dependencies
composer install --no-dev
npm install
npm run build

# Laravel setup
cp .env.example .env
php artisan key:generate
php artisan storage:link
php artisan optimize

# Run migrations if database is configured
# Uncomment if your .env.example has valid DB credentials
# php artisan migrate --force
EOWWW

## Verify versions and ownership
echo "Checking versions:"
node --version
npm --version
composer --version

echo "Checking file ownership:"
ls -la ${SITE_PATH}

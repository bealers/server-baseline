#!/bin/bash

# Production installs for Laravel + Node.js
# Standalone, but assumes 01-nginx-php.sh has been run first

SITE_DOMAIN=aiab.siftware.com

# assumes repo is public
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

## Setup www-data as a proper deployment user
usermod -s /bin/bash ${WWW_USER}
mkdir -p /var/www/.npm
mkdir -p /var/www/.composer
chown -R ${WWW_USER}:${WWW_GROUP} /var/www/

## Prepare site directory
rm -Rf ${SITE_PATH}
mkdir -p ${SITE_PATH}
chown ${WWW_USER}:${WWW_GROUP} ${SITE_PATH}

## Run commands as www-data
runuser -u ${WWW_USER} -- bash << EOF
cd ${SITE_PATH}

# Clone repository
git clone ${REPO_URL} .

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
EOF

## Verify versions and ownership
echo "Checking versions:"
node --version
npm --version
composer --version

echo "Checking file ownership:"
ls -la ${SITE_PATH}

#!/bin/bash

# Production installs for Laravel + Node.js
# Standalone, but assumes 01-nginx-php.sh has been run first

SITE_DOMAIN=aiab.siftware.com
REPO_URL=https://github.com/siftware/lara-collab.git

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

## laravel
composer global require laravel/installer

rm -Rf /var/www/${SITE_DOMAIN}/*

git clone ${REPO_URL} /var/www/${SITE_DOMAIN}

chown -R www-data:www-data /var/www/${SITE_DOMAIN}

cd /var/www/${SITE_DOMAIN}
composer install

cp .env.example .env

php artisan key:generate
php artisan migrate

npm install
npm run build

## Verify versions
node --version
npm --version
composer --version

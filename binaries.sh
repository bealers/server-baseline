#!/bin/bash

# The slow part - installing all binaries
# Run this once and then use config.sh for repeated configuration

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

echo "Installing all required packages..."
apt-get -qq update
apt-get -qq -y upgrade

# Base system utilities
apt-get -qq -y install \
    vim \
    curl \
    git \
    unzip \
    zip \
    ntp \
    ufw \
    stow \
    software-properties-common

# Add required repositories
echo "Adding PHP and Nginx repositories..."
add-apt-repository -y ppa:ondrej/php
add-apt-repository -y ppa:ondrej/nginx
apt-get -qq update

# Install only the selected database system
DB_TYPE=${DB_TYPE:-"mysql"}
echo "Installing database system ($DB_TYPE)..."
case $DB_TYPE in
    mysql)
        apt-get -qq -y install mysql-server
        ;;
    pgsql)
        apt-get -qq -y install postgresql postgresql-contrib
        ;;
    sqlite)
        apt-get -qq -y install sqlite3
        ;;
esac

# LEMP stack packages
apt-get -qq -y install \
    nginx \
    python3-certbot-nginx \
    certbot

# PHP and extensions
PHP_VERSION=${PHP_VERSION:-"8.4"}
echo "Installing PHP ${PHP_VERSION} and extensions..."
apt-get -qq -y install \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-bcmath

# Install database-specific PHP extension
case $DB_TYPE in
    mysql)
        apt-get -qq -y install php${PHP_VERSION}-mysql
        ;;
    pgsql)
        apt-get -qq -y install php${PHP_VERSION}-pgsql
        ;;
    sqlite)
        apt-get -qq -y install php${PHP_VERSION}-sqlite3
        ;;
esac

# Install Node.js and npm
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get -qq -y install nodejs

# Install Composer
echo "Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Cleanup
apt-get -qq clean > /dev/null
apt-get -qq -y autoremove > /dev/null

echo "All binaries installed successfully!"
echo "You can now run config.sh to configure the server." 
#!/bin/bash

# Let's Encrypt SSL setup script
# This script should run BEFORE the LEMP stack setup

# Use environment variables from setup.sh or set defaults
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
EMAIL=${EMAIL:-"your-email@example.com"}

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

echo "Setting up Let's Encrypt SSL for: $SITE_DOMAIN"
echo "Email: $EMAIL"

# Install required packages
echo "Installing SSL tools and Certbot..."
apt-get -qq update
apt-get -qq install -y software-properties-common
apt-get -qq install -y certbot

# Create webroot directory for Let's Encrypt
echo "Creating webroot directory for Let's Encrypt..."
mkdir -p /var/www/letsencrypt

# Generate certificates using standalone mode
echo "Generating SSL certificates..."
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domain $SITE_DOMAIN \
    --preferred-challenges http

echo "SSL certificates have been generated successfully!"
echo "Certificates are stored in /etc/letsencrypt/live/$SITE_DOMAIN/"
echo "The LEMP stack can now be installed with SSL support." 
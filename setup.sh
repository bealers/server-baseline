#!/bin/bash

MAINTENANCE_USER=bealers
SITE_DOMAIN="bealers.com"
EMAIL="darren.beale@siftware.com"
PHP_VERSION="8.4"
REPO_URL="https://github.com/bealers/bealers.com"
DB_TYPE="mysql"

# Script execution flags
RUN_LEMP=false
RUN_LARAVEL=false
INSTALL_BINARIES=true

# Prompt for configuration if running interactively
if [ -t 0 ]; then
    read -p "Do you need to install binaries? (First time only) (Y/n): " binaries_choice
    if [[ $binaries_choice == "n" || $binaries_choice == "N" ]]; then
        INSTALL_BINARIES=false
    fi

    read -p "Enter site domain (default: $SITE_DOMAIN): " input_domain
    SITE_DOMAIN=${input_domain:-$SITE_DOMAIN}
    
    read -p "Enter email for Let's Encrypt notifications (default: $EMAIL): " input_email
    EMAIL=${input_email:-$EMAIL}
    
    read -p "Enter PHP version (default: $PHP_VERSION): " input_php
    PHP_VERSION=${input_php:-$PHP_VERSION}
    
    read -p "Enter Git repository URL (default: $REPO_URL): " input_repo
    REPO_URL=${input_repo:-$REPO_URL}
    
    echo "Select database type:"
    echo "1) MySQL (default)"
    echo "2) PostgreSQL"
    echo "3) SQLite"
    read -p "Enter choice [1-3]: " db_choice
    case $db_choice in
        2) DB_TYPE="pgsql" ;;
        3) DB_TYPE="sqlite" ;;
        *) DB_TYPE="mysql" ;;
    esac
    
    echo "Which components would you like to configure?"
    read -p "LEMP stack (Nginx, PHP, Database, SSL)? (Y/n): " lemp_choice
    if [[ $lemp_choice != "n" && $lemp_choice != "N" ]]; then
        RUN_LEMP=true
    fi
    
    read -p "Laravel and Node.js? (Y/n): " laravel_choice
    if [[ $laravel_choice != "n" && $laravel_choice != "N" ]]; then
        RUN_LARAVEL=true
    fi
    
    echo "Configuration:"
    echo "Install Binaries: $INSTALL_BINARIES"
    echo "Domain: $SITE_DOMAIN"
    echo "Email: $EMAIL"
    echo "PHP Version: $PHP_VERSION"
    echo "Repository: $REPO_URL"
    echo "Database: $DB_TYPE"
    echo "Configure LEMP+SSL: $RUN_LEMP"
    echo "Configure Laravel/Node: $RUN_LARAVEL"
    read -p "Continue with this configuration? (Y/n): " confirm
    if [[ $confirm == "n" || $confirm == "N" ]]; then
        echo "Setup aborted."
        exit 1
    fi
fi

# Export variables for use in other scripts
export MAINTENANCE_USER
export SITE_DOMAIN
export EMAIL
export PHP_VERSION
export REPO_URL
export DB_TYPE
export RUN_LEMP
export RUN_LARAVEL

# Run the appropriate scripts
if [ "$INSTALL_BINARIES" = true ]; then
    echo "Installing binaries..."
    bash "$(dirname "$0")/binaries.sh"
fi

echo "Running configuration..."
bash "$(dirname "$0")/config.sh"

echo "Setup complete!"
if [ "$INSTALL_BINARIES" = true ]; then
    echo "All binaries and configuration installed successfully."
else
    echo "Configuration updated successfully."
fi
echo "You can now login as your maintenance user:"
echo "ssh $MAINTENANCE_USER@$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP") -i ~/.ssh/private-key"

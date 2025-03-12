#!/bin/bash

MAINTENANCE_USER=bealers
SITE_DOMAIN="bealers.com"
EMAIL="darren.beale@siftware.com"
PHP_VERSION="8.4"
REPO_URL="https://github.com/bealers/bealers.com"

DB_TYPE="mysql"

# Script execution flags
RUN_LEMP=true
RUN_LARAVEL=true

# Prompt for configuration if running interactively
if [ -t 0 ]; then
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
    
    echo "Which components would you like to install?"
    read -p "LEMP stack (Nginx, PHP, Database, SSL)? (Y/n): " lemp_choice
    if [[ $lemp_choice == "n" || $lemp_choice == "N" ]]; then
        RUN_LEMP=false
    fi
    
    read -p "Laravel and Node.js? (Y/n): " laravel_choice
    if [[ $laravel_choice == "n" || $laravel_choice == "N" ]]; then
        RUN_LARAVEL=false
    fi
    
    echo "Configuration:"
    echo "Domain: $SITE_DOMAIN"
    echo "Email: $EMAIL"
    echo "PHP Version: $PHP_VERSION"
    echo "Repository: $REPO_URL"
    echo "Database: $DB_TYPE"
    echo "Install LEMP+SSL: $RUN_LEMP"
    echo "Install Laravel/Node: $RUN_LARAVEL"
    read -p "Continue with this configuration? (Y/n): " confirm
    if [[ $confirm == "n" || $confirm == "N" ]]; then
        echo "Setup aborted."
        exit 1
    fi
    
    echo "Starting installation..."
fi

# Export variables for use in other scripts
export SITE_DOMAIN
export EMAIL
export PHP_VERSION
export REPO_URL
export DB_TYPE

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

################## Install ALL packages first

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

################## Configure system

# Firewall
echo "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Timezone and locale
timedatectl set-timezone Europe/London
locale-gen en_GB.UTF-8 > /dev/null
update-locale LANG=en_GB.UTF-8

################## Configure users

# Set up maintenance user
echo "Setting up maintenance user..."
useradd -m -s /bin/bash "$MAINTENANCE_USER"

mkdir -p /home/$MAINTENANCE_USER/.ssh
cp /root/.ssh/authorized_keys /home/$MAINTENANCE_USER/.ssh/ 2>/dev/null || true

chown -R $MAINTENANCE_USER:$MAINTENANCE_USER /home/$MAINTENANCE_USER/.ssh
chmod 700 /home/$MAINTENANCE_USER/.ssh
chmod 600 /home/$MAINTENANCE_USER/.ssh/authorized_keys 2>/dev/null || true

echo "$MAINTENANCE_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$MAINTENANCE_USER

# Clone and setup dotfiles
cd /home/$MAINTENANCE_USER
su - $MAINTENANCE_USER -c "git clone https://github.com/bealers/dotfiles.git" || echo "Dotfiles already exist"
su - $MAINTENANCE_USER -c "cd dotfiles && stow -t ~ bash" || echo "Failed to set up dotfiles"

# Set up www-data for deployments
echo "Setting up www-data for deployments..."
usermod -d /var/www -s /bin/bash www-data
mkdir -p /var/www/.nvm /var/www/.npm /var/www/.config
chown -R www-data:www-data /var/www

# Add NVM to www-data's profile
cat > /var/www/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
chown www-data:www-data /var/www/.bashrc

# Install NVM and Node.js for www-data
su - www-data -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install --lts'

################## Run configuration scripts

SCRIPT_DIR="/root/server-baseline/app"
chmod +x "$SCRIPT_DIR"/*.sh

if [ "$RUN_LEMP" = true ]; then
    echo "Setting up LEMP stack with SSL..."
    bash "$SCRIPT_DIR/01-lemp.sh"
fi

if [ "$RUN_LARAVEL" = true ]; then
    echo "Setting up Laravel and Node.js..."
    bash "$SCRIPT_DIR/03-laravel-node.sh"
fi

################## Cleanup

apt-get -qq clean > /dev/null
apt-get -qq -y autoremove > /dev/null

echo "Server setup complete!"
echo "You can now login as your maintenance user:"
echo "ssh $MAINTENANCE_USER@$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP") -i ~/.ssh/private-key"

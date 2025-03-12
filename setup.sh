#!/bin/bash

MAINTENANCE_USER=bealers
SITE_DOMAIN="bealers.com"
EMAIL="darren.beale@siftware.com"
PHP_VERSION="8.4"
REPO_URL="https://github.com/bealers/bealers.com"

DB_TYPE="mysql"

# Script execution flags
RUN_LEMP=true
RUN_SSL=true
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
    read -p "LEMP stack (Nginx, PHP, Database)? (Y/n): " lemp_choice
    if [[ $lemp_choice == "n" || $lemp_choice == "N" ]]; then
        RUN_LEMP=false
    fi
    
    read -p "Let's Encrypt SSL? (Y/n): " ssl_choice
    if [[ $ssl_choice == "n" || $ssl_choice == "N" ]]; then
        RUN_SSL=false
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
    echo "Install LEMP: $RUN_LEMP"
    echo "Install SSL: $RUN_SSL"
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

################## baseline install

apt-get -qq update
apt-get -qq -y upgrade
apt-get -qq -y install \
    vim \
    curl \
    git \
    unzip \
    zip \
    ntp \
    ufw \
    stow # for my dotfiles

################## firewall

ufw default deny incoming
ufw default allow outgoing

ufw allow 22/tcp
# HTTP and HTTPS for web server
ufw allow 80/tcp
ufw allow 443/tcp

ufw --force enable

################## harden ssh

# WARNING: This will very likely break default Digital Ocean access methods
#
# echo "PermitRootLogin no" >> /etc/ssh/sshd_config
# echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
# systemctl restart sshd
# passwd -l root  # Lock root account

################## locale

timedatectl set-timezone Europe/London
locale-gen en_GB.UTF-8 > /dev/null
update-locale LANG=en_GB.UTF-8


################## user

useradd -m -s /bin/bash "$MAINTENANCE_USER"

mkdir -p /home/$MAINTENANCE_USER/.ssh
# this is where DO puts the key when you create the droplet
cp /root/.ssh/authorized_keys /home/$MAINTENANCE_USER/.ssh/ 2>/dev/null || true

chown -R $MAINTENANCE_USER:$MAINTENANCE_USER /home/$MAINTENANCE_USER/.ssh
chmod 700 /home/$MAINTENANCE_USER/.ssh
chmod 600 /home/$MAINTENANCE_USER/.ssh/authorized_keys 2>/dev/null || true

echo "$MAINTENANCE_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$MAINTENANCE_USER

# Clone and setup dotfiles
echo "Setting up dotfiles for $MAINTENANCE_USER..."
cd /home/$MAINTENANCE_USER
su - $MAINTENANCE_USER -c "git clone https://github.com/bealers/dotfiles.git" || echo "Dotfiles already exist or couldn't be cloned"
su - $MAINTENANCE_USER -c "cd dotfiles && stow -t ~ bash" || echo "Failed to set up dotfiles, continuing anyway"

################## Install NVM for Node.js

echo "Installing NVM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || echo "Failed to install NVM, continuing anyway"

# Setup NVM for www-data user
mkdir -p /var/www/.nvm
chown www-data:www-data /var/www/.nvm

# Add NVM to www-data's profile
cat > /var/www/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
chown www-data:www-data /var/www/.bashrc

# Install latest LTS Node.js for www-data
su - www-data -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install --lts' || echo "Failed to install Node.js, continuing anyway"

################## cleanup

apt-get -qq clean > /dev/null
apt-get -qq -y autoremove > /dev/null

ufw status verbose || echo "UFW not available, continuing anyway"

echo "Sorted. You can now login as your maintenance user:"
echo "ssh $MAINTENANCE_USER@$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP") -i ~/.ssh/private-key"
echo ""
echo "Environment variables set for other scripts:"
echo "SITE_DOMAIN=$SITE_DOMAIN"
echo "EMAIL=$EMAIL"
echo "PHP_VERSION=$PHP_VERSION"
echo "DB_TYPE=$DB_TYPE"
echo "REPO_URL=$REPO_URL"

################## Run additional scripts

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/app"

# Make sure all scripts are executable
chmod +x $SCRIPT_DIR/*.sh 2>/dev/null || echo "Failed to make scripts executable, continuing anyway"

# Run scripts in new order
echo "Installing SSL certificates..."
bash "$SCRIPT_DIR/02-letsencrypt-ssl.sh"

echo "Setting up LEMP stack..."
bash "$SCRIPT_DIR/01-lemp.sh"

echo "Setting up Laravel and Node.js..."
bash "$SCRIPT_DIR/03-laravel-node.sh"

echo "Server setup complete!"

#!/bin/bash

# Configuration script - can be run multiple times
# Assumes binaries.sh has been run at least once

set -e
umask 022

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

set -x  # Enable debug mode to see what's happening
echo "Current directory: $(pwd)"
echo "Script location: $0"
SCRIPT_DIR="/root/server-baseline/app"  # Use absolute path
echo "Looking for scripts in: $SCRIPT_DIR"
echo "RUN_LEMP is set to: $RUN_LEMP"
echo "RUN_LARAVEL is set to: $RUN_LARAVEL"
echo "Directory contents:"
ls -la "$SCRIPT_DIR" || echo "Failed to list directory"

if [ -d "$SCRIPT_DIR" ]; then
    echo "Found app directory"
    chmod +x "$SCRIPT_DIR"/*.sh || echo "Failed to chmod scripts"
    
    if [ "$RUN_LEMP" = true ]; then
        echo "Setting up LEMP stack with SSL..."
        bash "$SCRIPT_DIR/01-lemp.sh"
    else
        echo "Skipping LEMP setup because RUN_LEMP is not true"
    fi

    if [ "$RUN_LARAVEL" = true ]; then
        echo "Setting up Laravel and Node.js..."
        bash "$SCRIPT_DIR/03-laravel-node.sh"
    else
        echo "Skipping Laravel setup because RUN_LARAVEL is not true"
    fi
else
    echo "Error: app directory not found at $SCRIPT_DIR"
    pwd
    ls -la
fi
set +x  # Disable debug mode 
#!/bin/bash

# Step 1: System Basics
# - Users
# - SSH
# - Timezone & Locale
# - Basic packages

# Exit on first error
set -e

echo "=== Step 1: Setting up system basics ==="

# Create log directory
mkdir -p /var/log/server-setup
LOGFILE="/var/log/server-setup/01-system-basics.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting system basics setup"

# Timezone and locale
log "Setting timezone to Europe/London"
timedatectl set-timezone Europe/London
locale-gen en_GB.UTF-8 > /dev/null
update-locale LANG=en_GB.UTF-8

# Update packages
log "Updating package lists"
apt-get update -qq

log "Installing essential packages"
apt-get install -y -qq \
    curl \
    wget \
    git \
    unzip \
    htop \
    vim \
    bash-completion \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    gnupg \
    lsb-release

# Set up maintenance user
if id "$MAINTENANCE_USER" &>/dev/null; then
    log "Maintenance user $MAINTENANCE_USER already exists"
else
    log "Creating maintenance user: $MAINTENANCE_USER"
    useradd -m -s /bin/bash "$MAINTENANCE_USER"
fi

# Set up sudo access
log "Setting up sudo access for $MAINTENANCE_USER"
echo "$MAINTENANCE_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$MAINTENANCE_USER
chmod 440 /etc/sudoers.d/$MAINTENANCE_USER

# Set up SSH keys for maintenance user
log "Setting up SSH for $MAINTENANCE_USER"
mkdir -p /home/$MAINTENANCE_USER/.ssh
touch /home/$MAINTENANCE_USER/.ssh/authorized_keys

# Check if root has authorized_keys, if so, copy to maintenance user
if [ -f /root/.ssh/authorized_keys ]; then
    log "Copying SSH keys from root to $MAINTENANCE_USER"
    cat /root/.ssh/authorized_keys >> /home/$MAINTENANCE_USER/.ssh/authorized_keys
fi

# Also copy over any private keys if they exist
if ls /root/.ssh/id_* 1> /dev/null 2>&1; then
    log "Copying SSH keys from root to $MAINTENANCE_USER"
    cp /root/.ssh/id_* /home/$MAINTENANCE_USER/.ssh/ 2>/dev/null || true
fi

# Fix permissions
chown -R $MAINTENANCE_USER:$MAINTENANCE_USER /home/$MAINTENANCE_USER/.ssh
chmod 700 /home/$MAINTENANCE_USER/.ssh
chmod 600 /home/$MAINTENANCE_USER/.ssh/authorized_keys

# Set up www-data for deployments
log "Setting up www-data for deployments"
usermod -d /var/www -s /bin/bash www-data
mkdir -p /var/www/.nvm /var/www/.npm /var/www/.config /var/www/.ssh
touch /var/www/.ssh/authorized_keys

# Set up dedicated deploy key for www-data
if [ "$REPO_ACCESS_TYPE" = "ssh" ]; then
    log "Setting up dedicated deploy key for www-data"
    
    # Check if we already have a deploy key
    if [ -f "/var/www/.ssh/id_ed25519" ]; then
        log "Existing deploy key found for www-data"
    elif [ -n "$DEPLOY_KEY_PATH" ] && [ -f "$DEPLOY_KEY_PATH" ]; then
        # Use provided deploy key
        log "Using provided deploy key"
        cp "$DEPLOY_KEY_PATH" /var/www/.ssh/id_ed25519
        chmod 600 /var/www/.ssh/id_ed25519
    else
        # Generate a new deploy key
        log "Generating a new deploy key for www-data"
        su - www-data -c "ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''"
        
        # Display the public key for adding to GitHub
        log "==============================================="
        log "IMPORTANT: Add this deploy key to your repository:"
        cat /var/www/.ssh/id_ed25519.pub
        log "==============================================="
        log "Press Enter after you've added the key to continue..."
        read -p ""
    fi
    
    # Set up SSH config for GitHub to avoid host verification issues
    cat > /var/www/.ssh/config << EOF
Host github.com
    IdentityFile /var/www/.ssh/id_ed25519
    StrictHostKeyChecking no
    User git
EOF
fi

# Fix permissions for www-data
chown -R www-data:www-data /var/www
chmod 700 /var/www/.ssh
find /var/www/.ssh -type f -exec chmod 600 {} \;

# Set up .bashrc for www-data
cat > /var/www/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
chown www-data:www-data /var/www/.bashrc

# Install NVM and Node.js for www-data if not already installed
if [ ! -d "/var/www/.nvm/versions" ]; then
    log "Installing NVM and Node.js for www-data"
    su - www-data -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
        export NVM_DIR="$HOME/.nvm" && \
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
        nvm install --lts'
else
    log "NVM already installed for www-data"
fi

log "System basics setup completed successfully"
exit 0 
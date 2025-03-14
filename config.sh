#!/bin/bash

# Configuration script - can be run multiple times
# Assumes binaries.sh has been run at least once

# Remove set -e to prevent early exits on non-fatal errors
set +e
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
mkdir -p /var/www/.nvm /var/www/.npm /var/www/.config /var/www/.ssh
chown -R www-data:www-data /var/www

# SIMPLIFIED: Copy SSH keys from root to both maintenance user and www-data
# This ensures both users have the same SSH keys that were used during server setup
echo "Setting up SSH keys for repository access..."

# First, make sure the maintenance user has the SSH key from root
if ls /root/.ssh/id_* 1> /dev/null 2>&1; then
    echo "Copying SSH keys from root to $MAINTENANCE_USER..."
    cp /root/.ssh/id_* /home/$MAINTENANCE_USER/.ssh/ 2>/dev/null
    chown $MAINTENANCE_USER:$MAINTENANCE_USER /home/$MAINTENANCE_USER/.ssh/*
    chmod 600 /home/$MAINTENANCE_USER/.ssh/id_*
fi

# Then copy the same keys to www-data
echo "Copying SSH keys from root to www-data..."
if ls /root/.ssh/id_* 1> /dev/null 2>&1; then
    cp /root/.ssh/id_* /var/www/.ssh/ 2>/dev/null
    
    # Set proper ownership and permissions
    chown www-data:www-data /var/www/.ssh/*
    chmod 600 /var/www/.ssh/id_*
else
    echo "WARNING: No SSH keys found in /root/.ssh/ - repository access may fail"
    echo "You'll need to manually set up SSH keys for www-data after installation"
fi

# Set up known_hosts and SSH config for GitHub
cat > /var/www/.ssh/config << 'EOF'
Host github.com
    StrictHostKeyChecking no
    User git
EOF

chown www-data:www-data /var/www/.ssh/config
chmod 600 /var/www/.ssh/config

# Also set up a failsafe to temporarily make www-data use the maintenance user's SSH agent
if [ "$REPO_ACCESS_TYPE" = "ssh" ]; then
    echo "Setting up Git helper scripts..."
    
    # Create a script to allow www-data to use maintenance user's SSH agent
    cat > /usr/local/bin/git-with-ssh << EOF
#!/bin/bash
sudo -u $MAINTENANCE_USER ssh-add -l > /dev/null || echo "No identities in SSH agent"
sudo -E -u $MAINTENANCE_USER GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git "\$@"
EOF
    
    chmod +x /usr/local/bin/git-with-ssh
    
    echo "Created git helper script: /usr/local/bin/git-with-ssh"
    echo "You can use this later if needed: sudo git-with-ssh clone git@github.com:yourusername/repo.git"
fi

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

# Keep set +e for the entire script execution
set +e

echo "DEBUG: Starting configuration scripts section"
cd /root/server-baseline || {
    echo "ERROR: Could not change to /root/server-baseline"
    exit 1
}

SCRIPT_DIR="/root/server-baseline"
echo "DEBUG: Script directory: $SCRIPT_DIR"
echo "DEBUG: Current directory: $(pwd)"
echo "DEBUG: RUN_LEMP=$RUN_LEMP"
echo "DEBUG: RUN_LARAVEL=$RUN_LARAVEL"
echo "DEBUG: RUN_HARDENING=$RUN_HARDENING"

if [ "$RUN_LEMP" = true ]; then
    echo "Setting up LEMP stack with SSL..."
    if [ -f "$SCRIPT_DIR/app/01-lemp.sh" ]; then
        echo "Found LEMP script, executing..."
        bash "$SCRIPT_DIR/app/01-lemp.sh"
        LEMP_EXIT=$?
        echo "LEMP script exited with code: $LEMP_EXIT"
    else
        echo "ERROR: LEMP script not found at $SCRIPT_DIR/app/01-lemp.sh"
        ls -la "$SCRIPT_DIR/app/"
    fi
fi

if [ "$RUN_LARAVEL" = true ]; then
    echo "Setting up Laravel and Node.js..."
    if [ -f "$SCRIPT_DIR/app/03-laravel-node.sh" ]; then
        echo "Found Laravel script, executing..."
        bash "$SCRIPT_DIR/app/03-laravel-node.sh"
        LARAVEL_EXIT=$?
        echo "Laravel script exited with code: $LARAVEL_EXIT"
    else
        echo "ERROR: Laravel script not found at $SCRIPT_DIR/app/03-laravel-node.sh"
        ls -la "$SCRIPT_DIR/app/"
    fi
fi

echo "DEBUG: Configuration scripts section complete" 

# Run hardening script
if [ "$RUN_HARDENING" = true ] && [ -f "./app/04-hardening.sh" ]; then
    echo "Running security hardening script..."
    bash "./app/04-hardening.sh"
    HARDENING_EXIT=$?
    logger "Security hardening completed with exit code: $HARDENING_EXIT"
fi

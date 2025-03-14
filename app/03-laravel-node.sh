#!/bin/bash

# Laravel and Node.js configuration
# Assumes binaries.sh has been run first

# Use environment variables from setup.sh or set defaults if not provided
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
REPO_URL=${REPO_URL:-"https://github.com/yourusername/yourrepo.git"}
REPO_ACCESS_TYPE=${REPO_ACCESS_TYPE:-"https"}
SITE_PATH=/var/www/${SITE_DOMAIN}

# Remove set -e and add error handling
set +e
umask 022

echo "Setting up Laravel and Node.js for: $SITE_DOMAIN"
echo "Using repository URL: $REPO_URL"
echo "Repository access type: $REPO_ACCESS_TYPE"

# Ensure directory is owned by www-data
rm -rf ${SITE_PATH}
mkdir -p ${SITE_PATH}
chown www-data:www-data ${SITE_PATH}

# Clone repository with improved approach
echo "Cloning repository..."

# First attempt: Try direct clone as www-data
echo "Attempting to clone as www-data..."
su - www-data -c "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' git clone ${REPO_URL} ${SITE_PATH}"
CLONE_EXIT_CODE=$?

# If that fails and we're using SSH, try alternative methods
if [ $CLONE_EXIT_CODE -ne 0 ] && [ "$REPO_ACCESS_TYPE" = "ssh" ]; then
    echo "Direct clone failed. Trying alternative methods..."
    
    # Method 2: Try using the git-with-ssh helper (uses maintenance user's credentials)
    if [ -f "/usr/local/bin/git-with-ssh" ]; then
        echo "Trying to clone using maintenance user's SSH credentials..."
        rm -rf ${SITE_PATH}
        mkdir -p ${SITE_PATH}
        
        # Clone using the helper script
        cd $(dirname ${SITE_PATH})
        /usr/local/bin/git-with-ssh clone ${REPO_URL} ${SITE_DOMAIN}
        CLONE_EXIT_CODE=$?
        
        # Fix permissions if successful
        if [ $CLONE_EXIT_CODE -eq 0 ]; then
            echo "Clone successful! Fixing permissions..."
            chown -R www-data:www-data ${SITE_PATH}
        fi
    fi
    
    # Method 3: Last resort - clone as the maintenance user directly
    if [ $CLONE_EXIT_CODE -ne 0 ]; then
        echo "Trying to clone as maintenance user..."
        rm -rf ${SITE_PATH}
        mkdir -p ${SITE_PATH}
        
        # Clone as maintenance user
        sudo -u ${MAINTENANCE_USER} git clone ${REPO_URL} ${SITE_PATH}
        CLONE_EXIT_CODE=$?
        
        # Fix permissions if successful
        if [ $CLONE_EXIT_CODE -eq 0 ]; then
            echo "Clone successful! Fixing permissions..."
            chown -R www-data:www-data ${SITE_PATH}
        fi
    fi
fi

# If all methods failed, create a placeholder
if [ $CLONE_EXIT_CODE -ne 0 ]; then
    echo "All clone attempts failed. Creating placeholder structure."
    echo "You can manually clone your repository after setup using one of these commands:"
    echo "  As www-data: sudo -u www-data git clone ${REPO_URL} ${SITE_PATH}"
    echo "  As ${MAINTENANCE_USER}: sudo -u ${MAINTENANCE_USER} git clone ${REPO_URL} ${SITE_PATH} && sudo chown -R www-data:www-data ${SITE_PATH}"
    
    # Create placeholder
    mkdir -p ${SITE_PATH}/public
    echo "<html><body><h1>Site under construction</h1><p>Repository clone failed during setup.</p></body></html>" > ${SITE_PATH}/public/index.html
    touch ${SITE_PATH}/.env.example
    chown -R www-data:www-data ${SITE_PATH}
else
    echo "Repository cloned successfully!"
fi

# Set up Laravel environment first (if it exists)
if [ -f "${SITE_PATH}/.env.example" ]; then
    echo "Setting up Laravel environment..."
    su - www-data -c "cd ${SITE_PATH} && cp -n .env.example .env"
    
    # Copy database credentials if they exist
    if [ -f "/root/.${SITE_DOMAIN}_db_credentials" ]; then
        echo "Copying database credentials to .env..."
        cat "/root/.${SITE_DOMAIN}_db_credentials" > ${SITE_PATH}/.env.tmp
        cat ${SITE_PATH}/.env >> ${SITE_PATH}/.env.tmp
        mv ${SITE_PATH}/.env.tmp ${SITE_PATH}/.env
        chown www-data:www-data ${SITE_PATH}/.env
    fi
    
    # Install dependencies (only if composer.json exists)
    if [ -f "${SITE_PATH}/composer.json" ]; then
        echo "Installing Composer dependencies..."
        su - www-data -c "cd ${SITE_PATH} && composer install --no-dev" || echo "Warning: Composer install failed"
        
        # Laravel setup (only if artisan exists)
        if [ -f "${SITE_PATH}/artisan" ]; then
            echo "Running Laravel setup commands..."
            su - www-data -c "cd ${SITE_PATH} && \
                php artisan key:generate && \
                php artisan storage:link && \
                php artisan optimize && \
                php artisan migrate --force" || echo "Warning: Laravel setup commands failed"
        else
            echo "No artisan file found. Skipping Laravel-specific commands."
        fi
    else
        echo "No composer.json found. Skipping Composer installation."
    fi
    
    # Install Node.js dependencies (only if package.json exists)
    if [ -f "${SITE_PATH}/package.json" ]; then
        echo "Installing NPM dependencies and building assets..."
        su - www-data -c "cd ${SITE_PATH} && npm install && npm run build" || echo "Warning: NPM build failed"
    else
        echo "No package.json found. Skipping NPM installation."
    fi
else
    echo "No .env.example file found. Skipping Laravel setup."
fi

echo "Laravel and Node.js setup complete!"
echo "Note: If you encountered any errors, you may need to manually complete some steps."

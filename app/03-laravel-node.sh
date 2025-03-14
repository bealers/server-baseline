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

# Clone repository as www-data
echo "Cloning repository..."
if [ "$REPO_ACCESS_TYPE" = "ssh" ]; then
    # Test SSH connection first
    echo "Testing SSH connection to GitHub..."
    su - www-data -c "ssh -T git@github.com || true"
    
    # Clone using SSH
    su - www-data -c "GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no' git clone ${REPO_URL} ${SITE_PATH}" || {
        echo "Error: Failed to clone repository using SSH."
        echo "Please check that your SSH keys are properly set up and have access to the repository."
        echo "You can manually clone the repository after setup using:"
        echo "  sudo -u www-data git clone ${REPO_URL} ${SITE_PATH}"
        
        # Create a minimal placeholder structure
        mkdir -p ${SITE_PATH}
        touch ${SITE_PATH}/.env.example
        mkdir -p ${SITE_PATH}/public
        echo "<html><body><h1>Site under construction</h1></body></html>" > ${SITE_PATH}/public/index.html
        chown -R www-data:www-data ${SITE_PATH}
    }
else
    # Standard HTTPS clone (may fail for private repos without credentials)
    su - www-data -c "git clone ${REPO_URL} ${SITE_PATH}" || {
        echo "Warning: Failed to clone repository using HTTPS."
        echo "If this is a private repository, you should use SSH access instead."
        echo "You can manually clone the repository after setup using:"
        echo "  sudo -u www-data git clone ${REPO_URL} ${SITE_PATH}"
        
        # Create a minimal placeholder structure
        mkdir -p ${SITE_PATH}
        touch ${SITE_PATH}/.env.example
        mkdir -p ${SITE_PATH}/public
        echo "<html><body><h1>Site under construction</h1></body></html>" > ${SITE_PATH}/public/index.html
        chown -R www-data:www-data ${SITE_PATH}
    }
fi

# Check if repository was successfully cloned
if [ ! -d "${SITE_PATH}/.git" ]; then
    echo "Repository not fully cloned. Created placeholder structure instead."
    echo "Please manually clone your repository after setup is complete."
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

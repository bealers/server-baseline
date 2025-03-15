#!/bin/bash

# Step 4: Application Deployment
# - Code checkout
# - Dependencies
# - Configuration

# Create log directory
mkdir -p /var/log/server-setup
LOGFILE="/var/log/server-setup/04-application-deploy.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting application deployment"

# Define site path
SITE_PATH="/var/www/${SITE_DOMAIN}"

# Check if we need to deploy the application
if [ -d "${SITE_PATH}/.git" ]; then
    log "Git repository already exists in ${SITE_PATH}"
    read -p "Do you want to re-deploy the application? This will DELETE all existing files. (y/N): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        log "Skipping deployment"
        exit 0
    fi
    log "Proceeding with re-deployment"
fi

# Prepare the directory
log "Preparing site directory"
rm -rf ${SITE_PATH}
mkdir -p ${SITE_PATH}
chown www-data:www-data ${SITE_PATH}

# Clone the repository
log "Cloning repository from ${REPO_URL}"
CLONE_SUCCESS=false

if [ "$REPO_ACCESS_TYPE" = "ssh" ]; then
    # Using SSH with deploy key
    log "Cloning repository using www-data's deploy key"
    
    # Verify deploy key exists
    if [ ! -f "/var/www/.ssh/id_ed25519" ]; then
        log "ERROR: Deploy key not found for www-data"
        log "Please run the system-basics step to set up a deploy key first"
        exit 1
    fi
    
    # Clone using deploy key
    su - www-data -c "cd /var/www && GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=no -i /var/www/.ssh/id_ed25519' git clone ${REPO_URL} ${SITE_DOMAIN}"
    CLONE_RESULT=$?
    
    if [ $CLONE_RESULT -eq 0 ]; then
        CLONE_SUCCESS=true
        log "Repository cloned successfully using deploy key"
    else
        log "ERROR: Failed to clone repository using deploy key"
        log "Please verify that the deploy key has been added to your repository with read access"
        log "Public key:"
        cat /var/www/.ssh/id_ed25519.pub
    fi
else
    # Using HTTPS
    log "Cloning repository using HTTPS"
    su - www-data -c "cd /var/www && git clone ${REPO_URL} ${SITE_DOMAIN}"
    CLONE_RESULT=$?
    
    if [ $CLONE_RESULT -eq 0 ]; then
        CLONE_SUCCESS=true
        log "Repository cloned successfully using HTTPS"
    else
        log "ERROR: Failed to clone repository using HTTPS"
        log "If this is a private repository, consider using SSH with a deploy key instead"
    fi
fi

# If clone failed, create a placeholder
if [ "$CLONE_SUCCESS" != "true" ]; then
    log "Creating placeholder structure"
    mkdir -p ${SITE_PATH}/public
    touch ${SITE_PATH}/.env.example
    
    cat > ${SITE_PATH}/public/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Site Under Construction</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 50px;
            text-align: center;
        }
        h1 {
            color: #e74c3c;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        code {
            background: #f4f4f4;
            padding: 3px 5px;
            border-radius: 3px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Repository Clone Failed</h1>
        <p>Unable to clone the repository during setup.</p>
        <p>For private repositories, make sure you've added the deploy key to your repository:</p>
        <code>$(cat /var/www/.ssh/id_ed25519.pub 2>/dev/null || echo "No deploy key found")</code>
        <p>Or manually deploy your application after setup:</p>
        <code>sudo -u www-data git clone ${REPO_URL} ${SITE_PATH}</code>
    </div>
</body>
</html>
EOF
    
    chown -R www-data:www-data ${SITE_PATH}
    log "Placeholder structure created"
else
    log "Repository cloned successfully"
    
    # Set up environment configuration
    if [ -f "${SITE_PATH}/.env.example" ]; then
        log "Setting up environment configuration"
        su - www-data -c "cd ${SITE_PATH} && cp -n .env.example .env"
        
        # Copy database credentials if they exist
        if [ -f "/root/.${SITE_DOMAIN}_db_credentials" ]; then
            log "Adding database credentials to .env"
            cat "/root/.${SITE_DOMAIN}_db_credentials" > ${SITE_PATH}/.env.tmp
            cat ${SITE_PATH}/.env >> ${SITE_PATH}/.env.tmp
            mv ${SITE_PATH}/.env.tmp ${SITE_PATH}/.env
            chown www-data:www-data ${SITE_PATH}/.env
        fi
    else
        log "No .env.example found, skipping environment setup"
    fi
    
    # Install Composer dependencies
    if [ -f "${SITE_PATH}/composer.json" ]; then
        log "Installing Composer dependencies"
        su - www-data -c "cd ${SITE_PATH} && composer install --no-dev --optimize-autoloader" || {
            log "WARNING: Composer installation failed"
        }
        
        # Run Laravel commands if it's a Laravel application
        if [ -f "${SITE_PATH}/artisan" ]; then
            log "Running Laravel setup commands"
            su - www-data -c "cd ${SITE_PATH} && php artisan key:generate" || log "WARNING: Key generation failed"
            su - www-data -c "cd ${SITE_PATH} && php artisan storage:link" || log "WARNING: Storage link failed"
            su - www-data -c "cd ${SITE_PATH} && php artisan optimize" || log "WARNING: Optimization failed"
            
            # Ask about running migrations
            read -p "Do you want to run database migrations? This might modify your database. (y/N): " confirm
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                log "Running database migrations"
                su - www-data -c "cd ${SITE_PATH} && php artisan migrate --force" || log "WARNING: Migrations failed"
            else
                log "Skipping database migrations"
            fi
        else
            log "Not a Laravel application, skipping artisan commands"
        fi
    else
        log "No composer.json found, skipping Composer installation"
    fi
    
    # Install Node.js dependencies
    if [ -f "${SITE_PATH}/package.json" ]; then
        log "Installing Node.js dependencies"
        su - www-data -c "cd ${SITE_PATH} && source ~/.nvm/nvm.sh && npm ci" || {
            log "WARNING: NPM installation failed, trying npm install"
            su - www-data -c "cd ${SITE_PATH} && source ~/.nvm/nvm.sh && npm install" || {
                log "WARNING: NPM install also failed"
            }
        }
        
        # Build assets
        if grep -q "\"build\"" "${SITE_PATH}/package.json"; then
            log "Building assets"
            su - www-data -c "cd ${SITE_PATH} && source ~/.nvm/nvm.sh && npm run build" || {
                log "WARNING: Asset build failed"
            }
        else
            log "No build script found in package.json"
        fi
    else
        log "No package.json found, skipping Node.js setup"
    fi
    
    # Fix permissions
    log "Setting correct permissions"
    find ${SITE_PATH} -type f -exec chmod 644 {} \;
    find ${SITE_PATH} -type d -exec chmod 755 {} \;
    
    # Make storage directory writable
    if [ -d "${SITE_PATH}/storage" ]; then
        chmod -R 775 ${SITE_PATH}/storage
    fi
    
    # Bootstrap/cache needs to be writable
    if [ -d "${SITE_PATH}/bootstrap/cache" ]; then
        chmod -R 775 ${SITE_PATH}/bootstrap/cache
    fi
    
    chown -R www-data:www-data ${SITE_PATH}
fi

log "Application deployment completed"
exit 0 
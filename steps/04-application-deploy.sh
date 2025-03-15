#!/bin/bash

# Step 4: Application Deployment
# - Code checkout
# - Dependencies
# - Configuration

mkdir -p /var/log/server-setup
LOGFILE="/var/log/server-setup/04-application-deploy.log"

# basic logger
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
    
    # Set up proper Node.js environment for www-data
    log "Setting up Node.js environment for www-data"
    
    # Ensure NVM is properly installed and configured
    if [ ! -f "/var/www/.nvm/nvm.sh" ]; then
        log "Installing NVM for www-data"
        su - www-data -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
    fi
    
    # Create a .nvmrc file if not present
    if [ ! -f "${SITE_PATH}/.nvmrc" ] && [ -f "${SITE_PATH}/package.json" ]; then
        log "Creating .nvmrc file with LTS version"
        echo "lts/*" > "${SITE_PATH}/.nvmrc"
        chown www-data:www-data "${SITE_PATH}/.nvmrc"
    fi
    
    # Ensure NVM is properly sourced for www-data
    NVM_SOURCING='export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    
    # Generate a helper script for npm commands
    log "Creating npm helper script for www-data"
    cat > /var/www/npm-helper.sh << 'EOF'
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
exec "$@"
EOF
    chmod +x /var/www/npm-helper.sh
    chown www-data:www-data /var/www/npm-helper.sh
    
    # Add automatic NVM sourcing to www-data's .profile
    if ! grep -q "NVM_DIR" /var/www/.profile 2>/dev/null; then
        log "Adding NVM sourcing to www-data's .profile"
        cat >> /var/www/.profile << 'EOF'
# Automatically source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
EOF
        chown www-data:www-data /var/www/.profile
    fi
    
    # Install Node.js via NVM
    log "Installing Node.js via NVM"
    su - www-data -c "$NVM_SOURCING && cd ${SITE_PATH} && nvm install"
    
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
            
            # Automatically run migrations (no prompt)
            log "Running database migrations"
            su - www-data -c "cd ${SITE_PATH} && php artisan migrate --force" || log "WARNING: Migrations failed"
        else
            log "Not a Laravel application, skipping artisan commands"
        fi
    else
        log "No composer.json found, skipping Composer installation"
    fi
    
    # Install Node.js dependencies
    if [ -f "${SITE_PATH}/package.json" ]; then
        log "Installing Node.js dependencies"
        
        # Use the helper script to run npm commands
        su - www-data -c "cd ${SITE_PATH} && /var/www/npm-helper.sh npm ci" || {
            log "WARNING: NPM CI failed, trying npm install"
            su - www-data -c "cd ${SITE_PATH} && /var/www/npm-helper.sh npm install" || {
                log "WARNING: NPM install also failed"
            }
        }
        
        # COMPREHENSIVE BINARY PERMISSION FIXING
        if [ -d "${SITE_PATH}/node_modules" ]; then
            log "Setting proper permissions for all Node.js binaries and executables"
            
            # Fix overall node_modules permissions (avoid too restrictive permissions)
            chmod -R 755 "${SITE_PATH}/node_modules"
            
            # Method 1: Fix all .bin directories
            find "${SITE_PATH}/node_modules" -type d -name ".bin" -exec chmod -R 755 {} \; 2>/dev/null || true
            find "${SITE_PATH}/node_modules" -type d -name ".bin" -exec find {} -type f -exec chmod +x {} \; \; 2>/dev/null || true
            
            # Method 2: Fix all files in bin directories
            find "${SITE_PATH}/node_modules" -type d -name "bin" -exec chmod -R 755 {} \; 2>/dev/null || true
            find "${SITE_PATH}/node_modules" -type d -name "bin" -exec find {} -type f -exec chmod +x {} \; \; 2>/dev/null || true
            
            # Method 3: Explicitly find binary packages that often cause issues
            for PKG in esbuild vite rollup terser postcss parcel webpack babel tsc; do
                find "${SITE_PATH}/node_modules" -path "*/$PKG*/bin/*" -type f -exec chmod +x {} \; 2>/dev/null || true
            done
            
            # Method 4: Check for files with shebang and make them executable
            log "Finding and making executable all files with shebang..."
            find "${SITE_PATH}/node_modules" -type f -exec grep -l "^#!/" {} \; 2>/dev/null | xargs -r chmod +x
            
            # Special handling for esbuild which often causes issues
            if [ -d "${SITE_PATH}/node_modules/@esbuild" ]; then
                find "${SITE_PATH}/node_modules/@esbuild" -type f -path "*/bin/*" -exec chmod +x {} \; 2>/dev/null || true
                # Direct fix for common esbuild binary
                chmod +x "${SITE_PATH}/node_modules/@esbuild/linux-x64/bin/esbuild" 2>/dev/null || true
            fi
            
            # Fix ownership for everything in node_modules
            chown -R www-data:www-data "${SITE_PATH}/node_modules"
            
            log "Node.js binary permissions fix completed"
        fi
        
        # Build assets with better error handling and fixed permissions
        if grep -q "\"build\"" "${SITE_PATH}/package.json"; then
            log "Building assets"
            # Run the build
            su - www-data -c "cd ${SITE_PATH} && /var/www/npm-helper.sh npm run build" || {
                log "WARNING: Asset build failed, attempting fallback methods"
                
                # Try direct vite execution if it exists
                if [ -f "${SITE_PATH}/node_modules/.bin/vite" ]; then
                    log "Trying direct vite execution..."
                    su - www-data -c "cd ${SITE_PATH} && /var/www/npm-helper.sh ./node_modules/.bin/vite build" || {
                        log "WARNING: Direct vite execution also failed"
                    }
                fi
                
                # If using esbuild directly may also be an option
                if [ -f "${SITE_PATH}/node_modules/.bin/esbuild" ]; then
                    log "Checking esbuild binary permissions..."
                    chmod +x "${SITE_PATH}/node_modules/.bin/esbuild"
                    chmod +x "${SITE_PATH}/node_modules/@esbuild/linux-x64/bin/esbuild" 2>/dev/null || true
                fi
                
                # Try one more time with npm run build after fixing permissions
                log "Trying build again after fixing permissions..."
                su - www-data -c "cd ${SITE_PATH} && /var/www/npm-helper.sh npm run build" || {
                    log "WARNING: All build attempts failed"
                    log "You may need to manually build the assets after installation"
                    log "  1. SSH as www-data or your maintenance user"
                    log "  2. cd ${SITE_PATH}"
                    log "  3. Run: ./npm-run run build"
                }
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
    
    # Re-fix executable permissions for script files
    find ${SITE_PATH} -name "*.sh" -type f -exec chmod +x {} \;
    if [ -d "${SITE_PATH}/node_modules" ]; then
        find "${SITE_PATH}/node_modules" -path "*/bin/*" -type f -exec chmod +x {} \; 2>/dev/null || true
        find "${SITE_PATH}/node_modules/.bin" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi
    
    # Fix ownership
    chown -R www-data:www-data ${SITE_PATH}
    
    # Create an npm runner script in the site directory
    log "Creating npm runner script for the site"
    cat > "${SITE_PATH}/npm-run" << 'EOF'
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
npm "$@"
EOF
    chmod +x "${SITE_PATH}/npm-run"
    chown www-data:www-data "${SITE_PATH}/npm-run"
    
    log "You can now run npm commands using: cd ${SITE_PATH} && sudo -u www-data ./npm-run [command]"
fi

log "Application deployment completed"
exit 0 
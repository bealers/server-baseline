#!/bin/bash

# Laravel and Node.js configuration
# Assumes binaries.sh has been run first

# Use environment variables from setup.sh or set defaults if not provided
SITE_DOMAIN=${SITE_DOMAIN:-"example.com"}
REPO_URL=${REPO_URL:-"https://github.com/yourusername/yourrepo.git"}
SITE_PATH=/var/www/${SITE_DOMAIN}

# Remove set -e and add error handling
set +e
umask 022

echo "Setting up Laravel and Node.js for: $SITE_DOMAIN"

# Convert HTTPS to SSH URL if needed
if [[ "$REPO_URL" == https://github.com/* ]]; then
    REPO_URL="git@github.com:${REPO_URL#https://github.com/}"
fi

echo "Using repository URL: $REPO_URL"

# Ensure directory is owned by www-data
rm -rf ${SITE_PATH}
mkdir -p ${SITE_PATH}
chown www-data:www-data ${SITE_PATH}

# Clone repository as www-data
su - www-data -c "git clone ${REPO_URL} ${SITE_PATH}" || {
    echo "Warning: Failed to clone repository, continuing..."
}

# Install dependencies and build
cd ${SITE_PATH} || exit 1

# Set up Laravel environment first
su - www-data -c "cd ${SITE_PATH} && cp -n .env.example .env"

# Copy database credentials if they exist
if [ -f "/root/.${SITE_DOMAIN}_db_credentials" ]; then
    echo "Copying database credentials to .env..."
    cat "/root/.${SITE_DOMAIN}_db_credentials" > ${SITE_PATH}/.env.tmp
    cat ${SITE_PATH}/.env >> ${SITE_PATH}/.env.tmp
    mv ${SITE_PATH}/.env.tmp ${SITE_PATH}/.env
    chown www-data:www-data ${SITE_PATH}/.env
fi

# Install dependencies
su - www-data -c "cd ${SITE_PATH} && composer install --no-dev" || echo "Warning: Composer install failed"
su - www-data -c "cd ${SITE_PATH} && npm install && npm run build" || echo "Warning: NPM build failed"

# Laravel setup
su - www-data -c "cd ${SITE_PATH} && \
    php artisan key:generate && \
    php artisan storage:link && \
    php artisan optimize && \
    php artisan migrate --force" || echo "Warning: Laravel setup commands failed"

echo "Laravel and Node.js setup complete!"

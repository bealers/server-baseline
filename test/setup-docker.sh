#!/bin/bash

# This script creates a Docker container for testing server setup

set -e

# Configuration
CONTAINER_NAME="server-test"
TEST_DOMAIN="bealers.test"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if the container already exists and remove it
if docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Removing existing container..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

# Create a Docker network for testing
echo "Creating Docker network..."
docker network create server-test-network 2>/dev/null || true

echo "Creating Docker container..."
docker run --name $CONTAINER_NAME \
    --network server-test-network \
    -d \
    --privileged \
    -v "$(pwd):/server-build" \
    -p 8080:80 \
    -p 8443:443 \
    ubuntu:22.04 \
    /bin/bash -c "sleep infinity"

# Check if container is running
if ! docker ps | grep -q $CONTAINER_NAME; then
    echo "Error: Container failed to start. Please check Docker logs."
    exit 1
fi

# Wait for container to be ready
echo "Waiting for container to be ready..."
sleep 5

# Install basic packages
echo "Installing basic packages..."
docker exec $CONTAINER_NAME bash -c "apt-get update && apt-get install -y sudo curl"

# Add a fake domain to /etc/hosts for testing
echo "Adding test domain to /etc/hosts..."
docker exec $CONTAINER_NAME bash -c "echo '127.0.0.1 $TEST_DOMAIN' >> /etc/hosts"

# Create necessary directories
echo "Creating necessary directories..."
docker exec $CONTAINER_NAME bash -c "mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled"

# Prepare for service management
echo "Setting up service management..."
docker exec $CONTAINER_NAME bash -c "apt-get install -y init systemd-sysv"

# Create service management script
echo "Creating service management script..."
docker exec $CONTAINER_NAME bash -c "cat > /usr/local/bin/service-manager << 'EOF'
#!/bin/bash
# Simple service management script for Docker testing

SERVICE=\$1
ACTION=\$2

case \$ACTION in
    start)
        echo \"Starting \$SERVICE...\"
        if [ \"\$SERVICE\" = \"nginx\" ]; then
            nginx
        elif [ \"\$SERVICE\" = \"mysql\" ]; then
            mysqld_safe &
        elif [[ \"\$SERVICE\" == php*-fpm ]]; then
            /usr/sbin/php-fpm\${SERVICE#php} --nodaemonize &
        else
            echo \"Unknown service: \$SERVICE\"
            exit 1
        fi
        ;;
    stop)
        echo \"Stopping \$SERVICE...\"
        if [ \"\$SERVICE\" = \"nginx\" ]; then
            nginx -s stop
        elif [ \"\$SERVICE\" = \"mysql\" ]; then
            mysqladmin shutdown
        elif [[ \"\$SERVICE\" == php*-fpm ]]; then
            pkill php-fpm
        else
            echo \"Unknown service: \$SERVICE\"
            exit 1
        fi
        ;;
    restart)
        \$0 \$SERVICE stop
        sleep 1
        \$0 \$SERVICE start
        ;;
    status)
        if [ \"\$SERVICE\" = \"nginx\" ]; then
            if pgrep -x nginx > /dev/null; then
                echo \"nginx is running\"
            else
                echo \"nginx is not running\"
                exit 1
            fi
        elif [ \"\$SERVICE\" = \"mysql\" ]; then
            if pgrep -x mysqld > /dev/null; then
                echo \"mysql is running\"
            else
                echo \"mysql is not running\"
                exit 1
            fi
        elif [[ \"\$SERVICE\" == php*-fpm ]]; then
            if pgrep -x php-fpm > /dev/null; then
                echo \"\$SERVICE is running\"
            else
                echo \"\$SERVICE is not running\"
                exit 1
            fi
        else
            echo \"Unknown service: \$SERVICE\"
            exit 1
        fi
        ;;
    *)
        echo \"Usage: \$0 {nginx|mysql|php*-fpm} {start|stop|restart|status}\"
        exit 1
        ;;
esac
EOF"

# Make the service manager executable
docker exec $CONTAINER_NAME bash -c "chmod +x /usr/local/bin/service-manager"

# Create systemctl replacement
echo "Creating systemctl replacement..."
docker exec $CONTAINER_NAME bash -c "cat > /usr/bin/systemctl << 'EOF'
#!/bin/bash
# Simple systemctl replacement for Docker testing

if [ \"\$1\" = \"restart\" ]; then
    /usr/local/bin/service-manager \$2 restart
elif [ \"\$1\" = \"start\" ]; then
    /usr/local/bin/service-manager \$2 start
elif [ \"\$1\" = \"stop\" ]; then
    /usr/local/bin/service-manager \$2 stop
elif [ \"\$1\" = \"status\" ]; then
    /usr/local/bin/service-manager \$2 status
else
    echo \"Unsupported systemctl command: \$1\"
    exit 0  # Don't fail to allow scripts to continue
fi
EOF"

# Make the systemctl replacement executable
docker exec $CONTAINER_NAME bash -c "chmod +x /usr/bin/systemctl"

# Set up the SSL script
echo "Setting up SSL scripts..."
docker exec $CONTAINER_NAME bash -c "cp /server-build/app/02-letsencrypt-local.sh /server-build/app/02-letsencrypt-ssl.sh"
docker exec $CONTAINER_NAME bash -c "chmod +x /server-build/app/*.sh"

echo ""
echo "Docker container is ready for testing!"
echo ""
echo "To access the container and run setup:"
echo "docker exec -it $CONTAINER_NAME bash"
echo ""
echo "Once inside the container, run:"
echo "cd /server-build && bash setup.sh"
echo ""
echo "After setup, you can access the web server at:"
echo "- HTTP: http://localhost:8080"
echo "- HTTPS: https://localhost:8443 (will show certificate warning)"
echo ""
echo "To stop and remove the container when done:"
echo "docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"

# Enter the container
echo ""
echo "Entering container. Type 'exit' to leave the container when done."
echo ""
docker exec -it $CONTAINER_NAME bash -c "cd /server-build && bash" || {
    echo "Failed to enter container. You can try manually with:"
    echo "docker exec -it $CONTAINER_NAME bash"
} 
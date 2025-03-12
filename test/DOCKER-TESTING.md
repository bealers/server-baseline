# Docker Testing

This document explains how to test the server setup scripts using Docker before deploying them to a production server.

## Quick Start

To test the server setup in Docker:

```bash
./setup-docker.sh
```

This will:
1. Create a Docker container with systemd support
2. Set up the environment for testing
3. Open a shell in the container where you can run the setup scripts

## What's Included

The Docker testing environment includes:

- Ubuntu 22.04 container with systemd support
- Ports 8080 (HTTP) and 8443 (HTTPS) mapped to your local machine
- A test domain (`bealers.test`) configured in the container
- The local SSL script (`02-letsencrypt-local.sh`) that uses self-signed certificates

## Testing Process

Once inside the container:

1. Run the setup script:
   ```bash
   cd /server-build && bash setup.sh
   ```

2. Follow the prompts to configure your test environment (press Enter to accept defaults)

3. After setup, you can access the web server at:
   - HTTP: http://localhost:8080
   - HTTPS: https://localhost:8443 (will show certificate warning)

## Useful Commands

### Accessing the container (if you've exited)

```bash
docker exec -it server-test bash
```

### Checking Nginx configuration

```bash
nginx -t
```

### Viewing Nginx error logs

```bash
cat /var/log/nginx/error.log
```

### Checking systemd services

```bash
systemctl status nginx
systemctl status mysql
systemctl status php*-fpm
```

### Stopping and removing the container when done

```bash
docker stop server-test && docker rm server-test
```

## Troubleshooting

### If the script stops unexpectedly

Check if the container is still running:

```bash
docker ps -a | grep server-test
```

If the container exists but is not running (status "Exited"), you can start it:

```bash
docker start server-test
docker exec -it server-test bash
```

### If you can't access the web server

1. Check if Nginx is running in the container:
   ```bash
   systemctl status nginx
   ```

2. Check if the ports are properly mapped:
   ```bash
   docker port server-test
   ```

### If the SSL setup fails

1. Check if the SSL directories exist:
   ```bash
   ls -la /etc/letsencrypt/live/
   ```

2. Try running the SSL script manually:
   ```bash
   cd /server-build && bash app/02-letsencrypt-local.sh
   ```

## Notes

- The SSL certificate is self-signed, so browsers will show a security warning when accessing via HTTPS
- The Docker container uses systemd, just like a real Ubuntu server
- Database credentials are saved to `/root/.bealers_test_db_credentials` in the container 
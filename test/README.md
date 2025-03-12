# Testing Scripts

ALL A BIT BROKEN as `systemd` a problem with docker apparently

## Contents

- `setup-docker.sh` - Script to set up a Docker container for testing the server setup
- `02-letsencrypt-local.sh` - Script to set up self-signed SSL certificates for local testing
- `DOCKER-TESTING.md` - Documentation for testing with Docker

## Usage

To test the server setup in Docker:

```bash
cd /path/to/.server-build/test
./setup-docker.sh
```

This will create a Docker container where you can test the server setup scripts without affecting your production environment.

## Local SSL Testing

If you need to test with SSL locally:

```bash
cd /path/to/.server-build/test
./02-letsencrypt-local.sh
```

This will generate self-signed SSL certificates for local testing. 
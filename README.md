# Default Server Build

Opinionated Laravel/Node web server setup scripts. Bash only, zero dependencies.

## What's Included

- A modular, step-based server setup framework that can resume after failures
- SSH key-based login for the maintenance user (with sudo access)
- LEMP stack (Linux, Nginx, MySQL/PostgreSQL/SQLite, PHP)
- Laravel and Node.js setup with proper dependency management
- Let's Encrypt SSL certificates
 Security hardening with firewall and fail2ban
- Dedicated deploy key for secure repository access

## Scripts

- `setup.sh` - Main control script that manages configuration and step execution
- `steps/01-system-basics.sh` - Sets up users, SSH, and basic system configuration
- `steps/02-security-baseline.sh` - Configures firewall and basic security
- `steps/03-web-stack.sh` - Installs and configures Nginx, PHP, and database
- `steps/04-application-deploy.sh` - Deploys application code and dependencies
- `steps/05-advanced-hardening.sh` - Configures advanced security measures

Each step is idempotent (can be run multiple times safely) and tracks completion status.

## Usage

1) Commission a new server, the latest [Ubuntu LTS](https://releases.ubuntu.com/) is recommended.

2) Connect to the server as root.

```bash
ssh root@server.ip -i ~/.ssh/private-key
```

3) Clone this repo and run the setup script.
```bash
git clone https://github.com/bealers/server-baseline.git
cd server-baseline && chmod +x setup.sh steps/*.sh
./setup.sh
```

4) Follow the prompts to configure your server with your domain, email, PHP version, and other settings.

The setup script provides several options:

```bash
# Run all steps (skipping completed ones)
./setup.sh

# Run a specific step
./setup.sh 03-web-stack

# Reconfigure settings
./setup.sh --reconfigure

# Reset a specific step to run it again
./setup.sh --reset-step 04-application-deploy

# Reset all steps and start fresh
./setup.sh --reset

# Start from a specific step onwards
./setup.sh --run-from 03-web-stack

# List all available steps
./setup.sh --list-steps

# Show help information
./setup.sh --help
```

## Security Features

The security features include:

- Firewall configuration with UFW
- SSH hardening to prevent brute force attacks
- Fail2ban for automatic IP banning of malicious activity
- Dedicated deploy key for secure repository access
- Advanced intrusion detection rules for Nginx
- Log monitoring and analysis

See the [fail2ban documentation](./docs/fail2ban.md) for more information on managing security.

## Repository Access

For private repositories, the setup uses a dedicated deploy key for the www-data user:

1. A unique SSH key is generated for the www-data user during setup
2. The public key is displayed during installation
3. Add this key to your repository's deploy keys in GitHub/GitLab
4. The application deployment will use this key to securely access your repository

This approach follows the principle of least privilege, ensuring www-data only has access to the specific repository it needs.

## Domain Change

If you need to change the domain after initial setup:

1. Reconfigure the setup with the new domain:
```bash
./setup.sh --reconfigure
```

2. Run the web stack step to update Nginx configuration:
```bash
./setup.sh 03-web-stack
```

3. Run the application deploy step to update the application:
```bash
./setup.sh 04-application-deploy
```

## Assumptions

You are using a Digital Ocean droplet or similar VPS provider.

Your server provisioning needs to leave a public key (that you have the matching private key for) in `/root/.ssh/authorized_keys`.

## Security Notes

For additional security, the following measures are implemented:

- Passwordless SSH authentication only
- Firewall limiting access to ports 22, 80, and 443
- Root login disabled via SSH
- Regular security updates via unattended-upgrades
- Comprehensive fail2ban rules to detect and block various attacks


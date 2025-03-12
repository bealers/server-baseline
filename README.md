# Default Sever Build

Scripts for setting up a production server with LEMP stack (Linux, Nginx, MySQL/PostgreSQL/SQLite, PHP), Let's Encrypt SSL, and Laravel/Node.js.

## What's Included

- An ssh-key based login for `$MAINTENANCE_USER` (who has sudo access)
- `ufw` firewall running with everything closed except ports 22 (SSH), 80 (HTTP), and 443 (HTTPS)
- `ntp` time server running and locale set to UK defaults
- LEMP stack (Linux, Nginx, MySQL/PostgreSQL/SQLite, PHP)
- Let's Encrypt SSL certificates
- Laravel and Node.js setup

## Production Scripts

- `setup.sh` - Main setup script
- `app/01-lemp.sh` - Sets up Nginx, PHP, and database
- `app/02-letsencrypt-ssl.sh` - Sets up Let's Encrypt SSL certificates
- `app/03-laravel-node.sh` - Sets up Laravel and Node.js

## Usage

1) Commission a new droplet, the latest [Ubuntu LTS](https://releases.ubuntu.com/) is a good choice. Make sure to select your ssh key when creating the droplet.

2) Connect to the server.

```bash
ssh root@droplet.ip -i ~/.ssh/private-key
```

3) Clone this repo and run the script.
```bash
git clone https://github.com/bealers/server-baseline.git
cd server-baseline && chmod +x setup.sh app/*.sh
./setup.sh
```

4) Follow the prompts to configure your server with your domain, email, PHP version, and other settings.

5) Open a new terminal and login as `$MAINTENANCE_USER`

```bash
# e.g.
ssh bealers@droplet-ip -i ~/.ssh/private-key
```

6) If step 5 works, close your root terminal and don't use root again.

## Assumptions

You are using a Digital Ocean droplet.

Which is to say that your server provisioning needs to leave a public key (that you have the matching private key for) in `/root/.ssh/authorized_keys`.

This is how Digital Ocean currently does it if you select your ssh key when creating a droplet, but you should check for your provider.

## Security Notes

For additional security, consider uncommenting and adjusting the SSH hardening section in the setup script:

```bash
# WARNING: This will very likely break default Digital Ocean access methods
#
# echo "PermitRootLogin no" >> /etc/ssh/sshd_config
# echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
# systemctl restart sshd
# passwd -l root  # Lock root account
```

## TODO

Hardening:
- passwordless entry only
- remove root sshkey


# Baseline Ubuntu Server Install

- Provides an ssh-key based login for `$USER`
- Firewalled with everything closed except port 22
- `ntp` time server installed
- Locale set to UK defaults

## Usage
```bash
git clone https://github.com/bealers/server-baseline.git
cd server-baseline && chmod +x setup.sh
./setup.sh
```

## Assumptions

TL;DR you are using a Digital Ocean droplet.

Your server provisioning needs to leave a public key that you have the private key for in `/root/.ssh/authorized_keys`. This is what Digital Ocean currently does, but you should check for your provider.

# Baseline Ubuntu Server Install

Provides
- an ssh-key based login for `$MAINTENANCE_USER` (who has sudo access)
- `ufw` firewall running with everything closed except port 22 for ssh
- `ntp` time server running and locale set to UK defaults, so the server matches my timezone

## Usage

1) Commission a new droplet, the latest [Ubuntu LTS](https://releases.ubuntu.com/) is a good choice. Make sure to select your ssh key when creating the droplet.

2) Connect to the server.

```bash
ssh root@droplet.ip -i ~/.ssh/private-key
```

3) Clone this repo and run the script.
```bash
git clone https://github.com/bealers/server-baseline.git
cd server-baseline && chmod +x setup.sh
./setup.sh
```

4) Open a new terminal and login as `$MAINTENANCE_USER`

```bash
# e.g.
ssh bealers@droplet-ip -i ~/.ssh/private-key
```

5) If 4. works, close your root terminal and don't use root again.

## Assumptions

TL;DR you are using a Digital Ocean droplet.

Which is to say that your server provisioning needs to leave a public key (that you have the matching private key for) in `/root/.ssh/authorized_keys`.

This is how Digital Ocean currently does it if you select your ssh key when creating a droplet, but you should check for your provider.

## TODO

Hardening:
- passwordless only
- remove root sshkey

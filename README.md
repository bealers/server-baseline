# Baseline Ubuntu Server install

- Provides an ssh-key based login for `$USER` (assuming the server provisioning left a pub you control in `/root/.ssh/authorized_keys`)
- Firewalled, port 22 open
- Time server and locale set to UK defaults
- no apps installed

```bash
git clone https://github.com/bealers/new-server.git
cd server-baseline && chmod +x setup.sh
./setup.sh
```

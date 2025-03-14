#!/bin/bash

echo "Installing and configuring fail2ban..."
apt-get install -y fail2ban

# Basic jail config
cat > /etc/fail2ban/jail.d/defaults.conf << 'CONF'
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-scan]
enabled = true
filter = nginx-scan
action = iptables-multiport[name=nginx-scan, port="http,https"]
logpath = /var/log/nginx/access.log
findtime = 60
bantime = 86400
maxretry = 3
CONF

# Nginx scan filter
cat > /etc/fail2ban/filter.d/nginx-scan.conf << 'CONF'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*(\.env|\.git|wp-login|wp-admin|\.php|\.asp|\.jar|\.json|\.yml|\.csv|\.txt|\.bak|\.sql|\.zip|\.tar\.gz|/cp/).* HTTP/1\..*
            ^<HOST> .* "(GET|POST|HEAD) .*(config|admin|setup|install|backup|dump).* HTTP/1\..*
ignoreregex =
CONF

systemctl enable fail2ban
systemctl restart fail2ban

echo "Fail2ban has been configured"
echo "Security hardening complete"

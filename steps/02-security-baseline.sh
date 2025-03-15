#!/bin/bash

# Step 2: Security Baseline
# - Firewall
# - SSH hardening
# - Basic security packages

mkdir -p /var/log/server-setup
LOGFILE="/var/log/server-setup/02-security-baseline.log"

# basic logger
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting security baseline setup"

log "Installing security packages"
apt-get update -qq
apt-get install -y -qq \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges

log "Configuring firewall"
# Check if UFW is already active with our rules
if ! ufw status | grep -q "22/tcp.*ALLOW"; then
    log "Setting up UFW rules"
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall non-interactively
    echo "y" | ufw enable || log "UFW was already enabled"
else
    log "UFW is already configured with required rules"
fi

log "Configuring unattended-upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

log "Configuring SSH hardening"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# Security hardening for SSH
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 5
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# Restart SSH service (but make sure we don't lock ourselves out)
log "Testing new SSH configuration"
sshd -t
if [ $? -eq 0 ]; then
    log "SSH configuration is valid, restarting service"
    systemctl restart sshd
else
    log "ERROR: SSH configuration test failed, not restarting SSH"
    log "Please check /etc/ssh/sshd_config.d/hardening.conf and fix any issues"
    # Don't exit with error to allow the script to continue
fi

log "Configuring basic fail2ban"
mkdir -p /etc/fail2ban/jail.d

cat > /etc/fail2ban/jail.d/ssh.conf << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl restart fail2ban

log "Checking fail2ban status"
fail2ban-client status

log "Security baseline verification:"
log "Firewall status:"
ufw status
log "SSH config verification:"
sshd -T | grep -E 'permitrootlogin|passwordauthentication|permitemptypasswords'
log "Fail2ban status:"
fail2ban-client status sshd

log "Security baseline setup completed successfully"
exit 0 
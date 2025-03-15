#!/bin/bash

# Step 5: Advanced Hardening
# - Advanced fail2ban configuration
# - Intrusion detection
# - Log monitoring

# Create log directory
mkdir -p /var/log/server-setup
LOGFILE="/var/log/server-setup/05-advanced-hardening.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting advanced security hardening"

# Install additional security packages
log "Installing additional security packages"
apt-get update -qq

# Pre-configure iptables-persistent to avoid prompts
log "Pre-configuring iptables-persistent"
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

# Install packages
log "Installing security packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    logwatch \
    rkhunter \
    lynis \
    iptables-persistent

# Advanced fail2ban configuration
log "Configuring advanced fail2ban rules"

# Nginx scan detection
cat > /etc/fail2ban/filter.d/nginx-scan.conf << 'EOF'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*(\.env|\.git|wp-login|wp-admin|\.php|\.asp|\.jar|\.json|\.yml|\.csv|\.txt|\.bak|\.sql|\.zip|\.tar\.gz|/cp/).* HTTP/1\..*
            ^<HOST> .* "(GET|POST|HEAD) .*(config|admin|setup|install|backup|dump).* HTTP/1\..*
ignoreregex =
EOF

# Configure nginx-scan jail
cat > /etc/fail2ban/jail.d/nginx-scan.conf << 'EOF'
[nginx-scan]
enabled = true
filter = nginx-scan
action = iptables-multiport[name=nginx-scan, port="http,https"]
logpath = /var/log/nginx/access.log
findtime = 60
bantime = 86400
maxretry = 3
EOF

# Additional protection for PHP
cat > /etc/fail2ban/jail.d/php-url-fopen.conf << 'EOF'
[php-url-fopen]
enabled = true
filter = php-url-fopen
action = iptables-multiport[name=php-url-fopen, port="http,https"]
logpath = /var/log/nginx/access.log
findtime = 60
bantime = 86400
maxretry = 2
EOF

cat > /etc/fail2ban/filter.d/php-url-fopen.conf << 'EOF'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*\?(?:file|path|url|src|source|data|target)=(?:https?|ftp|php|data).*
ignoreregex =
EOF

# Jail for excessive 404 errors (indicating scanning)
cat > /etc/fail2ban/jail.d/nginx-404.conf << 'EOF'
[nginx-404]
enabled = true
filter = nginx-404
action = iptables-multiport[name=nginx-404, port="http,https"]
logpath = /var/log/nginx/access.log
findtime = 300
bantime = 43200
maxretry = 10
EOF

cat > /etc/fail2ban/filter.d/nginx-404.conf << 'EOF'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .* HTTP/1\.[01]" 404 .*$
ignoreregex =
EOF

# Restart fail2ban to apply changes
log "Restarting fail2ban with new configuration"
systemctl restart fail2ban

# Set up disk monitoring
log "Setting up disk space monitoring"
cat > /etc/cron.daily/disk-space-check << 'EOF'
#!/bin/bash
THRESHOLD=85
USAGE=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')
if [ $USAGE -gt $THRESHOLD ]; then
    echo "Disk space alert: $USAGE% used on root filesystem" | mail -s "Disk Space Alert" root
fi
EOF
chmod +x /etc/cron.daily/disk-space-check

# Configure logwatch for daily log summaries
log "Configuring logwatch for daily log summaries"
if [ -f /etc/cron.daily/00logwatch ]; then
    cat > /etc/logwatch/conf/logwatch.conf << 'EOF'
LogDir = /var/log
TmpDir = /var/cache/logwatch
MailTo = root
MailFrom = Logwatch
Detail = Medium
Service = All
Range = yesterday
Format = text
EOF
fi

# Final checks
log "Running final security checks"

# Check fail2ban status
fail2ban-client status

# Run a quick security audit with Lynis
log "Running Lynis security audit"
lynis audit system --quick --no-colors | tee -a "$LOGFILE"

log "Advanced security hardening completed"
exit 0 
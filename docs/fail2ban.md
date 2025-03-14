# Fail2Ban Security Guide

## Quick Checks

### Fail2ban Status
```bash
# Check all jails
fail2ban-client status

# Check specific jail
fail2ban-client status nginx-scan

# Manually ban IP
fail2ban-client set nginx-scan banip <IP>

# Unban IP
fail2ban-client set nginx-scan unbanip <IP>
```

## Connection Monitoring
```bash
# Current connections
netstat -tunap | grep ESTABLISHED

# Top IP addresses in last 1000 requests
tail -n 1000 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr

# Live access log with IP counts
tail -f /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c
```

## Security Best Practices

1. Keep system updated: `apt update && apt upgrade`
2. Check auth logs: `tail -f /var/log/auth.log`
3. Monitor failed login attempts: `grep "Failed password" /var/log/auth.log`
4. Check running services: `systemctl list-units --type=service --state=running`
5. Monitor system resources: `htop`

## Common Attack Patterns

- Multiple failed SSH attempts
- Probing for common CMS paths (wp-admin, etc)
- Attempts to access .env or configuration files
- SQL injection attempts in URL parameters
- Scanning for known vulnerabilities 
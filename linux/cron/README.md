#!/bin/bash
################################################################################
# CRON JOBS FOR LINUX AUTOMATION
# DevOps Automation Toolkit
#
# Lightweight Bash scripts designed for scheduled execution via cron.
# All scripts log to syslog/files with minimal stdout output.
#
# SCRIPTS
# ───────
# 1. backup.sh         - Backup directories with timestamp
# 2. log-rotate.sh     - Archive and compress old logs
# 3. health-check.sh   - Server/service health checks
#
################################################################################

## OVERVIEW

Cron scripts in this directory are designed for **automated, scheduled execution**:

- **Minimal output**: No verbose stdout (suitable for quiet cron execution)
- **Robust logging**: All operations logged to syslog or dedicated log files
- **Exit codes**: Proper status codes for success/failure (0 = success, 1 = failure)
- **Error handling**: Graceful failures with clear error messages

---

## SCRIPT DESCRIPTIONS

### 1. backup.sh
**Create timestamped backups of directories**

**Signature**:
```bash
./backup.sh <source_directory> [backup_directory]
```

**Examples**:
```bash
# Backup to default /backup directory
./backup.sh /home/user

# Backup to custom location
./backup.sh /var/www /mnt/backups

# Backup database directory
./backup.sh /var/lib/mysql /backup/databases
```

**Output**:
```
Backup created: /backup/user_2026-03-25_14-32-15.tar.gz (245MB)
```

**Log Output** (syslog):
```
backup.sh: SUCCESS: /home/user backed up to /backup/user_2026-03-25_14-32-15.tar.gz (size: 245MB)
```

**Crontab Entries**:
```bash
# Daily backup at 2 AM
0 2 * * * /opt/scripts/backup.sh /home/user /backup >/dev/null 2>&1

# Backup every Sunday at 3 AM
0 3 * * 0 /opt/scripts/backup.sh /var/www /backup >/dev/null 2>&1

# Multiple backups (create multiple cron entries)
0 2 * * * /opt/scripts/backup.sh /home/user /backup >/dev/null 2>&1
0 3 * * * /opt/scripts/backup.sh /etc /backup >/dev/null 2>&1
0 4 * * * /opt/scripts/backup.sh /var/lib/mysql /backup/db >/dev/null 2>&1

# Every 6 hours for critical data
0 */6 * * * /opt/scripts/backup.sh /data/critical /backup >/dev/null 2>&1
```

---

### 2. log-rotate.sh
**Archive and compress old log files**

**Signature**:
```bash
./log-rotate.sh [days]
```

**Default**: Archives logs older than 7 days

**Examples**:
```bash
# Archive logs older than 7 days (default)
./log-rotate.sh

# Archive logs older than 14 days
./log-rotate.sh 14

# Aggressive: archive logs older than 3 days
./log-rotate.sh 3
```

**Log Output** (syslog):
```
log-rotate.sh: Starting log rotation (archiving logs >7 days old)
log-rotate.sh: Archived: /var/log/syslog -> /var/log/archive/syslog_20260325_143215.tar.gz (500MB)
log-rotate.sh: Log rotation completed: 3 files archived
```

**Monitored Directory**: `/var/log/archive/`

**Crontab Entries**:
```bash
# Daily log rotation at 1 AM
0 1 * * * /opt/scripts/log-rotate.sh 7 >/dev/null 2>&1

# Weekly aggressive cleanup
0 2 * * 0 /opt/scripts/log-rotate.sh 30 >/dev/null 2>&1

# Every 3 days for aggressive space management
0 3 */3 * * /opt/scripts/log-rotate.sh 5 >/dev/null 2>&1

# Database maintenance: rotate old logs daily
0 1 * * * /opt/scripts/log-rotate.sh 3 >/dev/null 2>&1
```

**Maintenance**:
```bash
# Check archive directory size
du -sh /var/log/archive/

# Remove very old archives (older than 90 days)
find /var/log/archive -type f -mtime +90 -delete

# View recent rotations
tail -20 /var/log/syslog | grep log-rotate.sh
```

---

### 3. health-check.sh
**Check server/service availability via ping**

**Signature**:
```bash
./health-check.sh [hostname] [--verbose]
```

**Default Host**: google.com (can be overridden)

**Examples**:
```bash
# Check default (google.com)
./health-check.sh

# Check specific host
./health-check.sh example.com

# Check with verbose output (debugging)
./health-check.sh api.myapp.com --verbose

# Check specific port/service (via /etc/hosts)
./health-check.sh db.internal
```

**Log Output** (to `/var/log/health-check.log`):
```
[2026-03-25 14:32:15] SUCCESS: google.com is reachable (response time: 23.5ms)
[2026-03-25 14:33:20] FAILURE: api.example.com is unreachable
[2026-03-25 14:34:10] SUCCESS: db.internal is reachable (response time: 12.3ms)
```

**Exit Codes**:
- `0` = Host reachable (success)
- `1` = Host unreachable (failure)

**Crontab Entries**:
```bash
# Check externally every 5 minutes
*/5 * * * * /opt/scripts/health-check.sh google.com >/dev/null 2>&1

# Check API every hour
0 * * * * /opt/scripts/health-check.sh api.example.com >/dev/null 2>&1

# Monitor multiple services (separate entries)
0 * * * * /opt/scripts/health-check.sh api.example.com >/dev/null 2>&1
0 * * * * /opt/scripts/health-check.sh db.example.com >/dev/null 2>&1
0 * * * * /opt/scripts/health-check.sh cache.example.com >/dev/null 2>&1

# Check during business hours only
0 8-17 * * 1-5 /opt/scripts/health-check.sh critical-app.local >/dev/null 2>&1

# More frequent monitoring with verbose logging for debugging
*/2 * * * * VERBOSE=1 /opt/scripts/health-check.sh api.prod.local >/dev/null 2>&1
```

**Monitoring**:
```bash
# Live monitoring
tail -f /var/log/health-check.log

# Count total checks
wc -l /var/log/health-check.log

# Count successes
grep SUCCESS /var/log/health-check.log | wc -l

# Count failures
grep FAILURE /var/log/health-check.log | wc -l

# Find last failure
grep FAILURE /var/log/health-check.log | tail -1

# Time-based analysis (last 24 hours)
grep "$(date -d '24 hours ago' '+%Y-%m-%d')" /var/log/health-check.log
```

**Alert Example** (detect consecutive failures):
```bash
#!/bin/bash
# Alert if 3 consecutive failures detected
failure_count=$(grep FAILURE /var/log/health-check.log | tail -3 | wc -l)
if [[ $failure_count -eq 3 ]]; then
    echo "ALERT: Health check failing!" | mail -s "Service Down" admin@example.com
fi
```

---

## SETUP INSTRUCTIONS

### Step 1: Prepare Scripts
```bash
# Navigate to cron directory
cd linux/cron/

# Verify executable permissions
ls -l *.sh  # Should show -rwxr-xr-x

# Make executable if needed
chmod +x *.sh
```

### Step 2: Test Manually
```bash
# Test backup script
./backup.sh /home/user /tmp/test-backup
# Should output: Backup created: /tmp/test-backup/user_YYYY-MM-DD_HH-MM-SS.tar.gz

# Test log rotation
./log-rotate.sh 30  # Archives logs older than 30 days

# Test health check
./health-check.sh google.com
# Should output: Backup created: ... (on success)
```

### Step 3: Add to Crontab
```bash
# Edit crontab
crontab -e

# Add entries (examples below)
# Backup daily
0 2 * * * /opt/scripts/backup.sh /home/user /backup >/dev/null 2>&1

# Rotate logs daily
0 1 * * * /opt/scripts/log-rotate.sh 7 >/dev/null 2>&1

# Health check every hour
0 * * * * /opt/scripts/health-check.sh example.com >/dev/null 2>&1

# Save and exit
```

### Step 4: Verify Cron Jobs
```bash
# List your cron jobs
crontab -l

# Check cron logs
tail -f /var/log/syslog | grep CRON

# Or use journalctl (systemd systems)
journalctl -u cron -f
```

---

## MONITORING & MAINTENANCE

### View Script Logs
```bash
# Health checks
tail -f /var/log/health-check.log

# Backup operations (syslog)
grep backup.sh /var/log/syslog

# Log rotation operations (syslog)
grep log-rotate.sh /var/log/syslog

# Combined view
tail -f /var/log/syslog | grep -E 'backup|log-rotate|health-check'
```

### Clean Old Archives
```bash
# Remove archives older than 90 days
find /var/log/archive -type f -mtime +90 -delete

# Remove backups older than 30 days
find /backup -type f -mtime +30 -delete

# Check disk usage
du -sh /backup /var/log/archive
```

### Troubleshoot Failed Cron Jobs
```bash
# Check if cron is running
systemctl status cron  # or: sudo service cron status

# View all cron activity
tail -100 /var/log/syslog | grep CRON

# Test script manually
cd /opt/scripts
./backup.sh /home/user /backup

# Enable verbose debugging
VERBOSE=1 ./health-check.sh example.com

# Check script permissions
ls -l *.sh  # Must be -rwxr-xr-x or executable
```

---

## CRON TIMING REFERENCE

**Common Patterns**:
```cron
# Every minute
* * * * * command

# Every 5 minutes
*/5 * * * * command

# Every hour (at :00)
0 * * * * command

# Every day at 2 AM
0 2 * * * command

# Every Sunday at 3 AM
0 3 * * 0 command

# Weekdays only (Mon-Fri)
0 9 * * 1-5 command

# Twice a day (2 AM and 2 PM)
0 2,14 * * * command

# Every 6 hours
0 */6 * * * command

# Every other day
0 2 */2 * * command
```

**Format**: `minute hour day month weekday command`

**Testing Cron Expressions**: https://crontab.guru

---

## COMMON SCENARIOS

### Daily Backup Strategy
```cron
# Incremental backup every 6 hours
0 */6 * * * /opt/scripts/backup.sh /data /backup >/dev/null 2>&1

# Full backup daily at 2 AM
0 2 * * * /opt/scripts/backup.sh /home /backup/full >/dev/null 2>&1

# Weekly archive
0 3 * * 0 tar -czf /archive/weekly_$(date +'%Y-%m-%d').tar.gz /backup >/dev/null 2>&1
```

### Log Management
```cron
# Rotate logs daily
0 1 * * * /opt/scripts/log-rotate.sh 7 >/dev/null 2>&1

# Clean very old archives monthly
0 4 1 * * find /var/log/archive -type f -mtime +90 -delete >/dev/null 2>&1
```

### Health Monitoring
```cron
# Check critical services every 5 minutes
*/5 * * * * /opt/scripts/health-check.sh api.prod >/dev/null 2>&1
*/5 * * * * /opt/scripts/health-check.sh db.prod >/dev/null 2>&1

# Business hours only alerts
*/15 * * * 1-5 /opt/scripts/health-check.sh critical >/dev/null 2>&1

# Hourly summary report
0 * * * * mail -s "Health Check Report" ops@example.com < /var/log/health-check.log
```

---

## BEST PRACTICES

✓ **Always test manually before adding to cron**
✓ **Redirect output to /dev/null in crontab** (scripts log to files/syslog)
✓ **Use absolute paths** in cron job commands
✓ **Monitor log files regularly** to catch issues early
✓ **Run backups during low-traffic periods** (e.g., 2 AM)
✓ **Keep log files/archives on separate storage** if possible
✓ **Test recovery procedures** regularly
✓ **Document your cron jobs** with comments

---

## TROUBLESHOOTING

| Problem | Solution |
|---------|----------|
| Cron job not running | Check `crontab -l`, verify script path, check cron logs |
| Permission denied | Ensure scripts have execute permission: `chmod +x` |
| Script runs manually but not in cron | Use absolute paths, check environment variables |
| No output in logs | Check log file permissions, verify syslog is running |
| Cron job fails silently | Add error output: `2>&1 >> /tmp/cron-errors.log` |

---

## SUPPORT & DOCUMENTATION

**Main README**: See `../README.md` for complete documentation
**Script Help**: Each script has `--help` option
```bash
./backup.sh --help
./log-rotate.sh --help
./health-check.sh --help
```

---

## VERSION

**Version**: 1.0.0  
**Created**: 2026-03-25  
**Author**: DevOps Team

---

END OF CRON DOCUMENTATION

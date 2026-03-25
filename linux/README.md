#!/bin/bash
################################################################################
# LINUX SYSTEM ADMINISTRATION SCRIPTS
# DevOps Automation Toolkit
#
# A collection of production-grade Bash scripts for system administration,
# user management, log analysis, disk cleanup, and process monitoring.
#
# DIRECTORY STRUCTURE
# ───────────────────
# linux/
#  ├── system-info.sh          # Display system information dashboard
#  ├── user-management.sh      # Manage local users and groups
#  ├── log-analyzer.sh         # Analyze system logs
#  ├── disk-cleanup.sh         # Find and manage large/old files
#  ├── process-monitor.sh      # Monitor and manage processes
#  └── cron/
#      ├── backup.sh           # Backup directories with timestamp
#      ├── log-rotate.sh       # Archive and compress old logs
#      └── health-check.sh     # Server health checks via ping
#
################################################################################

## SCRIPTS OVERVIEW

### Main Administration Scripts

#### 1. system-info.sh
**Purpose**: Display comprehensive system information dashboard

**Usage**:
```bash
./system-info.sh              # Display full report
./system-info.sh --help       # Show help
```

**Output**:
- CPU model, cores, and usage percentage
- RAM total, used, free (with percentage)
- Disk usage per filesystem
- System uptime
- Load average (1, 5, 15 minute)

**Requirements**: lscpu, top, free, df, uptime

---

#### 2. user-management.sh
**Purpose**: Create, delete, and manage local users and groups

**Usage**:
```bash
./user-management.sh --create username
./user-management.sh --delete username
./user-management.sh --add-group username groupname
./user-management.sh --remove-group username groupname
./user-management.sh --list
```

**Features**:
- Input validation and existence checks
- Confirmation prompts for destructive operations
- Logs all actions to `/var/log/user-management.log`
- Supports group membership management

**Requirements**: useradd, userdel, usermod, groupadd, sudo access

---

#### 3. log-analyzer.sh
**Purpose**: Analyze system logs for errors, warnings, and failures

**Usage**:
```bash
./log-analyzer.sh                      # Analyze /var/log/syslog
./log-analyzer.sh /var/log/auth.log    # Analyze specific log file
./log-analyzer.sh /var/log/kern.log --top 15
```

**Features**:
- Extracts ERROR, WARNING, FAILED entries
- Counts occurrences and shows frequencies
- Top 10 most common issues
- Formatted summary report

**Requirements**: grep, awk, sort, uniq

---

#### 4. disk-cleanup.sh
**Purpose**: Find and manage large/old files safely

**Usage**:
```bash
./disk-cleanup.sh                    # Preview cleanup candidates
./disk-cleanup.sh --dry-run          # Show what would be deleted
./disk-cleanup.sh --delete           # Interactive deletion
./disk-cleanup.sh --threshold 500M   # Find files >500MB
```

**Features**:
- Find large files (default: >100MB)
- Find old log files (default: >7 days)
- Dry-run mode preview
- Interactive confirmation before deletion
- Calculate recoverable space

**Requirements**: find, du, df, rm

---

#### 5. process-monitor.sh
**Purpose**: Monitor and manage system processes

**Usage**:
```bash
./process-monitor.sh                  # Display top processes
./process-monitor.sh --kill-pid 1234  # Kill by PID
./process-monitor.sh --kill-name nginx # Kill all nginx processes
./process-monitor.sh --monitor 5      # Real-time monitoring
```

**Features**:
- Top 10 CPU-consuming processes
- Top 10 memory-consuming processes
- Kill processes by PID or name
- Safety checks and confirmations
- Real-time monitoring with refresh

**Requirements**: ps, top, kill, pgrep

---

### Cron Job Scripts

These lightweight scripts are designed for automated execution via cron.
All operations are logged; minimal stdout output for quiet cron operation.

#### 6. cron/backup.sh
**Purpose**: Backup directory with timestamp

**Usage**:
```bash
./cron/backup.sh /path/to/source
./cron/backup.sh /path/to/source /path/to/backup
```

**Features**:
- Timestamped backup files (YYYY-MM-DD_HH-MM-SS)
- Compressed tar.gz format
- Default backup path: `/backup/`
- Logs to syslog

**Crontab Examples**:
```bash
# Daily backup at 2 AM
0 2 * * * /home/user/scripts/backup.sh /home/user /backup >/dev/null 2>&1

# Weekly backup at 3 AM Sunday
0 3 * * 0 /home/user/scripts/backup.sh /var/www /backup >/dev/null 2>&1

# Every 6 hours
0 */6 * * * /home/user/scripts/backup.sh /var/lib/mysql /backup >/dev/null 2>&1
```

---

#### 7. cron/log-rotate.sh
**Purpose**: Archive and compress old log files

**Usage**:
```bash
./cron/log-rotate.sh          # Archive logs >7 days old
./cron/log-rotate.sh 14       # Archive logs >14 days old
```

**Features**:
- Finds old log files in `/var/log`
- Compresses with tar.gz
- Moves to `/var/log/archive/`
- Removes original files
- Logs to syslog

**Crontab Examples**:
```bash
# Daily log rotation at 1 AM
0 1 * * * /home/user/scripts/log-rotate.sh 7 >/dev/null 2>&1

# Weekly aggressive rotation
0 2 * * 0 /home/user/scripts/log-rotate.sh 30 >/dev/null 2>&1

# Every 3 days for 5+ day old logs
0 3 */3 * * /home/user/scripts/log-rotate.sh 5 >/dev/null 2>&1
```

---

#### 8. cron/health-check.sh
**Purpose**: Server/service health check via ping

**Usage**:
```bash
./cron/health-check.sh              # Check google.com (default)
./cron/health-check.sh example.com  # Check specific host
./cron/health-check.sh --verbose    # Verbose output
```

**Features**:
- Ping target server
- Logs success/failure to `/var/log/health-check.log`
- Response time measurement
- Exit codes: 0=success, 1=failure
- Syslog integration

**Crontab Examples**:
```bash
# Check every 5 minutes
*/5 * * * * /home/user/scripts/health-check.sh google.com >/dev/null 2>&1

# Check every hour
0 * * * * /home/user/scripts/health-check.sh api.example.com >/dev/null 2>&1

# Check multiple services (create entries for each)
0 * * * * /home/user/scripts/health-check.sh api.example.com >/dev/null 2>&1
0 * * * * /home/user/scripts/health-check.sh db.example.com >/dev/null 2>&1
0 * * * * /home/user/scripts/health-check.sh cache.example.com >/dev/null 2>&1

# Check during business hours only
0 8-17 * * 1-5 /home/user/scripts/health-check.sh critical.local >/dev/null 2>&1
```

---

## QUICK START

### 1. Setup
```bash
# Clone or navigate to the repository
cd devops-automation-toolkit

# Scripts are already executable, but you can verify:
chmod +x linux/*.sh linux/cron/*.sh

# View help for any script:
./linux/system-info.sh --help
./linux/user-management.sh --help
./linux/log-analyzer.sh --help
./linux/disk-cleanup.sh --help
./linux/process-monitor.sh --help
```

### 2. Run Main Scripts
```bash
# Check system health
./linux/system-info.sh

# List all users
./linux/user-management.sh --list

# Analyze logs
./linux/log-analyzer.sh

# Find cleanup candidates
./linux/disk-cleanup.sh

# Monitor processes
./linux/process-monitor.sh
```

### 3. Schedule Cron Jobs
```bash
# Edit your crontab
crontab -e

# Add entries for automated tasks:
# Example: Daily backup at 2 AM
0 2 * * * /path/to/linux/cron/backup.sh /home/user /backup >/dev/null 2>&1

# Example: Log rotation daily at 1 AM
0 1 * * * /path/to/linux/cron/log-rotate.sh 7 >/dev/null 2>&1

# Example: Health check every hour
0 * * * * /path/to/linux/cron/health-check.sh example.com >/dev/null 2>&1
```

### 4. Monitor Logs
```bash
# User management actions
tail -f /var/log/user-management.log

# Health checks
tail -f /var/log/health-check.log

# Combined system log
tail -f /var/log/syslog | grep -E 'backup|health-check|log-rotate'

# View syslog entries
journalctl -u cron -f
```

---

## DESIGN PRINCIPLES

✓ **Production-Grade**: Error handling, input validation, safety checks
✓ **POSIX-Compliant**: Portable across Ubuntu, Debian, CentOS, RHEL
✓ **Modular**: Logical functions with clear separation of concerns
✓ **Self-Documenting**: Comprehensive comments and help sections
✓ **Secure**: Confirmation prompts, privilege elevation, no dangerous defaults
✓ **Observable**: Detailed logging to files and syslog
✓ **Minimal Dependencies**: Uses standard Linux tools only

---

## BEST PRACTICES

1. **Always test first**:
   ```bash
   ./linux/disk-cleanup.sh --dry-run  # Preview before deletion
   ```

2. **Use --help to understand options**:
   ```bash
   ./linux/user-management.sh --help
   ```

3. **Monitor log files for errors**:
   ```bash
   tail -f /var/log/user-management.log
   ```

4. **Schedule non-intrusive cron jobs**:
   ```bash
   # Run during low-traffic hours, redirect output to null
   0 2 * * * /path/to/script >/dev/null 2>&1
   ```

5. **Test cron jobs manually first**:
   ```bash
   # Run the script manually to verify it works
   /path/to/cron/health-check.sh example.com
   
   # Then add to crontab
   crontab -e
   ```

---

## TROUBLESHOOTING

### Scripts not executable
```bash
chmod +x linux/*.sh linux/cron/*.sh
```

### Syntax errors
```bash
bash -n linux/system-info.sh
```

### Permission denied when running
```bash
# Ensure executable permission
ls -l linux/system-info.sh  # Should show -rwxr-xr-x

# Some scripts may need sudo
sudo ./linux/user-management.sh --list
```

### Cron job not running
```bash
# Check cron logs
tail -f /var/log/syslog | grep CRON

# Verify crontab entry
crontab -l

# Check for errors in script
VERBOSE=1 /path/to/script  # Enable verbose output
```

---

## VERSION & AUTHOR

**Scripts Version**: 1.0.0  
**Created**: 2026-03-25  
**Author**: DevOps Team  
**License**: MIT

---

## ADDITIONAL RESOURCES

**Bash Scripting Best Practices**:
- Shellcheck (https://www.shellcheck.net/)
- Google Shell Style Guide

**Cron Job Scheduling**:
- `man crontab` for detailed timing syntax
- CronTab Guru (https://crontab.guru/) for expression testing

**System Administration**:
- `man systemd.timer` for modern alternatives to cron
- Process management: `ps`, `top`, `htop`
- Log management: `journalctl`, `logrotate`

---

## QUICK REFERENCE TABLE

| Script | Location | Purpose | Cron? |
|--------|----------|---------|-------|
| system-info | linux/ | System dashboard | No |
| user-management | linux/ | User/group CRUD | No |
| log-analyzer | linux/ | Log analysis | No |
| disk-cleanup | linux/ | Disk management | No |
| process-monitor | linux/ | Process monitoring | No |
| backup | linux/cron/ | Directory backup | Yes |
| log-rotate | linux/cron/ | Log archival | Yes |
| health-check | linux/cron/ | Server health | Yes |

---

END OF DOCUMENTATION

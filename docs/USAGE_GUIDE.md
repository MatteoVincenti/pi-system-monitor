# PiMonitor v2.0 Usage Guide

## 🚀 New Unified Interface

PiMonitor v2.0 introduces a revolutionary new interface that consolidates all operations into easy-to-use, menu-driven scripts with beautiful ASCII art branding.

## 🎯 Main Management Interface

### Interactive Menu System
```bash
./pimonitor
```

The main `pimonitor` script provides a comprehensive menu system for all operations:

```
   ____  _ __  __            _ __           
  / __ \(_) /_/ /_____  ____(_) /_____  ____
 / /_/ / / __/ __/ __ \/ ___/ / __/ __ \/ ___/
/ ____/ / /_/ /_/ /_/ / /  / / /_/ /_/ / /    
/_/   /_/\__/\__/\____/_/  /_/\__/\____/_/     

PiMonitor v2.0.0
Docker-based observability stack for Raspberry Pi

Main Menu
────────────────────────────────────────────────────

Please select an option:

1) Deployment Operations
2) Configuration Management
3) System Operations
4) Maintenance Tasks
5) View System Status
6) Exit
```

### Menu Navigation
- **Deployment Operations**: Start, stop, restart services, deploy configurations
- **Configuration Management**: Generate secrets, validate configs, manage environments
- **System Operations**: System validation, Docker cleanup, view logs
- **Maintenance Tasks**: Backup, restore, system cleanup, compatibility checks
- **View System Status**: Real-time service status and system information

## 🔧 Consolidated Scripts

### Maintenance Operations
```bash
./maintenance.sh
```

Provides comprehensive system maintenance:
- **System Maintenance**: Package updates, system cleanup
- **Docker Cleanup**: Safe and aggressive cleanup options
- **Compatibility Check**: Raspberry Pi compatibility validation
- **Performance Check**: System performance metrics
- **Scheduled Maintenance**: Automated maintenance setup

### Utility Operations
```bash
./utilities.sh
```

Comprehensive utility management:
- **Backup Management**: Create, restore, verify, export backups
- **Log Management**: View, search, export, clear logs
- **Configuration Tools**: Validate, generate, compare configurations
- **Secret Generation**: Generate secure passwords and tokens
- **System Information**: Hardware, network, performance info
- **Network Tools**: Port scanning, connectivity tests, DNS lookup
- **File Operations**: Find files, disk analysis, cleanup

## 🎨 Visual Features

### ASCII Art Branding
All scripts now feature consistent ASCII art branding:
- Beautiful PiMonitor logo on startup
- Colored status indicators (✓ ✗ ⚠ ℹ)
- Visual separators and borders
- Progress indicators with animations

### Smart Terminal Detection
- Automatically detects terminal width
- Falls back to text mode on narrow terminals
- Disables colors on non-interactive terminals
- Graceful degradation for compatibility

### Status Indicators
- ✓ **Success**: Green checkmark for successful operations
- ✗ **Error**: Red X for failed operations
- ⚠ **Warning**: Yellow warning triangle for warnings
- ℹ **Info**: Blue info icon for informational messages
- ⟳ **Progress**: Purple spinner for ongoing operations

## 📋 Command Reference

### Quick Commands
```bash
# Show help
./pimonitor --help
./maintenance.sh --help
./utilities.sh --help

# Show version
./pimonitor --version
./utilities.sh --version

# Automated maintenance
./maintenance.sh --auto-maintenance
```

### Legacy Script Support
All existing scripts remain available for automation and direct access:

```bash
# Direct script access (still supported)
./scripts/deploy.sh start
./scripts/backup.sh create my-backup
./scripts/logs.sh grafana -f
./scripts/validate-config.sh production
```

## 🔄 Migration from v1.x

### Interactive Users
**Before (v1.x):**
```bash
./scripts/backup.sh create
./scripts/system-maintenance.sh
./scripts/logs.sh grafana
```

**After (v2.0):**
```bash
./pimonitor
# Navigate through menus
```

### Automation Scripts
**No changes required!** All existing scripts continue to work:
```bash
./scripts/deploy.sh start
./scripts/backup.sh create automated-backup
./scripts/system-maintenance.sh --force
```

## 🎯 Best Practices

### For Interactive Use
1. **Use the main interface**: `./pimonitor` for guided operations
2. **Explore menus**: Each submenu provides detailed options
3. **Read descriptions**: Menu items include helpful descriptions
4. **Use help flags**: `--help` provides detailed usage information

### For Automation
1. **Use individual scripts**: Direct script access for automation
2. **Check exit codes**: All scripts return proper exit codes
3. **Use force flags**: `--force` to skip confirmations
4. **Log output**: Capture structured log output for monitoring

### For Development
1. **Use verbose mode**: `--verbose` for detailed debugging
2. **Check configurations**: Use validation tools before deployment
3. **Test in development**: Use development environment first
4. **Monitor logs**: Use log management tools for troubleshooting

## 🚨 Troubleshooting

### ASCII Art Issues
```bash
# If ASCII art doesn't display correctly
export PIMONITOR_ASCII_ART=false
./pimonitor

# Or use text-only mode
TERM=dumb ./pimonitor
```

### Color Issues
```bash
# Disable colors if needed
export PIMONITOR_COLOR_OUTPUT=false
./pimonitor
```

### Terminal Width Issues
The system automatically detects narrow terminals and switches to text mode. If you experience issues:
```bash
# Force text mode
COLUMNS=50 ./pimonitor
```

### Script Path Issues
If you encounter path-related errors:
```bash
# Run from project root directory
cd /path/to/pimonitor
./pimonitor
```

## 📚 Additional Resources

- **Migration Notes**: See `MIGRATION_NOTES.md` for detailed migration information
- **Individual Script Help**: Each script has detailed `--help` output
- **Configuration Guide**: See `docs/configuration.md` for configuration details
- **Troubleshooting**: See `docs/troubleshooting.md` for common issues

## 🎉 Enjoy PiMonitor v2.0!

The new interface makes PiMonitor more accessible and user-friendly while maintaining all the power and flexibility of the individual scripts. Whether you're a new user exploring the system or an experienced administrator automating deployments, PiMonitor v2.0 has you covered!
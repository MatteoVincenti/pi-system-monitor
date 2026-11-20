# PiMonitor v2.0 Migration Notes

## Script Consolidation

PiMonitor v2.0 introduces a new consolidated script interface while maintaining backward compatibility with existing scripts.

### New Unified Interface

#### Main Management Script
- **`./pimonitor`** - Interactive menu for all operations
  - Replaces the need to remember individual script names
  - Provides guided access to all functionality
  - Includes ASCII art branding and visual feedback

#### Consolidated Scripts
- **`./maintenance.sh`** - System maintenance and cleanup operations
  - Consolidates: system-maintenance.sh, system-cleanup.sh, docker-cleanup.sh, pi-compatibility-check.sh
  - Provides menu-driven maintenance interface
  - Includes automated scheduling options

- **`./utilities.sh`** - Backup, logging, configuration, and utility operations
  - Consolidates: backup.sh, logs.sh, generate-secrets.sh, validate-config.sh, config-manager.sh
  - Provides comprehensive utility management
  - Includes interactive configuration tools

### Backward Compatibility

All existing scripts remain available for:
- Automation and scripting
- Direct command-line access
- Legacy integrations

### Migration Recommendations

#### For Interactive Use
- **Old**: `./scripts/backup.sh create my-backup`
- **New**: `./utilities.sh` → Backup Management → Create Backup

#### For Automation
- **Continue using individual scripts**: `./scripts/backup.sh create my-backup`
- **Or use new consolidated scripts**: `./utilities.sh --backup create my-backup` (if implemented)

### Script Mapping

| Old Script | New Location | Notes |
|------------|--------------|-------|
| system-maintenance.sh | maintenance.sh | Menu-driven interface |
| system-cleanup.sh | maintenance.sh | Integrated cleanup options |
| docker-cleanup.sh | maintenance.sh | Docker cleanup submenu |
| pi-compatibility-check.sh | maintenance.sh | Compatibility check option |
| backup.sh | utilities.sh | Backup management menu |
| logs.sh | utilities.sh | Log management menu |
| generate-secrets.sh | utilities.sh | Secret generation menu |
| validate-config.sh | utilities.sh | Configuration validation |
| config-manager.sh | utilities.sh | Configuration tools menu |

### Benefits of New Interface

1. **Easier Discovery**: No need to remember script names
2. **Visual Feedback**: ASCII art branding and colored output
3. **Guided Operations**: Interactive menus with descriptions
4. **Consolidated Functionality**: Related operations grouped together
5. **Consistent Experience**: Unified interface across all operations

### Transition Period

- All existing scripts will remain functional
- New consolidated interface provides enhanced user experience
- Choose the interface that best fits your workflow
- Automation scripts can continue using individual scripts
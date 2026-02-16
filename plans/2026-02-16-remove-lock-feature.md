# Plan: Remove Lock Button Position Feature

## Overview

Remove the **"Lock Button Position"** option from the right-click context menu and eliminate the associated feature from the codebase and saved settings.

---

## Changes Required

### 1. ContextMenu.lua

| Line(s) | Action |
| --------- | -------- |
| 19 | Delete the `lockPositionItem` declaration |
| 25-26 | Remove the "Lock Button Position" menu item and the separator line before it |
| 42-44 | Remove the click handler that calls `ToggleLockPosition()` |
| 52 | Remove the line that sets the checkbox state for lock from `SetSelections()` |
| 81-89 | Remove the entire `ToggleLockPosition()` method |

### 2. MissionButton.lua

| Line(s) | Action |
| --------- | -------- |
| 85-87 | Remove the lock position check that blocks dragging when `Settings.lockButtonPosition == 1` |

### 3. SettingsManager.lua

| Line(s) | Action |
| --------- | -------- |
| 26 | Delete the `AddSettingConfig("lockButtonPosition", 0)` line |

---

## Files to Modify

- `src/ContextMenu.lua`
- `src/MissionButton.lua`
- `src/SettingsManager.lua`

---

## Expected Impact

After implementing these changes:

- ✓ Users will no longer see **"Lock Button Position"** in the right-click context menu
- ✓ The button will always be freely draggable with no restrictions
- ✓ The `lockButtonPosition` setting will be removed from the configuration
- ✓ Existing saved settings containing this value will be harmlessly ignored during load

---

## Implementation Notes

- No database/settings migration needed—unused settings are safely ignored
- This is a non-breaking change for users with existing save data
- All related functionality is isolated to the three specified files

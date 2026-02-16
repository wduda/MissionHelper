# Plan: Fix Main Window Not Opening

## Overview

The plugin's main window does not appear when the toolbar button is left-clicked or when the context menu's "Show Window" option is used. Create a small, safe bugfix that makes window toggling reliable by adding defensive checks, on-demand window creation, and diagnostic logging.

---

## Reproduction

- Left-click the Mission Helper button: nothing happens.
- Right-click the button -> choose "Show Window": nothing happens.

## Investigation Focus

- Confirm `missionWindow` is created before use and in scope where toggles call it.
- Check calls that use `missionWindow:IsVisible()` or `missionWindow:SetVisible()` for nil dereference.
- Ensure mouse click logic (drag detection) does not incorrectly treat clicks as drags.
- Add logs to identify where execution stops.

---

## Changes Required

- `src/ContextMenu.lua`
  - In `SetSelections()` wrap uses of `missionWindow` in a `if missionWindow then ... end` guard
  - In `ToggleWindowVisibility()` ensure `missionWindow` exists; if nil, create `missionWindow = MissionWindow()` before toggling. Add a debug `Turbine.Shell.WriteLine` when toggling

- `src/MissionButton.lua`
  - In `MouseUp` before calling `missionWindow:IsVisible()` / `missionWindow:SetVisible()` check `if missionWindow == nil then missionWindow = MissionWindow(); end`
  - Add a short debug line when toggling from the button so users get feedback
  - Review the drag threshold logic (BehaviorConstants.BUTTON_DRAG_DELAY). If clicks are being misclassified as drags, add a small tolerance (ensure hasMoved only true when actual movement > 0)

- `src/Main.lua` (optional)
  - Confirm `missionWindow = MissionWindow()` is created during `PluginLoad` (already present). No change required unless we prefer lazy creation

---

## Implementation Steps

1. Add nil checks and on-demand creation in `ContextMenu.lua` and `MissionButton.lua`
2. Add debug `Turbine.Shell.WriteLine` messages to both toggle paths (menu and button). Keep messages concise and removable
3. Add a small movement check in `MouseMove`/`MouseUp` to avoid false drag detection (e.g., only set `hasMoved = true` when deltaX or deltaY != 0)
4. Test in-game: left-click button, right-click -> Show Window, and trigger mission detection via chat to ensure `ShowMission()` still works
5. If logs show nil or errors, adjust accordingly and add minimal protection with `pcall` around `IsVisible`/`SetVisible` calls

---

## Files to Modify

- `src/ContextMenu.lua`
- `src/MissionButton.lua`
- (Optionally) `src/Main.lua`

---

## Acceptance Criteria

- Left-clicking the button toggles the main window visible state (and prints a short log message)
- The context menu "Show Window" toggles the main window and updates its checkbox state
- Triggering `missionWindow:ShowMission()` from `DetectMission()` still displays the window
- No runtime errors caused by nil `missionWindow` references
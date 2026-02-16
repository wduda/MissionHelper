# Plan: Show Last Accepted Mission When Opening Window

## Overview

If the main window is opened while the player is not currently in a mission, show information for the last mission quest that was accepted. This provides immediate useful context when users open the window manually.

---

## Goal

- Ensure the main window shows the most recently accepted mission when opened and there is no active mission context

---

## Approach

- Track the last accepted mission in a global `lastMissionInfo` variable stored in `Main.lua`
- Update `DetectMission()` to set `lastMissionInfo` whenever a mission is detected
- When toggling the window (via `MissionButton` or context menu), if the window is being shown and there is no currently active mission, call `missionWindow:ShowMission(lastMissionInfo)` to populate the UI
- Keep the change small and defensive (check for `nil` values)

---

## Changes Required

- `src/Main.lua`
  - Add a global `lastMissionInfo = nil` (and optional `lastMissionTimestamp` if desired)
  - Update `DetectMission()` to assign `lastMissionInfo = missionInfo` when a mission is recognized

- `src/MissionButton.lua`
  - When toggling the window open (MouseUp path), after creating the `missionWindow` if necessary and before leaving the toggle logic, if the new state is shown and no active mission context exists, call `missionWindow:ShowMission(lastMissionInfo)` (guarded by `if lastMissionInfo ~= nil then ... end`)

- `src/ContextMenu.lua`
  - Same as above: when toggling the window open, if no active mission, call `missionWindow:ShowMission(lastMissionInfo)` (guarded)

- `src/MissionWindow.lua` (no change required unless we want to add a lightweight `ShowLastMission()` helper—optional)

---

## Implementation Steps

1. Add `lastMissionInfo = nil` near the top of `src/Main.lua` (next to other globals)
2. Modify `DetectMission()` in `src/Main.lua` to set `lastMissionInfo = missionInfo` right before calling `missionWindow:ShowMission(missionInfo)`
3. Modify the window-toggle code paths in `src/MissionButton.lua` and `src/ContextMenu.lua` so that when the window is being shown, if there is no active mission context, the code calls `missionWindow:ShowMission(lastMissionInfo)` (with a `nil` check)
4. Add a short `Turbine.Shell.WriteLine` debug message when `lastMissionInfo` is shown via manual open (optional)
5. Test: left-click button and use context menu to open the window while not in a mission; confirm that last mission info is displayed. Also confirm that `DetectMission()` still displays the mission when a mission is detected via chat
6. Update any documentation or changelog if desired (use `fix:` prefix in changelog data)

---

## Acceptance Criteria

- Opening the main window manually (button or context menu) when not in a mission populates the window with the most recently accepted mission
- No runtime errors occur when `lastMissionInfo` is `nil`
- Detecting a mission via chat still displays that mission immediately and updates `lastMissionInfo`

---

## Notes

- This plan intentionally avoids adding complex mission-end detection. If future work provides reliable mission lifecycle events, we can refine the logic to better distinguish "active mission" vs. historical missions
- Optionally, we can add `lastMissionTimestamp` to avoid showing very old missions

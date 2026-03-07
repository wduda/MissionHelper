# Basic Delving Support Plan

Date: 2026-03-07
Branch: `feature/basic-delving-support`

## Goal
Add basic detection of delving tier quest acceptance from the mission-start chat flow and exclude delving runs from mission completion timing statistics.

## Scope
- Detect chat lines matching `New Quest: Tier N: Delving <Gem>` where `N` is 1-12 and `<Gem>` maps to tier ranges:
  - Zircon: 1-3
  - Garnet: 4-6
  - Emerald: 7-9
  - Amethyst: 10-12
- If detected during an active mission run:
  - stop the regular mission timer
  - keep showing `00:00` for mission timer after detection
  - ensure this run does not contribute to average completion time

## Implementation Steps
1. Locate mission timer lifecycle and chat message handling in `src/Main.lua`, `src/MissionWindow.lua`, and stats management code.
2. Add delving quest detection logic in chat parsing with a robust pattern for tiers 1-12 and valid gem names.
3. Track run state flag(s) to mark a mission run as delving-affected once detected.
4. Update timer behavior so mission timer halts and display remains at `00:00` for the run after detection.
5. Update mission completion/stat recording logic to skip average-time updates for delving-affected runs.
6. Validate that non-delving runs are unchanged.

## Validation
- Simulate/trace normal mission run: timer starts/stops normally and average completion updates.
- Simulate/trace delving acceptance chat after timer start: timer display stays `00:00` and completion time is not added to averages.
- Verify no regressions in mission start/end state reset between runs.

## Notes
- This is basic support focused on detection and timing/stat exclusion only.
- Future enhancements can expose delving tier details in UI/history if desired.

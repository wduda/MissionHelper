# Plan: Global Malice Section and Scan Workflow

Date: 2026-03-09

## Goals

- Add a new global section above mission-specific UI in the main plugin window
- Display `Malice Set:` with a numeric value (initial default `5`)
- Add a `Scan` button that runs `/loc` and parses chat output
- Add `Suggest Missions` and `Suggest Delvings` buttons on a second row (clickable no-op)
- Calculate and display malice day from scanned data using DelvingDigest-style logic
- Color malice day value green on day `1` and day `5`

## Implementation Steps

1. Extend `src/MissionWindow.lua` layout constants and control tree
- Reserve vertical space for a new global section under the header and above current mission row
- Add a `Malice Set:` prefix label and a malice value label on the left
- Add a right-aligned `Scan` button on the same row
- Add second-row buttons:
  - Left: `Suggest Missions`
  - Right: `Suggest Delvings`
- Shift mission/timer/content rows downward to avoid overlap

2. Add public interaction methods to `MissionWindow`
- Expose a `SetMaliceDay(dayNumber)` method to update text and color
- Expose handlers for:
  - scan requested
  - suggest missions clicked
  - suggest delvings clicked
- Keep suggest buttons as explicit no-op placeholders for now

3. Implement `/loc` scan request flow in `src/Main.lua`
- Add one-shot scan state (listening flag and optional timeout marker)
- On scan request:
  - mark scanner as listening
  - execute `/loc` through a quickslot-compatible alias shortcut path
- In chat handler, if listening, parse localized `/loc` result line and extract server name

4. Port DelvingDigest-style malice-day calculation into `src/Main.lua`
- Add a `GetMaliceDayForServer(serverName)` helper based on DelvingDigest `getVariant` behavior:
  - cycle length: 6
  - reset-time shift: 03:00 server time
  - base day from epoch-day modulo cycle
  - apply server-specific offset map (DelvingDigest server offsets)
- Use parsed server name to select offset set, fallback to `Default` if unknown
- Update MissionWindow malice value via `SetMaliceDay`

5. Preserve existing mission detection behavior
- Keep current `DetectMission` pipeline untouched for mission logic
- Route the same chat line through loc-scan parser without breaking existing detection

6. Verify and finalize
- Run lightweight checks (status diff, syntax-level scan)
- Confirm hardcoded initial value is `5` before first successful scan
- Ensure day `1` and `5` render green, other days render white

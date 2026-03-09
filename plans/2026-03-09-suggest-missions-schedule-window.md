# Plan: Suggest Missions Schedule Window

Date: 2026-03-09

## Goals

- Use DelvingDigest `Schedule.lua` mission-availability logic to compute missions available on the current server day
- Wire `Suggest Missions` button to open a new window listing those missions
- Group suggested missions by region
- Include missions known to MissionHelper but not present in DelvingDigest schedule as always-available entries

## Implementation Steps

1. Establish feature baseline on this task branch
- Bring in the existing global section + `Suggest Missions` button implementation from prior task branch so this task can extend it

2. Add DelvingDigest schedule data adapter in MissionHelper
- Create local schedule structures derived from DelvingDigest `Schedule.lua`:
  - mission areas (region, cycle length, day mapping)
  - mission groups (mission IDs by area/NPC/day variant)
- Add mission ID to mission name mapping for DelvingDigest mission indices

3. Implement availability calculation
- Compute current cycle day per area using existing malice/server time foundation
- Resolve scheduled mission IDs for each area/day
- Map scheduled mission IDs to mission names
- Build result buckets grouped by region
- Add fallback bucket entries for missions in MissionHelper data but missing from DelvingDigest mapping, marked as always available in their known region

4. Add Suggest Missions window UI
- Implement a separate LOTRO window class that:
  - displays grouped mission names by region
  - supports multiline scrolling
  - can be shown/hidden from `Suggest Missions` button
- Keep `Suggest Delvings` as no-op per current scope

5. Wire integration in `Main.lua`
- Connect `Suggest Missions` callback to compute data and populate/show the new window
- Ensure computed list updates each time the button is clicked

6. Verify behavior
- Validate grouping and inclusion rules:
  - scheduled missions appear by computed region/day
  - unknown-to-DelvingDigest but known-to-MissionHelper missions are included as always available with region
- Run repository diff/status checks and summarize outcomes

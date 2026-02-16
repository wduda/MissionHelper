# Main Window UI Redesign Replan

## Summary

Redesign `MissionWindow` to a compact, high-contrast layout focused on quick mission readability and minimal interaction friction.
The redesign keeps current mission data behavior, replaces the legacy close button with a custom red corner control, and adds explicit fallback messaging when detailed help is unavailable.

## Scope

### In Scope

- Visual/layout redesign of `src/MissionWindow.lua`
- Replace current centered `Close` button with top-right red square close control
- Add explicit `Current Mission:` prefix treatment
- Replace current multiline `Label` help area with a scrollable text area control
- Ensure fallback text `No help data for this mission` displays for missing/empty mission help
- Preserve current window position persistence and visibility settings behavior

### Out of Scope

- Changes to mission detection logic in `src/Main.lua`
- Changes to mission data schema in `src/MissionData.lua`
- Localization refactor
- New settings/options UI

## Current State Snapshot

- `MissionWindow` currently uses:
  - Title label (`Mission Helper`)
  - Mission label (mission name only, no prefix)
  - Multiline `Label` for rich mission text
  - Standard `Turbine.UI.Lotro.Button` labeled `Close`
- `ShowMission` builds composite text from `region`, `duration`, `difficulty`, `objectives`, `clickableObjectives`, and `tacticalAdvice/helpText`
- Unknown missions are currently filtered upstream in `Main.lua` and do not open window

## Design and Behavior Specification

### Window Container

- Keep class base as `Turbine.UI.Window`
- Size remains `400x250` initially for compatibility
- Apply solid black background using `SetBackColor(Turbine.UI.Color.Black)` (or equivalent alpha-safe black color)
- Keep drag behavior and `PositionChanged` persistence unchanged

### Header Row

- Top row contains:
  - Small title at left: `Mission Helper`
  - Red square close control at right
- Title styling default:
  - Font: `Turbine.UI.Lotro.Font.TrajanPro14`
  - Color: gold-like (`Turbine.UI.Color.Gold`)
- Close control:
  - Type: `Turbine.UI.Control` (custom, not Lotro Button skin)
  - Size: `12x12`
  - Position: padding-aligned to top-right (e.g. `x = windowWidth - 18`, `y = 8`)
  - Fill color: red (`~#CC3333`)
  - Click action: `self:SetVisible(false)` and persist `Settings.windowVisible = 0` then `SaveSettings()`
  - Hover state: slightly brighter red for affordance

### Mission Context Row

- Below header, show mission context as one line:
  - Prefix: `Current Mission:`
  - Value: mission name
- Layout:
  - Prefix label fixed-width
  - Mission name label consumes remaining width
- Styling:
  - Prefix font: `Verdana14` (or closest readable Lotro font)
  - Prefix color: light gray
  - Name color: white

### Help Content Area

- Replace multiline `Label` with:
  - `Turbine.UI.Lotro.TextBox` if available in environment
  - Fallback: keep multiline `Label` if API lacks desired text behavior
- Content box behavior:
  - Multiline enabled
  - Read-only behavior by not wiring edit interactions
  - Vertical scrollbar if API support exists; otherwise clipped text accepted as fallback
- Content text rules:
  - Use existing rich assembled text when available
  - If no meaningful help content resolves, show exact fallback: `No help data for this mission`

## Data and Text Composition Rules

- Keep existing field merge order and labels unless specified:
  - `Location`, `Duration`, `Difficulty`, `Objectives`, `Clickables`, `Strategy`
- Fallback resolution:
  1. Use assembled rich text if non-empty after trimming
  2. Else use `missionInfo.helpText` if non-empty
  3. Else show `No help data for this mission`
- `missionInfo.name` nil-safe default: `Unknown Mission`

## Interfaces and Public Surface Changes

- No external API signature changes for `MissionWindow:ShowMission(missionInfo)`
- Internal control fields in `MissionWindow` change:
  - Add `self.headerTitleLabel`, `self.currentMissionPrefixLabel`, `self.currentMissionValueLabel`, `self.helpTextBox`, `self.redCloseControl`
  - Remove dependency on `self.closeButton`
- Persistence contract remains:
  - `Settings.windowRelativeX`, `Settings.windowRelativeY`, `Settings.windowVisible` unchanged
- No plugin manifest/package changes

## Implementation Plan

1. Refactor constructor layout constants in `src/MissionWindow.lua`
2. Apply solid black background and adjust window title text handling
3. Replace current close button with red square control and hover/click handlers
4. Add explicit `Current Mission:` prefix/value controls
5. Replace help area control with text-box-first implementation plus fallback path
6. Update `ShowMission` to:
   - Set mission name value label
   - Build content with existing fields
   - Apply empty-content fallback text
   - Keep visibility + settings persistence
7. Validate compatibility with existing `Main.lua` flow and manual open behavior
8. Perform in-game visual and behavior verification pass

## Test Cases and Scenarios

### Functional

- Mission with full data shows header, prefixed mission name, and composed detail text
- Mission with only name and no help text shows fallback `No help data for this mission`
- Clicking red square hides window and persists hidden state
- Reopening window via mission detection shows latest mission correctly
- Dragging window updates and saves relative position

### UI/UX

- Header elements do not overlap at `400x250`
- Text remains readable on black background
- Mission name truncates or clips gracefully for long names
- Help area content remains legible for long text and line breaks

### Regression

- Plugin load/unload still succeeds
- Existing settings load/save unaffected
- No runtime errors when mission fields are missing/nil

## Risks and Mitigations

- Risk: `Turbine.UI.Lotro.TextBox` behavior may differ across clients
  Mitigation: implement control fallback to multiline `Label`
- Risk: hardcoded layout may break on very small resolutions
  Mitigation: retain current window dimensions and use conservative paddings
- Risk: visibility persistence inconsistency on close path
  Mitigation: explicitly set/save `Settings.windowVisible` in red close handler

## Assumptions and Defaults

- `TravelWindow` visual reference is interpreted as compact LOTRO-styled header, not exact pixel parity
- Existing font constants used in project are acceptable for redesign
- Unknown missions continue to be handled in `Main.lua` without opening the window
- No new configuration toggles are required for this redesign

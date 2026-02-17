# Mission Start/Completion Detection Hardening with Chat-Type Debug and Version 0.0.3

## Summary

Implement a reliability pass for mission start and completion detection in `src/Main.lua` with stronger chat-type diagnostics, strict regional leave gating, robust completion matching, and explicit start-window lifecycle logging.
Bump plugin version metadata to `v0.0.3`.

## Important API/Interface Changes

1. Internal-only behavior changes in `src/Main.lua`:
1. Completion matcher accepts both `Mission Complete!` and `Mission Completed!`.
1. Leave detection remains strict to `Turbine.ChatType.Regional`.
1. Completion and `Completed:` parsing produce consistent chat-type debug logs.
1. No public plugin command/API changes.
1. No mission stats schema changes.

## Files to Change

1. `src/Main.lua`
1. `MissionHelper.plugin`
1. `MissionHelper.plugincompendium`
1. `plans/2026-02-17-mission-complete-chattype-debugging.md`

## Implementation Plan

## 1. Chat-type diagnostics foundation in `src/Main.lua`

1. Keep/build reverse map from `Turbine.ChatType` numeric values to names.
1. Add static fallback map for known ids to guarantee readable names.
1. Standardize debug output format:
1. `MissionHelper DEBUG: event=<event> chatType=<Name>(<Number>) message="<trimmed>"`

## 2. Strict regional-leave start window with explicit debug

1. Keep trigger rule:
1. Open `pendingStartWindow` only when:
1. `chatType == Turbine.ChatType.Regional`
1. Message matches `^Left the .+ %- Regional channel%.?$`
1. Add debug events:
1. `regional_leave_match`
1. `regional_leave_ignored_nonregional` when text matches but chat type is not regional
1. `start_window_opened`
1. `start_window_expired`
1. `start_window_consumed`
1. Preserve bounded window:
1. `maxMessages = 10`
1. `maxSeconds = 5`

## 3. Completion-first detection robustness

1. Replace exact completion comparison with helper accepting:
1. `Mission Complete!`
1. `Mission Completed!`
1. On completion match:
1. Emit debug `mission_complete_match`
1. If active run exists:
1. Stop timer
1. Persist stats
1. Emit completion lines
1. If no active run:
1. Emit debug `mission_complete_no_active_run`
1. Do not persist stats

## 4. `Completed:` candidate parsing as verification-only

1. Keep support for:
1. `Completed: <name>`
1. `Completed:` header + next non-empty line
1. Multiline `Completed:\n<name>`
1. Emit debug for every candidate capture:
1. `completed_candidate`
1. Keep verification window (`10` messages / `5` seconds).
1. If mismatch with active/recent run, emit debug mismatch only.
1. Never block completion finalization on mismatch.

## 5. Quest/start classification hardening

1. Preserve `NormalizeMissionNameFromQuestMessage` prefix stripping for `Mission:`.
1. Add debug around duplicate suppression:
1. `quest_duplicate_suppressed`
1. Add debug for parsed quest lines from unexpected chat types:
1. `quest_unexpected`
1. Ensure path to `*** MISSION START DETECTED ***` is only gated by active start window and parsed quest line.

## 6. Version bump to `v0.0.3`

1. Update `MissionHelper.plugin`:
1. `<Version>v0.0.3</Version>`
1. Update `MissionHelper.plugincompendium`:
1. `<Version>v0.0.3</Version>`
1. Validate load banner reports `v0.0.3`.

## 7. Plan artifact update

1. Save this finalized plan into:
1. `plans/2026-02-17-mission-complete-chattype-debugging.md`
1. Replace file content with latest plan revision only.

## Test Cases and Scenarios

1. Quest acceptance:
1. `New Quest: Mission: Securing Salvage` -> `*** MISSION QUEST DETECTED ***`
1. Start detection success:
1. `Left the <region> - Regional channel.` in `ChatType.Regional` then quest line within window -> `*** MISSION START DETECTED ***` and timer starts
1. Non-regional leave lines:
1. Roleplay/OOC leave lines -> no start window; debug `regional_leave_ignored_nonregional`
1. Completion variants:
1. `Mission Complete!` ends active run
1. `Mission Completed!` ends active run
1. Completion without active run:
1. Debug only, no stats update
1. `Completed:` before completion:
1. Candidate captured and later verified
1. `Completed:` after completion:
1. Late verification debug only
1. Debug chat-type readability:
1. Completion-related debug always includes name and numeric id.

## Assumptions and Defaults

1. Regional leave trigger remains strict to `ChatType.Regional`.
1. Completion is authoritative on completion message match alone.
1. `Completed:` is auxiliary verification only.
1. Debug verbosity remains always-on until discovery phase is intentionally reduced.
1. This plan is implementation-ready and matches the shipped code changes in this revision.

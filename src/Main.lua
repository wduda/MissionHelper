import "Turbine"
import "Turbine.Gameplay"
import "Turbine.UI"

import "MissionHelper.src.VindarPatch"
import "MissionHelper.src.SettingsManager"
import "MissionHelper.src.MissionData"
import "MissionHelper.src.MissionStatsManager"
import "MissionHelper.src.MissionWindow"
import "MissionHelper.src.MissionButton"

Plugin = Turbine.Plugin
Player = Turbine.Gameplay.LocalPlayer:GetInstance()

lastMissionInfo = nil
lastDetectedMissionName = nil
lastDetectedMissionTime = -1000
lastTimerUiSecond = -1

local WINDOW_MAX_MESSAGES = 10
local WINDOW_MAX_SECONDS = 5

local expectedQuestChatTypes = {
    [Turbine.ChatType.Standard] = true,
    [Turbine.ChatType.Advancement] = true,
    [Turbine.ChatType.Quest] = true,
    [Turbine.ChatType.PlayerCombat] = true
}

local excludedMissionQuests = {
    ["march on gundabad: missions for the cause"] = true,
    ["march on gundabad: assisting the war effort (daily)"] = true
}

local chatTypeNames = {}
local knownChatTypeNames = {
    [0] = "Undef",
    [1] = "Error",
    [3] = "Admin",
    [4] = "Standard",
    [5] = "Say",
    [6] = "Tell",
    [7] = "Emote",
    [11] = "Fellowship",
    [12] = "Kinship",
    [13] = "Officer",
    [14] = "Advancement",
    [15] = "Trade",
    [16] = "LFF",
    [18] = "OOC",
    [19] = "Regional",
    [20] = "Death",
    [21] = "Quest",
    [23] = "Raid",
    [25] = "Unfiltered",
    [27] = "Roleplay",
    [28] = "UserChat1",
    [29] = "UserChat2",
    [30] = "UserChat3",
    [31] = "UserChat4",
    [32] = "Tribe",
    [34] = "PlayerCombat",
    [35] = "EnemyCombat",
    [36] = "SelfLoot",
    [37] = "FellowLoot",
    [38] = "World",
    [39] = "UserChat5",
    [40] = "UserChat6",
    [41] = "UserChat7",
    [42] = "UserChat8"
}

pendingStartWindow = {
    active = false,
    openedAtGameTime = 0,
    messagesSeen = 0
}

completedCandidate = {
    active = false,
    awaitingContinuation = false,
    name = nil,
    capturedAtGameTime = 0,
    messagesSeen = 0,
    chatType = nil
}

recentlyCompletedMission = {
    active = false,
    name = nil,
    completedAtGameTime = 0
}

activeMissionRun = {
    missionName = nil,
    startedAtGameTime = 0,
    isRunning = false
}

local function TrimText(text)
    if text == nil then
        return ""
    end

    local result = tostring(text)
    result = result:gsub("^%s+", "")
    result = result:gsub("%s+$", "")
    return result
end

local function FormatDurationMMSS(totalSeconds)
    local seconds = tonumber(totalSeconds) or 0
    if seconds < 0 then
        seconds = 0
    end

    local whole = math.floor(seconds)
    local minutes = math.floor(whole / 60)
    local remainder = whole - (minutes * 60)
    return string.format("%02d:%02d", minutes, remainder)
end

local function BuildChatTypeNameMap()
    chatTypeNames = {}
    for name, value in pairs(Turbine.ChatType) do
        if type(value) == "number" then
            chatTypeNames[value] = name
        end
    end

    for value, name in pairs(knownChatTypeNames) do
        if chatTypeNames[value] == nil then
            chatTypeNames[value] = name
        end
    end
end

local function GetChatTypeName(chatType)
    local name = chatTypeNames[chatType]
    if name == nil then
        return "Unknown"
    end
    return name
end

local function EscapeDebugText(text)
    local escaped = tostring(text or "")
    escaped = escaped:gsub("\"", "'")
    return escaped
end

local function DebugChatEvent(eventName, chatType, message, details)
    local chatTypeName = GetChatTypeName(chatType)
    local trimmed = EscapeDebugText(TrimText(message))
    local detailPart = ""
    if details ~= nil and details ~= "" then
        detailPart = " " .. details
    end

    Turbine.Shell.WriteLine(
        "MissionHelper DEBUG: event=" .. eventName ..
        " chatType=" .. chatTypeName .. "(" .. tostring(chatType) .. ")" ..
        detailPart ..
        " message=\"" .. trimmed .. "\""
    )
end

local function IsWindowExpired(windowState, now)
    if not windowState.active then
        return true
    end

    if windowState.messagesSeen > WINDOW_MAX_MESSAGES then
        return true
    end

    if (now - windowState.openedAtGameTime) > WINDOW_MAX_SECONDS then
        return true
    end

    return false
end

local function OpenStartWindow(now, chatType, message)
    pendingStartWindow.active = true
    pendingStartWindow.openedAtGameTime = now
    pendingStartWindow.messagesSeen = 0

    DebugChatEvent("start_window_opened", chatType, message)
end

local function AdvanceStartWindow(now)
    if not pendingStartWindow.active then
        return
    end

    pendingStartWindow.messagesSeen = pendingStartWindow.messagesSeen + 1
    if IsWindowExpired(pendingStartWindow, now) then
        DebugChatEvent("start_window_expired", Turbine.ChatType.Undef, "", "messagesSeen=" .. tostring(pendingStartWindow.messagesSeen))
        pendingStartWindow.active = false
    end
end

local function ResetCompletedCandidate()
    completedCandidate.active = false
    completedCandidate.awaitingContinuation = false
    completedCandidate.name = nil
    completedCandidate.capturedAtGameTime = 0
    completedCandidate.messagesSeen = 0
    completedCandidate.chatType = nil
end

local function SetCompletedCandidate(name, chatType, now)
    completedCandidate.active = true
    completedCandidate.awaitingContinuation = false
    completedCandidate.name = name
    completedCandidate.capturedAtGameTime = now
    completedCandidate.messagesSeen = 0
    completedCandidate.chatType = chatType
end

local function SetCompletedCandidateAwaitingContinuation(chatType, now)
    completedCandidate.active = true
    completedCandidate.awaitingContinuation = true
    completedCandidate.name = nil
    completedCandidate.capturedAtGameTime = now
    completedCandidate.messagesSeen = 0
    completedCandidate.chatType = chatType
end

local function IsCompletedCandidateValid(now)
    if not completedCandidate.active then
        return false
    end

    if completedCandidate.name == nil or completedCandidate.name == "" then
        return false
    end

    if completedCandidate.messagesSeen > WINDOW_MAX_MESSAGES then
        return false
    end

    if (now - completedCandidate.capturedAtGameTime) > WINDOW_MAX_SECONDS then
        return false
    end

    return true
end

local function AdvanceCompletedCandidate(now)
    if not completedCandidate.active then
        return
    end

    completedCandidate.messagesSeen = completedCandidate.messagesSeen + 1

    if completedCandidate.messagesSeen > WINDOW_MAX_MESSAGES or
       (now - completedCandidate.capturedAtGameTime) > WINDOW_MAX_SECONDS then
        ResetCompletedCandidate()
    end
end

local function IsRecentCompletionValid(now)
    if not recentlyCompletedMission.active then
        return false
    end

    return (now - recentlyCompletedMission.completedAtGameTime) <= WINDOW_MAX_SECONDS
end

function NormalizeMissionNameFromQuestMessage(message)
    local rawQuestName = string.match(message, "New Quest:%s*(.+)")
    if rawQuestName == nil then
        return nil
    end

    local normalizedMissionName = TrimText(rawQuestName)
    normalizedMissionName = normalizedMissionName:gsub("^Mission:%s*", "")
    normalizedMissionName = TrimText(normalizedMissionName)

    if normalizedMissionName == "" then
        return nil
    end

    return normalizedMissionName
end

local function IsExcludedMissionQuest(missionName)
    local normalized = string.lower(TrimText(missionName))
    return excludedMissionQuests[normalized] == true
end

local function IsKnownMissionQuest(missionName)
    if missionName == nil or missionName == "" then
        return false
    end

    return MissionData:HasMission(missionName)
end

function ParseCompletedMissionFromMessage(message)
    local completedPrefix = string.match(message, "^Completed:%s*(.*)")
    if completedPrefix ~= nil then
        local inline = TrimText(completedPrefix)
        if inline ~= "" then
            return inline, false
        end
        return nil, true
    end

    return nil, false
end

function IsDuplicateMissionDetection(missionName)
    local now = Turbine.Engine.GetGameTime()
    if lastDetectedMissionName == missionName and (now - lastDetectedMissionTime) < 2.0 then
        return true
    end

    lastDetectedMissionName = missionName
    lastDetectedMissionTime = now
    return false
end

function BuildFallbackMissionInfo(missionName)
    return {
        name = missionName,
        objectives = "",
        missionDescription = "",
        tacticalAdvice = "no helptext",
        bugs = "",
        delvingEnabled = false,
        difficulty = "no delving difficulty",
        difficultyDetails = "",
        timeRange = "",
        timeAssessment = ""
    }
end

function ShowMissionInfoFromName(missionName)
    local missionInfo = nil

    if MissionData:HasMission(missionName) then
        missionInfo = MissionData:GetMissionInfo(missionName)
    else
        missionInfo = BuildFallbackMissionInfo(missionName)
        Turbine.Shell.WriteLine("<rgb=#FFFF00>Note: No help data for mission: " .. missionName .. "</rgb>")
    end

    missionInfo.name = missionName
    lastMissionInfo = missionInfo

    if missionWindow == nil then
        missionWindow = MissionWindow()
    end

    missionWindow:ShowMission(missionInfo)
    Turbine.Shell.WriteLine("<rgb=#90EE90>Mission window displayed</rgb>")
end

function StartMissionRun(missionName)
    local now = Turbine.Engine.GetGameTime()
    activeMissionRun.missionName = missionName
    activeMissionRun.startedAtGameTime = now
    activeMissionRun.isRunning = true
    lastTimerUiSecond = -1

    if missionWindow ~= nil then
        missionWindow:SetLiveTimer(missionName, 0, true)
    end
end

function StopMissionRunAndPersist(missionName)
    if not activeMissionRun.isRunning then
        return
    end

    if activeMissionRun.missionName ~= missionName then
        return
    end

    local now = Turbine.Engine.GetGameTime()
    local durationSeconds = math.floor(math.max(0, now - activeMissionRun.startedAtGameTime))

    activeMissionRun.isRunning = false

    if missionWindow ~= nil then
        missionWindow:SetLiveTimer(missionName, durationSeconds, false)
    end

    MissionStatsManager:RecordCompletion(missionName, durationSeconds)

    Turbine.Shell.WriteLine("<rgb=#00FF00>*** MISSION COMPLETE DETECTED ***</rgb>")
    Turbine.Shell.WriteLine("<rgb=#00FF00>Mission: " .. missionName .. "</rgb>")
    Turbine.Shell.WriteLine("<rgb=#00FF00>Duration: " .. FormatDurationMMSS(durationSeconds) .. "</rgb>")

    recentlyCompletedMission.active = true
    recentlyCompletedMission.name = missionName
    recentlyCompletedMission.completedAtGameTime = now
end

function UpdateLiveMissionTimer()
    if not activeMissionRun.isRunning then
        return
    end

    local now = Turbine.Engine.GetGameTime()
    local elapsedSeconds = math.floor(math.max(0, now - activeMissionRun.startedAtGameTime))

    if elapsedSeconds == lastTimerUiSecond then
        return
    end

    lastTimerUiSecond = elapsedSeconds

    if missionWindow ~= nil then
        missionWindow:SetLiveTimer(activeMissionRun.missionName, elapsedSeconds, true)
    end
end

function HandleCompletedCandidateVerification(candidateMissionName, now)
    if activeMissionRun.isRunning then
        if candidateMissionName ~= activeMissionRun.missionName then
            Turbine.Shell.WriteLine(
                "MissionHelper DEBUG: completion_mismatch active=\"" .. activeMissionRun.missionName ..
                "\" completed=\"" .. candidateMissionName .. "\""
            )
        end
        return
    end

    if IsRecentCompletionValid(now) then
        if candidateMissionName ~= recentlyCompletedMission.name then
            Turbine.Shell.WriteLine(
                "MissionHelper DEBUG: completion_late_mismatch completed=\"" .. candidateMissionName ..
                "\" recent=\"" .. recentlyCompletedMission.name .. "\""
            )
        else
            Turbine.Shell.WriteLine(
                "MissionHelper DEBUG: completion_late_verified mission=\"" .. candidateMissionName .. "\""
            )
        end
    end
end

local function ParseAnyLeaveChannelMessage(message)
    local trimmed = TrimText(message)
    local regionName, channelName = string.match(trimmed, "^Left%s+the%s+(.+)%s+[%-%–]%s+(.+)%s+channel%.?$")
    if regionName == nil or channelName == nil then
        return nil, nil
    end

    return TrimText(regionName), TrimText(channelName)
end

local function IsRegionalLeaveMessage(message)
    local _, channelName = ParseAnyLeaveChannelMessage(message)
    if channelName == nil then
        return false
    end

    return string.lower(channelName) == "regional"
end

local function LooksLikeLeaveChannelMessage(message)
    local lowered = string.lower(TrimText(message))
    return string.find(lowered, "left the", 1, true) ~= nil and
        string.find(lowered, "channel", 1, true) ~= nil
end

local function IsMissionCompleteMessage(trimmedMessage)
    return trimmedMessage == "Mission Complete!" or trimmedMessage == "Mission Completed!"
end

local function NormalizeMissionName(text)
    local normalized = TrimText(text)
    normalized = normalized:gsub("^Mission:%s*", "")
    return TrimText(normalized)
end

local function TryFinalizeFromCompletedCandidate(candidateMissionName, chatType, message)
    if chatType ~= Turbine.ChatType.Quest then
        DebugChatEvent(
            "completed_candidate_nonquest_ignored",
            chatType,
            message,
            "candidate=\"" .. EscapeDebugText(candidateMissionName) .. "\""
        )
        return false
    end

    if not activeMissionRun.isRunning then
        DebugChatEvent(
            "completed_candidate_no_active_run",
            chatType,
            message,
            "candidate=\"" .. EscapeDebugText(candidateMissionName) .. "\""
        )
        return false
    end

    local candidateNormalized = NormalizeMissionName(candidateMissionName)
    local activeNormalized = NormalizeMissionName(activeMissionRun.missionName)

    if candidateNormalized ~= activeNormalized then
        DebugChatEvent(
            "completed_candidate_active_mismatch",
            chatType,
            message,
            "active=\"" .. EscapeDebugText(activeMissionRun.missionName) ..
            "\" candidate=\"" .. EscapeDebugText(candidateMissionName) .. "\""
        )
        return false
    end

    StopMissionRunAndPersist(activeMissionRun.missionName)
    ResetCompletedCandidate()
    DebugChatEvent(
        "completion_finalized_from_completed_candidate",
        chatType,
        message,
        "mission=\"" .. EscapeDebugText(activeMissionRun.missionName) .. "\""
    )

    return true
end

function DetectMission(message, chatType)
    local now = Turbine.Engine.GetGameTime()
    local trimmedMessage = TrimText(message)

    AdvanceStartWindow(now)
    AdvanceCompletedCandidate(now)

    if recentlyCompletedMission.active and not IsRecentCompletionValid(now) then
        recentlyCompletedMission.active = false
        recentlyCompletedMission.name = nil
        recentlyCompletedMission.completedAtGameTime = 0
    end

    local leaveRegion, leaveChannel = ParseAnyLeaveChannelMessage(message)
    if leaveRegion ~= nil then
        DebugChatEvent(
            "leave_channel_match_any",
            chatType,
            message,
            "region=\"" .. EscapeDebugText(leaveRegion) .. "\" channelInText=\"" .. EscapeDebugText(leaveChannel) .. "\""
        )
    elseif LooksLikeLeaveChannelMessage(message) then
        DebugChatEvent("leave_channel_probe_unparsed", chatType, message)
    end

    if IsRegionalLeaveMessage(message) then
        DebugChatEvent("regional_leave_match", chatType, message)

        if chatType == Turbine.ChatType.Regional then
            OpenStartWindow(now, chatType, message)
        else
            DebugChatEvent("regional_leave_nonregional_fallback_opened", chatType, message)
            OpenStartWindow(now, chatType, message)
        end

        return
    end

    if IsMissionCompleteMessage(trimmedMessage) then
        DebugChatEvent("mission_complete_observed_noop", chatType, message)
        return
    end

    local completedMissionNameInline, headerOnly = ParseCompletedMissionFromMessage(message)
    if completedMissionNameInline ~= nil then
        DebugChatEvent("completed_candidate", chatType, message, "kind=inline")
        SetCompletedCandidate(completedMissionNameInline, chatType, now)
        HandleCompletedCandidateVerification(completedMissionNameInline, now)
        TryFinalizeFromCompletedCandidate(completedMissionNameInline, chatType, message)
    elseif headerOnly then
        DebugChatEvent("completed_candidate", chatType, message, "kind=header")
        SetCompletedCandidateAwaitingContinuation(chatType, now)
    elseif completedCandidate.active and completedCandidate.awaitingContinuation and trimmedMessage ~= "" then
        DebugChatEvent("completed_candidate", chatType, message, "kind=continuation")
        SetCompletedCandidate(trimmedMessage, chatType, now)
        HandleCompletedCandidateVerification(trimmedMessage, now)
        TryFinalizeFromCompletedCandidate(trimmedMessage, chatType, message)
    end

    local missionName = NormalizeMissionNameFromQuestMessage(message)
    if missionName == nil then
        return
    end

    if IsExcludedMissionQuest(missionName) then
        DebugChatEvent(
            "excluded_mission_quest_detected",
            chatType,
            message,
            "mission=\"" .. EscapeDebugText(missionName) .. "\""
        )
        return
    end

    if not IsKnownMissionQuest(missionName) then
        DebugChatEvent(
            "quest_non_mission_ignored",
            chatType,
            message,
            "mission=\"" .. EscapeDebugText(missionName) .. "\""
        )
        return
    end

    if not expectedQuestChatTypes[chatType] then
        DebugChatEvent("quest_unexpected", chatType, message)
    end

    if IsDuplicateMissionDetection(missionName) then
        DebugChatEvent("quest_duplicate_suppressed", chatType, message, "mission=\"" .. EscapeDebugText(missionName) .. "\"")
        return
    end

    DebugChatEvent(
        "quest_parsed",
        chatType,
        message,
        "mission=\"" .. EscapeDebugText(missionName) .. "\" startWindowActive=" .. tostring(pendingStartWindow.active)
    )

    if pendingStartWindow.active then
        DebugChatEvent("start_window_consumed", chatType, message, "mission=\"" .. EscapeDebugText(missionName) .. "\"")
        Turbine.Shell.WriteLine("<rgb=#00FF00>*** MISSION START DETECTED ***</rgb>")
        Turbine.Shell.WriteLine("<rgb=#00FF00>Mission: " .. missionName .. "</rgb>")
        pendingStartWindow.active = false
        StartMissionRun(missionName)
    else
        Turbine.Shell.WriteLine("<rgb=#00FF00>*** MISSION QUEST DETECTED ***</rgb>")
        Turbine.Shell.WriteLine("<rgb=#00FF00>Mission: " .. missionName .. "</rgb>")
    end

    ShowMissionInfoFromName(missionName)
end

function AddCallback(object, event, callback)
    if object[event] == nil then
        object[event] = callback
    else
        if type(object[event]) == "table" then
            table.insert(object[event], callback)
        else
            object[event] = {object[event], callback}
        end
    end
    return callback
end

function PluginLoad(_sender, _args)
    BuildChatTypeNameMap()

    Turbine.Shell.WriteLine("<rgb=#DAA520>MissionHelper " ..
        Plugins["MissionHelper"]:GetVersion() .. " loaded</rgb>")

    LoadSettings()
    MissionStatsManager:Load()

    missionWindow = MissionWindow()
    missionButton = MissionButton()

    missionWindow.Update = function()
        UpdateLiveMissionTimer()
    end
    missionWindow:SetWantsUpdates(true)

    ChatLog = Turbine.Chat
    MissionChatHandler = function(_s, chatArgs)
        local message = tostring(chatArgs.Message)
        DetectMission(message, chatArgs.ChatType)
    end
    AddCallback(ChatLog, "Received", MissionChatHandler)

    Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Listening for mission starts...</rgb>")
end

function PluginUnload(sender, args)
    SaveSettings()
    MissionStatsManager:Save()

    if missionWindow then
        missionWindow:SetVisible(false)
        missionWindow = nil
    end

    if missionButton then
        missionButton:SetVisible(false)
        missionButton = nil
    end

    Turbine.Shell.WriteLine("<rgb=#DAA520>MissionHelper unloaded</rgb>")
end

Plugin.Load = PluginLoad
Plugin.Unload = PluginUnload

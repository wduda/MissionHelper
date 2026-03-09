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
    isRunning = false,
    delvingDetected = false,
    delvingTier = nil,
    delvingGem = nil
}

local LOC_SCAN_WINDOW_MAX_SECONDS = 8
local LOC_SCAN_SUPPORTED_CHAT_TYPES = {
    [Turbine.ChatType.Standard] = true,
    [Turbine.ChatType.Advancement] = true
}
local MALICE_CYCLE_LENGTH_DAYS = 6
local MALICE_RESET_SECONDS = 3 * 60 * 60
local MALICE_SERVER_OFFSETS = {
    ["Default"] = 0,
    ["Orcrist"] = 6,
    ["Peregrin"] = 4,
    ["Meriadoc"] = 0,
    ["Glamdring"] = 0,
    ["Angmar"] = 0,
    ["Mordor"] = 0,
    ["Treebeard"] = 0,
    ["Grond"] = 5,
    ["Sting"] = 2
}

local pendingLocScan = {
    isListening = false,
    startedAtGameTime = 0
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

local function IsLeapYear(year)
    local parsedYear = tonumber(year)
    if parsedYear == nil then
        return false
    end

    if math.fmod(parsedYear, 4) ~= 0 then
        return false
    end

    if math.fmod(parsedYear, 100) == 0 and math.fmod(parsedYear, 400) ~= 0 then
        return false
    end

    return true
end

local function GetMonthDayTable(year)
    if IsLeapYear(year) then
        return {31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    end

    return {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
end

local function CopyDateTime(dateTime)
    if dateTime == nil then
        return nil
    end

    local copied = {}
    copied.Year = tonumber(dateTime.Year)
    copied.Month = tonumber(dateTime.Month)
    copied.Day = tonumber(dateTime.Day)
    copied.Hour = tonumber(dateTime.Hour)
    copied.Minute = tonumber(dateTime.Minute)
    copied.Second = tonumber(dateTime.Second)
    return copied
end

local function GetDayOfWeek(dateTime)
    local value = dateTime
    if value == nil then
        value = Turbine.Engine:GetDate()
    end

    local year = tonumber(value.Year)
    local month = tonumber(value.Month)
    local day = tonumber(value.Day)
    if year == nil or month == nil or day == nil then
        return 1
    end

    local centuryRemainder = math.floor(year - (math.floor(year / 100) * 100))
    local yearQuarter = math.floor(centuryRemainder / 4)
    local monthAdjust = {1, 4, 4, 0, 2, 5, 0, 3, 6, 1, 4, 6}

    if IsLeapYear(year) then
        monthAdjust = {0, 3, 4, 0, 2, 5, 0, 3, 6, 1, 4, 6}
    end

    local sum = centuryRemainder + yearQuarter + day + monthAdjust[month]
    if year < 1800 then
        sum = sum + 4
    elseif year < 1900 then
        sum = sum + 2
    elseif year >= 2000 then
        sum = sum - 1
    end

    local whole, remainder = math.modf(sum / 7)
    local dayOfWeek = math.floor(remainder * 7 + 0.001)
    if dayOfWeek == 0 then
        dayOfWeek = 7
    end

    return dayOfWeek
end

local function ShiftDateByOneDay(dateTime, direction)
    local shifted = dateTime
    local monthDays = GetMonthDayTable(shifted.Year)

    if direction > 0 then
        shifted.Day = shifted.Day + 1
        if shifted.Day > monthDays[shifted.Month] then
            shifted.Day = 1
            shifted.Month = shifted.Month + 1
            if shifted.Month > 12 then
                shifted.Month = 1
                shifted.Year = shifted.Year + 1
            end
        end
    else
        shifted.Day = shifted.Day - 1
        if shifted.Day < 1 then
            shifted.Month = shifted.Month - 1
            if shifted.Month < 1 then
                shifted.Month = 12
                shifted.Year = shifted.Year - 1
            end
            monthDays = GetMonthDayTable(shifted.Year)
            shifted.Day = monthDays[shifted.Month]
        end
    end

    return shifted
end

local function GetLocalEpochTime(dateTime)
    local value = CopyDateTime(dateTime)
    if value == nil then
        value = CopyDateTime(Turbine.Engine:GetDate())
    end

    local now = Turbine.Engine:GetDate()
    if value.Hour == nil then
        value.Hour = now.Hour
    end
    if value.Minute == nil then
        value.Minute = now.Minute
    end
    if value.Second == nil then
        value.Second = now.Second
    end

    local year = tonumber(value.Year)
    local month = tonumber(value.Month)
    local day = tonumber(value.Day)
    if year == nil or month == nil or day == nil then
        return 0
    end

    local seconds = value.Hour * 3600 + value.Minute * 60 + value.Second

    for tmpYear = 1970, year - 1 do
        if IsLeapYear(tmpYear) then
            seconds = seconds + 31622400
        else
            seconds = seconds + 31536000
        end
    end

    local monthDays = GetMonthDayTable(year)
    for tmpMonth = 1, month - 1 do
        seconds = seconds + monthDays[tmpMonth] * 86400
    end

    seconds = seconds + (day - 1) * 86400
    return seconds
end

local function GetLocalTimeZoneHours()
    local localEpoch = GetLocalEpochTime(Turbine.Engine:GetDate())
    local utcEpoch = Turbine.Engine:GetLocalTime()
    local offsetHours = (localEpoch - utcEpoch) / 3600
    return math.floor(offsetHours + 0.5)
end

local function IsUSEastDST(dateTime)
    local value = CopyDateTime(dateTime)
    if value == nil then
        value = CopyDateTime(Turbine.Engine:GetDate())
    end

    if value.Month < 3 or value.Month > 11 then
        return false
    end

    if value.Month > 3 and value.Month < 11 then
        return true
    end

    if value.Month == 3 then
        local marchFirstDow = GetDayOfWeek({Year = value.Year, Month = 3, Day = 1})
        local secondSunday = 8
        if marchFirstDow > 1 then
            secondSunday = 16 - marchFirstDow
        end

        if value.Day > secondSunday then
            return true
        end
        if value.Day == secondSunday and value.Hour >= 2 then
            return true
        end
        return false
    end

    local novemberFirstDow = GetDayOfWeek({Year = value.Year, Month = 11, Day = 1})
    local firstSunday = 1
    if novemberFirstDow > 1 then
        firstSunday = 9 - novemberFirstDow
    end

    if value.Day < firstSunday then
        return true
    end
    if value.Day == firstSunday and value.Hour < 2 then
        return true
    end

    return false
end

local function IsServerDST(localDateTime)
    local serverDate = CopyDateTime(localDateTime)
    if serverDate == nil then
        serverDate = CopyDateTime(Turbine.Engine:GetDate())
    end

    local localOffset = GetLocalTimeZoneHours()
    local utcHour = serverDate.Hour - localOffset
    local adjustedHour = utcHour - 4

    while adjustedHour > 23 do
        adjustedHour = adjustedHour - 24
        serverDate = ShiftDateByOneDay(serverDate, 1)
    end
    while adjustedHour < 0 do
        adjustedHour = adjustedHour + 24
        serverDate = ShiftDateByOneDay(serverDate, -1)
    end

    serverDate.Hour = adjustedHour
    return IsUSEastDST(serverDate)
end

local function ParseServerNameFromLocMessage(message)
    local trimmed = TrimText(message)
    if trimmed == "" then
        return nil
    end

    local englishServerName = string.match(trimmed, "^You are on (.-) server .*")
    if englishServerName ~= nil and englishServerName ~= "" then
        return TrimText(englishServerName)
    end

    local germanServerName = string.match(trimmed, "^Ihr seid auf dem Server \"(.-)\" .*")
    if germanServerName ~= nil and germanServerName ~= "" then
        return TrimText(germanServerName)
    end

    local frenchServerName = string.match(trimmed, "^Vous vous trouvez sur (.-), serveur .*")
    if frenchServerName ~= nil and frenchServerName ~= "" then
        return TrimText(frenchServerName)
    end

    return nil
end

local function GetScanLocAliasCommand()
    if Turbine.Shell ~= nil and Turbine.Shell.IsCommand ~= nil then
        if Turbine.Shell.IsCommand("hilfe") then
            return "/pos"
        end

        if Turbine.Shell.IsCommand("aide") then
            return "/emp"
        end
    end

    return "/loc"
end

local function CalculateCurrentMaliceDay(serverName)
    local offset = MALICE_SERVER_OFFSETS["Default"]
    if serverName ~= nil and MALICE_SERVER_OFFSETS[serverName] ~= nil then
        offset = MALICE_SERVER_OFFSETS[serverName]
    end

    local localTimeZone = GetLocalTimeZoneHours()
    local serverUtcOffset = -5
    if IsServerDST(Turbine.Engine:GetDate()) then
        serverUtcOffset = -4
    end

    local timeZoneOffset = serverUtcOffset - localTimeZone
    local serverEpoch = GetLocalEpochTime(Turbine.Engine:GetDate()) + (timeZoneOffset * 3600)
    local adjustedEpoch = serverEpoch - MALICE_RESET_SECONDS
    local daysSinceEpoch = math.floor(adjustedEpoch / 86400)

    local cycleDayZeroBased = math.fmod(daysSinceEpoch, MALICE_CYCLE_LENGTH_DAYS)
    if cycleDayZeroBased < 0 then
        cycleDayZeroBased = cycleDayZeroBased + MALICE_CYCLE_LENGTH_DAYS
    end

    local shifted = cycleDayZeroBased + offset
    while shifted >= MALICE_CYCLE_LENGTH_DAYS do
        shifted = shifted - MALICE_CYCLE_LENGTH_DAYS
    end
    while shifted < 0 do
        shifted = shifted + MALICE_CYCLE_LENGTH_DAYS
    end

    return shifted + 1
end

local function StartLocScan()
    pendingLocScan.isListening = true
    pendingLocScan.startedAtGameTime = Turbine.Engine.GetGameTime()
end

local function HandleLocScanChatMessage(message, chatType)
    if not pendingLocScan.isListening then
        return
    end

    local now = Turbine.Engine.GetGameTime()
    if (now - pendingLocScan.startedAtGameTime) > LOC_SCAN_WINDOW_MAX_SECONDS then
        pendingLocScan.isListening = false
        return
    end

    if LOC_SCAN_SUPPORTED_CHAT_TYPES[chatType] ~= true then
        return
    end

    local serverName = ParseServerNameFromLocMessage(message)
    if serverName == nil then
        return
    end

    pendingLocScan.isListening = false

    local maliceDay = CalculateCurrentMaliceDay(serverName)
    if missionWindow ~= nil then
        missionWindow:SetMaliceDay(maliceDay)
    end

    Turbine.Shell.WriteLine("MissionHelper: Detected server \"" .. serverName .. "\". Malice set: " .. tostring(maliceDay))
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
    activeMissionRun.delvingDetected = false
    activeMissionRun.delvingTier = nil
    activeMissionRun.delvingGem = nil
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
    activeMissionRun.delvingDetected = false
    activeMissionRun.delvingTier = nil
    activeMissionRun.delvingGem = nil

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
    local regionName, channelName = string.match(trimmed, "^Left%s+the%s+(.+)%s+%-%s+(.+)%s+channel%.?$")
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

local function IsValidDelvingGemForTier(tier, gemName)
    if tier == nil or gemName == nil then
        return false
    end

    local gem = string.lower(TrimText(gemName))
    if tier >= 1 and tier <= 3 then
        return gem == "zircon"
    end
    if tier >= 4 and tier <= 6 then
        return gem == "garnet"
    end
    if tier >= 7 and tier <= 9 then
        return gem == "emerald"
    end
    if tier >= 10 and tier <= 12 then
        return gem == "amethyst"
    end

    return false
end

local function ParseDelvingTierQuestFromMessage(message)
    local tierText, gemName = string.match(message, "^New Quest:%s*Tier%s*(%d+)%s*:%s*Delving%s+([A-Za-z]+)%s*$")
    if tierText == nil then
        tierText, gemName = string.match(message, "^New Quest:%s*Tier%s*(%d+)%s+Delving%s+([A-Za-z]+)%s*$")
    end
    if tierText == nil then
        return nil
    end

    local tierNumber = tonumber(tierText)
    if tierNumber == nil or tierNumber < 1 or tierNumber > 12 then
        return nil
    end

    if not IsValidDelvingGemForTier(tierNumber, gemName) then
        return nil
    end

    return {
        tier = tierNumber,
        gem = TrimText(gemName)
    }
end

local function HandleDelvingTierQuestDetected(delvingInfo, chatType, message)
    if not activeMissionRun.isRunning then
        return false
    end

    activeMissionRun.isRunning = false
    activeMissionRun.delvingDetected = true
    activeMissionRun.delvingTier = delvingInfo.tier
    activeMissionRun.delvingGem = delvingInfo.gem
    lastTimerUiSecond = -1

    if missionWindow ~= nil and activeMissionRun.missionName ~= nil then
        missionWindow:SetDelvingTimerStopped(activeMissionRun.missionName)
    end

    DebugChatEvent(
        "delving_tier_detected",
        chatType,
        message,
        "mission=\"" .. EscapeDebugText(activeMissionRun.missionName) ..
        "\" tier=" .. tostring(delvingInfo.tier) ..
        " gem=\"" .. EscapeDebugText(delvingInfo.gem) .. "\""
    )

    Turbine.Shell.WriteLine("<rgb=#FFD700>MissionHelper: Delving tier detected for current run (Tier " ..
        tostring(delvingInfo.tier) .. " " .. delvingInfo.gem .. "). Timer frozen at 00:00 and run excluded from stats.</rgb>")

    return true
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
        if activeMissionRun.delvingDetected and activeMissionRun.missionName ~= nil then
            local candidateNormalized = NormalizeMissionName(candidateMissionName)
            local activeNormalized = NormalizeMissionName(activeMissionRun.missionName)
            if candidateNormalized == activeNormalized then
                DebugChatEvent(
                    "completion_ignored_delving_run",
                    chatType,
                    message,
                    "mission=\"" .. EscapeDebugText(activeMissionRun.missionName) .. "\""
                )
                activeMissionRun.delvingDetected = false
                activeMissionRun.delvingTier = nil
                activeMissionRun.delvingGem = nil
                activeMissionRun.missionName = nil
                activeMissionRun.startedAtGameTime = 0
                ResetCompletedCandidate()
                return true
            end
        end

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

    local delvingInfo = ParseDelvingTierQuestFromMessage(message)
    if delvingInfo ~= nil then
        HandleDelvingTierQuestDetected(delvingInfo, chatType, message)
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
    missionWindow:SetScanAlias(GetScanLocAliasCommand())
    missionWindow:SetScanRequestedCallback(function()
        StartLocScan()
    end)
    missionWindow:SetSuggestMissionsRequestedCallback(function()
        return
    end)
    missionWindow:SetSuggestDelvingsRequestedCallback(function()
        return
    end)

    missionWindow.Update = function()
        UpdateLiveMissionTimer()
    end
    missionWindow:SetWantsUpdates(true)

    ChatLog = Turbine.Chat
    MissionChatHandler = function(_s, chatArgs)
        local message = tostring(chatArgs.Message)
        HandleLocScanChatMessage(message, chatArgs.ChatType)
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


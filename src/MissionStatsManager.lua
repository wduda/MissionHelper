import "Turbine"
import "MissionHelper.src.VindarPatch"

--[[ MissionStatsManager - Mission completion stats persistence ]]--
--[[ Stores completion counts and timing stats at character/account scope ]]--

MissionStatsManager = {}

local CHARACTER_STATS_KEY = "MissionHelperMissionStatsCharacter"
local ACCOUNT_STATS_KEY = "MissionHelperMissionStatsAccount"
local STATS_VERSION = 1

local function CreateDefaultStatsTable()
    return {
        version = STATS_VERSION,
        missions = {}
    }
end

local function EnsureStatsTableShape(statsTable)
    if type(statsTable) ~= "table" then
        return CreateDefaultStatsTable()
    end

    if type(statsTable.missions) ~= "table" then
        statsTable.missions = {}
    end

    if statsTable.version == nil then
        statsTable.version = STATS_VERSION
    end

    return statsTable
end

local function EnsureMissionStatsEntry(statsTable, missionName)
    if type(statsTable.missions[missionName]) ~= "table" then
        statsTable.missions[missionName] = {
            count = 0,
            lastDurationSec = 0,
            bestDurationSec = 0,
            averageDurationSec = 0,
            totalDurationSec = 0
        }
    end

    return statsTable.missions[missionName]
end

local function RecordCompletionInScope(statsTable, missionName, durationSec)
    local entry = EnsureMissionStatsEntry(statsTable, missionName)

    entry.count = (tonumber(entry.count) or 0) + 1
    entry.lastDurationSec = durationSec

    local previousBest = tonumber(entry.bestDurationSec) or 0
    if previousBest <= 0 then
        entry.bestDurationSec = durationSec
    else
        entry.bestDurationSec = math.min(previousBest, durationSec)
    end

    entry.totalDurationSec = (tonumber(entry.totalDurationSec) or 0) + durationSec
    entry.averageDurationSec = entry.totalDurationSec / entry.count
end

function MissionStatsManager:Load()
    self.characterStats = EnsureStatsTableShape(PatchDataLoad(Turbine.DataScope.Character, CHARACTER_STATS_KEY))
    self.accountStats = EnsureStatsTableShape(PatchDataLoad(Turbine.DataScope.Account, ACCOUNT_STATS_KEY))
end

function MissionStatsManager:Save()
    if self.characterStats == nil then
        self.characterStats = CreateDefaultStatsTable()
    end

    if self.accountStats == nil then
        self.accountStats = CreateDefaultStatsTable()
    end

    PatchDataSave(Turbine.DataScope.Character, CHARACTER_STATS_KEY, self.characterStats)
    PatchDataSave(Turbine.DataScope.Account, ACCOUNT_STATS_KEY, self.accountStats)
end

function MissionStatsManager:RecordCompletion(missionName, durationSec)
    if missionName == nil or missionName == "" then
        return
    end

    local duration = tonumber(durationSec) or 0
    if duration < 0 then
        duration = 0
    end

    if self.characterStats == nil or self.accountStats == nil then
        self:Load()
    end

    RecordCompletionInScope(self.characterStats, missionName, duration)
    RecordCompletionInScope(self.accountStats, missionName, duration)

    self:Save()
end

function MissionStatsManager:GetMissionStats(missionName)
    local characterEntry = nil
    local accountEntry = nil

    if self.characterStats ~= nil and self.characterStats.missions ~= nil then
        characterEntry = self.characterStats.missions[missionName]
    end

    if self.accountStats ~= nil and self.accountStats.missions ~= nil then
        accountEntry = self.accountStats.missions[missionName]
    end

    return {
        character = characterEntry,
        account = accountEntry
    }
end

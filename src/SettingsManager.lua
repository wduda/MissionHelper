import "Turbine"
import "MissionHelper.src.VindarPatch"

--[[ SettingsManager - Settings management and persistence ]]--
--[[ Handles loading, saving, and managing all plugin settings ]]--

SettingsConfig = {}
Settings = {}

-- Behavioral constants
BehaviorConstants = {
    BUTTON_DRAG_DELAY = 0.2 -- Seconds before drag starts
}

-- Create settings configuration structure
function CreateSettingsConfig()
    SettingsConfig = {}

    -- Button settings
    AddSettingConfig("buttonRelativeX", 0.95)      -- Button X position (95% screen width)
    AddSettingConfig("buttonRelativeY", 0.75)      -- Button Y position (75% screen height)
    AddSettingConfig("buttonVisible", 1)           -- Button visibility (1=visible, 0=hidden)
    AddSettingConfig("buttonMinOpacity", 0.8)      -- Button opacity when not hovering
    AddSettingConfig("buttonMaxOpacity", 1.0)      -- Button opacity when hovering

    -- Window settings
    AddSettingConfig("windowRelativeX", 0.1)       -- Window X position (10% screen width)
    AddSettingConfig("windowRelativeY", 0.1)       -- Window Y position (10% screen height)
    AddSettingConfig("windowVisible", 0)           -- Window startup visibility (1=visible, 0=hidden)
end

-- Add a setting to the configuration
function AddSettingConfig(name, defValue)
    if SettingsConfig[name] == nil then
        SettingsConfig[name] = {}
    end
    SettingsConfig[name].name = name
    SettingsConfig[name].defValue = defValue
end

-- Initialize all settings to default values
function InitDefaultSettings()
    for k, v in pairs(SettingsConfig) do
        Settings[k] = v.defValue
    end
end

-- Initialize a number setting from saved data
function InitNumberSetting(strTable, name, forceDefault)
    if forceDefault then
        Settings[name] = SettingsConfig[name].defValue
    elseif strTable ~= nil and strTable[name] ~= nil then
        Settings[name] = tonumber(strTable[name])
        -- Validate loaded value
        if Settings[name] == nil then
            Settings[name] = SettingsConfig[name].defValue
        end
    else
        Settings[name] = SettingsConfig[name].defValue
    end
end

-- Load settings from PluginData
function LoadSettings()
    -- Create settings configuration
    CreateSettingsConfig()

    -- Initialize to defaults first
    InitDefaultSettings()

    -- Try to load saved settings
    local settingsStrings = PatchDataLoad(Turbine.DataScope.Character, "MissionHelperSettings")

    -- If settings exist, apply them
    if settingsStrings ~= nil then
        for k, v in pairs(SettingsConfig) do
            InitNumberSetting(settingsStrings, k, false)
        end

        Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Settings loaded</rgb>")
    else
        Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Using default settings</rgb>")
    end
end

-- Save settings to PluginData
function SaveSettings(scope)
    if scope == nil then
        scope = Turbine.DataScope.Character
    end

    -- Convert settings to string table for storage
    local settingsStrings = {}

    for k, v in pairs(SettingsConfig) do
        if Settings[k] ~= nil then
            settingsStrings[k] = tostring(Settings[k])
        end
    end

    -- Save using VindarPatch wrapper
    PatchDataSave(scope, "MissionHelperSettings", settingsStrings)
end

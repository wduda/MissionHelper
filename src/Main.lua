import "Turbine";
import "Turbine.Gameplay";
import "Turbine.UI";

-- Import MissionHelper modules
import "MissionHelper.src.VindarPatch";
import "MissionHelper.src.SettingsManager";
import "MissionHelper.src.MissionData";
import "MissionHelper.src.MissionWindow";
import "MissionHelper.src.MissionButton";

--[[ MissionHelper - Main Plugin File ]]--
--[[ Detects mission starts from chat and displays mission help ]]--

-- Plugin initialization
Plugin = Turbine.Plugin;
Player = Turbine.Gameplay.LocalPlayer:GetInstance();

-- Store last accepted mission info for manual window opens
lastMissionInfo = nil;

-- Plugin load handler
function PluginLoad(_sender, _args)
    Turbine.Shell.WriteLine("<rgb=#DAA520>MissionHelper " ..
        Plugins["MissionHelper"]:GetVersion() .. " loaded</rgb>");

    -- Load settings FIRST (before creating UI)
    LoadSettings();

    -- Create mission window (singleton)
    missionWindow = MissionWindow();

    -- Create toggle button
    missionButton = MissionButton();

    -- Set up chat listener
    ChatLog = Turbine.Chat;
    MissionChatHandler = function(_s, chatArgs)
        -- Listen to Standard chat type and other common types for mission messages
        -- Note: We cast a wide net since we don't know exact chat type for missions yet
        if chatArgs.ChatType == Turbine.ChatType.Standard or
           chatArgs.ChatType == Turbine.ChatType.Advancement or
           chatArgs.ChatType == Turbine.ChatType.Quest or
           chatArgs.ChatType == Turbine.ChatType.PlayerCombat then
            local message = tostring(chatArgs.Message);
            DetectMission(message);
        end
    end
    AddCallback(ChatLog, "Received", MissionChatHandler);

    Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Listening for mission starts...</rgb>");
end

-- Detect mission start from chat message
function DetectMission(message)
    -- Pattern: "New Quest: Mission: [Mission Name]"
    local missionName = string.match(message, "New Quest: Mission:%s*(.+)")

    if missionName then
        -- Clean up mission name (remove trailing whitespace)
        missionName = missionName:gsub("%s*$", "")

        -- Debug output
        Turbine.Shell.WriteLine("<rgb=#00FF00>*** MISSION DETECTED ***</rgb>")
        Turbine.Shell.WriteLine("<rgb=#00FF00>Mission: " .. missionName .. "</rgb>")

        local missionInfo = nil

        -- Show the window for every detected mission, with fallback text if unknown
        if MissionData:HasMission(missionName) then
            missionInfo = MissionData:GetMissionInfo(missionName)
        else
            missionInfo = {
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
            Turbine.Shell.WriteLine("<rgb=#FFFF00>Note: No help data for mission: " .. missionName .. "</rgb>")
        end

        -- Ensure detected chat name is always shown in the window title row
        missionInfo.name = missionName

        -- remember last accepted mission in case user opens window manually
        lastMissionInfo = missionInfo

        if missionWindow == nil then
            missionWindow = MissionWindow()
        end

        missionWindow:ShowMission(missionInfo)
        Turbine.Shell.WriteLine("<rgb=#90EE90>Mission window displayed</rgb>")
    end
end

-- Helper function to add callbacks to objects
function AddCallback(object, event, callback)
    if (object[event] == nil) then
        object[event] = callback;
    else
        if (type(object[event]) == "table") then
            table.insert(object[event], callback);
        else
            object[event] = {object[event], callback};
        end
    end
    return callback;
end

-- Plugin unload handler
function PluginUnload(sender, args)
    -- Save settings before cleanup
    SaveSettings();

    -- Clean up mission window
    if missionWindow then
        missionWindow:SetVisible(false);
        missionWindow = nil;
    end
    -- Clean up mission button
    if missionButton then
        missionButton:SetVisible(false);
        missionButton = nil;
    end
    Turbine.Shell.WriteLine("<rgb=#DAA520>MissionHelper unloaded</rgb>");
end

-- Register plugin event handlers
Plugin.Load = PluginLoad;
Plugin.Unload = PluginUnload;

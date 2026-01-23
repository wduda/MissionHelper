import "Turbine";
import "Turbine.UI";
import "Turbine.UI.Lotro";
import "MissionHelper.src.SettingsManager";

--[[ MissionWindow - UI Window for displaying mission help ]]--
--[[ Shows mission name and help text when missions are detected ]]--

-- MissionWindow class definition
MissionWindow = class(Turbine.UI.Window);

function MissionWindow:Constructor()
    Turbine.UI.Window.Constructor(self);

    -- Window properties
    self:SetSize(400, 250);

    -- Load position from settings (relative to screen)
    local screenWidth = Turbine.UI.Display.GetWidth();
    local screenHeight = Turbine.UI.Display.GetHeight();
    local windowX = Settings.windowRelativeX * screenWidth;
    local windowY = Settings.windowRelativeY * screenHeight;
    self:SetPosition(windowX, windowY);

    self:SetText("Mission Helper");
    self:SetVisible(Settings.windowVisible == 1);
    self:SetWantsKeyEvents(true);

    -- Title label at top
    self.titleLabel = Turbine.UI.Label();
    self.titleLabel:SetParent(self);
    self.titleLabel:SetPosition(10, 40);
    self.titleLabel:SetSize(380, 30);
    self.titleLabel:SetText("Mission Helper");
    self.titleLabel:SetFont(Turbine.UI.Lotro.Font.TrajanPro16);
    self.titleLabel:SetForeColor(Turbine.UI.Color.Gold);

    -- Mission name label
    self.missionNameLabel = Turbine.UI.Label();
    self.missionNameLabel:SetParent(self);
    self.missionNameLabel:SetPosition(10, 80);
    self.missionNameLabel:SetSize(380, 30);
    self.missionNameLabel:SetFont(Turbine.UI.Lotro.Font.TrajanPro14);
    self.missionNameLabel:SetForeColor(Turbine.UI.Color.White);

    -- Help text label
    self.helpTextLabel = Turbine.UI.Label();
    self.helpTextLabel:SetParent(self);
    self.helpTextLabel:SetPosition(10, 120);
    self.helpTextLabel:SetSize(380, 80);
    self.helpTextLabel:SetMultiline(true);
    self.helpTextLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14);
    self.helpTextLabel:SetForeColor(Turbine.UI.Color.LightGray);

    -- Close button
    self.closeButton = Turbine.UI.Lotro.Button();
    self.closeButton:SetParent(self);
    self.closeButton:SetPosition(150, 210);
    self.closeButton:SetSize(100, 25);
    self.closeButton:SetText("Close");

    -- Close button handler
    self.closeButton.Click = function(sender, args)
        self:SetVisible(false);
    end;

    -- Position changed handler - save position when window is dragged
    self.PositionChanged = function(sender, args)
        local posX, posY = self:GetPosition();
        local screenWidth, screenHeight = Turbine.UI.Display.GetSize();
        Settings.windowRelativeX = posX / screenWidth;
        Settings.windowRelativeY = posY / screenHeight;
        SaveSettings();
    end;
end

-- Update window with mission information and show it
-- @param missionInfo: table - Mission info with enhanced fields (region, objectives, tacticalAdvice, etc.)
function MissionWindow:ShowMission(missionInfo)
    if missionInfo then
        self.missionNameLabel:SetText(missionInfo.name);

        -- Build rich display text from available fields
        local displayText = "";

        if missionInfo.region and missionInfo.region ~= "" then
            displayText = displayText .. "Location: " .. missionInfo.region .. "\n\n";
        end

        if missionInfo.duration and missionInfo.duration ~= "" then
            displayText = displayText .. "Duration: " .. missionInfo.duration .. "\n";
        end

        if missionInfo.difficulty and missionInfo.difficulty ~= "" then
            displayText = displayText .. "Difficulty: " .. missionInfo.difficulty .. "\n\n";
        end

        if missionInfo.objectives and missionInfo.objectives ~= "" then
            displayText = displayText .. "Objectives: " .. missionInfo.objectives .. "\n\n";
        end

        if missionInfo.clickableObjectives and missionInfo.clickableObjectives ~= "" then
            displayText = displayText .. "Clickables: " .. missionInfo.clickableObjectives .. "\n\n";
        end

        -- Primary content: tacticalAdvice or fallback to helpText (backwards compatibility)
        local mainContent = missionInfo.tacticalAdvice or missionInfo.helpText or "No tactical information available";
        if mainContent ~= "" then
            displayText = displayText .. "Strategy: " .. mainContent;
        end

        self.helpTextLabel:SetText(displayText);
        self:SetVisible(true);

        -- Save visibility state
        Settings.windowVisible = 1;
        SaveSettings();
    end
end

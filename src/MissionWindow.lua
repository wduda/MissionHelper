import "Turbine"
import "Turbine.UI"
import "Turbine.UI.Lotro"
import "MissionHelper.src.SettingsManager"

--[[ MissionWindow - UI Window for displaying mission help ]]--
--[[ Shows mission name and help text when missions are detected ]]--

MissionWindow = class(Turbine.UI.Window)

local WINDOW_WIDTH = 400
local WINDOW_HEIGHT = 360
local HEADER_PADDING_X = 10
local HEADER_TITLE_Y = 8
local CLOSE_SIZE = 12
local CLOSE_X_OFFSET = 18
local GLOBAL_ROW_ONE_Y = 32
local GLOBAL_ROW_TWO_Y = 56
local MISSION_ROW_Y = 90
local TIMER_ROW_Y = 112
local PREFIX_WIDTH = 110
local CONTENT_Y = 138
local CONTENT_BOTTOM_PADDING = 10
local SCROLLBAR_WIDTH = 10
local SCROLLBAR_GAP = 4
local SCAN_BUTTON_WIDTH = 58
local ACTION_BUTTON_WIDTH = 140
local COLOR_RED = Turbine.UI.Color(1, 0.8, 0.2, 0.2)
local COLOR_RED_HOVER = Turbine.UI.Color(1, 0.95, 0.3, 0.3)
local COLOR_MALICE_HIGHLIGHT = Turbine.UI.Color.LightGreen
local COLOR_MALICE_DEFAULT = Turbine.UI.Color.White

local function TrimText(text)
    if text == nil then
        return ""
    end

    local str = tostring(text)
    str = str:gsub("^%s+", "")
    str = str:gsub("%s+$", "")
    return str
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

local function GetAccountBestDurationText(missionName)
    if MissionStatsManager == nil or MissionStatsManager.GetMissionStats == nil then
        return "-"
    end

    local stats = MissionStatsManager:GetMissionStats(missionName)
    if stats == nil or stats.account == nil then
        return "-"
    end

    local bestSeconds = tonumber(stats.account.bestDurationSec) or 0
    if bestSeconds <= 0 then
        return "-"
    end

    return FormatDurationMMSS(bestSeconds)
end

local function BuildTimerStatusText(isRunning, liveTimerMissionName, liveTimerElapsedSeconds, lastRunMissionName, lastRunDurationSeconds, forcedZeroMissionName, missionName)
    local accountBestText = GetAccountBestDurationText(missionName)

    if forcedZeroMissionName == missionName then
        return "Run Time: 00:00 | PB: " .. accountBestText
    end

    if isRunning and liveTimerMissionName == missionName then
        return "Run Time: " .. FormatDurationMMSS(liveTimerElapsedSeconds) .. " | PB: " .. accountBestText
    end

    if lastRunMissionName == missionName and lastRunDurationSeconds ~= nil then
        return "Last Run: " .. FormatDurationMMSS(lastRunDurationSeconds) .. " | PB: " .. accountBestText
    end

    return ""
end

local function ClampToScreen(x, y, width, height)
    local screenWidth, screenHeight = Turbine.UI.Display.GetSize()
    local maxX = math.max(0, screenWidth - width)
    local maxY = math.max(0, screenHeight - height)

    local clampedX = math.max(0, math.min(x, maxX))
    local clampedY = math.max(0, math.min(y, maxY))
    return clampedX, clampedY
end

function MissionWindow:ApplySavedPosition()
    local screenWidth, screenHeight = Turbine.UI.Display.GetSize()
    local relativeX = Settings.windowRelativeX or 0.1
    local relativeY = Settings.windowRelativeY or 0.1

    local windowX = relativeX * screenWidth
    local windowY = relativeY * screenHeight
    windowX, windowY = ClampToScreen(windowX, windowY, WINDOW_WIDTH, WINDOW_HEIGHT)
    self:SetPosition(windowX, windowY)
end

function MissionWindow:ClampCurrentPosition()
    local posX, posY = self:GetPosition()
    posX, posY = ClampToScreen(posX, posY, WINDOW_WIDTH, WINDOW_HEIGHT)
    self:SetPosition(posX, posY)
end

function MissionWindow:SaveCurrentPosition()
    local posX, posY = self:GetPosition()
    local screenWidth, screenHeight = Turbine.UI.Display.GetSize()

    if screenWidth <= 0 or screenHeight <= 0 then
        return
    end

    Settings.windowRelativeX = posX / screenWidth
    Settings.windowRelativeY = posY / screenHeight
end

function MissionWindow:Constructor()
    Turbine.UI.Window.Constructor(self)

    self.isDragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0

    self:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    self:SetBackColor(Turbine.UI.Color.Black)
    self:SetText("")
    self:SetVisible(Settings.windowVisible == 1)
    self:SetWantsKeyEvents(true)
    self:ApplySavedPosition()

    self.currentMissionInfo = nil
    self.liveTimerMissionName = nil
    self.liveTimerElapsedSeconds = 0
    self.liveTimerIsRunning = false
    self.lastRunMissionName = nil
    self.lastRunDurationSeconds = nil
    self.forcedZeroTimerMissionName = nil
    self.onScanRequested = nil
    self.onSuggestMissionsRequested = nil
    self.onSuggestDelvingsRequested = nil

    -- Header title label (drag handle)
    self.headerTitleLabel = Turbine.UI.Label()
    self.headerTitleLabel:SetParent(self)
    self.headerTitleLabel:SetPosition(HEADER_PADDING_X, HEADER_TITLE_Y)
    self.headerTitleLabel:SetSize(220, 20)
    self.headerTitleLabel:SetText("Mission Helper")
    self.headerTitleLabel:SetFont(Turbine.UI.Lotro.Font.TrajanPro14)
    self.headerTitleLabel:SetForeColor(Turbine.UI.Color.Gold)

    self.headerTitleLabel.MouseDown = function(sender, args)
        if args.Button == Turbine.UI.MouseButton.Left then
            self.isDragging = true
            self.dragOffsetX = args.X
            self.dragOffsetY = args.Y
        end
    end

    self.headerTitleLabel.MouseMove = function(sender, args)
        if self.isDragging then
            local mouseX, mouseY = Turbine.UI.Display.GetMousePosition()
            local newX = mouseX - self.dragOffsetX
            local newY = mouseY - self.dragOffsetY
            newX, newY = ClampToScreen(newX, newY, WINDOW_WIDTH, WINDOW_HEIGHT)
            self:SetPosition(newX, newY)
        end
    end

    self.headerTitleLabel.MouseUp = function(sender, args)
        if args.Button == Turbine.UI.MouseButton.Left then
            self.isDragging = false
            self:SaveCurrentPosition()
            SaveSettings()
        end
    end

    -- Custom red close control
    self.redCloseControl = Turbine.UI.Control()
    self.redCloseControl:SetParent(self)
    self.redCloseControl:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    self.redCloseControl:SetPosition(WINDOW_WIDTH - CLOSE_X_OFFSET, HEADER_TITLE_Y)
    self.redCloseControl:SetBackColor(COLOR_RED)

    self.redCloseControl.MouseEnter = function(sender, args)
        self.redCloseControl:SetBackColor(COLOR_RED_HOVER)
    end

    self.redCloseControl.MouseLeave = function(sender, args)
        self.redCloseControl:SetBackColor(COLOR_RED)
    end

    self.redCloseControl.MouseClick = function(sender, args)
        self:SetVisible(false)
        Settings.windowVisible = 0
        SaveSettings()
    end

    self.maliceSetPrefixLabel = Turbine.UI.Label()
    self.maliceSetPrefixLabel:SetParent(self)
    self.maliceSetPrefixLabel:SetPosition(HEADER_PADDING_X, GLOBAL_ROW_ONE_Y)
    self.maliceSetPrefixLabel:SetSize(80, 20)
    self.maliceSetPrefixLabel:SetText("Malice Set:")
    self.maliceSetPrefixLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.maliceSetPrefixLabel:SetForeColor(Turbine.UI.Color.LightGray)

    self.maliceSetValueLabel = Turbine.UI.Label()
    self.maliceSetValueLabel:SetParent(self)
    self.maliceSetValueLabel:SetPosition(HEADER_PADDING_X + 82, GLOBAL_ROW_ONE_Y)
    self.maliceSetValueLabel:SetSize(40, 20)
    self.maliceSetValueLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.maliceSetValueLabel:SetForeColor(COLOR_MALICE_DEFAULT)
    self.maliceSetValueLabel:SetText("5")

    self.scanButton = Turbine.UI.Lotro.Button()
    self.scanButton:SetParent(self)
    self.scanButton:SetSize(SCAN_BUTTON_WIDTH, 20)
    self.scanButton:SetPosition(WINDOW_WIDTH - HEADER_PADDING_X - SCAN_BUTTON_WIDTH, GLOBAL_ROW_ONE_Y)
    self.scanButton:SetText("Scan")
    self.scanButton.Click = function()
        if type(self.onScanRequested) == "function" then
            self.onScanRequested()
        end
    end

    self.scanQuickslot = Turbine.UI.Lotro.Quickslot()
    self.scanQuickslot:SetParent(self)
    self.scanQuickslot:SetPosition(WINDOW_WIDTH - HEADER_PADDING_X - SCAN_BUTTON_WIDTH, GLOBAL_ROW_ONE_Y)
    self.scanQuickslot:SetSize(SCAN_BUTTON_WIDTH, 20)
    self.scanQuickslot:SetAllowDrop(false)
    self.scanQuickslot:SetVisible(true)
    self.scanQuickslot:SetOpacity(0.01)
    self.scanQuickslot:SetZOrder(self.scanButton:GetZOrder() + 1)
    self.scanQuickslot.MouseClick = function()
        if type(self.onScanRequested) == "function" then
            self.onScanRequested()
        end
    end
    self:SetScanAlias("/loc")

    self.suggestMissionsButton = Turbine.UI.Lotro.Button()
    self.suggestMissionsButton:SetParent(self)
    self.suggestMissionsButton:SetSize(ACTION_BUTTON_WIDTH, 22)
    self.suggestMissionsButton:SetPosition(HEADER_PADDING_X, GLOBAL_ROW_TWO_Y)
    self.suggestMissionsButton:SetText("Suggest Missions")
    self.suggestMissionsButton.Click = function()
        if type(self.onSuggestMissionsRequested) == "function" then
            self.onSuggestMissionsRequested()
        end
    end

    self.suggestDelvingsButton = Turbine.UI.Lotro.Button()
    self.suggestDelvingsButton:SetParent(self)
    self.suggestDelvingsButton:SetSize(ACTION_BUTTON_WIDTH, 22)
    self.suggestDelvingsButton:SetPosition(
        WINDOW_WIDTH - HEADER_PADDING_X - ACTION_BUTTON_WIDTH,
        GLOBAL_ROW_TWO_Y
    )
    self.suggestDelvingsButton:SetText("Suggest Delvings")
    self.suggestDelvingsButton.Click = function()
        if type(self.onSuggestDelvingsRequested) == "function" then
            self.onSuggestDelvingsRequested()
        end
    end

    -- Mission row
    self.currentMissionPrefixLabel = Turbine.UI.Label()
    self.currentMissionPrefixLabel:SetParent(self)
    self.currentMissionPrefixLabel:SetPosition(HEADER_PADDING_X, MISSION_ROW_Y)
    self.currentMissionPrefixLabel:SetSize(PREFIX_WIDTH, 20)
    self.currentMissionPrefixLabel:SetText("Current Mission:")
    self.currentMissionPrefixLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.currentMissionPrefixLabel:SetForeColor(Turbine.UI.Color.LightGray)

    self.currentMissionValueLabel = Turbine.UI.Label()
    self.currentMissionValueLabel:SetParent(self)
    self.currentMissionValueLabel:SetPosition(HEADER_PADDING_X + PREFIX_WIDTH, MISSION_ROW_Y)
    self.currentMissionValueLabel:SetSize(WINDOW_WIDTH - (HEADER_PADDING_X + PREFIX_WIDTH) - HEADER_PADDING_X, 20)
    self.currentMissionValueLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.currentMissionValueLabel:SetForeColor(Turbine.UI.Color.White)
    self.currentMissionValueLabel:SetText("")

    self.timerStatusLabel = Turbine.UI.Label()
    self.timerStatusLabel:SetParent(self)
    self.timerStatusLabel:SetPosition(HEADER_PADDING_X, TIMER_ROW_Y)
    self.timerStatusLabel:SetSize(WINDOW_WIDTH - (HEADER_PADDING_X * 2), 20)
    self.timerStatusLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.timerStatusLabel:SetForeColor(Turbine.UI.Color(1, 0.9, 0.85, 0.5))
    self.timerStatusLabel:SetText("")

    -- Help text area with required TextBox + vertical scrollbar
    local contentHeight = WINDOW_HEIGHT - CONTENT_Y - CONTENT_BOTTOM_PADDING
    local contentWidth = WINDOW_WIDTH - (HEADER_PADDING_X * 2) - SCROLLBAR_WIDTH - SCROLLBAR_GAP

    self.helpTextBox = Turbine.UI.Lotro.TextBox()
    self.helpTextBox:SetParent(self)
    self.helpTextBox:SetPosition(HEADER_PADDING_X, CONTENT_Y)
    self.helpTextBox:SetSize(contentWidth, contentHeight)
    self.helpTextBox:SetMultiline(true)
    self.helpTextBox:SetReadOnly(true)
    self.helpTextBox:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.helpTextBox:SetForeColor(Turbine.UI.Color.LightGray)
    self.helpTextBox:SetText("")

    self.helpTextScrollBar = Turbine.UI.Lotro.ScrollBar()
    self.helpTextScrollBar:SetParent(self)
    self.helpTextScrollBar:SetOrientation(Turbine.UI.Orientation.Vertical)
    self.helpTextScrollBar:SetPosition(HEADER_PADDING_X + contentWidth + SCROLLBAR_GAP, CONTENT_Y)
    self.helpTextScrollBar:SetSize(SCROLLBAR_WIDTH, contentHeight)
    self.helpTextBox:SetVerticalScrollBar(self.helpTextScrollBar)

    self:SetMaliceDay(5)
end

function MissionWindow:SetScanRequestedCallback(callback)
    self.onScanRequested = callback
end

function MissionWindow:SetScanAlias(aliasText)
    if self.scanQuickslot == nil then
        return
    end

    local text = TrimText(aliasText)
    if text == "" then
        text = "/loc"
    end

    local shortcut = Turbine.UI.Lotro.Shortcut(Turbine.UI.Lotro.ShortcutType.Alias, text)
    if shortcut.SetData ~= nil then
        shortcut:SetData(text)
    end
    self.scanQuickslot:SetShortcut(shortcut)
end

function MissionWindow:SetSuggestMissionsRequestedCallback(callback)
    self.onSuggestMissionsRequested = callback
end

function MissionWindow:SetSuggestDelvingsRequestedCallback(callback)
    self.onSuggestDelvingsRequested = callback
end

function MissionWindow:SetMaliceDay(dayNumber)
    local parsedDay = tonumber(dayNumber)
    if parsedDay == nil then
        return
    end

    local renderedDay = math.floor(parsedDay)
    if renderedDay < 1 then
        renderedDay = 1
    end

    self.maliceSetValueLabel:SetText(tostring(renderedDay))
    if renderedDay == 1 or renderedDay == 5 then
        self.maliceSetValueLabel:SetForeColor(COLOR_MALICE_HIGHLIGHT)
    else
        self.maliceSetValueLabel:SetForeColor(COLOR_MALICE_DEFAULT)
    end
end

function MissionWindow:SetLiveTimer(missionName, elapsedSeconds, isRunning)
    self.liveTimerMissionName = missionName
    self.liveTimerElapsedSeconds = tonumber(elapsedSeconds) or 0
    self.liveTimerIsRunning = (isRunning == true)
    self.forcedZeroTimerMissionName = nil

    if not self.liveTimerIsRunning then
        self.lastRunMissionName = missionName
        self.lastRunDurationSeconds = self.liveTimerElapsedSeconds
    end

    if self.currentMissionInfo ~= nil then
        self:RenderMissionText()
    end
end

function MissionWindow:SetDelvingTimerStopped(missionName)
    self.liveTimerMissionName = missionName
    self.liveTimerElapsedSeconds = 0
    self.liveTimerIsRunning = false
    self.lastRunMissionName = nil
    self.lastRunDurationSeconds = nil
    self.forcedZeroTimerMissionName = missionName

    if self.currentMissionInfo ~= nil then
        self:RenderMissionText()
    end
end

function MissionWindow:ClearLiveTimer()
    self.liveTimerMissionName = nil
    self.liveTimerElapsedSeconds = 0
    self.liveTimerIsRunning = false
    self.forcedZeroTimerMissionName = nil

    if self.currentMissionInfo ~= nil then
        self:RenderMissionText()
    end
end

function MissionWindow:RenderMissionText()
    if self.currentMissionInfo == nil then
        self.timerStatusLabel:SetText("")
        self.helpTextBox:SetText("no helptext")
        return
    end

    local missionInfo = self.currentMissionInfo
    local missionName = TrimText(missionInfo.name)
    if missionName == "" then
        missionName = "Unknown Mission"
    end
    self.currentMissionValueLabel:SetText(missionName)

    self.timerStatusLabel:SetText(
        BuildTimerStatusText(
            self.liveTimerIsRunning,
            self.liveTimerMissionName,
            self.liveTimerElapsedSeconds,
            self.lastRunMissionName,
            self.lastRunDurationSeconds,
            self.forcedZeroTimerMissionName,
            missionName
        )
    )

    local displayText = ""

    local timeText = TrimText(missionInfo.timeRange)
    if timeText == "" then
        timeText = TrimText(missionInfo.timeAssessment)
    end
    if timeText ~= "" then
        displayText = displayText .. "Time: " .. timeText .. "\n\n"
    end

    local difficultyText = TrimText(missionInfo.difficulty)
    local difficultyDetails = TrimText(missionInfo.difficultyDetails)
    if difficultyText ~= "" then
        if difficultyDetails ~= "" and difficultyDetails ~= difficultyText then
            displayText = displayText .. "Difficulty: " .. difficultyText .. " (" .. difficultyDetails .. ")\n\n"
        else
            displayText = displayText .. "Difficulty: " .. difficultyText .. "\n\n"
        end
    end

    local objectivesText = TrimText(missionInfo.objectives)
    if objectivesText ~= "" then
        displayText = displayText .. "Objectives: " .. objectivesText .. "\n\n"
    end

    local missionDescriptionText = TrimText(missionInfo.missionDescription)
    if missionDescriptionText ~= "" then
        displayText = displayText .. "Mission: " .. missionDescriptionText .. "\n\n"
    end

    local tacticalAdviceText = TrimText(missionInfo.tacticalAdvice)
    if tacticalAdviceText ~= "" then
        displayText = displayText .. "Strategy: " .. tacticalAdviceText .. "\n\n"
    end

    local bugsText = TrimText(missionInfo.bugs)
    if bugsText ~= "" then
        displayText = displayText .. "Bugs: " .. bugsText
    end

    displayText = TrimText(displayText)
    if displayText == "" then
        displayText = "no helptext"
    end

    self.helpTextBox:SetText(displayText)
end

-- Update window with mission information and show it
-- @param missionInfo: table - Mission info with reduced fields (timeRange, timeAssessment, difficulty, objectives, missionDescription, tacticalAdvice, bugs)
function MissionWindow:ShowMission(missionInfo)
    if missionInfo then
        local incomingMissionName = TrimText(missionInfo.name)
        local previousMissionName = ""
        if self.currentMissionInfo ~= nil then
            previousMissionName = TrimText(self.currentMissionInfo.name)
        end

        if previousMissionName ~= "" and incomingMissionName ~= previousMissionName then
            self.lastRunMissionName = nil
            self.lastRunDurationSeconds = nil
            self.forcedZeroTimerMissionName = nil
        end

        self.currentMissionInfo = missionInfo
        self:RenderMissionText()
        self:ClampCurrentPosition()
        self:SetVisible(true)
        self:Activate()

        Settings.windowVisible = 1
        self:SaveCurrentPosition()
        SaveSettings()
    end
end

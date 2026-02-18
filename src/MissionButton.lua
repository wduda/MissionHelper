import "Turbine"
import "Turbine.UI"
import "MissionHelper.src.SettingsManager"
import "MissionHelper.src.ContextMenu"

--[[ MissionButton - Toggle button for Mission Helper window ]]--
--[[ Supports hover, drag-to-move, left-click toggle, right-click context menu ]]--

MissionButton = class(Turbine.UI.Window)

local BUTTON_SIZE = 32
local ICON_PATH = "MissionHelper/src/resources/mission_helper_32x32.tga"
local DRAG_TINT = Turbine.UI.Color(1.0, 0.8, 0.8, 1.0)
local ICON_TINT = Turbine.UI.Color(1.0, 1.0, 1.0, 1.0)
local FALLBACK_TINT = Turbine.UI.Color(1.0, 0.8, 0.4, 0.0)

local function ClampPositionToScreen(x, y, width, height)
    local screenWidth, screenHeight = Turbine.UI.Display.GetSize()
    local maxX = math.max(0, screenWidth - width)
    local maxY = math.max(0, screenHeight - height)

    local clampedX = math.max(0, math.min(x, maxX))
    local clampedY = math.max(0, math.min(y, maxY))
    return clampedX, clampedY
end

local function EnsureMissionWindow()
    if missionWindow == nil then
        missionWindow = MissionWindow()
        Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Mission window created</rgb>")
    end
end

local function SaveButtonPositionFromWindow(buttonWindow)
    local posX, posY = buttonWindow:GetPosition()
    local screenWidth, screenHeight = Turbine.UI.Display.GetSize()
    if screenWidth <= 0 or screenHeight <= 0 then
        return
    end

    Settings.buttonRelativeX = posX / screenWidth
    Settings.buttonRelativeY = posY / screenHeight
    SaveSettings()
end

function MissionButton:Constructor()
    Turbine.UI.Window.Constructor(self)

    self:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    self:SetZOrder(1)

    local iconLoaded = pcall(function()
        self:SetBackground(ICON_PATH)
        self:SetBackColorBlendMode(Turbine.UI.BlendMode.Multiply)
    end)
    self:SetBackColor(iconLoaded and ICON_TINT or FALLBACK_TINT)

    local screenWidth, screenHeight = Turbine.UI.Display.GetSize()
    local startX = (Settings.buttonRelativeX or 0.95) * screenWidth
    local startY = (Settings.buttonRelativeY or 0.75) * screenHeight
    startX, startY = ClampPositionToScreen(startX, startY, BUTTON_SIZE, BUTTON_SIZE)
    self:SetPosition(startX, startY)

    self:SetVisible(Settings.buttonVisible == 1)
    self:SetOpacity(Settings.buttonMinOpacity)

    local isMoving = false
    local hasMoved = false
    local buttonDownTime = 0
    local dragStartX = 0
    local dragStartY = 0

    self.MouseEnter = function()
        self:SetOpacity(Settings.buttonMaxOpacity)
    end

    self.MouseLeave = function()
        self:SetOpacity(Settings.buttonMinOpacity)
    end

    self.MouseDown = function(sender, args)
        if args.Button ~= Turbine.UI.MouseButton.Left then
            return
        end

        buttonDownTime = Turbine.Engine.GetGameTime()
        isMoving = true
        hasMoved = false
        dragStartX = args.X
        dragStartY = args.Y
    end

    self.MouseMove = function(sender, args)
        if not isMoving then
            return
        end

        local elapsed = Turbine.Engine.GetGameTime() - buttonDownTime
        if elapsed <= BehaviorConstants.BUTTON_DRAG_DELAY then
            return
        end

        local dx = args.X - dragStartX
        local dy = args.Y - dragStartY
        if dx == 0 and dy == 0 then
            return
        end

        hasMoved = true
        self:SetBackColor(DRAG_TINT)

        local currentX, currentY = self:GetPosition()
        local nextX = currentX + dx
        local nextY = currentY + dy
        nextX, nextY = ClampPositionToScreen(nextX, nextY, BUTTON_SIZE, BUTTON_SIZE)
        self:SetPosition(nextX, nextY)
    end

    self.MouseUp = function(sender, args)
        if args.Button == Turbine.UI.MouseButton.Right then
            if self.contextMenu == nil then
                self.contextMenu = MissionContextMenu(self)
            end
            self.contextMenu:ShowMenu()
            return
        end

        if args.Button ~= Turbine.UI.MouseButton.Left then
            return
        end

        isMoving = false

        if hasMoved then
            SaveButtonPositionFromWindow(self)
            self:SetBackColor(iconLoaded and ICON_TINT or FALLBACK_TINT)
            hasMoved = false
            Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Button position saved</rgb>")
            return
        end

        EnsureMissionWindow()
        local newState = not missionWindow:IsVisible()
        missionWindow:SetVisible(newState)
        Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Window " .. (newState and "shown" or "hidden") .. "</rgb>")

        if newState and lastMissionInfo ~= nil then
            missionWindow:ShowMission(lastMissionInfo)
            Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Showing last accepted mission</rgb>")
        end
    end
end

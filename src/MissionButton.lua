import "Turbine";
import "Turbine.UI";
import "MissionHelper.src.SettingsManager";
import "MissionHelper.src.ContextMenu";

--[[ MissionButton - Toggle button for Mission Helper window ]]--
--[[ Enhanced with icon, hover effects, drag-to-move, and context menu ]]--

-- MissionButton class definition
MissionButton = class(Turbine.UI.Window);

function MissionButton:Constructor()
    Turbine.UI.Window.Constructor(self);

    -- Button properties
    self:SetSize(32, 32);
    self:SetZOrder(1);

    -- Try to load custom icon, fallback to colored square
    -- Note: Using pcall to gracefully handle missing TGA file
    local success = pcall(function()
        self:SetBackground("MissionHelper/src/resources/mission_helper_32x32.tga");
        self:SetBackColorBlendMode(Turbine.UI.BlendMode.Multiply);
    end);

    if success then
        -- Icon loaded successfully, use white tint (neutral)
        self:SetBackColor(Turbine.UI.Color(1.0, 1.0, 1.0, 1.0));
    else
        -- Icon not found, use colored square fallback (orange/gold)
        self:SetBackColor(Turbine.UI.Color(1.0, 0.8, 0.4, 0.0));
    end

    -- Position from settings (relative to screen)
    local screenWidth = Turbine.UI.Display.GetWidth();
    local screenHeight = Turbine.UI.Display.GetHeight();
    local buttonX = Settings.buttonRelativeX * screenWidth;
    local buttonY = Settings.buttonRelativeY * screenHeight;

    -- Keep button on screen
    if buttonX + self:GetWidth() > screenWidth then
        buttonX = screenWidth - self:GetWidth();
    end
    if buttonY + self:GetHeight() > screenHeight then
        buttonY = screenHeight - self:GetHeight();
    end

    self:SetPosition(buttonX, buttonY);
    self:SetVisible(Settings.buttonVisible == 1);
    self:SetOpacity(Settings.buttonMinOpacity);

    -- Drag state tracking
    local isMoving = false;
    local hasMoved = false;
    local buttonDownTime = 0;
    local startX = 0;
    local startY = 0;
    local originalColor = Turbine.UI.Color(1.0, 1.0, 1.0, 1.0);

    -- HOVER EFFECTS
    self.MouseEnter = function(sender, args)
        self:SetOpacity(Settings.buttonMaxOpacity);
    end

    self.MouseLeave = function(sender, args)
        self:SetOpacity(Settings.buttonMinOpacity);
    end

    -- DRAG FUNCTIONALITY - MouseDown
    self.MouseDown = function(sender, args)
        if (args.Button == Turbine.UI.MouseButton.Left) then
            buttonDownTime = Turbine.Engine.GetGameTime();
            isMoving = true;
            hasMoved = false;
            startX = args.X;
            startY = args.Y;
        end
    end

    -- DRAG FUNCTIONALITY - MouseMove
    self.MouseMove = function(sender, args)
        if (isMoving and
            Turbine.Engine.GetGameTime() - buttonDownTime > BehaviorConstants.BUTTON_DRAG_DELAY) then

            hasMoved = true;

            -- Visual feedback during drag (red tint)
            self:SetBackColor(Turbine.UI.Color(1.0, 0.8, 0.8, 1.0));

            local oldX, oldY = self:GetPosition();
            self:SetPosition(oldX + args.X - startX, oldY + args.Y - startY);
        end
    end

    -- DRAG FUNCTIONALITY & TOGGLE - MouseUp
    self.MouseUp = function(sender, args)
        if (args.Button == Turbine.UI.MouseButton.Left) then
            isMoving = false;

            if (hasMoved) then
                -- Save new position
                local posX, posY = self:GetPosition();
                local screenWidth, screenHeight = Turbine.UI.Display.GetSize();
                Settings.buttonRelativeX = posX / screenWidth;
                Settings.buttonRelativeY = posY / screenHeight;
                SaveSettings();

                -- Reset visual feedback
                self:SetBackColor(originalColor);
                hasMoved = false;

                Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Button position saved</rgb>");
            else
                -- Toggle window (no drag occurred)
                missionWindow:SetVisible(not missionWindow:IsVisible());
            end
        elseif (args.Button == Turbine.UI.MouseButton.Right) then
            -- Show context menu
            if self.contextMenu == nil then
                self.contextMenu = MissionContextMenu(self);
            end
            self.contextMenu:ShowMenu();
        end
    end
end

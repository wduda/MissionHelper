import "Turbine"
import "Turbine.UI"
import "MissionHelper.src.SettingsManager"

--[[ MissionContextMenu - Right-click context menu for button ]]--
--[[ Provides Show/Hide Button, Show/Hide Window, About ]]--

MissionContextMenu = class(Turbine.UI.ContextMenu)

function MissionContextMenu:Constructor(parentButton)
    Turbine.UI.ContextMenu.Constructor(self)

    self.parent = parentButton

    -- Create menu items
    self.showButtonItem = Turbine.UI.MenuItem("Show Button", true, true)
    self.showWindowItem = Turbine.UI.MenuItem("Show Window", true, true)
    self.aboutItem = Turbine.UI.MenuItem("About Mission Helper", true, false)

    -- Add items to menu
    local items = self:GetItems()
    items:Add(self.showButtonItem)
    items:Add(self.showWindowItem)
    items:Add(self.aboutItem)

    -- Wire up click handlers
    self.showButtonItem.Click = function(sender, args)
        self:ToggleButtonVisibility()
    end

    self.showWindowItem.Click = function(sender, args)
        self:ToggleWindowVisibility()
    end

    self.aboutItem.Click = function(sender, args)
        self:ShowAbout()
    end
end

-- Update checkbox states from current settings
function MissionContextMenu:SetSelections()
    self.showButtonItem:SetChecked(Settings.buttonVisible == 1)
    if missionWindow ~= nil then
        self.showWindowItem:SetChecked(missionWindow:IsVisible())
    else
        self.showWindowItem:SetChecked(false)
    end
end

-- Show the context menu with updated states
function MissionContextMenu:ShowMenu()
    self:SetSelections()
    Turbine.UI.ContextMenu.ShowMenu(self)
end

-- Toggle button visibility
function MissionContextMenu:ToggleButtonVisibility()
    Settings.buttonVisible = (Settings.buttonVisible == 1) and 0 or 1
    self.parent:SetVisible(Settings.buttonVisible == 1)
    SaveSettings()
    self:SetSelections()

    if Settings.buttonVisible == 0 then
        Turbine.Shell.WriteLine("<rgb=#FFFF00>MissionHelper: Button hidden. Reload plugin to show again.</rgb>")
    end
end

-- Toggle window visibility
function MissionContextMenu:ToggleWindowVisibility()
    if missionWindow == nil then
        missionWindow = MissionWindow()
        Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Mission window created</rgb>")
    end

    local newState = not missionWindow:IsVisible()
    missionWindow:SetVisible(newState)
    Settings.windowVisible = newState and 1 or 0
    SaveSettings()

    Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Window " .. (newState and "shown" or "hidden") .. "</rgb>")

    if newState and lastMissionInfo ~= nil then
        missionWindow:ShowMission(lastMissionInfo)
        Turbine.Shell.WriteLine("<rgb=#90EE90>MissionHelper: Showing last accepted mission</rgb>")
    end

    self:SetSelections()
end

-- Show about information
function MissionContextMenu:ShowAbout()
    local version = Plugins["MissionHelper"]:GetVersion()
    local author = Plugins["MissionHelper"]:GetAuthor()

    Turbine.Shell.WriteLine("<rgb=#DAA520>Mission Helper " .. version .. "</rgb>")
    Turbine.Shell.WriteLine("<rgb=#90EE90>By " .. author .. "</rgb>")
    Turbine.Shell.WriteLine("<rgb=#90EE90>Mission detection and assistance plugin</rgb>")
end

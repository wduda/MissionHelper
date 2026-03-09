import "Turbine"
import "Turbine.UI"
import "Turbine.UI.Lotro"

SuggestMissionsWindow = class(Turbine.UI.Window)

local WINDOW_WIDTH = 520
local WINDOW_HEIGHT = 420
local PADDING = 10
local TITLE_Y = 8
local CONTENT_Y = 34
local CONTENT_BOTTOM_PADDING = 10
local SCROLLBAR_WIDTH = 10
local SCROLLBAR_GAP = 4

local function TrimText(text)
    if text == nil then
        return ""
    end

    local str = tostring(text)
    str = str:gsub("^%s+", "")
    str = str:gsub("%s+$", "")
    return str
end

function SuggestMissionsWindow:Constructor()
    Turbine.UI.Window.Constructor(self)

    self:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    self:SetBackColor(Turbine.UI.Color.Black)
    self:SetText("")
    self:SetVisible(false)

    local displayWidth, displayHeight = Turbine.UI.Display.GetSize()
    self:SetPosition(
        math.max(0, (displayWidth - WINDOW_WIDTH) / 2),
        math.max(0, (displayHeight - WINDOW_HEIGHT) / 2)
    )

    self.titleLabel = Turbine.UI.Label()
    self.titleLabel:SetParent(self)
    self.titleLabel:SetPosition(PADDING, TITLE_Y)
    self.titleLabel:SetSize(WINDOW_WIDTH - (PADDING * 2), 20)
    self.titleLabel:SetFont(Turbine.UI.Lotro.Font.TrajanPro14)
    self.titleLabel:SetForeColor(Turbine.UI.Color.Gold)
    self.titleLabel:SetText("Suggested Missions")

    local contentHeight = WINDOW_HEIGHT - CONTENT_Y - CONTENT_BOTTOM_PADDING
    local contentWidth = WINDOW_WIDTH - (PADDING * 2) - SCROLLBAR_WIDTH - SCROLLBAR_GAP

    self.contentTextBox = Turbine.UI.Lotro.TextBox()
    self.contentTextBox:SetParent(self)
    self.contentTextBox:SetPosition(PADDING, CONTENT_Y)
    self.contentTextBox:SetSize(contentWidth, contentHeight)
    self.contentTextBox:SetMultiline(true)
    self.contentTextBox:SetReadOnly(true)
    self.contentTextBox:SetFont(Turbine.UI.Lotro.Font.Verdana14)
    self.contentTextBox:SetForeColor(Turbine.UI.Color.LightGray)
    self.contentTextBox:SetText("")

    self.contentScrollBar = Turbine.UI.Lotro.ScrollBar()
    self.contentScrollBar:SetParent(self)
    self.contentScrollBar:SetOrientation(Turbine.UI.Orientation.Vertical)
    self.contentScrollBar:SetPosition(PADDING + contentWidth + SCROLLBAR_GAP, CONTENT_Y)
    self.contentScrollBar:SetSize(SCROLLBAR_WIDTH, contentHeight)
    self.contentTextBox:SetVerticalScrollBar(self.contentScrollBar)
end

function SuggestMissionsWindow:SetSuggestionText(titleSuffix, bodyText)
    local title = "Suggested Missions"
    local suffix = TrimText(titleSuffix)
    if suffix ~= "" then
        title = title .. " - " .. suffix
    end
    self.titleLabel:SetText(title)
    self.contentTextBox:SetText(TrimText(bodyText))
end

function SuggestMissionsWindow:ShowSuggestions(titleSuffix, bodyText)
    self:SetSuggestionText(titleSuffix, bodyText)
    self:SetVisible(true)
    self:Activate()
end

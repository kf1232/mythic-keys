local ADDON_NAME = ...

KeyMinimap = KeyMinimap or {}

local MinimapButton = KeyMinimap

local BUTTON_SIZE = 31
local BUTTON_RADIUS = 5
local BORDER_SIZE = 50
local BACKGROUND_SIZE = 24
local ICON_SIZE = 18

local function GetDB()
    KeyDB = KeyDB or {}
    KeyDB.minimap = KeyDB.minimap or {}
    return KeyDB.minimap
end

local function GetAngle()
    local db = GetDB()
    if db.angle == nil then
        db.angle = 225
    end
    return db.angle
end

local function SetAngle(angle)
    GetDB().angle = angle % 360
end

local function UpdatePosition(button)
    local x, y = KeyApiMinimap:GetOffsetForAngle(Minimap, GetAngle(), BUTTON_RADIUS)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:CreateButton()
    if self.button then
        return self.button
    end

    local button = CreateFrame("Button", "KeyMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetSize(BACKGROUND_SIZE, BACKGROUND_SIZE)
    button.background:SetPoint("CENTER")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.icon:SetTexture(Key and Key.DEFAULT_ICON or 134400)
    button.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    button.icon:SetPoint("CENTER")

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border:SetSize(BORDER_SIZE, BORDER_SIZE)
    button.border:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouseButton)
        if KeyMinimapLog and KeyMinimapLog.LogClick then
            KeyMinimapLog:LogClick(mouseButton)
        end
        if mouseButton == "RightButton" then
            if KeyDebugUI and KeyDebugUI.ShowConsole then
                KeyDebugUI:ShowConsole()
            end
            return
        end
        if KeyPartyUI and KeyPartyUI.TogglePanel then
            KeyPartyUI:TogglePanel()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Key")
        GameTooltip:AddLine("Click to view party list", 1, 1, 1)
        GameTooltip:AddLine("Right click to view debug log", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        if KeyMinimapLog and KeyMinimapLog.LogDragStart then
            KeyMinimapLog:LogDragStart()
        end
        self:SetScript("OnUpdate", function()
            SetAngle(KeyApiMinimap:GetAngleFromCursor(Minimap))
            UpdatePosition(self)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if KeyMinimapLog and KeyMinimapLog.LogDragStop then
            KeyMinimapLog:LogDragStop()
        end
    end)

    self.button = button
    UpdatePosition(button)
    if KeyMinimapLog and KeyMinimapLog.LogInit then
        KeyMinimapLog:LogInit()
    end
    return button
end

function MinimapButton:Init()
    GetDB().hidden = nil
    self:CreateButton()

    if not self.loginHooked then
        self.loginHooked = true
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("PLAYER_LOGIN")
        frame:SetScript("OnEvent", function()
            if MinimapButton.button then
                UpdatePosition(MinimapButton.button)
            end
        end)
    end
end

local ADDON_NAME = ...

Key.PartyUI = Key.PartyUI or {}
local PartyUI = Key.PartyUI

local HEADER_HEIGHT = 28
local PADDING = 10
local TAB_HEIGHT = 26
local TAB_GAP = 4
local BOTTOM_INSET = 34
local MAX_FRAME_WIDTH = 1248
local MAX_FRAME_HEIGHT = 900

PartyUI.TAB_COMPLETIONS = "completions"
PartyUI.TAB_READY = "ready"
PartyUI.PANE_BOTTOM_PADDING = 8
PartyUI.activeTab = PartyUI.activeTab or PartyUI.TAB_COMPLETIONS
PartyUI.refreshLockUntil = PartyUI.refreshLockUntil or 0
PartyUI.REFRESH_COOLDOWN = 10

local function GetDefaultFrameWidth()
    if Key.Teleports and Key.Teleports.GetDefaultFrameWidth then
        return Key.Teleports:GetDefaultFrameWidth(PADDING)
    end
    return 848
end

local function GetMinFrameWidth()
    if Key.Teleports and Key.Teleports.GetMinFrameWidth then
        return Key.Teleports:GetMinFrameWidth(PADDING)
    end
    return 248
end

local function GetFrameLimits()
    if Key.Teleports then
        return Key.Teleports:GetMinFrameWidth(PADDING), Key.Teleports:GetMaxFrameWidth(PADDING)
    end
    return GetMinFrameWidth(), MAX_FRAME_WIDTH
end

local DEFAULT_FRAME_WIDTH = GetDefaultFrameWidth()
local MIN_FRAME_WIDTH = GetMinFrameWidth()

function PartyUI:CollectMembers()
    if Key.Keystones and Key.Keystones.CollectMembers then
        return Key.Keystones:CollectMembers()
    end

    return {}
end

function PartyUI:GetContentWidth()
    local minContent = Key.Teleports and Key.Teleports:GetMinContentWidth() or (MIN_FRAME_WIDTH - (PADDING * 2))
    if not self.frame then
        return math.max(minContent, DEFAULT_FRAME_WIDTH - (PADDING * 2))
    end
    return math.max(minContent, self.frame:GetWidth() - (PADDING * 2))
end

function PartyUI:CreateTabButton(parent, label, tabId)
    return Key.UI:CreateTabButton(parent, label, tabId, function()
        PartyUI:SetActiveTab(tabId)
    end)
end

function PartyUI:UpdateTabVisuals()
    local frame = self.frame
    if not frame or not frame.tabs then
        return
    end

    for tabId, button in pairs(frame.tabs) do
        Key.UI:ApplyTabButtonStyle(button, tabId == self.activeTab)
    end

    if frame.completionsPane then
        frame.completionsPane:SetShown(self.activeTab == self.TAB_COMPLETIONS)
    end
    if frame.readyPane then
        frame.readyPane:SetShown(self.activeTab == self.TAB_READY)
    end
end

function PartyUI:SetActiveTab(tabId)
    if self.activeTab == tabId then
        return
    end

    self.activeTab = tabId
    self:UpdateTabVisuals()
    Key.Dispatch("REFRESH_UI", { immediate = true })
    if Key.BDUpdates and Key.BDUpdates.UpdatePolling then
        Key.BDUpdates:UpdatePolling()
    end
end

function PartyUI:LayoutTabs()
    local frame = self.frame
    if not frame or not frame.tabs then
        return
    end

    local order = { self.TAB_COMPLETIONS, self.TAB_READY }
    local tabWidth = math.floor((frame.tabBar:GetWidth() - TAB_GAP) / #order)
    local x = 0

    for _, tabId in ipairs(order) do
        local button = frame.tabs[tabId]
        button:SetSize(tabWidth, TAB_HEIGHT)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame.tabBar, "TOPLEFT", x, 0)
        x = x + tabWidth + TAB_GAP
    end
end

function PartyUI:CreateResizeHandle(frame)
    local sizer = CreateFrame("Button", nil, frame)
    sizer:SetSize(16, 16)
    sizer:SetPoint("BOTTOMRIGHT", -4, 4)
    sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    sizer:SetScript("OnEnter", function()
        GameTooltip:SetOwner(sizer, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to resize")
        GameTooltip:Show()
    end)
    sizer:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    sizer:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    sizer:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        Key.Dispatch("UI_RESIZE")
    end)
    return sizer
end

function PartyUI:IsRefreshLocked()
    return GetTime() < (self.refreshLockUntil or 0)
end

function PartyUI:GetRefreshCooldownRemaining()
    return math.max(0, (self.refreshLockUntil or 0) - GetTime())
end

function PartyUI:UpdateRefreshButton()
    local button = self.frame and self.frame.refreshButton
    if not button then
        return
    end

    button:SetEnabled(not self:IsRefreshLocked())
end

function PartyUI:CreateRefreshButton(parent, closeButton)
    return Key.UI:CreateRefreshButton(parent, {
        matchSizeTo = closeButton,
        onClick = function()
            PartyUI:OnRefreshClick()
        end,
        onEnter = function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            if PartyUI:IsRefreshLocked() then
                local remaining = math.ceil(PartyUI:GetRefreshCooldownRemaining())
                GameTooltip:SetText("Refresh on cooldown", 1, 1, 1)
                GameTooltip:AddLine(string.format("Available in %ds", remaining), 0.85, 0.85, 0.85)
            else
                GameTooltip:SetText("Refresh party data", 1, 1, 1)
                GameTooltip:AddLine("Request keys, bests, and ready state from the group.", 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end,
        onLeave = function()
            GameTooltip:Hide()
        end,
    })
end

function PartyUI:EnsureRefreshButton(frame)
    if frame.refreshButton then
        self:UpdateRefreshButton()
        return
    end

    local close = frame.closeButton
    if not close then
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        frame.closeButton = close
    end

    frame.refreshButton = self:CreateRefreshButton(frame, close)
    frame.refreshButton:SetPoint("TOPRIGHT", close, "TOPLEFT", -Key.UI.LAYOUT.refreshButtonGap, 0)
    self:UpdateRefreshButton()
end

function PartyUI:OnRefreshClick()
    if self:IsRefreshLocked() then
        return
    end

    self.refreshLockUntil = GetTime() + self.REFRESH_COOLDOWN
    self:UpdateRefreshButton()

    if Key.Log and Key.Log.RunProtected then
        Key.Log:RunProtected("PartyUI:OnRefreshClick", function()
            Key.Dispatch("UI_REFRESH_CLICK")
        end)
    else
        Key.Dispatch("UI_REFRESH_CLICK")
    end

    if self.refreshUnlockTimer then
        self.refreshUnlockTimer:Cancel()
    end

    self.refreshUnlockTimer = C_Timer.NewTimer(self.REFRESH_COOLDOWN, function()
        self.refreshUnlockTimer = nil
        self:UpdateRefreshButton()
    end)
end

function PartyUI:EnsureReadyPane(frame)
    if frame.readyPane then
        return
    end

    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", PADDING, -(HEADER_HEIGHT + 4))
    pane:SetPoint("BOTTOMRIGHT", -PADDING, BOTTOM_INSET)
    pane:Hide()

    pane.readyTable = Key.ReadyCheck.UI:EnsureTable(pane)
    pane.readyTable:SetPoint("TOPLEFT", 0, 0)

    frame.readyPane = pane
end

function PartyUI:EnsureTabBar(frame)
    if frame.tabBar then
        return
    end

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    tabBar:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    tabBar:SetHeight(TAB_HEIGHT)

    frame.tabBar = tabBar
    frame.tabs = {
        [self.TAB_COMPLETIONS] = self:CreateTabButton(tabBar, "M+ Completions", self.TAB_COMPLETIONS),
        [self.TAB_READY] = self:CreateTabButton(tabBar, "Ready Check", self.TAB_READY),
    }
end

function PartyUI:EnsureTitleBar(frame)
    if frame.titleBar then
        return
    end

    local titleBar = Key.UI:CreateFrame(Key.UI:TitleBarConfig(), frame)
    frame.titleBar = titleBar

    Key.UI:CreateFontString(Key.UI:TitleBarLabelConfig({
        text = "Key",
    }), titleBar)

    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    frame:RegisterForDrag()
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
end

function PartyUI:EnsureFrame()
    if self.frame then
        self:EnsureTitleBar(self.frame)
        self:EnsureCompletionsPane(self.frame)
        if self.frame.completionsPane then
            self:EnsureCompletionsScroll(self.frame.completionsPane)
        end
        self:EnsureReadyPane(self.frame)
        self:EnsureTabBar(self.frame)
        self:EnsureRefreshButton(self.frame)
        self:UpdateTabVisuals()
        return
    end

    local frame = Key.UI:CreateFrame(Key.UI:WindowConfig({
        name = "KeyPartyFrame",
        parent = UIParent,
        size = { DEFAULT_FRAME_WIDTH, 200 },
        anchors = {
            { "CENTER", 0, 0 },
        },
        movable = true,
        resizable = true,
        hidden = true,
    }))

    frame:SetScript("OnSizeChanged", function()
        if PartyUI._layingOut or not frame:IsShown() then
            return
        end
        Key.Dispatch("UI_RESIZE")
    end)

    self:EnsureTitleBar(frame)

    local close = Key.UI:CreateCloseButton(frame)
    frame.closeButton = close

    frame.refreshButton = self:CreateRefreshButton(frame, close)
    frame.refreshButton:SetPoint("TOPRIGHT", close, "TOPLEFT", -Key.UI.LAYOUT.refreshButtonGap, 0)

    self:CreateResizeHandle(frame)
    self:EnsureCompletionsPane(frame)
    self:EnsureReadyPane(frame)
    self:EnsureTabBar(frame)
    self:UpdateTabVisuals()

    self.frame = frame
end

function PartyUI:RefreshReadyPane(contentWidth, members)
    if not Key.ReadyCheck then
        return self.PANE_BOTTOM_PADDING
    end

    Key.ReadyCheck:RebindCache()

    local pane = self.frame.readyPane
    if not pane or not pane.readyTable then
        return self.PANE_BOTTOM_PADDING
    end

    local tableHeight = Key.ReadyCheck.UI:LayoutTable(pane.readyTable, contentWidth, members)
    return tableHeight + self.PANE_BOTTOM_PADDING
end

local function TraceReadyRefresh(message)
    if Key.AurasLog and Key.AurasLog.LogUpdate then
        Key.AurasLog:LogUpdate(message)
    end
end

function PartyUI:RefreshReadyOnly()
    self:EnsureFrame()

    if not self.frame or not self.frame:IsShown() then
        TraceReadyRefresh("RefreshReadyOnly skipped: party panel hidden")
        return
    end

    if not self:IsReadyTabActive() then
        TraceReadyRefresh("RefreshReadyOnly skipped: completions tab active")
        return
    end

    local pane = self.frame.readyPane
    if not pane or not pane.readyTable then
        TraceReadyRefresh("RefreshReadyOnly skipped: ready table missing")
        return
    end

    if not Key.ReadyCheck then
        TraceReadyRefresh("RefreshReadyOnly skipped: Key.ReadyCheck missing")
        return
    end

    Key.ReadyCheck:RebindCache()
    Key.ReadyCheck.UI:LayoutTable(pane.readyTable, self:GetContentWidth(), self:CollectMembers())
    TraceReadyRefresh(string.format(
        "RefreshReadyOnly laid out ready table (tab=%s)",
        tostring(self.activeTab)
    ))
end

function PartyUI:Refresh()
    self:EnsureFrame()

    if Key.Keystones then
        Key.Keystones:RebindPartyCache()
    end

    local frame = self.frame
    local contentWidth = self:GetContentWidth()
    self._layingOut = true

    self:LayoutTabs()

    local members = self:CollectMembers()
    local completionsHeight = self:RefreshCompletionsPane(contentWidth, members)
    local readyHeight = self:RefreshReadyPane(contentWidth, members)

    local contentHeight
    if self.activeTab == self.TAB_READY then
        contentHeight = HEADER_HEIGHT + 4 + readyHeight + BOTTOM_INSET
    else
        contentHeight = HEADER_HEIGHT + 4 + completionsHeight + BOTTOM_INSET
    end

    local minFrameWidth, maxFrameWidth = GetFrameLimits()
    frame:SetResizeBounds(minFrameWidth, contentHeight, maxFrameWidth, MAX_FRAME_HEIGHT)

    if frame:GetWidth() < minFrameWidth then
        frame:SetWidth(minFrameWidth)
    end

    local prevMinHeight = self._lastMinHeight
    if not prevMinHeight or frame:GetHeight() <= prevMinHeight + 2 or contentHeight < prevMinHeight then
        frame:SetHeight(contentHeight)
    end
    self._lastMinHeight = contentHeight

    self._layingOut = false

    if Key.BDUpdates and Key.BDUpdates.UpdatePolling then
        Key.BDUpdates:UpdatePolling()
    end
end

function PartyUI:TogglePanel()
    self:EnsureFrame()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        Key.Dispatch("UI_PANEL_OPEN")
        self.frame:Show()
        if Key.Debug.Click and Key.Debug.Click:IsEnabled() then
            Key.Debug.Click:RewireAll()
        end
    end

    if Key.BDUpdates and Key.BDUpdates.UpdatePolling then
        Key.BDUpdates:UpdatePolling()
    end
end

function PartyUI:IsShown()
    return self.frame and self.frame:IsShown()
end

function PartyUI:IsReadyTabActive()
    return self.activeTab == self.TAB_READY
end

Key.RegisterTrigger("GROUP_LEFT", function()
    Key.Dispatch("REFRESH_UI", { ifShown = true })
end)

Key.RegisterTrigger("PLAYER_ENTERING_WORLD", function()
    Key.Dispatch("REFRESH_UI", { ifShown = true })
end)

Key.RegisterTrigger("KEYSTONE_DATA_CHANGED", function()
    Key.Dispatch("REFRESH_UI", { ifShown = true })
end)

Key.RegisterTrigger("PARTY_CHANGED", function(ctx)
    Key.Dispatch("REFRESH_UI", {
        ifShown = true,
        immediate = ctx.immediate,
    })
end)

Key.RegisterTrigger("UI_PANEL_OPEN", function()
    Key.Dispatch("REFRESH_UI", { immediate = true })
end)

Key.RegisterTrigger("UI_REFRESH_CLICK", function()
    Key.Dispatch("REFRESH_UI", { immediate = true })
end)

Key.RegisterTrigger("UI_READY_TOGGLE", function()
    Key.Dispatch("REFRESH_UI", { ifShown = true, immediate = true })
end)

Key.RegisterTrigger("UI_RESIZE", function()
    Key.Dispatch("REFRESH_UI")
end)

local ADDON_NAME = ...

Key.PartyUI = Key.PartyUI or {}
local PartyUI = Key.PartyUI

if not Key.Teleports then
    error("Key.Teleports is missing. Load teleport-bar before party-ui/completions-pane.lua.")
end

if not Key.PartyComplete then
    error("Key.PartyComplete is missing. Load party-complete.lua before party-ui/completions-pane.lua.")
end

local HEADER_HEIGHT = Key.UI:GetHeaderHeight()
local LAYOUT = Key.UI.LAYOUT
local VISIBLE_MEMBER_ROWS = 6

PartyUI.FRAME_LEVEL_TELEPORT_BAR = 30
PartyUI.FRAME_LEVEL_SCROLL = 10

function PartyUI:GetMemberBlockHeight(memberCount, contentWidth)
    memberCount = memberCount or 0
    if memberCount == 0 then
        return 0
    end

    return Key.PartyComplete:GetBestTableHeight(memberCount, contentWidth)
end

function PartyUI:ApplyCompletionsLayering(pane, teleportHeight)
    if not pane or not pane.teleportBar or not pane.scrollFrame then
        return
    end

    pane.teleportBar:ClearAllPoints()
    pane.teleportBar:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    pane.teleportBar:SetFrameLevel(self.FRAME_LEVEL_TELEPORT_BAR)
    pane.teleportBar:EnableMouse(false)
    pane.teleportBar:Raise()

    pane.scrollFrame:ClearAllPoints()
    pane.scrollFrame:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(teleportHeight + LAYOUT.sectionGap))
    pane.scrollFrame:SetFrameLevel(self.FRAME_LEVEL_SCROLL)
end

function PartyUI:EnsureCompletionsScroll(pane)
    if pane.scrollFrame then
        return
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)

    pane.scrollFrame = scrollFrame
    pane.scrollChild = scrollChild

    pane.bestTable:SetParent(scrollChild)
end

function PartyUI:UpdateCompletionsScroll(memberCount, contentWidth, contentHeight, viewportHeight)
    local pane = self.frame.completionsPane
    local scrollFrame = pane.scrollFrame

    pane.scrollChild:SetSize(contentWidth, contentHeight)
    scrollFrame:SetSize(contentWidth, viewportHeight)

    local maxScroll = math.max(0, contentHeight - viewportHeight)
    if scrollFrame:GetVerticalScroll() > maxScroll then
        scrollFrame:SetVerticalScroll(maxScroll)
    end

    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:SetShown(memberCount > VISIBLE_MEMBER_ROWS)
    end
end

function PartyUI:EnsureCompletionsPane(frame)
    if frame.completionsPane then
        return
    end

    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", LAYOUT.padding, -(HEADER_HEIGHT + 4))
    pane:SetPoint("BOTTOMRIGHT", -LAYOUT.padding, LAYOUT.bottomInset)

    pane.teleportBar = Key.Teleports:EnsureBar(pane)
    pane.teleportBar:SetPoint("TOPLEFT", 0, 0)

    pane.bestTable = Key.PartyComplete:EnsureBestTable(pane)

    self:EnsureCompletionsScroll(pane)
    frame.completionsPane = pane
end

function PartyUI:RefreshCompletionsPane(contentWidth, members)
    local pane = self.frame.completionsPane
    self:EnsureCompletionsScroll(pane)

    local teleportHeight = Key.Teleports:LayoutBar(pane.teleportBar, contentWidth)
    local memberCount = members and #members or 0
    local scrollChild = pane.scrollChild

    pane.bestTable:ClearAllPoints()
    pane.bestTable:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)

    local function LayoutBestTable()
        Key.PartyComplete:LayoutBestTable(pane.bestTable, contentWidth, members)
    end

    if Key.Log and Key.Log.RunProtected then
        Key.Log:RunProtected("PartyUI:LayoutBestTable", LayoutBestTable)
    else
        LayoutBestTable()
    end

    local contentHeight = self:GetMemberBlockHeight(memberCount, contentWidth)
    local visibleRows = math.max(1, math.min(memberCount, VISIBLE_MEMBER_ROWS))
    local viewportHeight = self:GetMemberBlockHeight(visibleRows, contentWidth)
    self:UpdateCompletionsScroll(memberCount, contentWidth, contentHeight, viewportHeight)
    self:ApplyCompletionsLayering(pane, teleportHeight)

    if Key.PartyCompleteLog and Key.PartyCompleteLog.LogLayout then
        Key.PartyCompleteLog:LogLayout(contentWidth, memberCount, contentHeight, viewportHeight, teleportHeight)
    end

    return teleportHeight + LAYOUT.sectionGap + viewportHeight + LAYOUT.paneBottomPadding
end

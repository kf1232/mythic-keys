local ADDON_NAME = ...

KeyPartyCompleteLog = KeyPartyCompleteLog or {}
local PartyCompleteLog = KeyPartyCompleteLog

local function Log()
    return KeyLog
end

local function Teleports()
    return KeyTeleports
end

function PartyCompleteLog:ShouldLogUpdates()
    return KeyDebugUI and KeyDebugUI.IsShown and KeyDebugUI:IsShown()
end

function PartyCompleteLog:LogUpdate(message, dedupeKey, dedupeWindow)
    local keyLog = Log()
    if not keyLog or not self:ShouldLogUpdates() then
        return
    end

    keyLog:Add("Party complete: " .. message, dedupeKey, dedupeWindow)
end

function PartyCompleteLog:LogLayout(contentWidth, memberCount, tableHeight, viewportHeight, teleportHeight)
    self:LogUpdate(
        string.format(
            "layout width=%d members=%d table=%d viewport=%d teleport=%d",
            contentWidth or 0,
            memberCount or 0,
            tableHeight or 0,
            viewportHeight or 0,
            teleportHeight or 0
        ),
        "party-complete:layout",
        0.2
    )
end

function PartyCompleteLog:LogBestTableLayout(contentWidth, memberCount, tableHeight)
    self:LogUpdate(
        string.format("best table width=%d members=%d height=%d", contentWidth or 0, memberCount or 0, tableHeight or 0),
        "party-complete:best-table",
        0.2
    )
end

function PartyCompleteLog:LogInit()
    local teleports = Teleports()
    self:LogUpdate(
        string.format(
            "initialized dungeons=%d maxRows=%d table=%s",
            teleports and teleports.SLOT_COUNT or 0,
            teleports and teleports.MAX_BEST_ROWS or 0,
            (teleports and teleports.bestTable) and "yes" or "no"
        ),
        "party-complete:init",
        30
    )
end

function PartyCompleteLog:LogSnapshot()
    local keyLog = Log()
    local teleports = Teleports()
    if not keyLog or not teleports then
        return
    end

    keyLog:Add("Party complete:")
    keyLog:Add(string.format(
        "  dungeons=%d maxRows=%d table=%s",
        teleports.SLOT_COUNT or 0,
        teleports.MAX_BEST_ROWS or 0,
        teleports.bestTable and "yes" or "no"
    ))

    if teleports.bestTable then
        keyLog:Add(string.format(
            "  tableSize=%dx%d parent=%s",
            teleports.bestTable:GetWidth(),
            teleports.bestTable:GetHeight(),
            teleports.bestTable:GetParent() and teleports.bestTable:GetParent():GetName() or "(none)"
        ))
    end

    local pane = KeyPartyUI and KeyPartyUI.frame and KeyPartyUI.frame.completionsPane
    if pane and pane.scrollFrame then
        keyLog:Add(string.format(
            "  scroll=%dx%d child=%dx%d",
            pane.scrollFrame:GetWidth(),
            pane.scrollFrame:GetHeight(),
            pane.scrollChild and pane.scrollChild:GetWidth() or 0,
            pane.scrollChild and pane.scrollChild:GetHeight() or 0
        ))
    end
end

PartyCompleteLog:LogInit()

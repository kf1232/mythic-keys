local ADDON_NAME = ...

Key.PartyCompleteLog = Key.PartyCompleteLog or {}
local PartyCompleteLog = Key.PartyCompleteLog

local FEATURE = Key.Log and Key.Log.FEATURE and Key.Log.FEATURE.PARTY_COMPLETE or "PCMP"

local function Log()
    return Key.Log
end

local function PartyComplete()
    return Key.PartyComplete
end

local function WriteEvent(status, payload, options)
    local keyLog = Log()
    if not keyLog or not keyLog.WriteEvent then
        return
    end

    options = options or {}
    if not options.source and debug and debug.getinfo then
        local info = debug.getinfo(2, "n")
        if info and info.name and info.name ~= "" then
            options.source = info.name
        end
    end

    keyLog:WriteEvent(FEATURE, status, payload, options)
end

function PartyCompleteLog:ShouldLogUpdates()
    return Key.Debug.UI and Key.Debug.UI.IsShown and Key.Debug.UI:IsShown()
end

function PartyCompleteLog:LogUpdate(message, dedupeKey, dedupeWindow)
    if not self:ShouldLogUpdates() then
        return
    end

    WriteEvent(Key.Log.STATUS.DEBUG, message, {
        dedupeKey = dedupeKey,
        dedupeWindow = dedupeWindow,
    })
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
    local partyComplete = PartyComplete()
    self:LogUpdate(
        string.format(
            "initialized dungeons=%d maxRows=%d table=%s",
            partyComplete and partyComplete.SLOT_COUNT or 0,
            partyComplete and partyComplete.MAX_BEST_ROWS or 0,
            (partyComplete and partyComplete.bestTable) and "yes" or "no"
        ),
        "party-complete:init",
        30
    )
end

function PartyCompleteLog:LogSnapshot()
    local partyComplete = PartyComplete()
    if not partyComplete then
        return
    end

    WriteEvent(Key.Log.STATUS.DEBUG, string.format(
        "dungeons=%d maxRows=%d table=%s",
        partyComplete.SLOT_COUNT or 0,
        partyComplete.MAX_BEST_ROWS or 0,
        partyComplete.bestTable and "yes" or "no"
    ))

    if partyComplete.bestTable then
        WriteEvent(Key.Log.STATUS.DEBUG, string.format(
            "tableSize=%dx%d parent=%s",
            partyComplete.bestTable:GetWidth(),
            partyComplete.bestTable:GetHeight(),
            partyComplete.bestTable:GetParent() and partyComplete.bestTable:GetParent():GetName() or "(none)"
        ))
    end

    local pane = Key.PartyUI and Key.PartyUI.frame and Key.PartyUI.frame.completionsPane
    if pane and pane.scrollFrame then
        WriteEvent(Key.Log.STATUS.DEBUG, string.format(
            "scroll=%dx%d child=%dx%d",
            pane.scrollFrame:GetWidth(),
            pane.scrollFrame:GetHeight(),
            pane.scrollChild and pane.scrollChild:GetWidth() or 0,
            pane.scrollChild and pane.scrollChild:GetHeight() or 0
        ))
    end
end

PartyCompleteLog:LogInit()

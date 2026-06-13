local ADDON_NAME = ...

Key = Key or {}

Key.DEFAULT_ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\media\\icon"
Key.GCD_SPELL_ID = 61304
Key.refreshDebounce = 0.1

local refreshTimer
local pendingRefreshCtx

local function PrintMessage(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

local function MergeRefreshContext(existing, incoming)
    existing = existing or {}
    incoming = incoming or {}
    return {
        ifShown = existing.ifShown or incoming.ifShown,
        readyOnly = existing.readyOnly == true and incoming.readyOnly == true,
        immediate = incoming.immediate or existing.immediate,
    }
end

local function RunRefreshUI(ctx)
    if not Key.PartyUI then
        return
    end
    if ctx.ifShown and not Key.PartyUI:IsShown() then
        return
    end
    if ctx.readyOnly then
        if Key.PartyUI.RefreshReadyOnly then
            Key.PartyUI:RefreshReadyOnly()
        end
        return
    end
    Key.PartyUI:Refresh()
end

local function CancelRefreshSchedule()
    if refreshTimer then
        refreshTimer:Cancel()
        refreshTimer = nil
    end
end

function Key.Dispatch(trigger, ctx)
    local handler = Key.TRIGGERS and Key.TRIGGERS[trigger]
    if not handler then
        return
    end

    if Key.Log and Key.Log.RunProtected then
        return Key.Log:RunProtected("Dispatch:" .. tostring(trigger), handler, ctx or {})
    end

    return handler(ctx or {})
end

function Key.RefreshPartyUIIfShown()
    Key.Dispatch("REFRESH_UI", { ifShown = true })
end

function Key.SchedulePartySyncIfGrouped()
    if IsInGroup() then
        Key.Dispatch("PARTY_SYNC_SCHEDULE")
    end
end

function Key.InvalidatePartySyncPayloads()
    if Key.PartySync and Key.PartySync.InvalidatePayloadCache then
        Key.PartySync:InvalidatePayloadCache("key")
        Key.PartySync:InvalidatePayloadCache("best")
    end
end

Key.TRIGGERS = {
    ADDON_LOADED = function()
        if not Key.PartyUI or not Key.PartyUI.TogglePanel then
            PrintMessage("|cffFF0000Key:|r PartyUI failed to load. Enable /console scriptErrors 1 and /reload.")
        else
            PrintMessage("|cff55FF55Key|r loaded. |cffFFFFFF/keyf|r party list, |cffFFFFFF/keyf debug|r console.")
        end
        if Key.PartySync and Key.PartySync.BootstrapIfGrouped then
            Key.PartySync:BootstrapIfGrouped()
        end
        if Key.Minimap and Key.Minimap.Init then
            Key.Minimap:Init()
        end
    end,

    GROUP_LEFT = function()
        if Key.PartySync and Key.PartySync.OnGroupLeft then
            Key.PartySync:OnGroupLeft()
        end
        Key.Dispatch("REFRESH_UI", { ifShown = true })
    end,

    GROUP_CHANGED = function()
        Key.Dispatch("PARTY_SYNC_SCHEDULE")
    end,

    PLAYER_ENTERING_WORLD = function()
        if IsInGroup() and Key.Keystones and Key.Keystones.RestoreSessionCacheIfNeeded then
            Key.Keystones:RestoreSessionCacheIfNeeded()
        end
        Key.Dispatch("PARTY_SYNC_SCHEDULE")
        Key.Dispatch("REFRESH_UI", { ifShown = true })
    end,

    KEYSTONE_DATA_CHANGED = function()
        Key.InvalidatePartySyncPayloads()
        Key.Dispatch("PARTY_SYNC_SCHEDULE")
        Key.Dispatch("REFRESH_UI", { ifShown = true })
    end,

    CHAT_MSG_ADDON = function(ctx)
        if Key.PartySync then
            Key.PartySync:OnAddonMessage(ctx.prefix, ctx.message, ctx.channel, ctx.sender)
        end
    end,

    PARTY_SYNC_SCHEDULE = function()
        if IsInGroup() and Key.PartySync then
            Key.PartySync:SchedulePartySync()
            return
        end
        Key.Dispatch("REFRESH_UI", { ifShown = true })
    end,

    PARTY_CHANGED = function(ctx)
        if Key.PartySync then
            Key.PartySync:OnPartyChanged()
        end
        Key.Dispatch("REFRESH_UI", {
            ifShown = true,
            immediate = ctx.immediate,
        })
    end,

    REFRESH_UI = function(ctx)
        if ctx.immediate then
            CancelRefreshSchedule()
            if pendingRefreshCtx then
                ctx = MergeRefreshContext(pendingRefreshCtx, ctx)
                pendingRefreshCtx = nil
            end
            RunRefreshUI(ctx)
            return
        end

        pendingRefreshCtx = MergeRefreshContext(pendingRefreshCtx, ctx)
        CancelRefreshSchedule()
        refreshTimer = C_Timer.NewTimer(Key.refreshDebounce, function()
            refreshTimer = nil
            local pending = pendingRefreshCtx
            pendingRefreshCtx = nil
            RunRefreshUI(pending or {})
        end)
    end,

    UI_PANEL_OPEN = function()
        if Key.PartySync then
            if IsInGroup() then
                Key.PartySync:OnPartyChanged()
            else
                Key.PartySync:PushAll(true)
            end
        end
        Key.Dispatch("REFRESH_UI", { immediate = true })
    end,

    UI_REFRESH_CLICK = function()
        if IsInGroup() and Key.PartySync then
            Key.Dispatch("PARTY_CHANGED", { immediate = true })
            return
        end
        if Key.PartySync then
            Key.PartySync:PushBest(true)
            Key.PartySync:PushReady(true)
        end
        Key.Dispatch("REFRESH_UI", { immediate = true })
    end,

    UI_RESIZE = function()
        Key.Dispatch("REFRESH_UI")
    end,

    UI_READY_TOGGLE = function()
        if Key.PartySync then
            Key.PartySync:PushReadyState(true)
            Key.PartySync.lastReadyPayload = nil
            Key.PartySync:PushReady(true)
        end
        Key.Dispatch("REFRESH_UI", { ifShown = true, immediate = true })
    end,
}

local function RunSlashCommand(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "debug" then
        if Key.Debug.UI and Key.Debug.UI.ShowConsole then
            Key.Debug.UI:ShowConsole()
        else
            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")
        end
        return
    end

    if msg == "clear" then
        if Key.Debug.UI and Key.Debug.UI.ClearLog then
            Key.Debug.UI:ClearLog()
            PrintMessage("|cff55FF55Key:|r debug log cleared.")
        else
            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")
        end
        return
    end

    if msg == "dump" then
        if Key.Debug.UI and Key.Debug.UI.DumpData then
            Key.Debug.UI:DumpData()
            PrintMessage("|cff55FF55Key:|r addon data dumped to debug log.")
        else
            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")
        end
        return
    end

    if msg == "clickdebug" or msg == "click" then
        if Key.Debug.Click and Key.Debug.Click.Toggle then
            local on = Key.Debug.Click:Toggle()
            PrintMessage(on
                and "|cff55FF55Key:|r click debug ON — use /keyf debug and click teleport icons."
                or "|cff55FF55Key:|r click debug OFF.")
            if on and Key.PartyUI and Key.PartyUI.frame and Key.PartyUI.frame:IsShown() then
                Key.Debug.Click:RewireAll()
            end
        else
            PrintMessage("|cffFF8800Key:|r click debug not loaded.")
        end
        return
    end

    if msg ~= "" then
        return
    end

    if Key.PartyUI and Key.PartyUI.TogglePanel then
        Key.PartyUI:TogglePanel()
    else
        PrintMessage("|cffFF8800Key:|r party UI not loaded.")
    end
end

SLASH_KEYF1 = "/keyf"
SlashCmdList["KEYF"] = function(msg)
    local ok, err = pcall(RunSlashCommand, msg)
    if not ok then
        PrintMessage("|cffFF0000Key error:|r " .. tostring(err))
    end
end

local KEYSTONE_DATA_EVENTS = {}

local function SafeRegisterEvent(frame, event)
    if not frame or not frame.RegisterEvent then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event)
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "GROUP_JOINED",
    "GROUP_LEFT",
    "GROUP_ROSTER_UPDATE",
}) do
    SafeRegisterEvent(eventFrame, event)
end

for _, event in ipairs({
    "CHALLENGE_MODE_MAPS_UPDATE",
    "MYTHIC_PLUS_NEW_SEASON_RECORD",
    "BAG_UPDATE_DELAYED",
}) do
    if SafeRegisterEvent(eventFrame, event) then
        KEYSTONE_DATA_EVENTS[event] = true
    end
end
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then
        return
    end

    local function HandleEvent()
        if KEYSTONE_DATA_EVENTS[event] then
            Key.Dispatch("KEYSTONE_DATA_CHANGED")
            return
        end

        if event == "ADDON_LOADED" then
            Key.Dispatch("ADDON_LOADED")
            return
        end

        if event == "GROUP_JOINED" or event == "GROUP_ROSTER_UPDATE" then
            Key.Dispatch("GROUP_CHANGED")
            return
        end
        Key.Dispatch(event)
    end

    if Key.Log and Key.Log.RunProtected then
        Key.Log:RunProtected("Core:" .. tostring(event), HandleEvent)
    else
        HandleEvent()
    end
end)


local ADDON_NAME = ...



Key = Key or {}



Key.DEFAULT_ICON = 134400

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

        readyTabOnly = existing.readyTabOnly or incoming.readyTabOnly,

        immediate = incoming.immediate or existing.immediate,

    }

end



local function RunRefreshUI(ctx)

    if not KeyPartyUI then

        return

    end

    if ctx.ifShown and not KeyPartyUI:IsShown() then

        return

    end

    if ctx.readyTabOnly and not KeyPartyUI:IsReadyTabActive() then

        return

    end

    KeyPartyUI:Refresh()

end



local function CancelRefreshSchedule()

    if refreshTimer then

        refreshTimer:Cancel()

        refreshTimer = nil

    end

end



function Key.Dispatch(trigger, ctx)

    local handler = Key.TRIGGERS and Key.TRIGGERS[trigger]

    if handler then

        return handler(ctx or {})

    end

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

    if not KeyPartySync then

        return

    end

    KeyPartySync.lastPayload = nil

    KeyPartySync.lastBestPayload = nil

end



Key.TRIGGERS = {

    ADDON_LOADED = function()

        if not KeyPartyUI or not KeyPartyUI.TogglePanel then

            PrintMessage("|cffFF0000Key:|r PartyUI failed to load. Enable /console scriptErrors 1 and /reload.")

        else

            PrintMessage("|cff55FF55Key|r loaded. |cffFFFFFF/keyf|r party list, |cffFFFFFF/keyf debug|r console.")

        end

        if KeyPartySync and KeyPartySync.BootstrapIfGrouped then

            KeyPartySync:BootstrapIfGrouped()

        end

    end,



    GROUP_LEFT = function()

        if KeyPartySync and KeyPartySync.OnGroupLeft then

            KeyPartySync:OnGroupLeft()

        end

        Key.Dispatch("REFRESH_UI", { ifShown = true })

    end,



    GROUP_JOINED = function()

        Key.Dispatch("PARTY_SYNC_SCHEDULE")

    end,



    GROUP_ROSTER_UPDATE = function()

        Key.Dispatch("PARTY_SYNC_SCHEDULE")

    end,



    PLAYER_ENTERING_WORLD = function()

        if IsInGroup() and KeyKeystones and KeyKeystones.RestoreSessionCacheIfNeeded then

            KeyKeystones:RestoreSessionCacheIfNeeded()

        end

        Key.Dispatch("PARTY_SYNC_SCHEDULE")

        Key.Dispatch("REFRESH_UI", { ifShown = true })

    end,



    KEYSTONE_DATA_CHANGED = function()

        Key.InvalidatePartySyncPayloads()

        Key.Dispatch("PARTY_SYNC_SCHEDULE")

        Key.Dispatch("REFRESH_UI", { ifShown = true })

    end,



    PLAYER_EQUIPMENT_CHANGED = function()

        if KeyPartySync then

            KeyPartySync.lastReadyPayload = nil

            KeyPartySync:PushReady(false)

            KeyPartySync:PushReadyState(false)

        end

        Key.Dispatch("REFRESH_UI", { ifShown = true })

    end,



    UNIT_AURA = function(ctx)

        local unit = ctx.unit

        if unit ~= "player" and (not unit or (not unit:match("^party") and not unit:match("^raid"))) then

            return

        end



        if unit == "player" and KeyPartySync then

            KeyPartySync.lastReadyPayload = nil

            KeyPartySync:PushReady(false)

        end



        Key.Dispatch("REFRESH_UI", { ifShown = true, readyTabOnly = true })



        if KeyDebugUI and KeyDebugUI:IsShown() and KeyLog and KeyLog.ShouldLogAuras and KeyLog:ShouldLogAuras(unit) then

            KeyLog:LogUnitAuras(unit, "UNIT_AURA")

        end

    end,



    CHAT_MSG_ADDON = function(ctx)

        if KeyPartySync then

            KeyPartySync:OnAddonMessage(ctx.prefix, ctx.message, ctx.channel, ctx.sender)

        end

    end,



    PARTY_SYNC_SCHEDULE = function()

        if IsInGroup() and KeyPartySync then

            KeyPartySync:SchedulePartySync()

            return

        end

        Key.Dispatch("REFRESH_UI", { ifShown = true })

    end,



    PARTY_CHANGED = function(ctx)

        if KeyPartySync then

            KeyPartySync:OnPartyChanged()

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

        if KeyPartySync then

            if IsInGroup() then

                KeyPartySync:OnPartyChanged()

            else

                KeyPartySync:PushAll(true)

            end

        end

        Key.Dispatch("REFRESH_UI", { immediate = true })

    end,



    UI_REFRESH_CLICK = function()

        if IsInGroup() and KeyPartySync then

            Key.Dispatch("PARTY_CHANGED", { immediate = true })

            return

        end

        if KeyPartySync then

            KeyPartySync:PushBest(true)

            KeyPartySync:PushReady(true)

        end

        Key.Dispatch("REFRESH_UI", { immediate = true })

    end,



    UI_RESIZE = function()

        Key.Dispatch("REFRESH_UI")

    end,



    UI_READY_TOGGLE = function()

        if KeyPartySync then

            KeyPartySync:PushReadyState(true)

            KeyPartySync.lastReadyPayload = nil

            KeyPartySync:PushReady(true)

        end

        Key.Dispatch("REFRESH_UI", { ifShown = true, immediate = true })

    end,

}



local function RunSlashCommand(msg)

    msg = strtrim(msg or ""):lower()



    if msg == "debug" then

        if KeyDebugUI and KeyDebugUI.ShowConsole then

            KeyDebugUI:ShowConsole()

        else

            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")

        end

        return

    end



    if msg == "clear" then

        if KeyDebugUI and KeyDebugUI.ClearLog then

            KeyDebugUI:ClearLog()

            PrintMessage("|cff55FF55Key:|r debug log cleared.")

        else

            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")

        end

        return

    end



    if msg == "dump" then

        if KeyDebugUI and KeyDebugUI.DumpData then

            KeyDebugUI:DumpData()

            PrintMessage("|cff55FF55Key:|r addon data dumped to debug log.")

        else

            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")

        end

        return

    end



    if msg == "clickdebug" or msg == "click" then

        if KeyClickDebug and KeyClickDebug.Toggle then

            local on = KeyClickDebug:Toggle()

            PrintMessage(on
                and "|cff55FF55Key:|r click debug ON — use /keyf debug and click teleport icons."
                or "|cff55FF55Key:|r click debug OFF.")

            if on and KeyPartyUI and KeyPartyUI.frame and KeyPartyUI.frame:IsShown() then

                KeyClickDebug:RewireAll()

            end

        else

            PrintMessage("|cffFF8800Key:|r click debug not loaded.")

        end

        return

    end



    if msg ~= "" then

        return

    end



    if KeyPartyUI and KeyPartyUI.TogglePanel then

        KeyPartyUI:TogglePanel()

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



local KEYSTONE_DATA_EVENTS = {

    CHALLENGE_MODE_MAPS_UPDATE = true,

    MYTHIC_PLUS_NEW_SEASON_RECORD = true,

    BAG_UPDATE_DELAYED = true,

}



local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:RegisterEvent("GROUP_JOINED")

eventFrame:RegisterEvent("GROUP_LEFT")

eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")

eventFrame:RegisterEvent("MYTHIC_PLUS_NEW_SEASON_RECORD")

eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")



eventFrame:SetScript("OnEvent", function(_, event, arg1)

    if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then

        return

    end



    if KEYSTONE_DATA_EVENTS[event] then

        Key.Dispatch("KEYSTONE_DATA_CHANGED")

        return

    end



    if event == "UNIT_AURA" then

        Key.Dispatch("UNIT_AURA", { unit = arg1 })

        return

    end



    if event == "ADDON_LOADED" then

        Key.Dispatch("ADDON_LOADED")

        return

    end



    if event == "PLAYER_LOGIN" then

        Key.Dispatch("PARTY_SYNC_SCHEDULE")

        return

    end



    Key.Dispatch(event)

end)



local ADDON_NAME = ...

Key.BDUpdates = Key.BDUpdates or {}
local Updates = Key.BDUpdates

Updates.POLL_INTERVAL = 5
Updates.auraFrame = Updates.auraFrame or CreateFrame("Frame")
Updates.spellcastFrame = Updates.spellcastFrame or CreateFrame("Frame")
Updates.eventFrame = Updates.eventFrame or CreateFrame("Frame")
Updates.watchedUnits = Updates.watchedUnits or {}

local function Log()
    return Key.AurasLog
end

local function RunProtected(context, fn, ...)
    if Key.Log and Key.Log.RunProtected then
        return Key.Log:RunProtected(context, fn, ...)
    end

    return fn(...)
end

local function SafeRegisterEvent(frame, event)
    if not frame or not frame.RegisterEvent then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event)
end

local function SafeRegisterUnitEvent(frame, event, ...)
    if not frame or not frame.RegisterUnitEvent then
        return false
    end
    return pcall(frame.RegisterUnitEvent, frame, event, ...)
end

local function ClearTable(target)
    if wipe then
        wipe(target)
        return
    end

    for key in pairs(target) do
        target[key] = nil
    end
end

local function SafeCancelTimer(timer)
    if timer and timer.Cancel then
        pcall(timer.Cancel, timer)
    end
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

function Updates:CanProcessConsumables()
    return not IsInCombat()
end

function Updates:DeferConsumableRefresh(channel)
    if self.deferredCombatRefresh then
        return
    end

    self.deferredCombatRefresh = channel or true
    self:Trace("Buff&Debuff check disabled [combat start]", "defer-combat", nil)
end

function Updates:OnCombatStarted()
    self:DeferConsumableRefresh("combat")
    self:UpdatePolling()
end

function Updates:OnCombatEnded()
    self:UpdatePolling()
    self:FlushDeferredConsumableRefresh()
end

function Updates:FlushDeferredConsumableRefresh()
    if not self.deferredCombatRefresh then
        return
    end

    local channel = self.deferredCombatRefresh
    self.deferredCombatRefresh = nil
    self:Trace("Buff&Debuff refresh cleared [combat end]", "combat-end", nil)

    if channel == "equipment" then
        self:InvalidatePlayerReadyState()
    end

    self.dirtyChannel = nil
    RunProtected("Key.BDUpdates:FlushDeferredConsumableRefresh", function()
        self.lastFingerprint = self:GetConsumableFingerprint()
        self:RunConsumableRefresh("combat-end")
    end)
end

local function FingerprintValue(value, fallback)
    if value == nil or value == false then
        return fallback or ""
    end

    if issecretvalue and issecretvalue(value) then
        return fallback or ""
    end

    if Key.Log and Key.Log.TryDisplayValue then
        return Key.Log:TryDisplayValue(value) or fallback or ""
    end

    local ok, text = pcall(tostring, value)
    return ok and text or (fallback or "")
end

function Updates:Trace(message, dedupeKey, dedupeWindow)
    local aurasLog = Log()
    if aurasLog and aurasLog.LogUpdate then
        local source = "Trace"
        if debug and debug.getinfo then
            local info = debug.getinfo(2, "n")
            if info and info.name and info.name ~= "" then
                source = info.name
            end
        end
        aurasLog:LogUpdate(message, dedupeKey, dedupeWindow, source)
    end
end

function Updates:TraceConsumableState(unit, reason)
    local aurasLog = Log()
    if not aurasLog or not aurasLog.LogUpdateConsumableState then
        return
    end
    if aurasLog.ShouldLogUpdates and not aurasLog:ShouldLogUpdates() then
        return
    end

    aurasLog:LogUpdateConsumableState(unit, reason)
end

function Updates:ShouldRefreshReadyUI()
    return Key.PartyUI
        and Key.PartyUI.IsShown and Key.PartyUI:IsShown()
        and Key.PartyUI.IsReadyTabActive and Key.PartyUI:IsReadyTabActive()
end

function Updates:ScheduleConsumablePoll()
    if not self:CanProcessConsumables() then
        self:DeferConsumableRefresh(self.dirtyChannel)
        return
    end

    if self.consumablePollTimer then
        return
    end

    self.consumablePollTimer = C_Timer.After(0, function()
        self.consumablePollTimer = nil
        RunProtected("Key.BDUpdates:PollConsumableChanges", function()
            self:PollConsumableChanges()
        end)
    end)
end

function Updates:ScheduleReadyOnlyRefresh(reason)
    if not self:CanProcessConsumables() then
        self:DeferConsumableRefresh(reason)
        return
    end

    if not self:ShouldRefreshReadyUI() then
        return
    end

    if self.readyRefreshTimer then
        return
    end

    self.readyRefreshTimer = C_Timer.After(0, function()
        self.readyRefreshTimer = nil
        self:RefreshReadyConsumables(true, reason)
    end)
end

function Updates:IsTrackedAuraUnit(unit)
    if not unit then
        return false
    end

    if self.watchedUnits[unit] then
        return true
    end

    return unit == "player"
        or unit:match("^party") ~= nil
        or unit:match("^raid") ~= nil
end

function Updates:CollectAuraUnits()
    local units = { "player" }

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local unit = "raid" .. index
            if UnitExists(unit) then
                units[#units + 1] = unit
            end
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            local unit = "party" .. index
            if UnitExists(unit) then
                units[#units + 1] = unit
            end
        end
    end

    return units
end

function Updates:RefreshWatchedUnits(reason)
    ClearTable(self.watchedUnits)

    local units = self:CollectAuraUnits()
    for _, unit in ipairs(units) do
        self.watchedUnits[unit] = true
    end

    local aurasLog = Log()
    local unitList = aurasLog and aurasLog.FormatUnitList and aurasLog:FormatUnitList(units) or table.concat(units, ", ")
    self:Trace(string.format(
        "RefreshWatchedUnits (%s) units=%s poll=%ds",
        reason or "?",
        unitList,
        self.POLL_INTERVAL
    ))

    self:RegisterUnitAuraEvents()
end

function Updates:RegisterUnitAuraEvents()
    if not self.channelsInstalled or self.unitAuraUsesGlobalEvent then
        return
    end

    local units = self:CollectAuraUnits()
    if SafeRegisterUnitEvent(self.auraFrame, "UNIT_AURA", unpack(units)) then
        return
    end

    if SafeRegisterEvent(self.auraFrame, "UNIT_AURA") then
        self.unitAuraUsesGlobalEvent = true
        self:Trace("UNIT_AURA using global RegisterEvent fallback")
        return
    end

    self:Trace("UNIT_AURA registration failed")
end

function Updates:GetConsumableFingerprint()
    if not Key.Auras or not Key.Auras.GetConsumableStatus then
        return ""
    end

    local ok, fingerprint = pcall(function()
        local food, _, flaskReady, flaskLabel, oil, oilLabel, _, _, oilIcon, flaskIcon, flaskQualityTier, _, oilQualityTier,
            foodEating, foodEatingLabel = Key.Auras:GetConsumableStatus("player")
        return table.concat({
            food and "1" or "0",
            foodEating and "1" or "0",
            FingerprintValue(foodEatingLabel),
            FingerprintValue(flaskIcon, "0"),
            FingerprintValue(flaskLabel),
            flaskReady and "1" or "0",
            FingerprintValue(flaskQualityTier),
            oil and "1" or "0",
            FingerprintValue(oilIcon, "0"),
            FingerprintValue(oilLabel),
            FingerprintValue(oilQualityTier),
        }, "|")
    end)

    return ok and fingerprint or ""
end

function Updates:HasActiveFlaskTimer()
    if not Key.Auras or not Key.Auras.GetConsumableStatus then
        return false
    end

    local ok, flaskReady, hasRemaining = pcall(function()
        local _, _, ready, _, _, _, _, _, _, _, _, remaining = Key.Auras:GetConsumableStatus("player")
        if not ready then
            return false, false
        end
        if issecretvalue and issecretvalue(remaining) then
            return true, false
        end
        if remaining == nil then
            return true, false
        end
        return true, true
    end)

    return ok and flaskReady and hasRemaining
end

function Updates:ShouldRunPollTicker()
    local partyShown = Key.PartyUI and Key.PartyUI.IsShown and Key.PartyUI:IsShown()
    return partyShown and not IsInCombat()
end

function Updates:StopPollTicker(reason, silent)
    SafeCancelTimer(self.consumablePollTimer)
    self.consumablePollTimer = nil
    SafeCancelTimer(self.readyRefreshTimer)
    self.readyRefreshTimer = nil

    if not self.pollTicker then
        return
    end

    SafeCancelTimer(self.pollTicker)
    self.pollTicker = nil
    self.dirtyChannel = nil
    if not silent and reason then
        self:Trace(reason)
    end
end

function Updates:UpdatePolling()
    if self:ShouldRunPollTicker() then
        if not self.pollTicker then
            self.lastFingerprint = self:GetConsumableFingerprint()
            self.pollTicker = C_Timer.NewTicker(self.POLL_INTERVAL, function()
                if IsInCombat() then
                    return
                end

                RunProtected("Key.BDUpdates:PollConsumableChanges", function()
                    self:PollConsumableChanges()
                end)
            end)
            self:Trace(string.format("poll ticker started (every %ds, party panel open)", self.POLL_INTERVAL))
        end
        return
    end

    if self.pollTicker then
        self:StopPollTicker(nil, IsInCombat())
    end
end

function Updates:MarkConsumablesDirty(channel, unit)
    if not self:CanProcessConsumables() then
        return
    end

    self.dirtyChannel = channel or self.dirtyChannel or "dirty"

    if unit and unit ~= "player" then
        self:ScheduleReadyOnlyRefresh(channel or "UNIT_AURA")
        return
    end

    self:ScheduleConsumablePoll()
end

function Updates:RefreshReadyConsumablesIfShown(immediate, reason)
    if self:ShouldRefreshReadyUI() then
        self:RefreshReadyConsumables(immediate, reason)
    end
end

function Updates:PollConsumableChanges()
    if not self:CanProcessConsumables() then
        self:DeferConsumableRefresh(self.dirtyChannel)
        return
    end

    local fingerprint = self:GetConsumableFingerprint()
    local channel = self.dirtyChannel
    self.dirtyChannel = nil

    local previousFingerprint = self.lastFingerprint
    local fingerprintChanged = previousFingerprint ~= fingerprint
    self.lastFingerprint = fingerprint

    if fingerprintChanged then
        self:Trace(string.format("Buff&Debuff changed [%s]", channel or "poll"))
        self:RunConsumableRefresh(channel or "poll")
        return
    end

    if channel then
        self:ScheduleReadyOnlyRefresh(channel)
        return
    end

    if self:HasActiveFlaskTimer() and self:ShouldRefreshReadyUI() then
        self:RefreshReadyConsumables(true, "flask-timer")
    end
end

function Updates:RefreshReadyConsumables(immediate, reason)
    if reason ~= "combat-end" and self:ShouldRefreshReadyUI() then
        self:Trace(string.format("Buff&Debuff UI refresh [%s]", reason or "?"), "refresh:" .. tostring(reason or "generic"), 0.1)
    end

    if not Key or not Key.Dispatch then
        return
    end

    Key.Dispatch("REFRESH_UI", {
        ifShown = true,
        readyOnly = true,
        immediate = immediate,
    })
end

function Updates:SyncPlayerReadyPayload(reason)
    if not Key.PartySync then
        return
    end

    Key.PartySync:PushReady(false)

    if reason ~= "combat-end" then
        self:Trace(string.format("Buff&Debuff synced [%s]", reason or "?"))
    end
    self:TraceConsumableState("player", reason or "sync")
end

function Updates:InvalidatePlayerReadyState()
    if not Key.PartySync then
        return
    end

    Key.PartySync:InvalidatePayloadCache("ready")
    Key.PartySync:PushReady(false)
    Key.PartySync:PushReadyState(false)
end

function Updates:LogUnitAurasIfDebugging(unit, reason)
    if not self:CanProcessConsumables() then
        return
    end

    if not Key.Debug.UI or not Key.Debug.UI:IsShown() then
        return
    end

    if not Key.Log or not Key.Log.ShouldLogAuras or not Key.Log:ShouldLogAuras(unit) then
        return
    end

    Key.Log:LogUnitAuras(unit, reason)
end

function Updates:RunConsumableRefresh(channel)
    if not self:CanProcessConsumables() then
        self:DeferConsumableRefresh(channel)
        return
    end

    self:RefreshReadyConsumablesIfShown(true, channel or "refresh")
    self:SyncPlayerReadyPayload(channel or "refresh")
end

function Updates:OnUnitAura(unit)
    if not self:IsTrackedAuraUnit(unit) then
        return
    end

    if not self:CanProcessConsumables() then
        return
    end

    self:MarkConsumablesDirty("UNIT_AURA", unit)
    self:LogUnitAurasIfDebugging(unit, "UNIT_AURA")
end

function Updates:OnInventoryChanged(unit)
    if unit and unit ~= "player" then
        return
    end

    if not self:CanProcessConsumables() then
        return
    end

    self:Trace("UNIT_INVENTORY_CHANGED unit=player", "inventory-changed", 0.1)
    self:MarkConsumablesDirty("UNIT_INVENTORY_CHANGED")
end

function Updates:OnPlayerSpellcastSucceeded(unit, castGUID, spellId)
    if unit and unit ~= "player" then
        return
    end

    if not self:CanProcessConsumables() then
        return
    end

    if not Key.Auras or not Key.Auras.IsKnownConsumableSpell or not Key.Auras:IsKnownConsumableSpell(spellId) then
        return
    end

    self:Trace(string.format(
        "UNIT_SPELLCAST_SUCCEEDED unit=%s spellId=%s",
        unit or "?",
        tostring(spellId)
    ), "spellcast", 0.1)
    self:MarkConsumablesDirty("SPELLCAST_SUCCEEDED")
end

function Updates:OnEquipmentChanged()
    self:Trace("PLAYER_EQUIPMENT_CHANGED")
    if not self:CanProcessConsumables() then
        return
    end

    self:InvalidatePlayerReadyState()
    self:MarkConsumablesDirty("equipment")
end

function Updates:OnRosterChanged(event)
    self:Trace(string.format("roster event %s", event or "?"))
    self:RefreshWatchedUnits(event or "roster")
end

function Updates:InstallAuraChannels()
    if self.channelsInstalled then
        return
    end

    self.channelsInstalled = true

    self.auraFrame:SetScript("OnEvent", function(_, event, unit)
        RunProtected("Key.BDUpdates:" .. tostring(event), function()
            if event == "UNIT_AURA" then
                self:OnUnitAura(unit)
            elseif event == "UNIT_INVENTORY_CHANGED" then
                self:OnInventoryChanged(unit)
            end
        end)
    end)
    if not SafeRegisterUnitEvent(self.auraFrame, "UNIT_INVENTORY_CHANGED", "player") then
        self:Trace("UNIT_INVENTORY_CHANGED registration failed; poll still active")
    end

    self.spellcastFrame:SetScript("OnEvent", function(_, event, unit, castGUID, spellId)
        RunProtected("Key.BDUpdates:UNIT_SPELLCAST_SUCCEEDED", function()
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                self:OnPlayerSpellcastSucceeded(unit, castGUID, spellId)
            end
        end)
    end)

    if not SafeRegisterUnitEvent(self.spellcastFrame, "UNIT_SPELLCAST_SUCCEEDED", "player") then
        self:Trace("UNIT_SPELLCAST_SUCCEEDED registration failed; poll still active")
    end

    self:Trace("Aura channels installed (UNIT_AURA, UNIT_INVENTORY_CHANGED, optional SPELLCAST_SUCCEEDED)")
end

function Updates:Install()
    if self.installed then
        return
    end

    self.installed = true
    self:InstallAuraChannels()
    self:RefreshWatchedUnits("install")

    local eventFrame = self.eventFrame
    for _, event in ipairs({
        "PLAYER_LOGIN",
        "PLAYER_ENTERING_WORLD",
        "GROUP_JOINED",
        "GROUP_LEFT",
        "GROUP_ROSTER_UPDATE",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
    }) do
        SafeRegisterEvent(eventFrame, event)
    end

    eventFrame:SetScript("OnEvent", function(_, event)
        RunProtected("Key.BDUpdates:" .. tostring(event), function()
            if event == "PLAYER_LOGIN"
                or event == "PLAYER_ENTERING_WORLD"
                or event == "GROUP_JOINED"
                or event == "GROUP_LEFT"
                or event == "GROUP_ROSTER_UPDATE"
            then
                self:OnRosterChanged(event)
            elseif event == "PLAYER_EQUIPMENT_CHANGED" then
                self:OnEquipmentChanged()
            elseif event == "PLAYER_REGEN_DISABLED" then
                self:OnCombatStarted()
            elseif event == "PLAYER_REGEN_ENABLED" then
                self:OnCombatEnded()
            end
        end)
    end)

    self:Trace(string.format("Install complete (poll every %ds)", self.POLL_INTERVAL))

    if IsInCombat() then
        self:DeferConsumableRefresh("combat")
    end
end

RunProtected("Key.BDUpdates:Install", function()
    Updates:Install()
end)


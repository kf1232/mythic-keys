local ADDON_NAME = ...

KeyDebugData = KeyDebugData or {}
local DebugData = KeyDebugData

function DebugData:ShortName(sender)
    if not sender or sender == "" then
        return "?"
    end
    return Ambiguate(sender, "short")
end

function DebugData:FormatBestSummary(bests)
    if not bests or not next(bests) then
        return "none"
    end

    if not KeyKeystones or not KeyKeystones.GetSeasonDungeons then
        return "unavailable"
    end

    local parts = {}
    for _, dungeon in ipairs(KeyKeystones:GetSeasonDungeons()) do
        local entry = bests[dungeon.challengeModeID]
        if entry and entry.level and entry.level > 0 then
            local suffix = entry.overTime and " OT" or ""
            parts[#parts + 1] = string.format("%s +%d%s", dungeon.shortName, entry.level, suffix)
        end
    end

    if #parts == 0 then
        return "none"
    end

    return table.concat(parts, ", ")
end

function DebugData:FormatReadySummary(entry)
    if not entry then
        return "none"
    end

    return string.format(
        "ready=%s repair=%s food=%s flask=%s oil=%s",
        (entry.isReady and "yes" or "no"),
        tostring(entry.repair or "?"),
        tostring(entry.food or 0),
        tostring(entry.flask or 0),
        tostring(entry.oil or 0)
    )
end

function DebugData:GetGroupSummary()
    if IsInRaid() then
        return string.format("raid (%d)", GetNumGroupMembers())
    end

    if IsInGroup() then
        return string.format("party (%d)", 1 + GetNumSubgroupMembers())
    end

    return "solo"
end

function DebugData:DumpPrimaryCache(title, cache, formatter)
    if not KeyLog then
        return
    end

    KeyLog:Add(title)

    if not cache or not next(cache) then
        KeyLog:Add("  (empty)")
        return
    end

    local senders = {}
    for sender in pairs(cache) do
        senders[#senders + 1] = sender
    end
    table.sort(senders, function(a, b)
        return self:ShortName(a) < self:ShortName(b)
    end)

    for _, sender in ipairs(senders) do
        KeyLog:Add(string.format("  %s: %s", self:ShortName(sender), formatter(cache[sender])))
    end
end

function DebugData:DumpToLog()
    if not KeyLog or not KeyLog.Add then
        return
    end

    KeyLog:Add("--- Key data dump ---")

    KeyLog:Add("Group: " .. self:GetGroupSummary())

    if KeyExternalKeystones and KeyExternalKeystones.GetProviderSummary then
        KeyLog:Add("External keystones: " .. KeyExternalKeystones:GetProviderSummary())
    end

    if KeyPartyUI and KeyPartyUI.activeTab then
        KeyLog:Add("Active tab: " .. tostring(KeyPartyUI.activeTab))
    end

    if KeyKeystones then
        local ownKey = KeyKeystones:GetOwnKeystone()
        KeyLog:Add("Player keystone: " .. KeyKeystones:FormatKey(ownKey))

        self:DumpPrimaryCache("Party keystones:", KeyKeystones.primaryCache, function(entry)
            return KeyKeystones:FormatKey(entry)
        end)

        self:DumpPrimaryCache("Season bests:", KeyKeystones.primaryBestCache, function(entry)
            return self:FormatBestSummary(entry)
        end)
    end

    if KeyReadyCheck then
        KeyLog:Add(string.format("Player ready toggle: %s", KeyReadyCheck:GetPlayerReady() and "yes" or "no"))

        self:DumpPrimaryCache("Ready payloads:", KeyReadyCheck.primaryReadyCache, function(entry)
            return self:FormatReadySummary(entry)
        end)
    end

    if KeyAurasLog and KeyAurasLog.LogConsumableDiagnostics then
        KeyAurasLog:LogConsumableDiagnostics("player")
    end

    if KeyAurasLog and KeyAurasLog.LogUnitAuras then
        KeyAurasLog:LogUnitAuras("player", "Dump snapshot")
    end

    if KeyLog and KeyLog.LogMinimapSnapshot then
        KeyLog:LogMinimapSnapshot()
    end

    if KeyLog and KeyLog.LogTeleportBarSnapshot then
        KeyLog:LogTeleportBarSnapshot()
    end

    if KeyLog and KeyLog.LogPartyCompleteSnapshot then
        KeyLog:LogPartyCompleteSnapshot()
    end

    if KeyPartySync then
        KeyLog:Add("Sync payloads:")
        KeyLog:Add("  lastKey: " .. tostring(KeyPartySync.lastPayload or "(none)"))
        KeyLog:Add("  lastBest: " .. tostring(KeyPartySync.lastBestPayload or "(none)"))
        KeyLog:Add("  lastReady: " .. tostring(KeyPartySync.lastReadyPayload or "(none)"))
        KeyLog:Add("  lastReadyState: " .. tostring(KeyPartySync.lastReadyStatePayload or "(none)"))
    end

    KeyLog:Add("--- end dump ---")
end

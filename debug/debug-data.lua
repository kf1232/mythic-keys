local ADDON_NAME = ...

Key.Debug.Data = Key.Debug.Data or {}
local DebugData = Key.Debug.Data

local FEATURE = Key.Log and Key.Log.FEATURE and Key.Log.FEATURE.DEBUG or "DBUG"

local function WriteEvent(status, payload, options)
    if not Key.Log or not Key.Log.WriteEvent then
        return
    end

    options = options or {}
    if not options.source and debug and debug.getinfo then
        local info = debug.getinfo(2, "n")
        if info and info.name and info.name ~= "" then
            options.source = info.name
        end
    end

    Key.Log:WriteEvent(FEATURE, status, payload, options)
end

function DebugData:ShortName(sender)
    if not sender or sender == "" then
        return "?"
    end
    return Key.Api.Strings:Ambiguate(false, sender, "short") or "?"
end

function DebugData:FormatBestSummary(bests)
    if not bests or not next(bests) then
        return "none"
    end

    if not Key.Keystones or not Key.Keystones.GetSeasonDungeons then
        return "unavailable"
    end

    local parts = {}
    for _, dungeon in ipairs(Key.Keystones:GetSeasonDungeons()) do
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
    if Key.Api.Group:IsInRaid(false) then
        return string.format("raid (%d)", Key.Api.Group:GetNumMembers(false))
    end

    if Key.Api.Group:IsInGroup(false) then
        return string.format("party (%d)", 1 + Key.Api.Group:GetNumSubgroupMembers(false))
    end

    return "solo"
end

function DebugData:DumpPrimaryCache(title, cache, formatter)
    WriteEvent(Key.Log.STATUS.DEBUG, title, { dedupe = false })

    if not cache or not next(cache) then
        WriteEvent(Key.Log.STATUS.DEBUG, "  (empty)", { dedupe = false })
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
        WriteEvent(Key.Log.STATUS.DEBUG, string.format("  %s: %s", self:ShortName(sender), formatter(cache[sender])), {
            dedupe = false,
        })
    end
end

function DebugData:DumpToLog()
    if not Key.Log or not Key.Log.WriteEvent then
        return
    end

    WriteEvent(Key.Log.STATUS.INFO, "--- Key data dump ---", { dedupe = false })

    WriteEvent(Key.Log.STATUS.DEBUG, "Group: " .. self:GetGroupSummary(), { dedupe = false })

    if Key.Integrations.ExternalKeystones and Key.Integrations.ExternalKeystones.GetProviderSummary then
        WriteEvent(Key.Log.STATUS.DEBUG, "External keystones: " .. Key.Integrations.ExternalKeystones:GetProviderSummary(), { dedupe = false })
    end

    if Key.PartyUI and Key.PartyUI.activeTab then
        WriteEvent(Key.Log.STATUS.DEBUG, "Active tab: " .. tostring(Key.PartyUI.activeTab), { dedupe = false })
    end

    if Key.Keystones then
        local ownKey = Key.Keystones:GetOwnKeystone()
        WriteEvent(Key.Log.STATUS.DEBUG, "Player keystone: " .. Key.Keystones:FormatKey(ownKey), { dedupe = false })

        self:DumpPrimaryCache("Party keystones:", Key.Cache:GetPrimary(Key.Keystones:GetKeystoneStore()), function(entry)
            return Key.Keystones:FormatKey(entry)
        end)

        self:DumpPrimaryCache("Season bests:", Key.Cache:GetPrimary(Key.Keystones:GetSeasonBestStore()), function(entry)
            return self:FormatBestSummary(entry)
        end)
    end

    if Key.ReadyCheck then
        local targetZone = Key.ReadyCheck.GetTargetZone and Key.ReadyCheck:GetTargetZone() or nil
        WriteEvent(Key.Log.STATUS.DEBUG, string.format("Target zone: %s", targetZone or "none"), {
            dedupe = false,
        })

        self:DumpPrimaryCache("Ready payloads:", Key.Cache:GetPrimary(Key.ReadyCheck:GetReadyStore()), function(entry)
            return self:FormatReadySummary(entry)
        end)
    end

    if Key.AurasLog and Key.AurasLog.LogConsumableDiagnostics then
        Key.AurasLog:LogConsumableDiagnostics("player")
    end

    if Key.AurasLog and Key.AurasLog.LogUnitAuras then
        Key.AurasLog:LogUnitAuras("player", "Dump snapshot")
    end

    if Key.Log and Key.Log.LogMinimapSnapshot then
        Key.Log:LogMinimapSnapshot()
    end

    if Key.Log and Key.Log.LogTeleportBarSnapshot then
        Key.Log:LogTeleportBarSnapshot()
    end

    if Key.Log and Key.Log.LogPartyCompleteSnapshot then
        Key.Log:LogPartyCompleteSnapshot()
    end

    if Key.PartySync then
        WriteEvent(Key.Log.STATUS.DEBUG, "Sync payloads:", { dedupe = false })
        WriteEvent(Key.Log.STATUS.DEBUG, "  lastKey: " .. tostring(Key.PartySync.lastPayload or "(none)"), { dedupe = false })
        WriteEvent(Key.Log.STATUS.DEBUG, "  lastBest: " .. tostring(Key.PartySync.lastBestPayload or "(none)"), { dedupe = false })
        WriteEvent(Key.Log.STATUS.DEBUG, "  lastReady: " .. tostring(Key.PartySync.lastReadyPayload or "(none)"), { dedupe = false })
        WriteEvent(Key.Log.STATUS.DEBUG, "  lastReadyState: " .. tostring(Key.PartySync.lastReadyStatePayload or "(none)"), { dedupe = false })
    end

    WriteEvent(Key.Log.STATUS.INFO, "--- end dump ---", { dedupe = false })
end

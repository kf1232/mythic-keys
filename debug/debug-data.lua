local ADDON_NAME = ...

KeyDebugData = KeyDebugData or {}
local DebugData = KeyDebugData

local FEATURE = KeyLog and KeyLog.FEATURE and KeyLog.FEATURE.DEBUG or "DBUG"

local function WriteEvent(status, payload, options)
    if not KeyLog or not KeyLog.WriteEvent then
        return
    end

    options = options or {}
    if not options.source and debug and debug.getinfo then
        local info = debug.getinfo(2, "n")
        if info and info.name and info.name ~= "" then
            options.source = info.name
        end
    end

    KeyLog:WriteEvent(FEATURE, status, payload, options)
end

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
    WriteEvent(KeyLog.STATUS.DEBUG, title, { dedupe = false })

    if not cache or not next(cache) then
        WriteEvent(KeyLog.STATUS.DEBUG, "  (empty)", { dedupe = false })
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
        WriteEvent(KeyLog.STATUS.DEBUG, string.format("  %s: %s", self:ShortName(sender), formatter(cache[sender])), {
            dedupe = false,
        })
    end
end

function DebugData:DumpToLog()
    if not KeyLog or not KeyLog.WriteEvent then
        return
    end

    WriteEvent(KeyLog.STATUS.INFO, "--- Key data dump ---", { dedupe = false })

    WriteEvent(KeyLog.STATUS.DEBUG, "Group: " .. self:GetGroupSummary(), { dedupe = false })

    if KeyExternalKeystones and KeyExternalKeystones.GetProviderSummary then
        WriteEvent(KeyLog.STATUS.DEBUG, "External keystones: " .. KeyExternalKeystones:GetProviderSummary(), { dedupe = false })
    end

    if KeyPartyUI and KeyPartyUI.activeTab then
        WriteEvent(KeyLog.STATUS.DEBUG, "Active tab: " .. tostring(KeyPartyUI.activeTab), { dedupe = false })
    end

    if KeyKeystones then
        local ownKey = KeyKeystones:GetOwnKeystone()
        WriteEvent(KeyLog.STATUS.DEBUG, "Player keystone: " .. KeyKeystones:FormatKey(ownKey), { dedupe = false })

        self:DumpPrimaryCache("Party keystones:", KeyKeystones.primaryCache, function(entry)
            return KeyKeystones:FormatKey(entry)
        end)

        self:DumpPrimaryCache("Season bests:", KeyKeystones.primaryBestCache, function(entry)
            return self:FormatBestSummary(entry)
        end)
    end

    if KeyReadyCheck then
        WriteEvent(KeyLog.STATUS.DEBUG, string.format("Player ready toggle: %s", KeyReadyCheck:GetPlayerReady() and "yes" or "no"), {
            dedupe = false,
        })

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
        WriteEvent(KeyLog.STATUS.DEBUG, "Sync payloads:", { dedupe = false })
        WriteEvent(KeyLog.STATUS.DEBUG, "  lastKey: " .. tostring(KeyPartySync.lastPayload or "(none)"), { dedupe = false })
        WriteEvent(KeyLog.STATUS.DEBUG, "  lastBest: " .. tostring(KeyPartySync.lastBestPayload or "(none)"), { dedupe = false })
        WriteEvent(KeyLog.STATUS.DEBUG, "  lastReady: " .. tostring(KeyPartySync.lastReadyPayload or "(none)"), { dedupe = false })
        WriteEvent(KeyLog.STATUS.DEBUG, "  lastReadyState: " .. tostring(KeyPartySync.lastReadyStatePayload or "(none)"), { dedupe = false })
    end

    WriteEvent(KeyLog.STATUS.INFO, "--- end dump ---", { dedupe = false })
end

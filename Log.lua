local ADDON_NAME = ...

KeyLog = KeyLog or {}
local Log = KeyLog

Log.entries = Log.entries or {}
Log.listeners = Log.listeners or {}
Log.maxEntries = 500
Log.auraLogThrottle = Log.auraLogThrottle or {}
Log.dedupeCache = Log.dedupeCache or {}

local function Auras()
    return KeyAuras
end

function Log:MergeAuraSources(aura, rawAura)
    return Auras():MergeAuraSources(aura, rawAura)
end

function Log:SafeValue(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return "[secret]"
    end
    return tostring(value)
end

function Log:TryDisplayValue(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        local ok, result = pcall(string.format, "%s", value)
        if ok and result and result ~= "" then
            return result
        end
        return "[secret]"
    end
    return tostring(value)
end

function Log:ResolveSpellName(spellId, displayName)
    if not spellId or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end
    if issecretvalue and issecretvalue(spellId) then
        return nil
    end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    if not spellInfo or not spellInfo.name then
        return nil
    end

    local spellName = self:TryDisplayValue(spellInfo.name)
    if spellName and spellName ~= displayName then
        return spellName
    end

    return nil
end

function Log:GetAuraName(aura, rawAura)
    if not aura and not rawAura then
        return nil
    end

    local merged = self:MergeAuraSources(aura, rawAura)

    for _, source in ipairs({ merged, rawAura, aura }) do
        if source and source.name then
            local name = self:TryDisplayValue(source.name)
            if name and name ~= "[secret]" then
                return name
            end
        end
    end

    if merged and merged.spellId then
        return self:ResolveSpellName(merged.spellId, nil)
    end

    return nil
end

function Log:FormatAuraRemaining(merged)
    if not merged
        or not merged.expirationTime
        or merged.expirationTime <= 0
        or (issecretvalue and issecretvalue(merged.expirationTime))
    then
        return nil
    end

    local remaining = merged.expirationTime - GetTime()
    if remaining <= 0 then
        return nil
    end

    if remaining >= 60 then
        return string.format("%dm", math.floor(remaining / 60 + 0.5))
    end

    return string.format("%ds", math.floor(remaining + 0.5))
end

function Log:GetAuraStacks(aura, rawAura)
    for _, source in ipairs({ aura, rawAura }) do
        if source then
            local stacks = source.applications or source.count or source.charges
            if stacks and stacks > 1 then
                return self:TryDisplayValue(stacks)
            end
        end
    end

    return nil
end

function Log:GetAuraLabel(aura, rawAura)
    local label = self:GetAuraName(aura, rawAura) or "?"
    local merged = self:MergeAuraSources(aura, rawAura)
    local details = {}
    local remaining = self:FormatAuraRemaining(merged)
    local stacks = self:GetAuraStacks(aura, rawAura)

    if remaining then
        details[#details + 1] = remaining
    end

    if stacks then
        details[#details + 1] = "x" .. stacks
    end

    if #details == 0 then
        return label
    end

    return label .. " (" .. table.concat(details, ", ") .. ")"
end

function Log:CollectAuras(unit, filter)
    return Auras():CollectAuras(unit, filter)
end

function Log:ShouldLogAuras(unit)
    local now = GetTime()
    local nextAt = self.auraLogThrottle[unit] or 0
    if now < nextAt then
        return false
    end
    self.auraLogThrottle[unit] = now + 0.5
    return true
end

function Log:LogConsumableSummary(unit)
    if not KeyAuras then
        return
    end

    local food, foodLabel, flask, flaskLabel, oil, oilLabel, _, foodHearty, _, _, flaskQualityTier = KeyAuras:GetConsumableStatus(unit)
    local parts = {}

    if flask then
        local label = flaskLabel or "Flask"
        if flaskQualityTier then
            label = label .. " (" .. flaskQualityTier .. ")"
        end
        parts[#parts + 1] = label
    end

    if food then
        local label = foodLabel or "Food"
        if foodHearty then
            label = "Hearty " .. label
        end
        parts[#parts + 1] = label
    end

    if oil then
        parts[#parts + 1] = oilLabel or "Oil"
    end

    if #parts == 0 then
        self:Add("  consumables: none")
        return
    end

    self:Add("  consumables: " .. table.concat(parts, ", "))
end

function Log:LogUnitAuras(unit, reason)
    if not unit or not UnitExists(unit) then
        return
    end

    local buffs = self:CollectAuras(unit, "HELPFUL")
    local debuffs = self:CollectAuras(unit, "HARMFUL")
    local unitLabel = self:SafeValue(UnitName(unit)) or unit

    self:Add(string.format(
        "%s %s — %d buff(s), %d debuff(s)",
        reason or "Auras",
        unitLabel,
        #buffs,
        #debuffs
    ))

    self:LogConsumableSummary(unit)

    for _, entry in ipairs(buffs) do
        self:Add("  + " .. self:GetAuraLabel(entry.aura, entry.rawAura))
    end
end

function Log:FormatEntry(entry)
    return string.format("[%s] %s", entry.time, entry.message)
end

function Log:Add(message, dedupeKey, dedupeWindow)
    if type(message) ~= "string" or message == "" then
        return
    end

    if dedupeKey then
        local now = GetTime()
        local lastAt = self.dedupeCache[dedupeKey]
        if lastAt and (now - lastAt) < (dedupeWindow or 2) then
            return
        end
        self.dedupeCache[dedupeKey] = now
    end

    local entry = {
        time = date("%H:%M:%S"),
        message = message,
    }

    table.insert(self.entries, entry)

    while #self.entries > self.maxEntries do
        table.remove(self.entries, 1)
    end

    for _, listener in ipairs(self.listeners) do
        listener(entry)
    end
end

function Log:FormatKeystone(key)
    if KeyKeystones and KeyKeystones.FormatKey then
        return KeyKeystones:FormatKey(key)
    end

    if not key or not key.level or key.level == 0 then
        return "no key"
    end

    return string.format("+%d", key.level)
end

function Log:LogKeystone(sender, key)
    if not sender or sender == "" then
        return
    end

    local shortName = Ambiguate(sender, "short")
    local summary = self:FormatKeystone(key)
    self:Add(
        string.format("%s: %s", shortName, summary),
        "keystone:" .. shortName .. ":" .. summary,
        10
    )
end

function Log:Subscribe(callback)
    if type(callback) ~= "function" then
        return
    end
    table.insert(self.listeners, callback)
end

function Log:GetText()
    local lines = {}
    for _, entry in ipairs(self.entries) do
        lines[#lines + 1] = self:FormatEntry(entry)
    end
    return table.concat(lines, "\n")
end

function Log:Clear()
    wipe(self.entries)
    wipe(self.dedupeCache)
    for _, listener in ipairs(self.listeners) do
        listener(nil, true)
    end
end

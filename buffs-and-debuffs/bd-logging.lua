local ADDON_NAME = ...

Key.AurasLog = Key.AurasLog or {}
local AurasLog = Key.AurasLog

AurasLog.auraLogThrottle = AurasLog.auraLogThrottle or {}
AurasLog.updateLogThrottle = AurasLog.updateLogThrottle or {}

local function Log()
    return Key.Log
end

local FEATURE = Key.Log and Key.Log.FEATURE and Key.Log.FEATURE.BUFFS_DEBUFFS or "B&DB"

local function Write(status, payload, dedupeKey, dedupeWindow, source)
    local keyLog = Log()
    if not keyLog or not keyLog.WriteEvent then
        return
    end

    local options = {}
    if dedupeKey then
        options.dedupeKey = dedupeKey
        if dedupeWindow then
            options.dedupeWindow = dedupeWindow
        end
    else
        options.dedupe = false
    end

    options.source = source
    if not options.source and debug and debug.getinfo then
        local info = debug.getinfo(2, "n")
        if info and info.name and info.name ~= "" then
            options.source = info.name
        end
    end

    keyLog:WriteEvent(FEATURE, status, payload, options)
end

local function Auras()
    return Key.Auras
end

function AurasLog:MergeAuraSources(aura, rawAura)
    local auras = Auras()
    if not auras then
        return rawAura or aura
    end
    return auras:MergeAuraSources(aura, rawAura)
end

function AurasLog:GetAuraName(aura, rawAura)
    local keyLog = Log()
    if not keyLog then
        return nil
    end

    if not aura and not rawAura then
        return nil
    end

    local merged = self:MergeAuraSources(aura, rawAura)

    for _, source in ipairs({ merged, rawAura, aura }) do
        if source and source.name then
            local name = keyLog:TryDisplayValue(source.name)
            if name and name ~= "[secret]" then
                return name
            end
        end
    end

    if merged and merged.spellId and keyLog.ResolveSpellName then
        return keyLog:ResolveSpellName(merged.spellId, nil)
    end

    return nil
end

function AurasLog:FormatAuraRemaining(merged)
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

function AurasLog:GetAuraStacks(aura, rawAura)
    local keyLog = Log()
    if not keyLog then
        return nil
    end

    for _, source in ipairs({ aura, rawAura }) do
        if source then
            local stacks = source.applications or source.count or source.charges
            if stacks and stacks > 1 then
                return keyLog:TryDisplayValue(stacks)
            end
        end
    end

    return nil
end

function AurasLog:GetAuraSpellId(aura, rawAura)
    local keyLog = Log()
    if not keyLog then
        return nil
    end

    local merged = self:MergeAuraSources(aura, rawAura)
    if not merged or not merged.spellId then
        return nil
    end
    return keyLog:TryDisplayValue(merged.spellId)
end

function AurasLog:GetAuraMatchHint(aura, rawAura)
    local auras = Auras()
    if not auras then
        return nil
    end

    local merged = self:MergeAuraSources(aura, rawAura)
    if not merged or not merged.spellId then
        return nil
    end
    if issecretvalue and issecretvalue(merged.spellId) then
        return nil
    end

    local hints = {}
    local spellId = merged.spellId

    if auras.GetKnownFlaskEntry and auras:GetKnownFlaskEntry(spellId) then
        hints[#hints + 1] = "flask"
    end
    if auras.GetKnownOilEntry and auras:GetKnownOilEntry(spellId) then
        hints[#hints + 1] = "oil"
    end
    if auras.IsEatingAura and auras:IsEatingAura(merged) then
        hints[#hints + 1] = "eating"
    end
    if auras.GetKnownPhialEntry and auras:GetKnownPhialEntry(spellId) then
        hints[#hints + 1] = "phial"
    end

    if auras.ClassifyAura then
        local kind, classifyLabel = auras:ClassifyAura(merged)
        if kind then
            hints[#hints + 1] = "classify:" .. kind
            if classifyLabel and classifyLabel ~= "" then
                hints[#hints + 1] = classifyLabel
            end
        end
    end

    if #hints == 0 then
        return nil
    end

    return table.concat(hints, ", ")
end

function AurasLog:GetAuraLabel(aura, rawAura)
    local label = self:GetAuraName(aura, rawAura) or "?"
    local merged = self:MergeAuraSources(aura, rawAura)
    local details = {}
    local remaining = self:FormatAuraRemaining(merged)
    local stacks = self:GetAuraStacks(aura, rawAura)
    local spellId = self:GetAuraSpellId(aura, rawAura)
    local matchHint = self:GetAuraMatchHint(aura, rawAura)
    local auras = Auras()

    if spellId then
        details[#details + 1] = "#" .. spellId
    end

    if matchHint then
        details[#details + 1] = matchHint
    end

    if remaining then
        details[#details + 1] = remaining
    end

    if stacks then
        details[#details + 1] = "x" .. stacks
    end

    if auras and auras.GetAuraMaxPoint then
        local maxPoint = auras:GetAuraMaxPoint(aura, rawAura)
        if maxPoint then
            details[#details + 1] = "pts:" .. tostring(maxPoint)
        end
    end

    if #details == 0 then
        return label
    end

    return label .. " (" .. table.concat(details, ", ") .. ")"
end

function AurasLog:CollectAuras(unit, filter)
    local auras = Auras()
    if not auras then
        return {}
    end
    return auras:CollectAuras(unit, filter)
end

function AurasLog:ShouldLogAuras(unit)
    local now = GetTime()
    local nextAt = self.auraLogThrottle[unit] or 0
    if now < nextAt then
        return false
    end
    self.auraLogThrottle[unit] = now + 0.5
    return true
end

function AurasLog:ShouldLogUpdates()
    return Key.Debug.UI and Key.Debug.UI.IsShown and Key.Debug.UI:IsShown()
end

function AurasLog:LogUpdate(message, dedupeKey, dedupeWindow, source)
    if not self:ShouldLogUpdates() then
        return
    end

    Write(Key.Log.STATUS.DEBUG, message, dedupeKey, dedupeWindow, source or "LogUpdate")
end

function AurasLog:FormatUnitList(units)
    if not units or #units == 0 then
        return "(none)"
    end

    return table.concat(units, ", ")
end

function AurasLog:LogUpdateConsumableState(unit, reason)
    local keyLog = Log()
    local auras = Auras()
    if not keyLog or not self:ShouldLogUpdates() then
        return
    end
    if not auras or not auras.GetConsumableStatus then
        self:LogUpdate(string.format("%s: consumables unavailable", reason or "state"))
        return
    end

    local food, _, flaskReady, flaskLabel, oil, _, _, _, _, flaskIcon, flaskQualityTier, _, _, foodEating = auras:GetConsumableStatus(unit)
    local unitLabel = keyLog:SafeValue(UnitName(unit)) or unit

    self:LogUpdate(string.format(
        "%s %s — food=%s eating=%s flask=%s (%s, icon=%s, tier=%s) oil=%s",
        reason or "state",
        unitLabel,
        food and "yes" or "no",
        foodEating and "yes" or "no",
        flaskIcon and "detected" or "no",
        flaskReady and "ready" or "not-ready",
        flaskLabel or "nil",
        self:FormatOptionalIcon(flaskIcon),
        tostring(flaskQualityTier or "nil"),
        oil and "yes" or "no"
    ))
end

function AurasLog:FormatOptionalIcon(icon)
    if icon == nil then
        return "nil"
    end
    return tostring(icon)
end

function AurasLog:LogConsumableSummary(unit)
    local keyLog = Log()
    local auras = Auras()
    if not keyLog then
        return
    end
    if not auras or not auras.GetConsumableStatus then
        Write(Key.Log.STATUS.DEBUG, "  consumables: unavailable (Key.Auras missing)")
        return
    end

    local food, foodLabel, flaskReady, flaskLabel, oil, oilLabel,
        foodIcon, foodHearty, oilIcon, flaskIcon, flaskQualityTier, _, oilQualityTier,
        foodEating, foodEatingLabel, foodEatingIcon = auras:GetConsumableStatus(unit)

    Write(Key.Log.STATUS.DEBUG, string.format(
        "  food: ready=%s%s icon=%s hearty=%s eating=%s%s",
        food and "yes" or "no",
        foodLabel and (" (" .. foodLabel .. ")") or "",
        self:FormatOptionalIcon(foodIcon),
        tostring(foodHearty == true),
        foodEating and "yes" or "no",
        foodEatingLabel and (" (" .. foodEatingLabel .. ")") or ""
    ))
    if foodEating then
        Write(Key.Log.STATUS.DEBUG, string.format(
            "  food eating icon=%s",
            self:FormatOptionalIcon(foodEatingIcon)
        ))
    end
    Write(Key.Log.STATUS.DEBUG, string.format(
        "  flask: ready=%s detected=%s%s icon=%s quality=%s",
        flaskReady and "yes" or "no",
        flaskIcon and "yes" or "no",
        flaskLabel and (" (" .. flaskLabel .. ")") or "",
        self:FormatOptionalIcon(flaskIcon),
        tostring(flaskQualityTier or "nil")
    ))
    Write(Key.Log.STATUS.DEBUG, string.format(
        "  oil: %s%s icon=%s quality=%s",
        oil and "yes" or "no",
        oilLabel and (" (" .. oilLabel .. ")") or "",
        self:FormatOptionalIcon(oilIcon),
        tostring(oilQualityTier or "nil")
    ))
end

function AurasLog:LogSpellIndex(title, index)
    local keyLog = Log()
    if not keyLog then
        return
    end

    Write(Key.Log.STATUS.DEBUG, title)
    if not index or #index == 0 then
        Write(Key.Log.STATUS.DEBUG, "  (empty)")
        return
    end

    for _, item in ipairs(index) do
        Write(Key.Log.STATUS.DEBUG, string.format("  #%s = %s", tostring(item.spellId), item.label or "?"))
    end
end

function AurasLog:LogConsumableDiagnostics(unit)
    local keyLog = Log()
    local auras = Auras()
    if not keyLog then
        return
    end
    if not auras or not auras.GetConsumableDiagnostics then
        Write(Key.Log.STATUS.DEBUG, "Consumable diagnostics: unavailable (Key.Auras missing)")
        return
    end

    unit = unit or "player"
    local unitLabel = keyLog:SafeValue(UnitName(unit)) or unit
    local diagnostics = auras:GetConsumableDiagnostics(unit)

    Write(Key.Log.STATUS.DEBUG, string.format("--- Consumable diagnostics (%s) ---", unitLabel))

    Write(Key.Log.STATUS.DEBUG, "Known flasks (data):")
    for _, flask in ipairs(diagnostics.catalog.flasks or {}) do
        local ready = flask.countsForReady == false and "ready=no" or "ready=yes"
        Write(Key.Log.STATUS.DEBUG, string.format(
            "  %s spellId=%s icon=%s %s",
            flask.label or "?",
            tostring(flask.spellId or "nil"),
            self:FormatOptionalIcon(flask.icon),
            ready
        ))
    end

    Write(Key.Log.STATUS.DEBUG, "Known phials (data):")
    for _, phial in ipairs(diagnostics.catalog.phials or {}) do
        Write(Key.Log.STATUS.DEBUG, string.format(
            "  %s spellId=%s icon=%s",
            phial.label or "?",
            tostring(phial.spellId or "nil"),
            self:FormatOptionalIcon(phial.icon)
        ))
    end

    Write(Key.Log.STATUS.DEBUG, "Known oils/stones (data):")
    for _, oil in ipairs(diagnostics.catalog.oils or {}) do
        local spellIds = oil.spellIds and table.concat(oil.spellIds, ",") or tostring(oil.spellId or "nil")
        local enchantIds = oil.enchantIds and table.concat(oil.enchantIds, ",") or "nil"
        Write(Key.Log.STATUS.DEBUG, string.format(
            "  %s spellIds=%s enchantIds=%s icon=%s",
            oil.label or "?",
            spellIds,
            enchantIds,
            self:FormatOptionalIcon(oil.icon)
        ))
    end

    self:LogSpellIndex("Flask match index:", diagnostics.flaskIndex)
    self:LogSpellIndex("Phial match index:", diagnostics.phialIndex)
    self:LogSpellIndex("Oil match index:", diagnostics.oilIndex)

    if diagnostics.catalog.qualityTiers then
        local tierParts = {}
        for _, tier in ipairs(diagnostics.catalog.qualityTiers) do
            tierParts[#tierParts + 1] = string.format("%s>=%s", tier.id, tier.minPoint)
        end
        Write(Key.Log.STATUS.DEBUG, "Flask quality tiers: " .. table.concat(tierParts, ", "))
    end

    if not UnitExists(unit) then
        Write(Key.Log.STATUS.DEBUG, "Runtime: unit does not exist")
        Write(Key.Log.STATUS.DEBUG, "--- end consumable diagnostics ---")
        return
    end

    Write(Key.Log.STATUS.DEBUG, "Detected status (GetConsumableStatus):")
    self:LogConsumableSummary(unit)

    if Key.ReadyCheck and Key.ReadyCheck.GetMemberStatus then
        local uiStatus = Key.ReadyCheck:GetMemberStatus(unit)
        Write(Key.Log.STATUS.DEBUG, "Ready UI fields:")
        Write(Key.Log.STATUS.DEBUG, string.format(
            "  foodOk=%s foodEating=%s flaskOk=%s oilOk=%s",
            tostring(uiStatus.foodOk),
            tostring(uiStatus.foodEating == true),
            tostring(uiStatus.flaskOk),
            tostring(uiStatus.oilOk)
        ))
        Write(Key.Log.STATUS.DEBUG, string.format(
            "  foodIcon=%s flaskIcon=%s oilIcon=%s flaskQualityTier=%s oilQualityTier=%s foodHearty=%s",
            self:FormatOptionalIcon(uiStatus.foodIcon),
            self:FormatOptionalIcon(uiStatus.flaskIcon),
            self:FormatOptionalIcon(uiStatus.oilIcon),
            tostring(uiStatus.flaskQualityTier or "nil"),
            tostring(uiStatus.oilQualityTier or "nil"),
            tostring(uiStatus.foodHearty == true)
        ))
    end

    if diagnostics.weaponOil then
        local weaponOil = diagnostics.weaponOil
        Write(Key.Log.STATUS.DEBUG, string.format(
            "Weapon enchant: mh=%s oh=%s enchantId=%s known=%s quality=%s",
            tostring(weaponOil.hasMainHand),
            tostring(weaponOil.hasOffHand),
            tostring(weaponOil.enchantId or "nil"),
            tostring(weaponOil.knownLabel or "nil"),
            tostring(weaponOil.qualityTier or "nil")
        ))
    end

    Write(Key.Log.STATUS.DEBUG, string.format("Helpful aura scan (%d):", #(diagnostics.auraMatches or {})))
    for _, match in ipairs(diagnostics.auraMatches or {}) do
        local tags = {}
        if match.knownFlask then
            tags[#tags + 1] = "flask:" .. match.knownFlask
        end
        if match.knownOil then
            tags[#tags + 1] = "oil:" .. match.knownOil
        end
        if match.knownPhial then
            tags[#tags + 1] = "phial:" .. match.knownPhial
        end
        if match.classifyKind then
            tags[#tags + 1] = "classify:" .. match.classifyKind
        end

        Write(Key.Log.STATUS.DEBUG, string.format(
            "  [%s] %s #%s pts=%s %s",
            tostring(match.index or "?"),
            match.name or "?",
            tostring(match.spellId or "?"),
            tostring(match.maxPoint or "nil"),
            (#tags > 0 and table.concat(tags, ", ") or "(no consumable match)")
        ))
    end

    Write(Key.Log.STATUS.DEBUG, "--- end consumable diagnostics ---")
end

function AurasLog:LogUnitAuras(unit, reason)
    local keyLog = Log()
    if not keyLog or not unit or not UnitExists(unit) then
        return
    end

    local buffs = self:CollectAuras(unit, "HELPFUL")
    local debuffs = self:CollectAuras(unit, "HARMFUL")
    local unitLabel = keyLog:SafeValue(UnitName(unit)) or unit

    Write(Key.Log.STATUS.DEBUG, string.format(
        "%s %s — %d buff(s), %d debuff(s)",
        reason or "Auras",
        unitLabel,
        #buffs,
        #debuffs
    ))

    self:LogConsumableSummary(unit)

    for _, entry in ipairs(buffs) do
        Write(Key.Log.STATUS.DEBUG, "  + " .. self:GetAuraLabel(entry.aura, entry.rawAura))
    end
end

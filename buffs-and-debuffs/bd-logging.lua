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
            if name and (not issecretvalue or not issecretvalue(name)) and name ~= "[secret]" then
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
    if not merged or not merged.expirationTime then
        return nil
    end
    if issecretvalue and issecretvalue(merged.expirationTime) then
        return nil
    end
    if merged.expirationTime <= 0 then
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
            if stacks and (not issecretvalue or not issecretvalue(stacks)) and stacks > 1 then
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

local function AppendSpellIndex(index, spellId, label)
    if not spellId then
        return
    end
    index[#index + 1] = { spellId = spellId, label = label }
end

local function BuildSpellIndex(entries, includeBuffSpellIds)
    local index = {}
    for _, entry in ipairs(entries or {}) do
        if entry.spellIds then
            for _, spellId in ipairs(entry.spellIds) do
                AppendSpellIndex(index, spellId, entry.label)
            end
        end
        AppendSpellIndex(index, entry.spellId, entry.label)
        if entry.enchantIds then
            for _, enchantId in ipairs(entry.enchantIds) do
                AppendSpellIndex(index, enchantId, entry.label .. " (enchant)")
            end
        end
        if includeBuffSpellIds and entry.buffSpellIds then
            for _, spellId in ipairs(entry.buffSpellIds) do
                AppendSpellIndex(index, spellId, entry.label .. " (buff)")
            end
        end
    end
    table.sort(index, function(a, b)
        return a.spellId < b.spellId
    end)
    return index
end

function AurasLog:CollectAuras(unit, filter)
    local auras = Auras()
    if not auras or not Key.Api.UnitAuras or not Key.Api.UnitAuras.Collect then
        return {}
    end

    return Key.Api.UnitAuras:Collect(unit, filter, function(readableAura, rawAura)
        return auras:MergeAuraSources(readableAura, rawAura)
    end)
end

function AurasLog:GetConsumableDiagnostics(unit)
    local auras = Auras()
    local diagnostics = {
        catalog = {
            flasks = auras and auras.FLASKS or {},
            phials = auras and auras.PHIALS or {},
            oils = auras and auras.OILS or {},
            qualityTiers = auras and auras.QUALITY_TIERS,
        },
        flaskIndex = BuildSpellIndex(auras and auras.FLASKS),
        phialIndex = BuildSpellIndex(auras and auras.PHIALS),
        oilIndex = BuildSpellIndex(auras and auras.OILS, true),
        status = {},
        auraMatches = {},
        weaponOil = nil,
    }

    if not auras or not unit or not UnitExists(unit) then
        return diagnostics
    end

    local foodOk, foodLabel, flaskReady, flaskLabel, oilOk, oilLabel,
        foodIcon, foodHearty, oilIcon, flaskIcon, flaskQualityTier, _, oilQualityTier,
        foodEating, foodEatingLabel, foodEatingIcon = auras:GetConsumableStatus(unit)

    diagnostics.status = {
        food = {
            ok = foodOk,
            label = foodLabel,
            icon = foodIcon,
            hearty = foodHearty,
            eating = foodEating,
            eatingLabel = foodEatingLabel,
            eatingIcon = foodEatingIcon,
        },
        flask = {
            ready = flaskReady,
            detected = flaskIcon ~= nil,
            label = flaskLabel,
            icon = flaskIcon,
            qualityTier = flaskQualityTier,
        },
        oil = {
            ok = oilOk,
            label = oilLabel,
            icon = oilIcon,
            qualityTier = oilQualityTier,
        },
    }

    auras:ScanAuras(unit, "HELPFUL", function(aura, rawAura, index)
        local merged = auras:MergeAuraSources(aura, rawAura)
        local spellId = merged and merged.spellId
        local accessibleSpellId = spellId and (not issecretvalue or not issecretvalue(spellId)) and spellId or nil
        local knownFlask = accessibleSpellId and auras:GetKnownFlaskEntry(accessibleSpellId)
        local knownOil = accessibleSpellId and auras:GetKnownOilEntry(accessibleSpellId)
        local knownPhial = accessibleSpellId and auras:GetKnownPhialEntry(accessibleSpellId)
        local classifyKind, classifyLabel = auras:ClassifyAura(merged)

        diagnostics.auraMatches[#diagnostics.auraMatches + 1] = {
            index = index,
            name = auras:GetAuraDisplayName(merged),
            spellId = accessibleSpellId,
            maxPoint = auras:GetAuraMaxPoint(aura, rawAura),
            knownFlask = knownFlask and knownFlask.label,
            knownOil = knownOil and knownOil.label,
            knownPhial = knownPhial and knownPhial.label,
            classifyKind = classifyKind,
            classifyLabel = classifyLabel,
        }
    end)

    if UnitIsUnit(unit, "player") and Key.Api.WeaponEnchant and Key.Api.WeaponEnchant.GetInfo then
        local weaponEnchant = Key.Api.WeaponEnchant:GetInfo()
        local enchantId = weaponEnchant and weaponEnchant.enchantId
        local accessibleEnchantId = enchantId and (not issecretvalue or not issecretvalue(enchantId)) and enchantId or nil
        local knownOil = accessibleEnchantId and auras:GetKnownOilEntry(accessibleEnchantId)

        diagnostics.weaponOil = {
            hasMainHand = weaponEnchant and weaponEnchant.hasMainHand and true or false,
            hasOffHand = weaponEnchant and weaponEnchant.hasOffHand and true or false,
            enchantId = accessibleEnchantId,
            knownLabel = knownOil and knownOil.label,
            qualityTier = accessibleEnchantId and auras:GetOilQualityTierForId(accessibleEnchantId),
        }
    end

    return diagnostics
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

    local food, _, flaskReady, _, oil, _, _, _, _, flaskIcon = auras:GetConsumableStatus(unit)
    local unitLabel = keyLog:SafeValue(UnitName(unit)) or unit

    self:LogUpdate(string.format(
        "[%s] %s — food=%s flask=%s oil=%s",
        reason or "state",
        unitLabel,
        food and "yes" or "no",
        flaskIcon and (flaskReady and "ready" or "detected") or "no",
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
    if not auras then
        Write(Key.Log.STATUS.DEBUG, "Consumable diagnostics: unavailable (Key.Auras missing)")
        return
    end

    unit = unit or "player"
    local unitLabel = keyLog:SafeValue(UnitName(unit)) or unit
    local diagnostics = self:GetConsumableDiagnostics(unit)

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

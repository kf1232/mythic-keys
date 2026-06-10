local ADDON_NAME = ...

KeyAuras = KeyAuras or {}
local Auras = KeyAuras

Auras.KIND = {
    FOOD = "food",
    FLASK = "flask",
    OIL = "oil",
}

Auras.QUALITY_TIERS = {
    { id = "high", minPoint = 165, label = "High quality", premiumBorder = true },
    { id = "low", minPoint = 151, label = "Low quality", premiumBorder = false },
}

Auras.LOW_QUALITY_POINT = Auras.QUALITY_TIERS[#Auras.QUALITY_TIERS].minPoint
Auras.HIGH_QUALITY_POINT = Auras.QUALITY_TIERS[1].minPoint

Auras.CONSUMABLES = {
    flask = {
        kind = Auras.KIND.FLASK,
        classifyPriority = 1,
        defaultLabel = "Flask",
        namePatterns = { "flask" },
        defaultIconSpellIds = { 430604, 432073 },
        usesQualityTiers = true,
    },
    oil = {
        kind = Auras.KIND.OIL,
        classifyPriority = 2,
        defaultLabel = "Oil",
        namePatterns = { "oil", "whetstone", "weightstone", "sharpening", "coating", "rune of " },
        defaultIconSpellIds = { 451292, 384003, 383947 },
    },
    food = {
        kind = Auras.KIND.FOOD,
        classifyPriority = 3,
        defaultLabel = "Food",
        namePatterns = { "hearty well fed", "hearty well%-fed", "well fed", "well%-fed", "nourishment", "feast" },
        heartyPatterns = { "hearty well fed", "hearty well%-fed" },
        defaultIconSpellIds = { 457284, 462187 },
        heartyIconSpellIds = { 462187, 457284 },
        premiumTooltip = "Hearty — persists through death",
    },
}

Auras.WELL_FED_SPELL_ID = Auras.CONSUMABLES.food.defaultIconSpellIds[1]
Auras.HEARTY_WELL_FED_SPELL_ID = Auras.CONSUMABLES.food.heartyIconSpellIds[1]
Auras.DEFAULT_FLASK_SPELL_ID = Auras.CONSUMABLES.flask.defaultIconSpellIds[1]

do
    local ordered = {}
    for kindKey, config in pairs(Auras.CONSUMABLES) do
        ordered[#ordered + 1] = { kindKey = kindKey, priority = config.classifyPriority or 99 }
    end
    table.sort(ordered, function(a, b)
        return a.priority < b.priority
    end)

    Auras.CLASSIFY_ORDER = {}
    for _, item in ipairs(ordered) do
        Auras.CLASSIFY_ORDER[#Auras.CLASSIFY_ORDER + 1] = item.kindKey
    end
end

function Auras:IsAccessible(value)
    if KeyKeystones and KeyKeystones.IsAccessible then
        return KeyKeystones:IsAccessible(value)
    end
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

function Auras:MergeAuraSources(aura, rawAura)
    if not rawAura then
        return aura
    end
    if not aura or aura == rawAura then
        return rawAura
    end

    local merged = {}
    for key, value in pairs(aura) do
        merged[key] = value
    end
    for key, value in pairs(rawAura) do
        if merged[key] == nil then
            merged[key] = value
        end
    end

    if rawAura.points then
        merged.points = rawAura.points
    end

    return merged
end

function Auras:BuildReadableAuraLookup(unit, filter)
    local lookup = {}

    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then
        return lookup
    end

    local list = C_UnitAuras.GetUnitAuras(unit, filter)
    if not list then
        return lookup
    end

    for _, aura in ipairs(list) do
        if aura.auraInstanceID then
            lookup[aura.auraInstanceID] = aura
        end
    end

    return lookup
end

function Auras:ScanAuras(unit, filter, callback)
    if not unit or not UnitExists(unit) or type(callback) ~= "function" then
        return
    end

    filter = filter or "HELPFUL"
    local readable = self:BuildReadableAuraLookup(unit, filter)

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local index = 1
        while true do
            local rawAura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if not rawAura then
                break
            end

            local aura = rawAura
            if rawAura.auraInstanceID and readable[rawAura.auraInstanceID] then
                aura = self:MergeAuraSources(readable[rawAura.auraInstanceID], rawAura)
            end

            callback(aura, rawAura, index)
            index = index + 1
        end
        return
    end

    if C_UnitAuras and C_UnitAuras.GetUnitAuras then
        for index, aura in ipairs(C_UnitAuras.GetUnitAuras(unit, filter) or {}) do
            callback(aura, aura, index)
        end
        return
    end

    if AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura(unit, filter, nil, function(aura)
            callback(aura, aura, nil)
        end, nil)
    end
end

function Auras:CollectAuras(unit, filter)
    local auras = {}

    self:ScanAuras(unit, filter, function(aura, rawAura, index)
        auras[#auras + 1] = { aura = aura, rawAura = rawAura or aura, index = index or #auras + 1 }
    end)

    if #auras == 0 and C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local list = C_UnitAuras.GetUnitAuras(unit, filter)
        if list then
            for index, aura in ipairs(list) do
                auras[#auras + 1] = { aura = aura, rawAura = aura, index = index }
            end
        end
    end

    return auras
end

function Auras:GetAuraPointValues(aura, rawAura)
    local values = {}

    for _, source in ipairs({ aura, rawAura }) do
        if source and source.points then
            for _, value in ipairs(source.points) do
                if value and self:IsAccessible(value) and type(value) == "number" then
                    values[#values + 1] = value
                end
            end
        end
    end

    return values
end

function Auras:GetAuraMaxPoint(aura, rawAura)
    local maxPoint = 0
    for _, value in ipairs(self:GetAuraPointValues(aura, rawAura)) do
        if value > maxPoint then
            maxPoint = value
        end
    end
    return maxPoint > 0 and maxPoint or nil
end

function Auras:InferQualityTier(maxPoint)
    if not maxPoint then
        return nil
    end

    for _, tier in ipairs(self.QUALITY_TIERS) do
        if maxPoint >= tier.minPoint then
            return tier.id
        end
    end

    return nil
end

function Auras:GetQualityTierMeta(tierId)
    if not tierId then
        return nil
    end

    for _, tier in ipairs(self.QUALITY_TIERS) do
        if tier.id == tierId then
            return tier
        end
    end

    return nil
end

function Auras:GetConsumableConfig(kindKey)
    return self.CONSUMABLES[kindKey]
end

function Auras:NameMatchesPatterns(name, patterns)
    if not name or not self:IsAccessible(name) or not patterns then
        return false
    end

    local lower = name:lower()
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern, 1, true) then
            return true
        end
    end

    return false
end

function Auras:NameMatchesKind(name, kindKey)
    local config = self:GetConsumableConfig(kindKey)
    if not config then
        return false
    end

    return self:NameMatchesPatterns(name, config.namePatterns)
end

function Auras:IsHeartyFoodName(name)
    local config = self:GetConsumableConfig("food")
    if not config then
        return false
    end

    return self:NameMatchesPatterns(name, config.heartyPatterns)
end

function Auras:GetAuraNameCandidates(aura, displayFn)
    local names = {}

    local function addName(name)
        if not name then
            return
        end
        if displayFn then
            name = displayFn(name)
        end
        if name and name ~= "" and name ~= "[secret]" and self:IsAccessible(name) then
            names[#names + 1] = name
        end
    end

    addName(aura and aura.name)

    if aura and aura.spellId and self:IsAccessible(aura.spellId) and C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(aura.spellId)
        if spellInfo and spellInfo.name then
            addName(spellInfo.name)
        end
    end

    return names
end

function Auras:GetAuraDisplayName(aura)
    for _, name in ipairs(self:GetAuraNameCandidates(aura)) do
        return name
    end
    return nil
end

function Auras:NameMatchesFood(name)
    return self:NameMatchesKind(name, "food")
end

function Auras:NameMatchesFlask(name)
    return self:NameMatchesKind(name, "flask")
end

function Auras:NameMatchesOil(name)
    return self:NameMatchesKind(name, "oil")
end

function Auras:AuraMatchesKind(aura, kindKey)
    local config = self:GetConsumableConfig(kindKey)
    if not config then
        return false
    end

    for _, name in ipairs(self:GetAuraNameCandidates(aura)) do
        if self:NameMatchesKind(name, kindKey) then
            return true
        end
    end

    return false
end

function Auras:IsHeartyFoodAura(aura)
    for _, name in ipairs(self:GetAuraNameCandidates(aura)) do
        if self:IsHeartyFoodName(name) then
            return true
        end
    end

    return false
end

function Auras:GetDefaultIconForKind(kindKey, hearty)
    local config = self:GetConsumableConfig(kindKey)
    if not config then
        return nil
    end

    local spellIds = hearty and config.heartyIconSpellIds or config.defaultIconSpellIds
    if not spellIds then
        return nil
    end

    for _, spellId in ipairs(spellIds) do
        local icon = self:GetSpellIcon(spellId)
        if icon then
            return icon
        end
    end

    return nil
end

function Auras:GetSpellIcon(spellId)
    if not spellId or not self:IsAccessible(spellId) or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end

    local spellInfo = C_Spell.GetSpellInfo(spellId)
    if spellInfo and spellInfo.iconID and self:IsAccessible(spellInfo.iconID) then
        return spellInfo.iconID
    end

    return nil
end

function Auras:GetAuraIcon(aura)
    if not aura then
        return nil
    end

    if aura.icon and self:IsAccessible(aura.icon) then
        return aura.icon
    end

    return self:GetSpellIcon(aura.spellId)
end

function Auras:GetDefaultFoodIcon(hearty)
    return self:GetDefaultIconForKind("food", hearty)
end

function Auras:GetDefaultOilIcon()
    return self:GetDefaultIconForKind("oil")
end

function Auras:GetDefaultFlaskIcon()
    return self:GetDefaultIconForKind("flask")
end

function Auras:GetFlaskQualityTier(aura)
    return self:InferQualityTier(self:GetAuraMaxPoint(aura))
end

function Auras:ClassifyAura(aura)
    if not aura then
        return nil
    end

    local label = self:GetAuraDisplayName(aura)

    for _, kindKey in ipairs(self.CLASSIFY_ORDER) do
        if self:AuraMatchesKind(aura, kindKey) then
            local config = self:GetConsumableConfig(kindKey)
            return config.kind, label or config.defaultLabel
        end
    end

    return nil
end

function Auras:GetAuraKindHint(aura, rawAura, displayFn)
    local merged = self:MergeAuraSources(aura, rawAura)
    local names = {}

    for _, source in ipairs({ merged, rawAura, aura }) do
        if not source then
            break
        end
        for _, name in ipairs(self:GetAuraNameCandidates(source, displayFn)) do
            names[#names + 1] = name
        end
    end

    for _, kindKey in ipairs(self.CLASSIFY_ORDER) do
        for _, name in ipairs(names) do
            if self:NameMatchesKind(name, kindKey) then
                local config = self:GetConsumableConfig(kindKey)
                return config.kind
            end
        end
    end

    return nil
end

function Auras:GetPlayerWeaponOilHit()
    if not GetWeaponEnchantInfo then
        return nil
    end

    local hasMainHand, _, _, mainEnchantId, hasOffHand, _, _, offEnchantId = GetWeaponEnchantInfo()
    if not hasMainHand and not hasOffHand then
        return nil
    end

    local enchantId = (hasMainHand and mainEnchantId) or offEnchantId
    return {
        label = "Active",
        icon = self:GetSpellIcon(enchantId),
    }
end

function Auras:GetConsumableStatus(unit)
    local hits = {}

    self:ScanAuras(unit, "HELPFUL", function(aura)
        local kind, auraName = self:ClassifyAura(aura)
        if not kind or hits[kind] then
            return
        end

        hits[kind] = {
            label = auraName,
            icon = self:GetAuraIcon(aura),
            aura = aura,
        }
    end)

    if UnitIsUnit(unit, "player") and not hits[self.KIND.OIL] then
        hits[self.KIND.OIL] = self:GetPlayerWeaponOilHit()
    end

    local food = hits[self.KIND.FOOD]
    local flask = hits[self.KIND.FLASK]
    local oil = hits[self.KIND.OIL]

    return
        food ~= nil,
        food and food.label,
        flask ~= nil,
        flask and flask.label,
        oil ~= nil,
        oil and oil.label,
        food and food.icon,
        food and food.aura and self:IsHeartyFoodAura(food.aura),
        oil and oil.icon,
        flask and flask.icon,
        flask and flask.aura and self:GetFlaskQualityTier(flask.aura)
end

function Auras:FindAuraEntryBySpellId(unit, spellId)
    if not spellId or not self:IsAccessible(spellId) then
        return nil
    end

    for _, entry in ipairs(self:CollectAuras(unit, "HELPFUL")) do
        for _, source in ipairs({ entry.aura, entry.rawAura }) do
            if source and source.spellId and self:IsAccessible(source.spellId) and source.spellId == spellId then
                return entry
            end
        end
    end

    return nil
end

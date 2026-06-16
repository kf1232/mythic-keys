local ADDON_NAME = ...

Key.Auras = Key.Auras or {}
local Auras = Key.Auras

local function GetMidnightData()
    local data = Key.AurasData and Key.AurasData.midnight
    if not data then
        error("Key.AurasData.midnight is missing. Load bd-midnight-data.lua before bd.lua.")
    end
    return data
end

local function ResolveSpellIcon(spellId)
    if Key.Api.Spell and Key.Api.Spell.ResolveIcon then
        return Key.Api.Spell:ResolveIcon(spellId)
    end
    return nil
end

local function IndexSpellIds(lookup, entry, spellIds)
    if not lookup or not entry or not spellIds then
        return
    end

    for _, spellId in ipairs(spellIds) do
        lookup[spellId] = entry
    end
end

local function ApplyMidnightData(data)
    Auras.KIND = data.KIND
    Auras.QUALITY_TIERS = data.QUALITY_TIERS
    Auras.CONSUMABLES = data.CONSUMABLES
    Auras.FLASKS = data.FLASKS or {}
    Auras.PHIALS = data.PHIALS or {}
    Auras.OILS = data.OILS or {}

    Auras.LOW_QUALITY_POINT = Auras.QUALITY_TIERS[#Auras.QUALITY_TIERS].minPoint
    Auras.HIGH_QUALITY_POINT = Auras.QUALITY_TIERS[1].minPoint

    Auras.WELL_FED_SPELL_ID = Auras.CONSUMABLES.food.defaultIconSpellIds[1]
    Auras.HEARTY_WELL_FED_SPELL_ID = Auras.CONSUMABLES.food.heartyIconSpellIds[1]
    Auras.DEFAULT_FLASK_SPELL_ID = Auras.FLASKS[1] and Auras.FLASKS[1].spellId

    Auras.FLASK_BY_SPELL_ID = {}
    for _, flask in ipairs(Auras.FLASKS) do
        flask.icon = ResolveSpellIcon(flask.iconSpellId or flask.spellId)
        IndexSpellIds(Auras.FLASK_BY_SPELL_ID, flask, flask.spellIds)
        if flask.spellId then
            Auras.FLASK_BY_SPELL_ID[flask.spellId] = flask
        end
    end

    Auras.PHIAL_BY_SPELL_ID = {}
    for _, phial in ipairs(Auras.PHIALS) do
        phial.icon = ResolveSpellIcon(phial.iconSpellId or phial.spellId)
        IndexSpellIds(Auras.PHIAL_BY_SPELL_ID, phial, phial.spellIds)
        if phial.spellId then
            Auras.PHIAL_BY_SPELL_ID[phial.spellId] = phial
        end
    end

    Auras.OIL_BY_SPELL_ID = {}
    for _, oil in ipairs(Auras.OILS) do
        oil.icon = ResolveSpellIcon(oil.iconSpellId or (oil.spellIds and oil.spellIds[1]))
        IndexSpellIds(Auras.OIL_BY_SPELL_ID, oil, oil.spellIds)
        IndexSpellIds(Auras.OIL_BY_SPELL_ID, oil, oil.enchantIds)
        IndexSpellIds(Auras.OIL_BY_SPELL_ID, oil, oil.buffSpellIds)
    end

    Auras.EATING_BY_SPELL_ID = {}
    local eatingSpellIds = Auras.CONSUMABLES.food and Auras.CONSUMABLES.food.eatingSpellIds
    if eatingSpellIds then
        for _, spellId in ipairs(eatingSpellIds) do
            Auras.EATING_BY_SPELL_ID[spellId] = true
        end
    end

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

ApplyMidnightData(GetMidnightData())

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

local function IsUsableValue(value)
    if value == nil then
        return false
    end
    if IsSecretValue(value) then
        return false
    end
    return true
end

local function IsUsableSpellId(spellId)
    return IsUsableValue(spellId) and spellId ~= 0
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

function Auras:ScanAuras(unit, filter, callback)
    if not Key.Api.UnitAuras or not Key.Api.UnitAuras.Scan then
        return
    end

    Key.Api.UnitAuras:Scan(unit, filter, callback, function(readableAura, rawAura)
        return self:MergeAuraSources(readableAura, rawAura)
    end)
end

function Auras:GetAuraPointValues(aura, rawAura)
    local values = {}

    for _, source in ipairs({ aura, rawAura }) do
        local points = source and source.points
        if points and not IsSecretValue(points) and type(points) == "table" then
            for _, value in ipairs(points) do
                if IsUsableValue(value) and type(value) == "number" then
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

function Auras:GetKnownFlaskEntry(spellId)
    if not IsUsableSpellId(spellId) then
        return nil
    end
    return self.FLASK_BY_SPELL_ID and self.FLASK_BY_SPELL_ID[spellId]
end

function Auras:GetKnownOilEntry(spellId)
    if not IsUsableSpellId(spellId) then
        return nil
    end
    return self.OIL_BY_SPELL_ID and self.OIL_BY_SPELL_ID[spellId]
end

function Auras:GetKnownPhialEntry(spellId)
    if not IsUsableSpellId(spellId) then
        return nil
    end
    return self.PHIAL_BY_SPELL_ID and self.PHIAL_BY_SPELL_ID[spellId]
end

function Auras:IsKnownConsumableSpell(spellId)
    if not IsUsableSpellId(spellId) then
        return false
    end

    if self.EATING_BY_SPELL_ID and self.EATING_BY_SPELL_ID[spellId] then
        return true
    end

    return self:GetKnownFlaskEntry(spellId) ~= nil
        or self:GetKnownOilEntry(spellId) ~= nil
end

function Auras:GetKnownEntryForAura(aura, kindKey)
    if not aura or not IsUsableSpellId(aura.spellId) then
        return nil
    end

    if kindKey == "flask" then
        return self:GetKnownFlaskEntry(aura.spellId)
    end

    if kindKey == "oil" then
        return self:GetKnownOilEntry(aura.spellId)
    end

    return nil
end

function Auras:NameMatchesPatterns(name, patterns)
    if not IsUsableValue(name) or not patterns then
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
    if kindKey == "flask" or kindKey == "oil" then
        return false
    end

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

function Auras:GetAuraNameCandidates(aura)
    local names = {}

    local function addName(name)
        if not IsUsableValue(name) then
            return
        end
        if name == "" or name == "[secret]" then
            return
        end
        names[#names + 1] = name
    end

    addName(aura and aura.name)

    if aura and aura.spellId and Key.Api.Spell and Key.Api.Spell.GetSpellInfo then
        local spellInfo = Key.Api.Spell:GetSpellInfo(aura.spellId)
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

function Auras:AuraMatchesKind(aura, kindKey)
    if kindKey == "flask" or kindKey == "oil" then
        return self:GetKnownEntryForAura(aura, kindKey) ~= nil
    end

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

function Auras:IsEatingAura(aura)
    if not aura or not IsUsableSpellId(aura.spellId) then
        return false
    end

    return self.EATING_BY_SPELL_ID and self.EATING_BY_SPELL_ID[aura.spellId] == true
end

function Auras:GetEatingHit(aura)
    local config = self:GetConsumableConfig("food")
    if not config then
        return nil
    end

    return {
        label = config.eatingLabel or "Eating",
        icon = self:GetAuraIcon(aura) or ResolveSpellIcon(config.eatingIconSpellId),
        aura = aura,
    }
end

function Auras:GetDefaultIconForKind(kindKey, hearty)
    if kindKey == "flask" then
        local flask = self.FLASKS and self.FLASKS[1]
        return flask and flask.icon
    end

    if kindKey == "oil" then
        local oil = self.OILS and self.OILS[1]
        return oil and oil.icon
    end

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
    if Key.Api.Spell and Key.Api.Spell.GetIcon then
        return Key.Api.Spell:GetIcon(spellId)
    end
    return nil
end

function Auras:GetAuraIcon(aura)
    if not aura then
        return nil
    end

    if aura.icon and (not issecretvalue or not issecretvalue(aura.icon)) then
        return aura.icon
    end

    return self:GetSpellIcon(aura.spellId)
end

function Auras:GetAuraRemainingSeconds(aura)
    if not aura or not aura.expirationTime then
        return nil
    end

    if issecretvalue and issecretvalue(aura.expirationTime) then
        return nil
    end

    if aura.expirationTime <= 0 then
        return nil
    end

    local remaining = aura.expirationTime - GetTime()
    if remaining <= 0 then
        return nil
    end

    return remaining
end

function Auras:GetFlaskQualityTier(aura)
    return self:InferQualityTier(self:GetAuraMaxPoint(aura))
end

function Auras:GetEntryQualityTierForId(entry, id)
    if not entry or not IsUsableValue(id) then
        return nil
    end

    for _, field in ipairs({ "enchantIds", "spellIds", "buffSpellIds" }) do
        local ids = entry[field]
        if ids and #ids >= 2 then
            for index, listedId in ipairs(ids) do
                if listedId == id then
                    return index >= 2 and "high" or "low"
                end
            end
        end
    end

    return nil
end

function Auras:GetOilQualityTierForId(id)
    if not IsUsableValue(id) then
        return nil
    end

    for _, oil in ipairs(self.OILS or {}) do
        local tier = self:GetEntryQualityTierForId(oil, id)
        if tier then
            return tier
        end
    end

    return nil
end

function Auras:ClassifyAura(aura)
    if not aura then
        return nil
    end

    local label = self:GetAuraDisplayName(aura)

    for _, kindKey in ipairs(self.CLASSIFY_ORDER) do
        local knownEntry = self:GetKnownEntryForAura(aura, kindKey)
        if knownEntry then
            local config = self:GetConsumableConfig(kindKey)
            return config.kind, label or knownEntry.label or config.defaultLabel
        end

        if self:AuraMatchesKind(aura, kindKey) then
            local config = self:GetConsumableConfig(kindKey)
            return config.kind, label or config.defaultLabel
        end
    end

    return nil
end

function Auras:GetPlayerWeaponOilHit()
    if not Key.Api.WeaponEnchant or not Key.Api.WeaponEnchant.GetInfo then
        return nil
    end

    local weaponEnchant = Key.Api.WeaponEnchant:GetInfo()
    if not weaponEnchant then
        return nil
    end

    local enchantId = weaponEnchant.enchantId
    local oil = self:GetKnownOilEntry(enchantId)
    if not oil then
        return nil
    end

    return {
        label = oil.label,
        icon = oil.icon or self:GetSpellIcon(enchantId),
        qualityTier = self:GetOilQualityTierForId(enchantId),
        enchantId = enchantId,
    }
end

function Auras:GetConsumableStatus(unit)
    local hits = {}
    local eatingHit = nil

    self:ScanAuras(unit, "HELPFUL", function(aura)
        if not eatingHit and self:IsEatingAura(aura) then
            eatingHit = self:GetEatingHit(aura)
        end

        local kind, auraName = self:ClassifyAura(aura)
        if not kind or hits[kind] then
            return
        end

        local knownEntry = self:GetKnownEntryForAura(aura, kind)
        local countsForReady = kind ~= self.KIND.FLASK
            or (knownEntry and knownEntry.countsForReady ~= false)
        hits[kind] = {
            label = (knownEntry and knownEntry.label) or auraName,
            icon = self:GetAuraIcon(aura) or (knownEntry and knownEntry.icon),
            aura = aura,
            countsForReady = countsForReady,
            remainingSeconds = self:GetAuraRemainingSeconds(aura),
            qualityTier = kind == self.KIND.OIL and self:GetOilQualityTierForId(aura.spellId) or nil,
        }
    end)

    if UnitIsUnit(unit, "player") then
        local weaponOil = self:GetPlayerWeaponOilHit()
        if weaponOil then
            local oilHit = hits[self.KIND.OIL]
            if oilHit then
                if weaponOil.qualityTier then
                    oilHit.qualityTier = weaponOil.qualityTier
                end
            else
                hits[self.KIND.OIL] = weaponOil
            end
        end
    end

    local food = hits[self.KIND.FOOD]
    local foodEating = not food and eatingHit
    local flask = hits[self.KIND.FLASK]
    local oil = hits[self.KIND.OIL]
    local flaskReady = flask and flask.countsForReady

    return
        food ~= nil,
        food and food.label,
        flaskReady,
        flask and flask.label,
        oil ~= nil,
        oil and oil.label,
        food and food.icon,
        food and food.aura and self:IsHeartyFoodAura(food.aura),
        oil and oil.icon,
        flask and flask.icon,
        flask and flask.aura and self:GetFlaskQualityTier(flask.aura),
        flask and flask.remainingSeconds,
        oil and oil.qualityTier,
        foodEating ~= nil,
        foodEating and foodEating.label,
        foodEating and foodEating.icon
end

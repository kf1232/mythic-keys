local ADDON_NAME = ...

KeyApiCUnitAuras = KeyApiCUnitAuras or {}
local API = KeyApiCUnitAuras

local function IsUsableValue(value)
    if value == nil then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return true
end

function API:GetUnitAuras(unit, filter)
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then
        return nil
    end
    return C_UnitAuras.GetUnitAuras(unit, filter)
end

function API:GetAuraDataByIndex(unit, index, filter)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return nil
    end
    return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
end

function API:BuildReadableLookup(unit, filter)
    local lookup = {}
    local list = self:GetUnitAuras(unit, filter)
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

function API:Scan(unit, filter, callback, mergeFn)
    if not unit or type(callback) ~= "function" then
        return
    end

    if not UnitExists(unit) then
        return
    end

    filter = filter or "HELPFUL"
    local readable = self:BuildReadableLookup(unit, filter)

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local index = 1
        while true do
            local rawAura = self:GetAuraDataByIndex(unit, index, filter)
            if not rawAura then
                break
            end

            local aura = rawAura
            if rawAura.auraInstanceID and readable[rawAura.auraInstanceID] then
                aura = mergeFn and mergeFn(readable[rawAura.auraInstanceID], rawAura) or rawAura
            end

            callback(aura, rawAura, index)
            index = index + 1
        end
        return
    end

    local list = self:GetUnitAuras(unit, filter)
    if list then
        for index, aura in ipairs(list) do
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

function API:Collect(unit, filter, mergeFn)
    local auras = {}

    self:Scan(unit, filter, function(aura, rawAura, index)
        auras[#auras + 1] = { aura = aura, rawAura = rawAura or aura, index = index or #auras + 1 }
    end, mergeFn)

    if #auras == 0 then
        local list = self:GetUnitAuras(unit, filter)
        if list then
            for index, aura in ipairs(list) do
                auras[#auras + 1] = { aura = aura, rawAura = aura, index = index }
            end
        end
    end

    return auras
end

function API:GetSelfSourcedBuffNames(unit, filter)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return nil
    end

    filter = filter or "HELPFUL|RAID"
    local buffs = {}
    local index = 1

    while true do
        local aura = self:GetAuraDataByIndex(unit, index, filter)
        if not aura then
            break
        end

        local sameUnit = aura.sourceUnit and UnitIsUnit(aura.sourceUnit, unit)
        if sameUnit and IsUsableValue(aura.name) then
            buffs[#buffs + 1] = aura.name
        end

        index = index + 1
    end

    return buffs
end

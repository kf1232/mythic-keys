local ADDON_NAME = ...

Key.Api.UnitAuras = Key.Api.UnitAuras or {}
local API = Key.Api.UnitAuras
local Middleware = Key.Api.Middleware
local UnitAPI = Key.Api.Unit

local function IsAuraSecret(aura)
    if not aura then
        return false
    end

    return Middleware:CheckSecret(
        aura.name,
        aura.spellId,
        aura.icon,
        aura.sourceUnit,
        aura.expirationTime,
        aura.auraInstanceID
    )
end

function API:GetUnitAuras(isSecret, unit, filter)
    if Middleware:Guard(isSecret, unit) then
        return nil
    end
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then
        return nil
    end

    local list, secret = Middleware:Call(false, C_UnitAuras.GetUnitAuras, unit, filter)
    if secret then
        return nil
    end

    return list
end

function API:GetAuraDataByIndex(isSecret, unit, index, filter)
    if Middleware:Guard(isSecret, unit, index) then
        return nil
    end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return nil
    end

    local aura, secret = Middleware:Call(false, C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    if secret or IsAuraSecret(aura) then
        return nil, true
    end

    return aura, false
end

function API:BuildReadableLookup(isSecret, unit, filter)
    local lookup = {}
    local list = self:GetUnitAuras(isSecret, unit, filter)
    if not list then
        return lookup
    end

    for _, aura in ipairs(list) do
        if IsAuraSecret(aura) then
            return lookup, true
        end
        if aura.auraInstanceID then
            lookup[aura.auraInstanceID] = aura
        end
    end

    return lookup, false
end

function API:Scan(isSecret, unit, filter, callback, mergeFn)
    if Middleware:Guard(isSecret, unit) or type(callback) ~= "function" then
        return
    end

    if not UnitAPI:Exists(false, unit) then
        return
    end

    filter = filter or "HELPFUL"
    local readable, readableSecret = self:BuildReadableLookup(false, unit, filter)
    if readableSecret then
        return
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local index = 1
        while true do
            local rawAura, auraSecret = self:GetAuraDataByIndex(false, unit, index, filter)
            if auraSecret then
                return
            end
            if not rawAura then
                break
            end

            local aura = rawAura
            if rawAura.auraInstanceID and readable[rawAura.auraInstanceID] then
                aura = mergeFn and mergeFn(readable[rawAura.auraInstanceID], rawAura) or rawAura
            end

            if IsAuraSecret(aura) or IsAuraSecret(rawAura) then
                return
            end

            callback(aura, rawAura, index)
            index = index + 1
        end
        return
    end

    local list = self:GetUnitAuras(false, unit, filter)
    if list then
        for index, aura in ipairs(list) do
            if IsAuraSecret(aura) then
                return
            end
            callback(aura, aura, index)
        end
        return
    end

    if AuraUtil and AuraUtil.ForEachAura then
        local abortScan = false
        AuraUtil.ForEachAura(unit, filter, nil, function(aura)
            if IsAuraSecret(aura) then
                abortScan = true
                return
            end
            callback(aura, aura, nil)
        end, nil)
        if abortScan then
            return
        end
    end
end

function API:Collect(isSecret, unit, filter, mergeFn)
    local auras = {}

    self:Scan(isSecret, unit, filter, function(aura, rawAura, index)
        auras[#auras + 1] = { aura = aura, rawAura = rawAura or aura, index = index or #auras + 1 }
    end, mergeFn)

    if #auras == 0 then
        local list = self:GetUnitAuras(isSecret, unit, filter)
        if list then
            for index, aura in ipairs(list) do
                if IsAuraSecret(aura) then
                    return auras
                end
                auras[#auras + 1] = { aura = aura, rawAura = aura, index = index }
            end
        end
    end

    return auras
end

function API:GetSelfSourcedBuffNames(isSecret, unit, filter)
    if Middleware:Guard(isSecret, unit) then
        return nil
    end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return nil
    end

    filter = filter or "HELPFUL|RAID"
    local buffs = {}
    local index = 1

    while true do
        local aura, auraSecret = self:GetAuraDataByIndex(false, unit, index, filter)
        if auraSecret then
            return nil
        end
        if not aura then
            break
        end

        local sameUnit = aura.sourceUnit and UnitAPI:IsUnit(false, aura.sourceUnit, unit)
        if sameUnit and Middleware:IsAccessible(aura.name) then
            buffs[#buffs + 1] = aura.name
        end

        index = index + 1
    end

    return buffs
end

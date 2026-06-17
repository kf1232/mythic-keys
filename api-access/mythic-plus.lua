local ADDON_NAME = ...

Key.Api.MythicPlus = Key.Api.MythicPlus or {}
local API = Key.Api.MythicPlus
local Middleware = Key.Api.Middleware

function API:RequestMapInfo(isSecret)
    if Middleware:Guard(isSecret) then
        return false
    end
    if not C_MythicPlus or not C_MythicPlus.RequestMapInfo then
        return false
    end

    C_MythicPlus.RequestMapInfo()
    return true
end

function API:GetOwnedKeystoneLevel(isSecret)
    if Middleware:Guard(isSecret) or not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneLevel then
        return nil
    end

    local values, secret = Middleware:PCall(false, C_MythicPlus.GetOwnedKeystoneLevel)
    if secret or not values then
        return nil
    end

    return Middleware:AsNumber(false, values[1])
end

function API:GetOwnedKeystoneChallengeMapID(isSecret)
    if Middleware:Guard(isSecret) or not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneChallengeMapID then
        return nil
    end

    local values, secret = Middleware:PCall(false, C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    if secret or not values then
        return nil
    end

    return Middleware:AsNumber(false, values[1])
end

function API:GetOwnedKeystoneMapID(isSecret)
    if Middleware:Guard(isSecret) or not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneMapID then
        return nil
    end

    local values, secret = Middleware:PCall(false, C_MythicPlus.GetOwnedKeystoneMapID)
    if secret or not values then
        return nil
    end

    return Middleware:AsNumber(false, values[1])
end

function API:GetSeasonBestForMap(isSecret, challengeModeID)
    if Middleware:Guard(isSecret, challengeModeID) then
        return nil
    end
    if not C_MythicPlus or not C_MythicPlus.GetSeasonBestForMap then
        return nil
    end

    local values, secret = Middleware:PCall(false, C_MythicPlus.GetSeasonBestForMap, challengeModeID)
    if secret or not values then
        return nil
    end

    return values[1]
end

local ADDON_NAME = ...

Key.Api.ChallengeMode = Key.Api.ChallengeMode or {}
local API = Key.Api.ChallengeMode
local Middleware = Key.Api.Middleware

function API:GetMapUIInfo(isSecret, mapID)
    if Middleware:Guard(isSecret, mapID) then
        return nil
    end
    if not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return nil
    end

    local values, secret = Middleware:PCall(false, C_ChallengeMode.GetMapUIInfo, mapID)
    if secret or not values then
        return nil
    end

    local name = values[1]
    local texture = values[4]

    if name and not Middleware:IsAccessible(name) then
        name = nil
    end
    if texture and not Middleware:IsAccessible(texture) then
        texture = nil
    end

    if not name and not texture then
        return nil
    end

    return {
        name = name,
        texture = texture,
    }
end

function API:GetMapName(isSecret, mapID)
    local info = self:GetMapUIInfo(isSecret, mapID)
    return info and info.name or nil
end

function API:GetMapTexture(isSecret, mapID)
    local info = self:GetMapUIInfo(isSecret, mapID)
    return info and info.texture or nil
end

function API:GetKeystoneLevelAndMapID(isSecret, link)
    if Middleware:Guard(isSecret, link) then
        return nil, nil
    end
    if not C_ChallengeMode or not C_ChallengeMode.GetKeystoneLevelAndMapID then
        return nil, nil
    end

    local values, secret = Middleware:PCall(false, C_ChallengeMode.GetKeystoneLevelAndMapID, link)
    if secret or not values then
        return nil, nil
    end

    local level = Middleware:AsNumber(false, values[1])
    local mapID = Middleware:AsNumber(false, values[2])
    return level, mapID
end

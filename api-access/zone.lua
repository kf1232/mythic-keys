local ADDON_NAME = ...

Key.Api.Zone = Key.Api.Zone or {}
local API = Key.Api.Zone
local Middleware = Key.Api.Middleware

function API:GetZoneText(isSecret)
    if Middleware:Guard(isSecret) then
        return nil
    end

    local zoneText, secret = Middleware:Call(false, GetZoneText)
    if secret or not Middleware:IsAccessible(zoneText) then
        return nil
    end

    return zoneText
end

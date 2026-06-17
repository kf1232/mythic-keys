local ADDON_NAME = ...

Key.Api.Strings = Key.Api.Strings or {}
local API = Key.Api.Strings
local Middleware = Key.Api.Middleware

function API:Ambiguate(isSecret, name, context)
    if Middleware:Guard(isSecret, name) then
        return nil
    end

    local result, secret = Middleware:Call(false, Ambiguate, name, context)
    if secret or not Middleware:IsAccessible(result) or result == "" then
        return nil
    end

    return result
end

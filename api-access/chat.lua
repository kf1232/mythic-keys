local ADDON_NAME = ...

Key.Api.Chat = Key.Api.Chat or {}
local API = Key.Api.Chat
local Middleware = Key.Api.Middleware

function API:RegisterAddonMessagePrefix(isSecret, prefix)
    if Middleware:Guard(isSecret, prefix) then
        return false
    end
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then
        return false
    end

    C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    return true
end

function API:SendAddonMessage(isSecret, prefix, message, channel)
    if Middleware:Guard(isSecret, prefix, message, channel) then
        return false
    end
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return false
    end

    local ok = pcall(C_ChatInfo.SendAddonMessage, prefix, message, channel)
    return ok and true or false
end

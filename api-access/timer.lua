local ADDON_NAME = ...

Key.Api.Timer = Key.Api.Timer or {}
local API = Key.Api.Timer
local Middleware = Key.Api.Middleware

function API:GetTime(isSecret)
    if Middleware:Guard(isSecret) then
        return 0
    end

    local now, secret = Middleware:Call(false, GetTime)
    if secret then
        return 0
    end

    return now or 0
end

function API:After(isSecret, delay, callback)
    if Middleware:Guard(isSecret, delay) or type(callback) ~= "function" then
        return nil
    end
    if not C_Timer or not C_Timer.After then
        return nil
    end

    return C_Timer.After(delay, callback)
end

function API:NewTicker(isSecret, interval, callback)
    if Middleware:Guard(isSecret, interval) or type(callback) ~= "function" then
        return nil
    end
    if not C_Timer or not C_Timer.NewTicker then
        return nil
    end

    return C_Timer.NewTicker(interval, callback)
end

function API:NewTimer(isSecret, delay, callback)
    if Middleware:Guard(isSecret, delay) or type(callback) ~= "function" then
        return nil
    end
    if not C_Timer or not C_Timer.NewTimer then
        return nil
    end

    return C_Timer.NewTimer(delay, callback)
end

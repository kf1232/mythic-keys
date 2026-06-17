local ADDON_NAME = ...

Key.Api = Key.Api or {}
Key.Api.Middleware = Key.Api.Middleware or {}
local Middleware = Key.Api.Middleware

function Middleware:IsSecret(value)
    return value ~= nil and issecretvalue and issecretvalue(value) or false
end

function Middleware:IsAccessible(value)
    return value ~= nil and not self:IsSecret(value)
end

function Middleware:CheckSecret(...)
    for index = 1, select("#", ...) do
        if self:IsSecret(select(index, ...)) then
            return true
        end
    end
    return false
end

function Middleware:Guard(isSecret, ...)
    if isSecret == true or self:CheckSecret(...) then
        return true
    end
    return false
end

function Middleware:Call(isSecret, fn, ...)
    if self:Guard(isSecret, ...) then
        return nil, true
    end

    return fn(...), false
end

function Middleware:PCall(isSecret, fn, ...)
    if self:Guard(isSecret, ...) then
        return nil, true
    end

    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil, false
    end

    table.remove(results, 1)
    for _, value in ipairs(results) do
        if self:IsSecret(value) then
            return nil, true
        end
    end

    return results, false
end

function Middleware:AsNumber(isSecret, value)
    if self:Guard(isSecret, value) then
        return nil
    end

    return tonumber(value)
end

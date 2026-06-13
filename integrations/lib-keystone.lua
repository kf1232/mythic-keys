local ADDON_NAME = ...

KeyIntegrationLibKeystone = KeyIntegrationLibKeystone or {}
local Provider = KeyIntegrationLibKeystone

Provider.id = "LibKeystone"

function Provider:OnUpdate(host, keyLevel, mapID, playerRating, sender, channel)
    if channel ~= "PARTY" then
        return
    end

    host:ApplyPartyKey(sender, keyLevel, mapID)
end

function Provider:TryInit(host)
    if host.libKeystone then
        return true
    end

    local libStub = LibStub
    if not libStub then
        return false
    end

    local ok, libKeystone = pcall(libStub, "LibKeystone", true)
    if not ok or not libKeystone or not libKeystone.Register then
        return false
    end

    local registered = pcall(libKeystone.Register, host, function(...)
        self:OnUpdate(host, ...)
    end)
    if not registered then
        return false
    end

    host.libKeystone = libKeystone
    return true
end

function Provider:Request(host)
    if host.libKeystone and host.libKeystone.Request then
        pcall(host.libKeystone.Request, "PARTY")
    end
end

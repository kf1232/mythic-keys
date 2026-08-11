Key.Integrations = Key.Integrations or {}

local Provider = {}
Key.Integrations.LibKeystone = Provider

Provider.id = "LibKeystone"

function Provider:OnUpdate(host, keyLevel, mapID, _playerRating, sender, channel)
    if channel ~= "PARTY" and channel ~= "INSTANCE_CHAT" and channel ~= "RAID" then
        return
    end

    host:ApplyPartyKey(sender, keyLevel, mapID)
end

function Provider:TryInit(host)
    if host.libKeystone then
        return true
    end

    if not LibStub then
        return false
    end

    local ok, libKeystone = pcall(LibStub, "LibKeystone", true)
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
    if not host.libKeystone or not host.libKeystone.Request then
        return
    end

    local KeySync = Key.Data and Key.Data.KeySync
    local channel = KeySync and KeySync.GetChannel and KeySync.GetChannel()
    if channel then
        pcall(host.libKeystone.Request, channel)
    end
end

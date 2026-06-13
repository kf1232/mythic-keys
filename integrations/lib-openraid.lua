local ADDON_NAME = ...

Key.Integrations.LibOpenRaid = Key.Integrations.LibOpenRaid or {}
local Provider = Key.Integrations.LibOpenRaid

Provider.id = "LibOpenRaid"

function Provider:ResolveChallengeMapID(keystoneInfo)
    if not keystoneInfo then
        return nil
    end

    local mapID = keystoneInfo.challengeMapID
    if Key.Keystones:IsAccessible(mapID) and mapID ~= 0 then
        return mapID
    end

    mapID = keystoneInfo.mapID
    if Key.Keystones:IsAccessible(mapID) and mapID ~= 0 then
        return mapID
    end

    mapID = keystoneInfo.mythicPlusMapID
    if Key.Keystones:IsAccessible(mapID) and mapID ~= 0 then
        return mapID
    end

    return nil
end

function Provider:OnKeystoneUpdate(host, unitName, keystoneInfo)
    if not unitName or not keystoneInfo then
        return
    end

    local mapID = self:ResolveChallengeMapID(keystoneInfo)
    host:ApplyPartyKey(unitName, keystoneInfo.level, mapID)
end

function Provider:TryInit(host)
    if host.openRaid then
        return true
    end

    local libStub = LibStub
    if not libStub then
        return false
    end

    local ok, openRaid = pcall(libStub, "LibOpenRaid-1.0", true)
    if not ok or not openRaid or not openRaid.RegisterCallback then
        return false
    end

    local registered, registerResult = pcall(openRaid.RegisterCallback, openRaid, host, "KeystoneUpdate", function(unitName, keystoneInfo)
        self:OnKeystoneUpdate(host, unitName, keystoneInfo)
    end)
    if not registered or registerResult ~= true then
        return false
    end

    host.openRaid = openRaid
    return true
end

function Provider:ImportPartyCache(host)
    if not host.openRaid or not Key.Keystones or not Key.Keystones.GetPartyUnits then
        return
    end

    if not host.openRaid.GetKeystoneInfo then
        return
    end

    for _, unit in ipairs(Key.Keystones:GetPartyUnits()) do
        if unit ~= "player" and UnitExists(unit) then
            local ok, keystoneInfo = pcall(host.openRaid.GetKeystoneInfo, unit)
            if ok and keystoneInfo then
                self:OnKeystoneUpdate(host, GetUnitName(unit, true) or UnitName(unit), keystoneInfo)
            end
        end
    end
end

function Provider:Request(host)
    if host.openRaid and host.openRaid.RequestKeystoneDataFromParty then
        pcall(host.openRaid.RequestKeystoneDataFromParty)
    end
end

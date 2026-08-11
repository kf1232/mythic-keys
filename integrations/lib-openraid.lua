Key.Integrations = Key.Integrations or {}

local Guard = Key.Guard
local PlayerData = Key.Data.PlayerData

local Provider = {}
Key.Integrations.LibOpenRaid = Provider

Provider.id = "LibOpenRaid"

local function UsableNumber(value)
    return Guard.usable(value) and tonumber(value) or nil
end

function Provider:ResolveChallengeMapID(keystoneInfo)
    if not keystoneInfo then
        return nil
    end

    local candidates = {
        keystoneInfo.challengeMapID,
        keystoneInfo.mapID,
        keystoneInfo.mythicPlusMapID,
    }

    for i = 1, #candidates do
        local mapID = UsableNumber(candidates[i])
        if mapID and mapID > 0 then
            return mapID
        end
    end

    return nil
end

function Provider:OnKeystoneUpdate(host, unitName, keystoneInfo)
    if not unitName or not keystoneInfo then
        return
    end

    local level = UsableNumber(keystoneInfo.level)
    local mapID = self:ResolveChallengeMapID(keystoneInfo)
    if not level or not mapID then
        return
    end

    host:ApplyPartyKey(unitName, level, mapID)
end

function Provider:TryInit(host)
    if host.openRaid then
        return true
    end

    if not LibStub then
        return false
    end

    local ok, openRaid = pcall(LibStub, "LibOpenRaid-1.0", true)
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

local function CollectPartyUnits()
    local units = {}
    if not IsInGroup or not IsInGroup() then
        return units
    end

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                units[#units + 1] = unit
            end
        end
        return units
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            units[#units + 1] = unit
        end
    end
    return units
end

function Provider:ImportPartyCache(host)
    if not host.openRaid or not host.openRaid.GetKeystoneInfo then
        return
    end

    for _, unit in ipairs(CollectPartyUnits()) do
        local ok, keystoneInfo = pcall(host.openRaid.GetKeystoneInfo, unit)
        if ok and keystoneInfo then
            local senderKey = PlayerData.GetCacheKey(unit)
            if senderKey then
                self:OnKeystoneUpdate(host, senderKey, keystoneInfo)
            end
        end
    end
end

function Provider:Request(host)
    if not host.openRaid then
        return
    end

    local KeySync = Key.Data and Key.Data.KeySync
    local channel = KeySync and KeySync.GetChannel and KeySync.GetChannel()
    if channel == "PARTY" and host.openRaid.RequestKeystoneDataFromParty then
        pcall(host.openRaid.RequestKeystoneDataFromParty)
    elseif channel == "RAID" and host.openRaid.RequestKeystoneDataFromRaid then
        pcall(host.openRaid.RequestKeystoneDataFromRaid)
    end
end

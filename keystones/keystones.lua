local ADDON_NAME = ...

Key.Keystones = Key.Keystones or {}
local Keystones = Key.Keystones
local Cache = Key.Cache
local Middleware = Key.Api.Middleware
local UnitAPI = Key.Api.Unit
local GroupAPI = Key.Api.Group
local ChallengeMode = Key.Api.ChallengeMode
local MythicPlus = Key.Api.MythicPlus
local Container = Key.Api.Container

function Keystones:GetKeystoneStore()
    return Cache:GetStore(Cache.STORE.KEYSTONE)
end

function Keystones:GetSeasonBestStore()
    return Cache:GetStore(Cache.STORE.SEASON_BEST)
end

function Keystones:IsAccessible(value)
    return Cache:IsAccessible(value)
end

function Keystones:AsAccessibleNumber(value)
    return Middleware:AsNumber(false, value)
end

local Party = Key.Party

function Keystones:RequestMapInfo()
    MythicPlus:RequestMapInfo(false)
end

function Keystones:GetDungeonName(mapID)
    if not mapID or mapID == 0 then
        return nil
    end

    local name = ChallengeMode:GetMapName(false, mapID)
    if name then
        return name
    end

    return "Unknown"
end

function Keystones:FindKeystoneInBags()
    local bagKey = Container:FindKeystoneInBags(false)
    if not bagKey then
        return nil
    end

    return {
        level = bagKey.level,
        mapID = bagKey.mapID,
        dungeonName = self:GetDungeonName(bagKey.mapID),
    }
end

function Keystones:GetOwnKeystone()
    self:RequestMapInfo()

    local level = MythicPlus:GetOwnedKeystoneLevel(false)
    local mapID = MythicPlus:GetOwnedKeystoneChallengeMapID(false)
    if (not mapID or mapID == 0) then
        mapID = MythicPlus:GetOwnedKeystoneMapID(false)
    end

    if not level or level == 0 or not mapID or mapID == 0 then
        local bagKey = self:FindKeystoneInBags()
        if bagKey then
            return bagKey
        end
        return nil
    end

    return {
        level = level,
        mapID = mapID,
        dungeonName = self:GetDungeonName(mapID),
    }
end

function Keystones:FormatKey(key)
    local level = key and self:AsAccessibleNumber(key.level)
    if not level or level == 0 then
        return "no key"
    end

    local name = key.dungeonName or self:GetDungeonName(key.mapID) or "Unknown"
    return string.format("%s +%d", name, level)
end

function Keystones:LookupCachedKeyBySender(sender)
    return Cache:ReadBySender(self:GetKeystoneStore(), sender, true)
end

function Keystones:RebindPartyCache()
    Cache:RebindByGUID(self:GetKeystoneStore())
    Cache:RebindByGUID(self:GetSeasonBestStore())
end

function Keystones:StorePartyKeyEntry(entry, sender)
    Cache:Write(self:GetKeystoneStore(), sender, entry)
end

function Keystones:SetPartyKey(sender, level, mapID)
    if not sender or sender == "" then
        return false
    end

    local existing = self:LookupCachedKeyBySender(sender)

    if not level or level == 0 or not mapID or mapID == 0 then
        if not existing then
            return false
        end

        Cache:Clear(self:GetKeystoneStore(), sender)
        return true
    end

    if existing and existing.level == level and existing.mapID == mapID then
        return false
    end

    self:StorePartyKeyEntry({
        level = level,
        mapID = mapID,
        dungeonName = self:GetDungeonName(mapID),
    }, sender)
    return true
end

function Keystones:LookupCachedKey(unit)
    return Cache:ReadByUnit(self:GetKeystoneStore(), unit, true)
end

function Keystones:GetMemberKey(unitOrSender)
    if type(unitOrSender) == "string" and not UnitAPI:Exists(false, unitOrSender) then
        return self:LookupCachedKeyBySender(unitOrSender)
    end

    if unitOrSender and UnitAPI:Exists(false, unitOrSender) and UnitAPI:IsPlayer(false, unitOrSender) then
        return self:GetOwnKeystone()
    end

    if unitOrSender and UnitAPI:Exists(false, unitOrSender) then
        local key = self:LookupCachedKey(unitOrSender)
        if key then
            return key
        end

        for sender, entry in pairs(Cache:GetPrimary(self:GetKeystoneStore())) do
            local matchedUnit = Party:FindPartyUnitForSender(sender)
            if matchedUnit and UnitAPI:IsUnit(false, matchedUnit, unitOrSender) then
                return entry
            end
        end

        local keystoneStore = self:GetKeystoneStore()
        for sender, entry in pairs(keystoneStore.sessionPrimary) do
            local matchedUnit = Party:FindPartyUnitForSender(sender)
            if matchedUnit and UnitAPI:IsUnit(false, matchedUnit, unitOrSender) then
                return entry
            end
        end
    end

    return nil
end

function Keystones:RestoreSessionCacheIfNeeded()
    Cache:RestoreSession(self:GetKeystoneStore())
    Cache:RestoreSession(self:GetSeasonBestStore())

    if Key.ReadyCheck and Key.ReadyCheck.RestoreSessionCacheIfNeeded then
        Key.ReadyCheck:RestoreSessionCacheIfNeeded()
    end

    self:RebindPartyCache()
end

function Keystones:ClearPartyCache()
    Cache:Wipe(self:GetKeystoneStore())
    Cache:Wipe(self:GetSeasonBestStore())
end

function Keystones:GetSeasonDungeons()
    if Key.PartyComplete and Key.PartyComplete.SEASON_DUNGEONS then
        return Key.PartyComplete.SEASON_DUNGEONS
    end
    return {}
end

function Keystones:PickBestRun(intimeInfo)
    if not intimeInfo then
        return 0, false
    end

    local intimeLevel = self:AsAccessibleNumber(intimeInfo.level)
    if intimeLevel and intimeLevel > 0 then
        return intimeLevel, false
    end

    return 0, false
end

function Keystones:GetOwnBestForMap(challengeModeID)
    if not challengeModeID or challengeModeID == 0 then
        return 0, false
    end

    self:RequestMapInfo()

    local intimeInfo = MythicPlus:GetSeasonBestForMap(false, challengeModeID)
    return self:PickBestRun(intimeInfo)
end

function Keystones:GetBestPayloadPrefix()
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.BEST then
        return Key.PartySync.PROTOCOL.BEST.prefix
    end
    return "M"
end

function Keystones:GetBestPayloadPattern()
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.BEST then
        return Key.PartySync.PROTOCOL.BEST.pattern
    end
    return "^M:(.+)$"
end

function Keystones:BuildEmptyBestPayload()
    local parts = {}

    for _ in ipairs(self:GetSeasonDungeons()) do
        parts[#parts + 1] = "0:0"
    end

    return self:GetBestPayloadPrefix() .. ":" .. table.concat(parts, ",")
end

function Keystones:BuildBestPayload()
    local parts = {}

    for _, dungeon in ipairs(self:GetSeasonDungeons()) do
        local level, overTime = self:GetOwnBestForMap(dungeon.challengeModeID)
        parts[#parts + 1] = string.format("%d:%d", level or 0, overTime and 1 or 0)
    end

    return self:GetBestPayloadPrefix() .. ":" .. table.concat(parts, ",")
end

function Keystones:ParseBestPayload(message)
    local data = message and message:match(self:GetBestPayloadPattern())
    if not data then
        return nil
    end

    local bests = {}
    local index = 0

    for pair in string.gmatch(data, "([^,]+)") do
        index = index + 1
        local level, overTime = pair:match("^(%d+):(%d+)$")
        local dungeon = self:GetSeasonDungeons()[index]
        if dungeon and level then
            level = tonumber(level)
            if level and level > 0 and tonumber(overTime) ~= 1 then
                bests[dungeon.challengeModeID] = {
                    level = level,
                    overTime = false,
                }
            end
        end
    end

    return bests
end

function Keystones:StorePartyBestEntry(entry, sender)
    Cache:Write(self:GetSeasonBestStore(), sender, entry)
end

function Keystones:SetPartyBest(sender, bests)
    if not sender or sender == "" then
        return
    end

    if not bests or not next(bests) then
        Cache:Clear(self:GetSeasonBestStore(), sender)
        return
    end

    self:StorePartyBestEntry(bests, sender)
end

function Keystones:LookupCachedBest(unit)
    return Cache:ReadByUnit(self:GetSeasonBestStore(), unit, true)
end

function Keystones:GetMemberBestForMap(unit, challengeModeID)
    if not unit or not challengeModeID then
        return 0, false
    end

    if UnitAPI:Exists(false, unit) and UnitAPI:IsPlayer(false, unit) then
        return self:GetOwnBestForMap(challengeModeID)
    end

    local cached = self:LookupCachedBest(unit)
    local entry = cached and cached[challengeModeID]
    if entry and entry.level and entry.level > 0 and not entry.overTime then
        return entry.level, false
    end

    return 0, false
end

function Keystones:GetClassColor(classFilename)
    if not self:IsAccessible(classFilename) then
        return 1, 1, 1
    end

    local color = RAID_CLASS_COLORS[classFilename]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function Keystones:GetUnitClassFilename(unit)
    return UnitAPI:GetClassFilename(false, unit)
end

function Keystones:IsUnitLeader(unit)
    return UnitAPI:IsGroupLeader(false, unit)
end

function Keystones:GetUnitRole(unit)
    return UnitAPI:GetGroupRole(false, unit)
end

function Keystones:GetPartyKeyTokensByMap()
    local byMap = {}

    for _, unit in ipairs(Party:GetPartyUnits()) do
        if UnitAPI:Exists(false, unit) then
            local key = self:GetMemberKey(unit)
            local level = key and self:AsAccessibleNumber(key.level)
            local mapID = key and self:AsAccessibleNumber(key.mapID)
            if level and level > 0 and mapID and mapID ~= 0 then
                byMap[mapID] = byMap[mapID] or {}
                byMap[mapID][#byMap[mapID] + 1] = {
                    level = level,
                    classFilename = self:GetUnitClassFilename(unit),
                    isLeader = self:IsUnitLeader(unit),
                    role = self:GetUnitRole(unit),
                }
            end
        end
    end

    return byMap
end

Key.RegisterTrigger("PLAYER_ENTERING_WORLD", function()
    if GroupAPI:IsInGroup(false) then
        Keystones:RestoreSessionCacheIfNeeded()
    end
end)

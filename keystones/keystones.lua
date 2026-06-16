local ADDON_NAME = ...

Key.Keystones = Key.Keystones or {}
local Keystones = Key.Keystones
local Cache = Key.Cache

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
    if not self:IsAccessible(value) then
        return nil
    end

    return tonumber(value)
end

local Party = Key.Party

function Keystones:RequestMapInfo()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end
end

function Keystones:GetDungeonName(mapID)
    if not mapID or mapID == 0 then
        return nil
    end
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name and self:IsAccessible(name) then
            return name
        end
    end
    return "Unknown"
end

function Keystones:FindKeystoneInBags()
    if not C_Container or not C_Item then
        return nil
    end

    local numBags = NUM_BAG_SLOTS or 4
    for bag = 0, numBags do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            local link = itemInfo and itemInfo.hyperlink
            if link and C_Item.IsItemKeystone and C_Item.IsItemKeystone(link) then
                if C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelAndMapID then
                    local level, mapID = C_ChallengeMode.GetKeystoneLevelAndMapID(link)
                    level = self:AsAccessibleNumber(level)
                    mapID = self:AsAccessibleNumber(mapID)
                    if level and level > 0 and mapID and mapID ~= 0 then
                        return {
                            level = level,
                            mapID = mapID,
                            dungeonName = self:GetDungeonName(mapID),
                        }
                    end
                end
            end
        end
    end

    return nil
end

local function ReadMythicPlusValue(api)
    if not api then
        return nil
    end

    local ok, value = pcall(api)
    if not ok then
        return nil
    end

    return value
end

function Keystones:GetOwnKeystone()
    self:RequestMapInfo()

    local level
    local mapID

    if C_MythicPlus then
        if C_MythicPlus.GetOwnedKeystoneLevel then
            level = ReadMythicPlusValue(C_MythicPlus.GetOwnedKeystoneLevel)
        end
        if C_MythicPlus.GetOwnedKeystoneChallengeMapID then
            mapID = ReadMythicPlusValue(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
        end
        if (not mapID or mapID == 0) and C_MythicPlus.GetOwnedKeystoneMapID then
            mapID = ReadMythicPlusValue(C_MythicPlus.GetOwnedKeystoneMapID)
        end
    end

    level = self:AsAccessibleNumber(level)
    mapID = self:AsAccessibleNumber(mapID)

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
    if type(unitOrSender) == "string" and not UnitExists(unitOrSender) then
        return self:LookupCachedKeyBySender(unitOrSender)
    end

    if unitOrSender and UnitExists(unitOrSender) and UnitIsUnit(unitOrSender, "player") then
        return self:GetOwnKeystone()
    end

    if unitOrSender and UnitExists(unitOrSender) then
        local key = self:LookupCachedKey(unitOrSender)
        if key then
            return key
        end

        for sender, entry in pairs(Cache:GetPrimary(self:GetKeystoneStore())) do
            local matchedUnit = Party:FindPartyUnitForSender(sender)
            if matchedUnit and UnitIsUnit(matchedUnit, unitOrSender) then
                return entry
            end
        end

        local keystoneStore = self:GetKeystoneStore()
        for sender, entry in pairs(keystoneStore.sessionPrimary) do
            local matchedUnit = Party:FindPartyUnitForSender(sender)
            if matchedUnit and UnitIsUnit(matchedUnit, unitOrSender) then
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

    local ok, intimeLevel = pcall(function()
        return intimeInfo.level
    end)
    if not ok then
        return 0, false
    end

    intimeLevel = self:AsAccessibleNumber(intimeLevel)
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

    if not C_MythicPlus or not C_MythicPlus.GetSeasonBestForMap then
        return 0, false
    end

    local ok, intimeInfo = pcall(C_MythicPlus.GetSeasonBestForMap, challengeModeID)
    if not ok then
        return 0, false
    end

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

    if UnitExists(unit) and UnitIsUnit(unit, "player") then
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
    if not unit or not UnitExists(unit) or not UnitClass then
        return nil
    end

    local _, classFilename = UnitClass(unit)
    if self:IsAccessible(classFilename) then
        return classFilename
    end

    return nil
end

function Keystones:IsUnitLeader(unit)
    if not unit or not UnitIsGroupLeader then
        return false
    end

    local isLeader = UnitIsGroupLeader(unit)
    if not self:IsAccessible(isLeader) then
        return false
    end

    return isLeader and true or false
end

function Keystones:GetUnitRole(unit)
    if not unit or not UnitGroupRolesAssigned then
        return nil
    end

    local role = UnitGroupRolesAssigned(unit)
    if not self:IsAccessible(role) then
        return nil
    end

    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
    end

    return nil
end

-- Keys are indexed by challenge map ID (same as Teleports.SEASON_DUNGEONS[].challengeModeID).
function Keystones:GetPartyKeyTokensByMap()
    local byMap = {}

    for _, unit in ipairs(Party:GetPartyUnits()) do
        if UnitExists(unit) then
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
    if IsInGroup() then
        Keystones:RestoreSessionCacheIfNeeded()
    end
end)

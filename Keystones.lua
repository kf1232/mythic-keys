local ADDON_NAME = ...

KeyKeystones = KeyKeystones or {}
local Keystones = KeyKeystones

Keystones.partyCache = Keystones.partyCache or {}
Keystones.partyCacheByGUID = Keystones.partyCacheByGUID or {}
Keystones.primaryCache = Keystones.primaryCache or {}
Keystones.partyBestCache = Keystones.partyBestCache or {}
Keystones.partyBestCacheByGUID = Keystones.partyBestCacheByGUID or {}
Keystones.primaryBestCache = Keystones.primaryBestCache or {}
Keystones.sessionPrimaryCache = Keystones.sessionPrimaryCache or {}
Keystones.sessionPartyCache = Keystones.sessionPartyCache or {}
Keystones.sessionPartyCacheByGUID = Keystones.sessionPartyCacheByGUID or {}
Keystones.sessionPrimaryBestCache = Keystones.sessionPrimaryBestCache or {}
Keystones.sessionPartyBestCache = Keystones.sessionPartyBestCache or {}
Keystones.sessionPartyBestCacheByGUID = Keystones.sessionPartyBestCacheByGUID or {}

function Keystones:IsAccessible(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

function Keystones:NormalizeSender(sender)
    if not self:IsAccessible(sender) or sender == "" then
        return nil
    end
    return Ambiguate(sender, "none")
end

function Keystones:BuildLookupKeys(name)
    if not self:IsAccessible(name) or name == "" then
        return {}
    end

    local keys = {
        name,
        Ambiguate(name, "none"),
        Ambiguate(name, "short"),
        Ambiguate(name, "guild"),
    }

    local seen = {}
    local result = {}
    for _, key in ipairs(keys) do
        if key and key ~= "" and not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end
    return result
end

function Keystones:GetSessionStores(primaryCache)
    if primaryCache == self.primaryBestCache then
        return self.sessionPrimaryBestCache, self.sessionPartyBestCache, self.sessionPartyBestCacheByGUID
    end

    if primaryCache == self.primaryCache then
        return self.sessionPrimaryCache, self.sessionPartyCache, self.sessionPartyCacheByGUID
    end

    if KeyReadyCheck and primaryCache == KeyReadyCheck.primaryReadyCache then
        return KeyReadyCheck.sessionPrimaryReadyCache, KeyReadyCheck.sessionReadyCache, KeyReadyCheck.sessionReadyCacheByGUID
    end

    return nil, nil, nil
end

function Keystones:MirrorEntryToSession(sender, entry, primaryCache, nameCache, cacheByGUID)
    local sessionPrimary, sessionName, sessionByGUID = self:GetSessionStores(primaryCache)
    if not sessionPrimary then
        return
    end

    sessionPrimary[sender] = entry

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        sessionName[key] = entry
    end

    if not sessionByGUID then
        return
    end

    local unit = self:FindPartyUnitForSender(sender)
    if unit then
        local guid = UnitGUID(unit)
        if self:IsAccessible(guid) then
            sessionByGUID[guid] = entry
            return
        end
    end

    for guid, cachedEntry in pairs(cacheByGUID) do
        if cachedEntry == entry then
            sessionByGUID[guid] = entry
            break
        end
    end
end

function Keystones:ClearSessionEntryForSender(sender, primaryCache)
    local sessionPrimary, sessionName, sessionByGUID = self:GetSessionStores(primaryCache)
    if not sessionPrimary then
        return
    end

    local entry = sessionPrimary[sender]
    sessionPrimary[sender] = nil

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        sessionName[key] = nil
    end

    if not sessionByGUID or not entry then
        return
    end

    for guid, cachedEntry in pairs(sessionByGUID) do
        if cachedEntry == entry then
            sessionByGUID[guid] = nil
        end
    end
end

function Keystones:LookupUnitInCaches(unit, cacheByGUID, nameCache)
    if not unit then
        return nil
    end

    local guid = UnitGUID(unit)
    if self:IsAccessible(guid) and cacheByGUID[guid] then
        return cacheByGUID[guid]
    end

    local fullName = GetUnitName and GetUnitName(unit, true)
    if self:IsAccessible(fullName) then
        for _, key in ipairs(self:BuildLookupKeys(fullName)) do
            if nameCache[key] then
                return nameCache[key]
            end
        end
    end

    if UnitFullName then
        local name, realm = UnitFullName(unit)
        if self:IsAccessible(name) and self:IsAccessible(realm) and realm ~= "" then
            for _, key in ipairs(self:BuildLookupKeys(name .. "-" .. realm)) do
                if nameCache[key] then
                    return nameCache[key]
                end
            end
        end
    end

    local name = UnitName(unit)
    if self:IsAccessible(name) then
        for _, key in ipairs(self:BuildLookupKeys(name)) do
            if nameCache[key] then
                return nameCache[key]
            end
        end
    end

    return nil
end

function Keystones:LookupCachedBySender(sender, primaryCache, nameCache)
    if not sender or sender == "" then
        return nil
    end

    if primaryCache[sender] then
        return primaryCache[sender]
    end

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        if nameCache[key] then
            return nameCache[key]
        end
    end

    return nil
end

function Keystones:StoreEntryForSender(entry, sender, primaryCache, nameCache, cacheByGUID)
    primaryCache[sender] = entry

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        nameCache[key] = entry
    end

    local unit = self:FindPartyUnitForSender(sender)
    if unit then
        local guid = UnitGUID(unit)
        if self:IsAccessible(guid) then
            cacheByGUID[guid] = entry
        end
    end

    self:MirrorEntryToSession(sender, entry, primaryCache, nameCache, cacheByGUID)
end

function Keystones:ClearEntryForSender(sender, primaryCache, nameCache, cacheByGUID)
    self:ClearSessionEntryForSender(sender, primaryCache)

    primaryCache[sender] = nil

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        nameCache[key] = nil
    end

    local unit = self:FindPartyUnitForSender(sender)
    if unit then
        local guid = UnitGUID(unit)
        if self:IsAccessible(guid) then
            cacheByGUID[guid] = nil
        end
    end
end

function Keystones:RebindCacheByGUID(primaryCache, cacheByGUID)
    wipe(cacheByGUID)

    for sender in pairs(primaryCache) do
        local unit = self:FindPartyUnitForSender(sender)
        if unit then
            local guid = UnitGUID(unit)
            if self:IsAccessible(guid) then
                cacheByGUID[guid] = primaryCache[sender]
            end
        end
    end
end

function Keystones:CollectMembers()
    local members = {}

    local function AddMember(unit)
        if not UnitExists(unit) then
            return
        end

        local name = UnitName(unit)
        if not name then
            return
        end

        members[#members + 1] = {
            unit = unit,
            name = name,
            classFilename = self:GetUnitClassFilename(unit),
        }
    end

    AddMember("player")

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                AddMember(unit)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            AddMember("party" .. i)
        end
    end

    return members
end

function Keystones:GetPartyUnits()
    local units = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
        return units
    end

    units[#units + 1] = "player"
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    end

    return units
end

function Keystones:FindPartyUnitForSender(sender)
    local senderKeys = self:BuildLookupKeys(sender)
    if #senderKeys == 0 then
        return nil
    end

    local senderSet = {}
    for _, key in ipairs(senderKeys) do
        senderSet[key] = true
    end

    for _, unit in ipairs(self:GetPartyUnits()) do
        local fullName = GetUnitName and GetUnitName(unit, true)
        if self:IsAccessible(fullName) then
            if senderSet[fullName] then
                return unit
            end
            for _, key in ipairs(self:BuildLookupKeys(fullName)) do
                if senderSet[key] then
                    return unit
                end
            end
        end

        if UnitFullName then
            local name, realm = UnitFullName(unit)
            if self:IsAccessible(name) and self:IsAccessible(realm) and realm ~= "" then
                local combined = name .. "-" .. realm
                if senderSet[combined] then
                    return unit
                end
                for _, key in ipairs(self:BuildLookupKeys(combined)) do
                    if senderSet[key] then
                        return unit
                    end
                end
            end
        end

        local name = UnitName(unit)
        if self:IsAccessible(name) then
            for _, key in ipairs(self:BuildLookupKeys(name)) do
                if senderSet[key] then
                    return unit
                end
            end
        end
    end

    return nil
end

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
        if name then
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
                    if level and mapID and mapID ~= 0 then
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

function Keystones:GetOwnKeystone()
    self:RequestMapInfo()

    local level
    local mapID

    if C_MythicPlus then
        if C_MythicPlus.GetOwnedKeystoneLevel then
            level = C_MythicPlus.GetOwnedKeystoneLevel()
        end
        if C_MythicPlus.GetOwnedKeystoneChallengeMapID then
            mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        end
        if (not mapID or mapID == 0) and C_MythicPlus.GetOwnedKeystoneMapID then
            mapID = C_MythicPlus.GetOwnedKeystoneMapID()
        end
    end

    if (not level or level == 0 or not mapID or mapID == 0) then
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
    if not key or not key.level or key.level == 0 then
        return "no key"
    end

    local name = key.dungeonName or self:GetDungeonName(key.mapID) or "Unknown"
    return string.format("%s +%d", name, key.level)
end

function Keystones:LookupCachedKeyBySender(sender)
    return self:LookupCachedBySender(sender, self.primaryCache, self.partyCache)
        or self:LookupCachedBySender(sender, self.sessionPrimaryCache, self.sessionPartyCache)
end

function Keystones:RebindPartyCache()
    self:RebindCacheByGUID(self.primaryCache, self.partyCacheByGUID)
    self:RebindCacheByGUID(self.primaryBestCache, self.partyBestCacheByGUID)
end

function Keystones:StorePartyKeyEntry(entry, sender)
    self:StoreEntryForSender(entry, sender, self.primaryCache, self.partyCache, self.partyCacheByGUID)
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

        self:ClearEntryForSender(sender, self.primaryCache, self.partyCache, self.partyCacheByGUID)
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
    return self:LookupUnitInCaches(unit, self.partyCacheByGUID, self.partyCache)
        or self:LookupUnitInCaches(unit, self.sessionPartyCacheByGUID, self.sessionPartyCache)
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

        for sender, entry in pairs(self.primaryCache) do
            local matchedUnit = self:FindPartyUnitForSender(sender)
            if matchedUnit and UnitIsUnit(matchedUnit, unitOrSender) then
                return entry
            end
        end

        for sender, entry in pairs(self.sessionPrimaryCache) do
            local matchedUnit = self:FindPartyUnitForSender(sender)
            if matchedUnit and UnitIsUnit(matchedUnit, unitOrSender) then
                return entry
            end
        end
    end

    return nil
end

function Keystones:ClearSessionCaches()
    wipe(self.sessionPartyCache)
    wipe(self.sessionPartyCacheByGUID)
    wipe(self.sessionPrimaryCache)
    wipe(self.sessionPartyBestCache)
    wipe(self.sessionPartyBestCacheByGUID)
    wipe(self.sessionPrimaryBestCache)
end

function Keystones:RestoreSessionCacheIfNeeded()
    if not next(self.primaryCache) and next(self.sessionPrimaryCache) then
        for sender, entry in pairs(self.sessionPrimaryCache) do
            self:StorePartyKeyEntry(entry, sender)
        end
    end

    if not next(self.primaryBestCache) and next(self.sessionPrimaryBestCache) then
        for sender, entry in pairs(self.sessionPrimaryBestCache) do
            self:StorePartyBestEntry(entry, sender)
        end
    end

    if KeyReadyCheck and KeyReadyCheck.RestoreSessionCacheIfNeeded then
        KeyReadyCheck:RestoreSessionCacheIfNeeded()
    end

    self:RebindPartyCache()
end

function Keystones:ClearPartyCache()
    wipe(self.partyCache)
    wipe(self.partyCacheByGUID)
    wipe(self.primaryCache)
    wipe(self.partyBestCache)
    wipe(self.partyBestCacheByGUID)
    wipe(self.primaryBestCache)
    self:ClearSessionCaches()
end

function Keystones:GetSeasonDungeons()
    if KeyTeleports and KeyTeleports.SEASON_DUNGEONS then
        return KeyTeleports.SEASON_DUNGEONS
    end
    return {}
end

function Keystones:PickBestRun(intimeInfo)
    local intimeLevel = intimeInfo and intimeInfo.level
    if self:IsAccessible(intimeLevel) and intimeLevel > 0 then
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

    local intimeInfo = C_MythicPlus.GetSeasonBestForMap(challengeModeID)
    return self:PickBestRun(intimeInfo)
end

function Keystones:GetBestPayloadPrefix()
    if KeyPartySync and KeyPartySync.PROTOCOL and KeyPartySync.PROTOCOL.BEST then
        return KeyPartySync.PROTOCOL.BEST.prefix
    end
    return "M"
end

function Keystones:GetBestPayloadPattern()
    if KeyPartySync and KeyPartySync.PROTOCOL and KeyPartySync.PROTOCOL.BEST then
        return KeyPartySync.PROTOCOL.BEST.pattern
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
    self:StoreEntryForSender(entry, sender, self.primaryBestCache, self.partyBestCache, self.partyBestCacheByGUID)
end

function Keystones:SetPartyBest(sender, bests)
    if not sender or sender == "" then
        return
    end

    if not bests or not next(bests) then
        self:ClearEntryForSender(sender, self.primaryBestCache, self.partyBestCache, self.partyBestCacheByGUID)
        return
    end

    self:StorePartyBestEntry(bests, sender)
end

function Keystones:LookupCachedBest(unit)
    return self:LookupUnitInCaches(unit, self.partyBestCacheByGUID, self.partyBestCache)
        or self:LookupUnitInCaches(unit, self.sessionPartyBestCacheByGUID, self.sessionPartyBestCache)
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

    for _, unit in ipairs(self:GetPartyUnits()) do
        if UnitExists(unit) then
            local key = self:GetMemberKey(unit)
            if key and key.level and key.level > 0 and key.mapID and key.mapID ~= 0 then
                byMap[key.mapID] = byMap[key.mapID] or {}
                byMap[key.mapID][#byMap[key.mapID] + 1] = {
                    level = key.level,
                    classFilename = self:GetUnitClassFilename(unit),
                    isLeader = self:IsUnitLeader(unit),
                    role = self:GetUnitRole(unit),
                }
            end
        end
    end

    return byMap
end

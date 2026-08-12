Key.Data = Key.Data or {}



local OwnedKeystone = {}

Key.Data.OwnedKeystone = OwnedKeystone



local Guard = Key.Guard

local PlayerData = Key.Data.PlayerData



-- Cache keyed by unit GUID so party members can be added later without reshaping callers.

local byGuid = {}

local listeners = {}

local dirty = false

local debouncePending = false

local debounceTimer

local postMythicPlusWatch = false

local eventFrame



local PLAYER_UNIT = "player"

local DEBOUNCE_SECONDS = 0.25

local POST_MYTHIC_PLUS_DELAY = 1

local MAX_KEY_LEVEL = 99

local BADGE_SOURCE_BAG = "bag"

local BADGE_SOURCE_API = "api"

local BADGE_SOURCE_SYNC = "sync"



local function CopyEntry(entry)

    if not entry then

        return nil

    end

    return {

        guid = entry.guid,

        unit = entry.unit,

        name = entry.name,

        realm = entry.realm,

        classFile = entry.classFile,

        mapChallengeModeID = entry.mapChallengeModeID,

        level = entry.level,

        link = entry.link,

        itemID = entry.itemID,

        source = entry.source,

        scannedAt = entry.scannedAt,

    }

end



local function EntriesEqual(a, b)

    if a == b then

        return true

    end

    if not a or not b then

        return a == b

    end

    -- Bag vs API scans differ in link/source; only level+map identify the key.

    return a.mapChallengeModeID == b.mapChallengeModeID

        and a.level == b.level

end



local function MergeEntryMetadata(into, from)

    if not into or not from then

        return into or from

    end

    if not into.link and from.link then

        into.link = from.link

    end

    if not into.itemID and from.itemID then

        into.itemID = from.itemID

    end

    if from.source == BADGE_SOURCE_BAG then

        into.source = BADGE_SOURCE_BAG

    elseif not into.source then

        into.source = from.source

    end

    if not into.classFile and from.classFile then

        into.classFile = from.classFile

    end

    if not into.name and from.name then

        into.name = from.name

        into.realm = from.realm

    end

    return into

end



local function NotifyChanged()

    for i = 1, #listeners do

        local ok, err = pcall(listeners[i])

        if not ok then

            print("|cff00ff00Mythic Keys:|r OwnedKeystone listener error:", err)

        end

    end

end



function OwnedKeystone.Validate(level, mapChallengeModeID)

    if level == nil or mapChallengeModeID == nil then

        return false

    end



    level = tonumber(level)

    mapChallengeModeID = tonumber(mapChallengeModeID)

    if not level or not mapChallengeModeID then

        return false

    end



    if level ~= math.floor(level) or mapChallengeModeID ~= math.floor(mapChallengeModeID) then

        return false

    end



    if level < 0 or level > MAX_KEY_LEVEL then

        return false

    end



    if mapChallengeModeID < 0 then

        return false

    end



    if level == 0 then

        return mapChallengeModeID == 0

    end



    return mapChallengeModeID > 0

end



local function SetGuidEntry(guid, unit, entry)

    if not guid then

        return false

    end



    local previous = byGuid[guid]

    if not entry then

        if previous == nil then

            return false

        end

        byGuid[guid] = nil

        NotifyChanged()

        return true

    end



    entry.guid = guid

    entry.unit = unit

    entry.scannedAt = GetTime and GetTime() or 0



    if unit and UnitExists(unit) then

        if not entry.classFile then

            local classResult = Guard.call(UnitClass, unit)

            if classResult.ok and classResult[2] then

                entry.classFile = classResult[2]

            end

        end

        if not entry.name then

            local nameResult = Guard.call(UnitName, unit)

            if nameResult.ok and nameResult[1] then

                entry.name = nameResult[1]

                entry.realm = nameResult[2]

            end

        end

    end



    if EntriesEqual(previous, entry) then

        byGuid[guid] = MergeEntryMetadata(previous, entry)

        return false

    end



    byGuid[guid] = entry

    NotifyChanged()

    return true

end



local function SetPlayerEntry(entry)

    local guidResult = Guard.call(UnitGUID, PLAYER_UNIT)

    local guid = guidResult.ok and guidResult[1] or nil

    if not guid then

        return false

    end

    return SetGuidEntry(guid, PLAYER_UNIT, entry)

end



local function ParseKeystoneLink(link)

    if not Guard.usable(link) or type(link) ~= "string" then

        return nil

    end



    if not link:find("keystone:", 1, true) then

        return nil

    end



    if C_Item and C_Item.IsItemKeystone then

        local isKeystoneResult = Guard.call(C_Item.IsItemKeystone, link)

        if not isKeystoneResult.ok or not isKeystoneResult[1] then

            return nil

        end

    end



    local level

    local mapID

    local itemID



    if C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelAndMapID then

        local parsed = Guard.call(C_ChallengeMode.GetKeystoneLevelAndMapID, link)

        if parsed.ok then

            level = parsed[1]

            mapID = parsed[2]

        end

    end



    if not level or not mapID then

        itemID, mapID, level = link:match("keystone:(%d+):(%d+):(%d+)")

        itemID = tonumber(itemID)

        mapID = tonumber(mapID)

        level = tonumber(level)

    end



    if not OwnedKeystone.Validate(level, mapID) then

        return nil

    end



    return {

        itemID = itemID,

        mapChallengeModeID = mapID,

        level = level,

        link = link,

        source = BADGE_SOURCE_BAG,

    }

end



local function ReadKeystoneFromBags()

    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemLink then

        return nil

    end



    local firstBag = BACKPACK_CONTAINER or 0

    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 5



    for bag = firstBag, lastBag do

        local slotsResult = Guard.call(C_Container.GetContainerNumSlots, bag)

        local numSlots = slotsResult.ok and slotsResult[1] or 0

        if Guard.usable(numSlots) then

            numSlots = tonumber(numSlots) or 0

        else

            numSlots = 0

        end



        for slot = 1, numSlots do

            local linkResult = Guard.call(C_Container.GetContainerItemLink, bag, slot)

            local link = linkResult.ok and linkResult[1] or nil

            if link and link:find("keystone:", 1, true) then

                local parsed = ParseKeystoneLink(link)

                if parsed then

                    return parsed

                end

            end

        end

    end



    return nil

end



local function ReadKeystoneFromApi()

    if not C_MythicPlus then

        return nil

    end



    local mapID

    if C_MythicPlus.GetOwnedKeystoneChallengeMapID then

        local mapResult = Guard.call(C_MythicPlus.GetOwnedKeystoneChallengeMapID)

        mapID = mapResult.ok and mapResult[1] or nil

    end



    if (not mapID or mapID == 0) and C_MythicPlus.GetOwnedKeystoneMapID then

        local fallbackResult = Guard.call(C_MythicPlus.GetOwnedKeystoneMapID)

        mapID = fallbackResult.ok and fallbackResult[1] or mapID

    end



    if not mapID or mapID == 0 then

        return nil

    end



    local level

    if C_MythicPlus.GetOwnedKeystoneLevel then

        local levelResult = Guard.call(C_MythicPlus.GetOwnedKeystoneLevel)

        level = levelResult.ok and levelResult[1] or nil

    end



    if not level or level == 0 then

        return nil

    end



    if not OwnedKeystone.Validate(level, mapID) then

        return nil

    end



    return {

        mapChallengeModeID = mapID,

        level = level,

        link = nil,

        itemID = nil,

        source = BADGE_SOURCE_API,

    }

end



-- Single source of truth for reading the local player's keystone from the game.

local function DiscoverPlayerKeystone()

    local entry = ReadKeystoneFromApi()

    if entry then

        return entry

    end

    return ReadKeystoneFromBags()

end



local function CancelDebounce()

    if debounceTimer and debounceTimer.Cancel then

        debounceTimer:Cancel()

        debounceTimer = nil

    end

    debouncePending = false

end



local function ScheduleRefresh(delay)

    dirty = true

    if InCombatLockdown and InCombatLockdown() then

        return

    end



    delay = delay or DEBOUNCE_SECONDS



    if debouncePending then

        return

    end



    debouncePending = true

    if C_Timer and C_Timer.After then

        debounceTimer = C_Timer.After(delay, function()

            debounceTimer = nil

            debouncePending = false

            if dirty then

                OwnedKeystone.Refresh()

            end

        end)

    else

        debouncePending = false

        OwnedKeystone.Refresh()

    end

end



local function StopPostMythicPlusWatch()

    if not eventFrame or not postMythicPlusWatch then

        return

    end



    postMythicPlusWatch = false

    eventFrame:UnregisterEvent("ITEM_CHANGED")

    pcall(eventFrame.UnregisterEvent, eventFrame, "ITEM_PUSH")

    eventFrame:UnregisterEvent("PLAYER_LEAVING_WORLD")

end



local function StartPostMythicPlusWatch()

    if not eventFrame then

        return

    end



    postMythicPlusWatch = true

    eventFrame:RegisterEvent("ITEM_CHANGED")

    pcall(eventFrame.RegisterEvent, eventFrame, "ITEM_PUSH")

    eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")

end



local function EnsureEvents()

    if eventFrame then

        return

    end



    eventFrame = CreateFrame("Frame")

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

    eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")

    pcall(eventFrame.RegisterEvent, eventFrame, "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")



    eventFrame:SetScript("OnEvent", function(_, event, arg1)

        if event == "PLAYER_REGEN_ENABLED" then

            if dirty then

                OwnedKeystone.Refresh()

            end

            return

        end



        if event == "PLAYER_ENTERING_WORLD" then

            StopPostMythicPlusWatch()

            dirty = true

            OwnedKeystone.Refresh()

            return

        end



        if event == "CHALLENGE_MODE_COMPLETED" then

            StartPostMythicPlusWatch()

            ScheduleRefresh(POST_MYTHIC_PLUS_DELAY)

            return

        end



        if event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then

            ScheduleRefresh()

            return

        end



        if event == "PLAYER_LEAVING_WORLD" then

            StopPostMythicPlusWatch()

            return

        end



        if postMythicPlusWatch and (event == "ITEM_CHANGED" or event == "ITEM_PUSH") then

            ScheduleRefresh(POST_MYTHIC_PLUS_DELAY)

        end

    end)

end



local function CollectGroupUnits()

    local units = {}

    if not IsInGroup or not IsInGroup() then

        return units

    end



    if IsInRaid and IsInRaid() then

        for i = 1, GetNumGroupMembers() do

            local unit = "raid" .. i

            if UnitExists(unit) then

                units[#units + 1] = unit

            end

        end

        return units

    end



    units[#units + 1] = PLAYER_UNIT

    for i = 1, 4 do

        local unit = "party" .. i

        if UnitExists(unit) then

            units[#units + 1] = unit

        end

    end

    return units

end



local function FindUnitForSenderKey(senderKey)

    if not senderKey or senderKey == "" then

        return nil

    end



    local units = CollectGroupUnits()

    for i = 1, #units do

        local unit = units[i]

        local cacheKey = PlayerData.GetCacheKey(unit)

        if cacheKey == senderKey then

            return unit

        end

        local nameResult = Guard.call(UnitName, unit)

        if nameResult.ok and nameResult[1] == senderKey then

            return unit

        end

    end



    return nil

end



function OwnedKeystone.OnChanged(listener)

    if type(listener) ~= "function" then

        return

    end

    listeners[#listeners + 1] = listener

end



-- Only entry point for discovering the local player's keystone and updating the cache.

function OwnedKeystone.Refresh()

    EnsureEvents()

    dirty = false



    if InCombatLockdown and InCombatLockdown() then

        dirty = true

        return false

    end



    return SetPlayerEntry(DiscoverPlayerKeystone())

end



function OwnedKeystone.Get(unit)

    EnsureEvents()

    unit = unit or PLAYER_UNIT

    local guidResult = Guard.call(UnitGUID, unit)

    local guid = guidResult.ok and guidResult[1] or nil

    if not guid then

        return nil

    end

    return CopyEntry(byGuid[guid])

end



function OwnedKeystone.GetSyncPayload()

    EnsureEvents()

    local entry = OwnedKeystone.Get(PLAYER_UNIT)

    if not entry or not entry.level or entry.level == 0 or not entry.mapChallengeModeID then

        return "K:0:0"

    end

    if not OwnedKeystone.Validate(entry.level, entry.mapChallengeModeID) then

        return "K:0:0"

    end

    return string.format("K:%d:%d", entry.level, entry.mapChallengeModeID)

end



function OwnedKeystone.SetParty(senderKey, level, mapChallengeModeID)

    if not senderKey or senderKey == "" then

        return false

    end



    level = tonumber(level)

    mapChallengeModeID = tonumber(mapChallengeModeID)



    if level == 0 and mapChallengeModeID == 0 then

        local unit = FindUnitForSenderKey(senderKey)

        if not unit or UnitIsUnit(unit, PLAYER_UNIT) then

            return false

        end

        local guidResult = Guard.call(UnitGUID, unit)

        local guid = guidResult.ok and guidResult[1] or nil

        if not guid then

            return false

        end

        return SetGuidEntry(guid, unit, nil)

    end



    if not OwnedKeystone.Validate(level, mapChallengeModeID) then

        return false

    end



    local unit = FindUnitForSenderKey(senderKey)

    if not unit or UnitIsUnit(unit, PLAYER_UNIT) then

        return false

    end



    local guidResult = Guard.call(UnitGUID, unit)

    local guid = guidResult.ok and guidResult[1] or nil

    if not guid then

        return false

    end



    local name, realm = senderKey:match("^([^%-]+)%-(.+)$")

    if not name then

        name = senderKey

    end



    return SetGuidEntry(guid, unit, {

        mapChallengeModeID = mapChallengeModeID,

        level = level,

        name = name,

        realm = realm,

        source = BADGE_SOURCE_SYNC,

    })

end



function OwnedKeystone.RebindPartyUnits()

    for guid, entry in pairs(byGuid) do

        if entry and entry.unit and entry.unit ~= PLAYER_UNIT and UnitExists(entry.unit) then

            entry.guid = guid

        end

    end

end



function OwnedKeystone.ClearParty()

    local playerGuidResult = Guard.call(UnitGUID, PLAYER_UNIT)

    local playerGuid = playerGuidResult.ok and playerGuidResult[1] or nil

    local changed = false



    for guid, entry in pairs(byGuid) do

        if guid ~= playerGuid then

            byGuid[guid] = nil

            changed = true

        end

    end



    if changed then

        NotifyChanged()

    end

end



function OwnedKeystone.GetHoldersForMap(mapChallengeModeID)

    EnsureEvents()

    if not mapChallengeModeID then

        return {}

    end



    local holders = {}

    for _, entry in pairs(byGuid) do

        if entry.mapChallengeModeID == mapChallengeModeID then

            holders[#holders + 1] = CopyEntry(entry)

        end

    end



    table.sort(holders, function(a, b)

        local unitA = a.unit or ""

        local unitB = b.unit or ""

        if unitA == PLAYER_UNIT and unitB ~= PLAYER_UNIT then

            return true

        end

        if unitB == PLAYER_UNIT and unitA ~= PLAYER_UNIT then

            return false

        end

        return (a.level or 0) > (b.level or 0)

    end)



    return holders

end



EnsureEvents()

OwnedKeystone.Refresh()



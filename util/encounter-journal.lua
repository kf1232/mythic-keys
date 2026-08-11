Key.Util = Key.Util or {}

local EncounterJournal = {}
Key.Util.EncounterJournal = EncounterJournal

local ChallengeMode = Key.Util.ChallengeMode
local SpecCatalog = Key.Util.SpecCatalog

local MYTHIC_DUNGEON_DIFFICULTY_ID = 23
local MYTHIC_RAID_DIFFICULTY_ID = 16

local ejLookupByName
local savedTier

local function EnsureLoaded()
    if not C_AddOns or not C_AddOns.IsAddOnLoaded or not C_AddOns.LoadAddOn then
        return false
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
        C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")
        and EJ_SelectInstance ~= nil
        and EJ_GetNumLoot ~= nil
end

local function BuildNameLookup()
    if ejLookupByName then
        return ejLookupByName
    end

    ejLookupByName = {}
    if not EJ_GetNumTiers or not EJ_GetInstanceByIndex then
        return ejLookupByName
    end

    savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()

    local numTiers = EJ_GetNumTiers()
    for tierIndex = 1, numTiers do
        EJ_SelectTier(tierIndex)
        -- false = dungeons, true = raids
        for _, isRaid in ipairs({ false, true }) do
            local instanceIndex = 1
            while true do
                local instanceID, instanceName = EJ_GetInstanceByIndex(instanceIndex, isRaid)
                if not instanceID then
                    break
                end
                if instanceName then
                    ejLookupByName[instanceName] = instanceID
                end
                instanceIndex = instanceIndex + 1
            end
        end
    end

    if savedTier and EJ_SelectTier then
        EJ_SelectTier(savedTier)
    end

    return ejLookupByName
end

function EncounterJournal.ResolveInstanceID(mapChallengeModeID)
    if not mapChallengeModeID then
        return nil
    end

    local info = ChallengeMode.GetMapUIInfo(mapChallengeModeID)
    if not info then
        return nil
    end

    if info.mapID and EJ_GetInstanceForMap then
        local instanceID = EJ_GetInstanceForMap(info.mapID)
        if instanceID and instanceID > 0 then
            return instanceID, info.name
        end
    end

    local lookup = BuildNameLookup()
    local instanceID = lookup[info.name]
    if instanceID and instanceID > 0 then
        return instanceID, info.name
    end

    return nil, info.name
end

function EncounterJournal.ResolveInstanceIDByName(instanceName)
    if not instanceName then
        return nil
    end
    local lookup = BuildNameLookup()
    local instanceID = lookup[instanceName]
    if instanceID and instanceID > 0 then
        return instanceID, instanceName
    end

    -- EJ naming sometimes drops or adds a leading "The ".
    local alternate
    if instanceName:match("^The ") then
        alternate = instanceName:sub(5)
    else
        alternate = "The " .. instanceName
    end
    instanceID = lookup[alternate]
    if instanceID and instanceID > 0 then
        return instanceID, alternate
    end

    return nil, instanceName
end

local function PrepareLootQuery(instanceID, difficultyID, options)
    options = options or {}
    if not instanceID or not EnsureLoaded() then
        return false
    end

    if EJ_ClearSearch then
        EJ_ClearSearch()
    end
    if C_EncounterJournal and C_EncounterJournal.ResetSlotFilter then
        C_EncounterJournal.ResetSlotFilter()
    end
    if EJ_ResetLootFilter then
        EJ_ResetLootFilter()
    end

    -- Select instance first; difficulty/filter after. Selecting later can wipe filters.
    EJ_SelectInstance(instanceID)

    if EJ_SetDifficulty then
        EJ_SetDifficulty(difficultyID or MYTHIC_DUNGEON_DIFFICULTY_ID)
    end

    if options.forPlayer and EJ_SetLootFilter then
        local _, _, classID = UnitClass("player")
        local specIndex = GetSpecialization and GetSpecialization()
        local specID = specIndex and GetSpecializationInfo and select(1, GetSpecializationInfo(specIndex)) or 0
        if classID then
            EJ_SetLootFilter(classID, specID or 0)
        end
    end

    return true
end

local function EnrichItemFields(item)
    if not item or not item.itemID then
        return item
    end

    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(item.itemID)
    if (not name or not link) and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(item.itemID)
        name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(item.itemID)
    end

    if (not item.name or item.name == "") and name then
        item.name = name
    end
    if (not item.link or item.link == "") and link then
        item.link = link
    end
    if (not item.icon or item.icon == 0) and icon then
        item.icon = icon
    end
    if quality and not item.quality then
        item.quality = quality
    end

    return item
end

local function ReadInstanceLootEntries()
    local items = {}
    local numLoot = EJ_GetNumLoot()

    for lootIndex = 1, numLoot do
        local itemInfo = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
            and C_EncounterJournal.GetLootInfoByIndex(lootIndex)

        if itemInfo and itemInfo.itemID then
            local encounterID = itemInfo.encounterID
            local encounterName
            if encounterID and EJ_GetEncounterInfo then
                encounterName = EJ_GetEncounterInfo(encounterID)
            end

            local item = EnrichItemFields({
                itemID = itemInfo.itemID,
                name = itemInfo.name,
                link = itemInfo.link or itemInfo.itemLink,
                icon = itemInfo.icon,
                slot = itemInfo.slot,
                armorType = itemInfo.armorType,
                quality = itemInfo.itemQuality,
                encounterID = encounterID,
                encounterName = encounterName,
            })

            items[#items + 1] = item
        end
    end

    return items, numLoot
end

local function IsEligibleLootInfo(itemInfo)
    -- If EJ includes the item under a spec filter, that spec can use it.
    -- handError and weaponTypeError both false-positive on armor, ranged, and shields.
    return itemInfo ~= nil and itemInfo.itemID ~= nil
end

local function ScanFilteredLootForSpec(spec)
    if EJ_SetLootFilter then
        EJ_SetLootFilter(spec.classID, spec.specID)
    end

    local lootByItemID = {}
    local numLoot = EJ_GetNumLoot()
    for lootIndex = 1, numLoot do
        local itemInfo = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex
            and C_EncounterJournal.GetLootInfoByIndex(lootIndex)

        if itemInfo and itemInfo.itemID then
            lootByItemID[itemInfo.itemID] = itemInfo
        end
    end

    return lootByItemID, numLoot
end

local function WarmLootCache()
    local numLoot = EJ_GetNumLoot()
    for lootIndex = 1, numLoot do
        if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
            C_EncounterJournal.GetLootInfoByIndex(lootIndex)
        end
    end
    return numLoot
end

local function PickSampleSpecs()
    local samples = {}
    local seenSpecID = {}

    local function add(spec)
        if spec and not seenSpecID[spec.specID] then
            seenSpecID[spec.specID] = true
            samples[#samples + 1] = spec
        end
    end

    for _, spec in ipairs(SpecCatalog.GetAll()) do
        if spec.classID == 10 then
            add(spec)
            break
        end
    end

    for _, spec in ipairs(SpecCatalog.GetAll()) do
        if spec.classID == 1 then
            add(spec)
            break
        end
    end

    if UnitClass and GetSpecialization and GetSpecializationInfo then
        local _, _, classID = UnitClass("player")
        local specIndex = GetSpecialization()
        if classID and specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID then
                for _, spec in ipairs(SpecCatalog.GetAll()) do
                    if spec.specID == specID then
                        add(spec)
                        break
                    end
                end
            end
        end
    end

    add(SpecCatalog.GetAll()[1])
    return samples
end

function EncounterJournal.GetItemEligibleSpecs(instanceID, options)
    options = options or {}
    if not PrepareLootQuery(instanceID, options.difficultyID) then
        if options.debug then
            return {}, {}
        end
        return {}
    end

    WarmLootCache()

    local items = options.items or {}
    local itemIDs = {}
    local itemMeta = {}
    for i = 1, #items do
        local item = items[i]
        if item.itemID then
            itemIDs[#itemIDs + 1] = item.itemID
            itemMeta[item.itemID] = item
        end
    end

    if #itemIDs == 0 then
        local lootItems, _ = ReadInstanceLootEntries()
        for i = 1, #lootItems do
            local item = lootItems[i]
            if item.itemID then
                itemIDs[#itemIDs + 1] = item.itemID
                itemMeta[item.itemID] = item
            end
        end
    end

    local savedClassFilter, savedSpecFilter
    if EJ_GetLootFilter then
        savedClassFilter, savedSpecFilter = EJ_GetLootFilter()
    end

    local byItem = {}
    local debugByItem = options.debug and {} or nil
    if debugByItem then
        for i = 1, #itemIDs do
            local itemID = itemIDs[i]
            local meta = itemMeta[itemID] or {}
            debugByItem[itemID] = {
                itemID = itemID,
                slot = meta.slot,
                armorType = meta.armorType,
                encounterID = meta.encounterID,
                specsScanned = 0,
                inFilteredList = 0,
                eligible = 0,
                handErrorOnly = 0,
                weaponErrorOnly = 0,
                bothErrors = 0,
            }
        end
    end

    for _, spec in ipairs(SpecCatalog.GetAll()) do
        local filteredLoot = ScanFilteredLootForSpec(spec)

        for i = 1, #itemIDs do
            local itemID = itemIDs[i]
            local itemInfo = filteredLoot[itemID]
            local debugEntry = debugByItem and debugByItem[itemID]

            if debugEntry then
                debugEntry.specsScanned = debugEntry.specsScanned + 1
            end

            if itemInfo then
                if debugEntry then
                    debugEntry.inFilteredList = debugEntry.inFilteredList + 1
                    if itemInfo.handError == true and itemInfo.weaponTypeError == true then
                        debugEntry.bothErrors = debugEntry.bothErrors + 1
                    elseif itemInfo.handError == true then
                        debugEntry.handErrorOnly = debugEntry.handErrorOnly + 1
                    elseif itemInfo.weaponTypeError == true then
                        debugEntry.weaponErrorOnly = debugEntry.weaponErrorOnly + 1
                    end
                end

                if IsEligibleLootInfo(itemInfo) then
                    if debugEntry then
                        debugEntry.eligible = debugEntry.eligible + 1
                    end

                    local bucket = byItem[itemID]
                    if not bucket then
                        bucket = {}
                        byItem[itemID] = bucket
                    end
                    bucket[spec.specID] = spec
                end
            end
        end
    end

    if EJ_ResetLootFilter then
        EJ_ResetLootFilter()
    end
    if EJ_SetLootFilter and savedClassFilter ~= nil and savedSpecFilter ~= nil then
        EJ_SetLootFilter(savedClassFilter, savedSpecFilter)
    end

    local eligibility = {}
    for itemID, bucket in pairs(byItem) do
        local specs = {}
        for _, spec in pairs(bucket) do
            specs[#specs + 1] = spec
        end
        table.sort(specs, function(a, b)
            if a.classID ~= b.classID then
                return a.classID < b.classID
            end
            return a.specIndex < b.specIndex
        end)
        eligibility[itemID] = specs
    end

    if debugByItem then
        local sampleSpecs = PickSampleSpecs()
        for i = 1, #itemIDs do
            local itemID = itemIDs[i]
            local debugEntry = debugByItem[itemID]
            if debugEntry and (not eligibility[itemID] or #eligibility[itemID] == 0) then
                if EJ_ResetLootFilter then
                    EJ_ResetLootFilter()
                end
                local unfilteredInfo = C_EncounterJournal and C_EncounterJournal.GetLootInfo
                    and C_EncounterJournal.GetLootInfo(itemID)
                debugEntry.unfilteredGetLootInfo = unfilteredInfo and "ok" or "nil"

                debugEntry.samples = {}
                for j = 1, #sampleSpecs do
                    local spec = sampleSpecs[j]
                    local filteredLoot, filteredLootCount = ScanFilteredLootForSpec(spec)
                    local itemInfo = filteredLoot[itemID]
                    debugEntry.samples[#debugEntry.samples + 1] = {
                        name = spec.name,
                        classID = spec.classID,
                        specID = spec.specID,
                        filteredLootCount = filteredLootCount,
                        inFilteredList = itemInfo and "ok" or "nil",
                        handError = itemInfo and itemInfo.handError,
                        weaponTypeError = itemInfo and itemInfo.weaponTypeError,
                    }
                end

                if EJ_ResetLootFilter then
                    EJ_ResetLootFilter()
                end
                if EJ_SetLootFilter and savedClassFilter ~= nil and savedSpecFilter ~= nil then
                    EJ_SetLootFilter(savedClassFilter, savedSpecFilter)
                end
            end
        end

        return eligibility, debugByItem
    end

    return eligibility
end

function EncounterJournal.GetInstanceLoot(instanceID, difficultyID, options)
    if not PrepareLootQuery(instanceID, difficultyID, options) then
        return nil
    end

    local items, rawLootCount = ReadInstanceLootEntries()
    return {
        instanceID = instanceID,
        items = items,
        rawLootCount = rawLootCount,
        difficultyID = difficultyID or MYTHIC_DUNGEON_DIFFICULTY_ID,
    }
end

function EncounterJournal.GetInstanceLootForPlayer(instanceID, difficultyID)
    return EncounterJournal.GetInstanceLoot(instanceID, difficultyID, { forPlayer = true })
end

function EncounterJournal.GetMythicRaidDifficultyID()
    return MYTHIC_RAID_DIFFICULTY_ID
end

function EncounterJournal.GetMythicDungeonDifficultyID()
    return MYTHIC_DUNGEON_DIFFICULTY_ID
end

function EncounterJournal.GetLootForMap(mapChallengeModeID)
    local instanceID, dungeonName = EncounterJournal.ResolveInstanceID(mapChallengeModeID)
    if not instanceID then
        return {
            mapChallengeModeID = mapChallengeModeID,
            name = dungeonName,
            instanceID = nil,
            items = {},
            rawLootCount = 0,
        }
    end

    local loot = EncounterJournal.GetInstanceLoot(instanceID)
    if not loot then
        return {
            mapChallengeModeID = mapChallengeModeID,
            name = dungeonName,
            instanceID = instanceID,
            items = {},
            rawLootCount = 0,
        }
    end

    loot.mapChallengeModeID = mapChallengeModeID
    loot.name = dungeonName
    return loot
end

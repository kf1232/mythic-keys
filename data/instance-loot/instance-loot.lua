Key.Data = Key.Data or {}

local InstanceLoot = {}
Key.Data.InstanceLoot = InstanceLoot

local SeasonDungeons = Key.Data.SeasonDungeons
local EncounterJournal = Key.Util.EncounterJournal
local SpecCatalog = Key.Util.SpecCatalog
local Chat = Key.Util.Chat

function InstanceLoot.GetForDungeon(mapChallengeModeID)
    return EncounterJournal.GetLootForMap(mapChallengeModeID)
end

function InstanceLoot.GetAllForSeason()
    local tables = {}
    local dungeons = SeasonDungeons.GetAll()
    for i = 1, #dungeons do
        tables[#tables + 1] = InstanceLoot.GetForDungeon(dungeons[i].id)
    end
    return tables
end

local function PrintEligibilityDebug(debugEntry)
    print(string.format("    [loot-spec debug] itemID=%s slot=%s armorType=%s encounterID=%s",
        tostring(debugEntry.itemID),
        tostring(debugEntry.slot),
        tostring(debugEntry.armorType),
        tostring(debugEntry.encounterID)))
    print(string.format("      unfiltered GetLootInfo=%s scanned=%d inFiltered=%d eligible=%d handError=%d weaponError=%d bothErrors=%d",
        tostring(debugEntry.unfilteredGetLootInfo),
        debugEntry.specsScanned or 0,
        debugEntry.inFilteredList or 0,
        debugEntry.eligible or 0,
        debugEntry.handErrorOnly or 0,
        debugEntry.weaponErrorOnly or 0,
        debugEntry.bothErrors or 0))

    if debugEntry.samples then
        for i = 1, #debugEntry.samples do
            local sample = debugEntry.samples[i]
            print(string.format("      sample %s (class %s spec %s): filteredLoot=%s inList=%s handError=%s weaponError=%s",
                tostring(sample.name),
                tostring(sample.classID),
                tostring(sample.specID),
                tostring(sample.filteredLootCount),
                tostring(sample.inFilteredList),
                tostring(sample.handError),
                tostring(sample.weaponTypeError)))
        end
    end
end

function InstanceLoot.DumpLiveValues(debug)
    Chat.Print(debug
        and "Instance loot from the Encounter Journal (Mythic, spec debug on):"
        or "Instance loot from the Encounter Journal (Mythic):")

    local dungeons = SeasonDungeons.GetAll()
    for i = 1, #dungeons do
        local dungeon = dungeons[i]
        local loot = InstanceLoot.GetForDungeon(dungeon.id)
        print(string.format("-- %s (map %s, instance %s): %d items",
            dungeon.name,
            tostring(dungeon.id),
            tostring(loot.instanceID),
            #loot.items))

        local eligibleSpecs, debugByItem
        if loot.instanceID then
            eligibleSpecs, debugByItem = EncounterJournal.GetItemEligibleSpecs(loot.instanceID, {
                items = loot.items,
                debug = debug,
            })
        end

        for j = 1, #loot.items do
            local item = loot.items[j]
            local label = item.link or item.name or ("item:" .. tostring(item.itemID))
            local specs = eligibleSpecs and item.itemID and eligibleSpecs[item.itemID]
            local specIcons = SpecCatalog.FormatIconList(specs, 16)
            print(string.format("  %s %s", label, specIcons))

            if debug and item.itemID and debugByItem and debugByItem[item.itemID]
                and (not specs or #specs == 0)
            then
                PrintEligibilityDebug(debugByItem[item.itemID])
            end
        end

        if not loot.instanceID then
            print(string.format("  (could not resolve Encounter Journal instance for %s)", dungeon.name))
        elseif loot.rawLootCount and loot.rawLootCount > 0 and #loot.items == 0 then
            print("  (Encounter Journal returned loot entries but none could be read)")
        elseif loot.rawLootCount == 0 then
            print("  (Encounter Journal has no loot entries for this instance at Mythic difficulty)")
        end
    end
end

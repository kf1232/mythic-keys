Key.Data = Key.Data or {}

local SeasonDungeons = {}
Key.Data.SeasonDungeons = SeasonDungeons

local SeasonConfig = Key.Data.SeasonConfig
local Chat = Key.Util.Chat
local ChallengeMode = Key.Util.ChallengeMode

local missingIconWarningShown = false

local function GetStore()
    return SeasonConfig or {}
end

local function GetActiveId()
    local store = GetStore()
    return store.active
end

local function GetActiveSeason()
    local store = GetStore()
    local id = store.active
    if not id then
        return nil, nil
    end
    local season = store.seasons and store.seasons[id]
    return season, id
end

local function WarnMissingIcons(dungeons)
    if missingIconWarningShown then
        return
    end

    local missing = {}
    for i = 1, #dungeons do
        local dungeon = dungeons[i]
        if not dungeon.icon then
            missing[#missing + 1] = dungeon.name
        end
    end

    if #missing > 0 then
        missingIconWarningShown = true
        Chat.Print("Dungeon header icons are not configured. Run /keyf dumpseason after login, then paste icon values into season-config.lua.")
    end
end

function SeasonDungeons.GetActiveId()
    return GetActiveId()
end

function SeasonDungeons.GetName()
    local season = GetActiveSeason()
    return (season and season.name) or "Unknown Season"
end

function SeasonDungeons.GetAll()
    local season = GetActiveSeason()
    local dungeons = (season and season.dungeons) or {}
    WarnMissingIcons(dungeons)
    return dungeons
end

function SeasonDungeons.GetCount()
    return #SeasonDungeons.GetAll()
end

function SeasonDungeons.GetDungeon(mapChallengeModeID)
    if not mapChallengeModeID then
        return nil
    end

    local dungeons = SeasonDungeons.GetAll()
    for i = 1, #dungeons do
        if dungeons[i].id == mapChallengeModeID then
            return dungeons[i]
        end
    end
    return nil
end

function SeasonDungeons.GetTeleportSpellIDs(mapChallengeModeID, faction)
    local dungeon = SeasonDungeons.GetDungeon(mapChallengeModeID)
    if not dungeon then
        return nil
    end

    local factionTeleports = dungeon.factionTeleports
    if factionTeleports and faction then
        local spellID = factionTeleports[faction]
        if spellID then
            return { spellID }
        end
    end

    return dungeon.teleports
end

function SeasonDungeons.HasTeleportMapping(mapChallengeModeID)
    local spellIDs = SeasonDungeons.GetTeleportSpellIDs(mapChallengeModeID)
    return spellIDs ~= nil and #spellIDs > 0
end

function SeasonDungeons.DumpLiveValues()
    local activeId = GetActiveId()
    Chat.Print(string.format(
        "Season dungeon values for %s (paste into season-config.lua under seasons[%q].dungeons):",
        SeasonDungeons.GetName(),
        activeId or "?"
    ))

    for _, dungeon in ipairs(SeasonDungeons.GetAll()) do
        local info = ChallengeMode.GetMapUIInfo(dungeon.id)
        if info then
            local teleportText = "nil"
            if dungeon.teleports and #dungeon.teleports > 0 then
                teleportText = "{ " .. table.concat(dungeon.teleports, ", ") .. " }"
            end
            print(string.format(
                "  { id = %s, name = %q, short = %q, icon = %s, teleports = %s }, -- api: %s",
                tostring(dungeon.id),
                dungeon.name,
                dungeon.short,
                tostring(info.texture or "nil"),
                teleportText,
                info.name
            ))
        else
            print(string.format(
                "  -- id %s (%s): C_ChallengeMode.GetMapUIInfo returned nothing",
                tostring(dungeon.id),
                dungeon.name
            ))
        end
    end
end

function SeasonDungeons.DumpAllMaps()
    Chat.Print("All MapChallengeMode entries (id, name, icon FileID):")

    for _, mapChallengeModeID in ipairs(ChallengeMode.GetMapTable()) do
        local info = ChallengeMode.GetMapUIInfo(mapChallengeModeID)
        if info and info.name then
            print(string.format(
                "  id = %s, name = %q, icon = %s",
                tostring(mapChallengeModeID),
                info.name,
                tostring(info.texture or "nil")
            ))
        end
    end
end

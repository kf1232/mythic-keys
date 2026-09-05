Key.Data = Key.Data or {}

local SeasonDungeons = {}
Key.Data.SeasonDungeons = SeasonDungeons

local function GetActiveSeason()
    local store = Key.Data.SeasonConfig or {}
    local id = store.active
    if not id or not store.seasons then
        return nil
    end
    return store.seasons[id]
end

function SeasonDungeons.GetName()
    local season = GetActiveSeason()
    return (season and season.name) or "Unknown Season"
end

function SeasonDungeons.GetAll()
    local season = GetActiveSeason()
    return (season and season.dungeons) or {}
end

Key.Data = Key.Data or {}

local Spells = {}
Key.Data.DungeonTeleportSpells = Spells

local SeasonDungeons = Key.Data.SeasonDungeons

function Spells.GetSpellIDs(mapChallengeModeID, faction)
    if SeasonDungeons and SeasonDungeons.GetTeleportSpellIDs then
        return SeasonDungeons.GetTeleportSpellIDs(mapChallengeModeID, faction)
    end
    return nil
end

function Spells.HasMapping(mapChallengeModeID)
    if SeasonDungeons and SeasonDungeons.HasTeleportMapping then
        return SeasonDungeons.HasTeleportMapping(mapChallengeModeID)
    end
    return false
end

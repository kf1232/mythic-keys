local ADDON_NAME = ...

Key.Teleports = Key.Teleports or {}
local Teleports = Key.Teleports

-- Midnight Season 1 M+ pool (MapChallengeMode.ID -> teleport spell)
Teleports.SEASON_DUNGEONS = {
    { challengeModeID = 558, spellID = 1254572, shortName = "Magisters'" },
    { challengeModeID = 560, spellID = 1254559, shortName = "Maisara" },
    { challengeModeID = 559, spellID = 1254563, shortName = "Nexus-Point" },
    { challengeModeID = 557, spellID = 1254400, shortName = "Windrunner" },
    { challengeModeID = 402, spellID = 393273, shortName = "Algeth'ar" },
    { challengeModeID = 556, spellID = 1254555, shortName = "Pit of Saron" },
    { challengeModeID = 239, spellID = 1254551, shortName = "Seat" },
    { challengeModeID = 161, spellID = 159898, shortName = "Skyreach" },
}

Teleports.SLOT_COUNT = #Teleports.SEASON_DUNGEONS

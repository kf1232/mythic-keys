Key.Data = Key.Data or {}

-- Change `active` to switch seasons. All season-scoped data lives under `seasons`.
Key.Data.SeasonConfig = {
    active = "midnight-s2",

    seasons = {
        ["midnight-s1"] = {
            name = "Midnight Season 1",

            -- id = MapChallengeMode.ID. Column order matches party/target views.
            -- teleports = spell IDs to try (first known/unlocked wins).
            -- factionTeleports = optional { Alliance = spellID, Horde = spellID }.
            dungeons = {
                { id = 558, name = "Magisters' Terrace", short = "MAG", icon = 7467178, teleports = { 1255433, 1254572 } },
                { id = 560, name = "Maisara Caverns", short = "MAI", icon = 7478535, teleports = { 1254559 } },
                { id = 559, name = "Nexus-Point Xenas", short = "NEX", icon = 7570495, teleports = { 1254563 } },
                { id = 557, name = "Windrunner Spire", short = "WIN", icon = 7464936, teleports = { 1254400 } },
                { id = 402, name = "Algeth'ar Academy", short = "AA", icon = 4746641, teleports = { 393273 } },
                { id = 556, name = "Pit of Saron", short = "PS", icon = 336391, teleports = { 1254555 } },
                { id = 239, name = "Seat of the Triumvirate", short = "ST", icon = 1718526, teleports = { 1254551 } },
                { id = 161, name = "Skyreach", short = "SKR", icon = 1042064, teleports = { 159898 } },
            },
        },

        ["midnight-s2"] = {
            name = "Midnight Season 2",

            -- Run /keyf dumpseason after login to fill icon FileIDs for dungeons missing icons.
            dungeons = {
                { id = 588, name = "Altar of Fangs", short = "AOF", icon = nil, teleports = { 1286812 } },
                { id = 587, name = "Murder Row", short = "MUR", icon = nil, teleports = { 1286809 } },
                { id = 586, name = "Den of Nalorakk", short = "DEN", icon = nil, teleports = { 1286807 } },
                { id = 584, name = "The Blinding Vale", short = "BLV", icon = nil, teleports = { 1286801 } },
                { id = 585, name = "Voidscar Arena", short = "VSA", icon = nil, teleports = { 1286804 } },
                { id = 176, name = "Kings' Rest", short = "KR", icon = 2011123, teleports = { 1286831 } },
                { id = 399, name = "Ruby Life Pools", short = "RLP", icon = nil, teleports = { 393256 } },
                { id = 247, name = "Temple of Sethraliss", short = "TOS", icon = 2011143, teleports = { 1286828 } },
            },
        },
    },
}

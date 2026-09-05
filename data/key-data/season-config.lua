Key.Data = Key.Data or {}

-- Column layout only. `active` picks which header row to draw.
Key.Data.SeasonConfig = {
    active = "midnight-s2",

    seasons = {
        ["midnight-s1"] = {
            name = "Midnight Season 1",
            dungeons = {
                { name = "Magisters' Terrace", short = "MAG", icon = 7467178 },
                { name = "Maisara Caverns", short = "MAI", icon = 7478535 },
                { name = "Nexus-Point Xenas", short = "NEX", icon = 7570495 },
                { name = "Windrunner Spire", short = "WIN", icon = 7464936 },
                { name = "Algeth'ar Academy", short = "AA", icon = 4746641 },
                { name = "Pit of Saron", short = "PS", icon = 336391 },
                { name = "Seat of the Triumvirate", short = "ST", icon = 1718526 },
                { name = "Skyreach", short = "SKR", icon = 1042064 },
            },
        },

        ["midnight-s2"] = {
            name = "Midnight Season 2",
            dungeons = {
                { name = "Altar of Fangs", short = "AOF", icon = 7956176 },
                { name = "Murder Row", short = "MUR", icon = 7467179 },
                { name = "Den of Nalorakk", short = "DEN", icon = 7478536 },
                { name = "The Blinding Vale", short = "BLV", icon = 7478534 },
                { name = "Voidscar Arena", short = "VSA", icon = 7479112 },
                { name = "Kings' Rest", short = "KR", icon = 2178730 },
                { name = "Ruby Life Pools", short = "RLP", icon = 4746639 },
                { name = "Temple of Sethraliss", short = "TOS", icon = 2178734 },
            },
        },
    },
}

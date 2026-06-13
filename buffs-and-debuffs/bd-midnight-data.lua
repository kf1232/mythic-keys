local ADDON_NAME = ...

Key.AurasData = Key.AurasData or {}

-- Midnight Season 1 flasks, phials, and weapon oils/stones.
-- spellId: player buff aura ID.
-- spellIds / enchantIds: weapon oil apply spells and GetWeaponEnchantInfo IDs (8051–8056).
-- First id in each pair is low craft quality; second is high (gold border in ready UI).
-- itemIds: vendor/craft item IDs (Wowhead); detection uses spell/enchant IDs, not items.
-- iconSpellId: optional; defaults to spellId when resolving icons at load.
-- countsForReady: combat flasks only; phials and the PvP honor flask are excluded.
-- Gold/silver craft quality on flasks is read from aura points via QUALITY_TIERS.
Key.AurasData.midnight = {
    KIND = {
        FOOD = "food",
        FLASK = "flask",
        OIL = "oil",
    },

    QUALITY_TIERS = {
        { id = "high", minPoint = 165, label = "High quality", premiumBorder = true },
        { id = "low", minPoint = 151, label = "Low quality", premiumBorder = false },
    },

    -- Sin'dorei combat flasks (alchemy "Flasks & Phials" list).
    FLASKS = {
        {
            label = "Flask of Thalassian Resistance",
            spellId = 1235057,
            countsForReady = true,
        },
        {
            label = "Flask of the Shattered Sun",
            spellId = 1235111,
            countsForReady = true,
        },
        {
            label = "Flask of the Blood Knights",
            spellId = 1235110,
            countsForReady = true,
        },
        {
            label = "Flask of the Magisters",
            spellId = 1235108,
            countsForReady = true,
        },
        {
            label = "Vicious Thalassian Flask of Honor",
            spellId = 1239355,
            countsForReady = false,
        },
    },

    -- Haranir profession phials (same alchemy tab; not combat flasks).
    PHIALS = {
        {
            label = "Haranir Phial of Finesse",
            spellId = 1236767,
        },
        {
            label = "Haranir Phial of Perception",
            spellId = 1236763,
        },
        {
            label = "Haranir Phial of Ingenuity",
            spellId = 1239755,
        },
    },

    OILS = {
        {
            label = "Thalassian Phoenix Oil",
            itemIds = { 243734 },
            spellIds = { 1237008, 1237006 },
            enchantIds = { 8051, 8052 },
            iconSpellId = 1237006,
        },
        {
            label = "Oil of Dawn",
            itemIds = { 243736 },
            spellIds = { 1237002, 1237001 },
            enchantIds = { 8053, 8054 },
            buffSpellIds = { 1237014 },
            iconSpellId = 1237002,
        },
        {
            label = "Smuggler's Enchanted Edge",
            itemIds = { 243738 },
            spellIds = { 1237004, 1237003 },
            enchantIds = { 8055, 8056 },
            buffSpellIds = { 1237009, 1237012 },
            iconSpellId = 1237003,
        },
        {
            label = "Refulgent Whetstone",
            spellIds = { 1224331, 1224328 },
            iconSpellId = 1224328,
        },
        {
            label = "Refulgent Weightstone",
            spellIds = { 1224332, 1224333 },
            iconSpellId = 1224333,
        },
    },

    CONSUMABLES = {
        flask = {
            kind = "flask",
            classifyPriority = 1,
            defaultLabel = "Flask",
            usesQualityTiers = true,
        },
        oil = {
            kind = "oil",
            classifyPriority = 2,
            defaultLabel = "Oil",
            usesQualityTiers = true,
            premiumTooltip = "High quality",
        },
        food = {
            kind = "food",
            classifyPriority = 3,
            defaultLabel = "Food",
            namePatterns = { "hearty well fed", "hearty well%-fed", "well fed", "well%-fed", "nourishment", "feast" },
            heartyPatterns = { "hearty well fed", "hearty well%-fed" },
            eatingSpellIds = { 192002, 452389 },
            eatingLabel = "Eating",
            eatingIconSpellId = 192002,
            defaultIconSpellIds = { 457284, 462187 },
            heartyIconSpellIds = { 462187, 457284 },
            premiumTooltip = "Hearty — persists through death",
            eatingTooltip = "Eating — not ready yet",
        },
    },
}

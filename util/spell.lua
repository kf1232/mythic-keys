Key.Util = Key.Util or {}

local Spell = {}
Key.Util.Spell = Spell

function Spell.Exists(spellID)
    if not spellID then
        return false
    end
    if C_Spell and C_Spell.GetSpellInfo then
        return C_Spell.GetSpellInfo(spellID) ~= nil
    end
    return _G.GetSpellInfo and _G.GetSpellInfo(spellID) ~= nil
end

function Spell.IsKnown(spellID)
    if not spellID then
        return false
    end
    if C_Spell and C_Spell.IsSpellKnown then
        return C_Spell.IsSpellKnown(spellID)
    end
    return _G.IsSpellKnown and _G.IsSpellKnown(spellID)
end

function Spell.GetName(spellID)
    if not spellID then
        return nil
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end
    return _G.GetSpellInfo and select(1, _G.GetSpellInfo(spellID))
end

function Spell.GetCooldown(spellID)
    if not spellID then
        return 0, 0, false
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime or 0, info.duration or 0, info.isEnabled ~= false
        end
    end

    if GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spellID)
        return start or 0, duration or 0, enabled ~= 0 and enabled ~= false
    end

    return 0, 0, false
end

function Spell.ResolveBestKnown(spellIDs)
    if not spellIDs or #spellIDs == 0 then
        return nil, false
    end

    local firstValid
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        if Spell.Exists(spellID) then
            if Spell.IsKnown(spellID) then
                return spellID, true
            end
            if not firstValid then
                firstValid = spellID
            end
        end
    end

    if firstValid then
        return firstValid, false
    end

    return nil, false
end

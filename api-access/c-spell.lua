local ADDON_NAME = ...

KeyApiCSpell = KeyApiCSpell or {}
local API = KeyApiCSpell

function API:GetSpellInfo(spellId)
    if not spellId or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end
    if issecretvalue and issecretvalue(spellId) then
        return nil
    end

    return C_Spell.GetSpellInfo(spellId)
end

function API:GetIcon(spellId)
    local spellInfo = self:GetSpellInfo(spellId)
    if not spellInfo or not spellInfo.iconID then
        return nil
    end
    if issecretvalue and issecretvalue(spellInfo.iconID) then
        return nil
    end

    return spellInfo.iconID
end

function API:ResolveIcon(spellId)
    return self:GetIcon(spellId)
end

function API:GetSpellName(spellId, displayName)
    local spellInfo = self:GetSpellInfo(spellId)
    if not spellInfo or not spellInfo.name then
        return nil
    end

    if KeyLog and KeyLog.TryDisplayValue then
        local spellName = KeyLog:TryDisplayValue(spellInfo.name)
        if spellName and spellName ~= displayName then
            return spellName
        end
        return nil
    end

    if issecretvalue and issecretvalue(spellInfo.name) then
        return nil
    end

    if spellInfo.name ~= displayName then
        return spellInfo.name
    end

    return nil
end

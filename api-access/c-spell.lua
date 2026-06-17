local ADDON_NAME = ...

Key.Api.Spell = Key.Api.Spell or {}
local API = Key.Api.Spell
local Middleware = Key.Api.Middleware

function API:GetSpellInfo(isSecret, spellId)
    if Middleware:Guard(isSecret, spellId) then
        return nil
    end
    if not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end

    local spellInfo, secret = Middleware:Call(false, C_Spell.GetSpellInfo, spellId)
    if secret then
        return nil
    end

    return spellInfo
end

function API:GetIcon(isSecret, spellId)
    local spellInfo = self:GetSpellInfo(isSecret, spellId)
    if not spellInfo or Middleware:Guard(false, spellInfo.iconID) then
        return nil
    end

    return spellInfo.iconID
end

function API:ResolveIcon(isSecret, spellId)
    return self:GetIcon(isSecret, spellId)
end

function API:GetSpellName(isSecret, spellId, displayName)
    local spellInfo = self:GetSpellInfo(isSecret, spellId)
    if not spellInfo or Middleware:Guard(false, spellInfo.name) then
        return nil
    end

    if Key.Log and Key.Log.TryDisplayValue then
        local spellName = Key.Log:TryDisplayValue(spellInfo.name)
        if spellName and Middleware:IsAccessible(spellName) and spellName ~= displayName then
            return spellName
        end
        return nil
    end

    if spellInfo.name ~= displayName then
        return spellInfo.name
    end

    return nil
end

function API:IsSpellInSpellBook(isSecret, spellID, spellBank)
    if Middleware:Guard(isSecret, spellID) then
        return false
    end
    if not C_SpellBook or not C_SpellBook.IsSpellInSpellBook then
        return false
    end

    local isKnown, secret
    if spellBank ~= nil then
        isKnown, secret = Middleware:Call(false, C_SpellBook.IsSpellInSpellBook, spellID, spellBank)
    else
        isKnown, secret = Middleware:Call(false, C_SpellBook.IsSpellInSpellBook, spellID)
    end

    if secret then
        return false
    end

    return isKnown and true or false
end

function API:IsSpellKnown(isSecret, spellID)
    if Middleware:Guard(isSecret, spellID) then
        return false
    end
    if not C_SpellBook or not C_SpellBook.IsSpellKnown then
        return false
    end

    local isKnown, secret = Middleware:Call(false, C_SpellBook.IsSpellKnown, spellID)
    if secret then
        return false
    end

    return isKnown and true or false
end

function API:GetSpellCooldown(isSecret, spellID)
    if Middleware:Guard(isSecret, spellID) then
        return nil
    end
    if not C_Spell or not C_Spell.GetSpellCooldown then
        return nil
    end

    local cooldown, secret = Middleware:Call(false, C_Spell.GetSpellCooldown, spellID)
    if secret or not cooldown then
        return nil
    end

    return cooldown
end

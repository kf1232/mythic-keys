Key.Util = Key.Util or {}

local ActionButton = {}
Key.Util.ActionButton = ActionButton

local Spell = Key.Util.Spell

function ActionButton.RegisterCastClicks(button)
    if GetCVar and GetCVar("ActionButtonUseKeyDown") == "1" then
        button:RegisterForClicks("LeftButtonDown")
    else
        button:RegisterForClicks("LeftButtonUp")
    end
end

function ActionButton.SetSpellCast(button, spellID)
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", Spell.GetName(spellID) or spellID)
end

function ActionButton.ClearCast(button)
    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
end

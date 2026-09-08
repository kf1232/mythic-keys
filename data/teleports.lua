local _, Key = ...

local TELEPORTS = {
	[584] = 1286801, -- The Blinding Vale
	[585] = 1286804, -- Voidscar Arena
	[586] = 1286807, -- Den of Nalorakk
	[587] = 1286809, -- Murder Row
	[588] = 1286812, -- Altar of Fangs
	[250] = 1286828, -- Temple of Sethraliss
	[249] = 1286831, -- Kings' Rest
	[399] = 393256, -- Ruby Life Pools
}

function Key.GetTeleportSpell(challengeID)
	return TELEPORTS[challengeID]
end

function Key.IsTeleportKnown(challengeID)
	local spellID = TELEPORTS[challengeID]
	return spellID and IsPlayerSpell(spellID) or false
end

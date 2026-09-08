local addonName, Key = ...

Key.addonName = addonName
Key.savedVarName = addonName == "mythic-keys-beta" and "KeyBetaDB" or "KeyDB"

function Key.GetDB()
	local name = Key.savedVarName
	if not name then
		return nil
	end
	local db = _G[name]
	if type(db) ~= "table" then
		db = {}
		_G[name] = db
	end
	return db
end

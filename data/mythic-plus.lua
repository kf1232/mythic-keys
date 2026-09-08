local _, Key = ...

Key.mythicPlus = {
	byUnit = {},
	byPlayer = {},
}

local function shortName(name)
	name = name or "?"
	name = name:match("^([^,]+)") or name
	name = name:gsub("^The ", "")
	if #name > 12 then
		name = name:sub(1, 11) .. "."
	end
	return name
end

local function mapInfo(mapID)
	local name, challengeID, _, icon, bg, instanceMapID = C_ChallengeMode.GetMapUIInfo(mapID)
	name = name or tostring(mapID)
	return {
		id = challengeID or mapID,
		name = name,
		short = shortName(name),
		icon = icon,
		bg = bg,
		mapID = instanceMapID,
	}
end

local function mapName(mapID)
	return mapInfo(mapID).name
end

local function attachByMap(info)
	info.byMap = {}
	for _, run in ipairs(info.runs or {}) do
		if run.mapID then
			info.byMap[run.mapID] = run
		end
	end
	return info
end

local function normalize(summary)
	local info = {
		score = summary and summary.currentSeasonScore or nil,
		runs = {},
		byMap = {},
	}
	if not summary or not summary.runs then
		return attachByMap(info)
	end

	for _, run in ipairs(summary.runs) do
		if run.finishedSuccess and run.bestRunLevel and run.bestRunLevel > 0 then
			info.runs[#info.runs + 1] = {
				mapID = run.challengeModeID,
				name = mapName(run.challengeModeID),
				level = run.bestRunLevel,
				timed = run.finishedSuccess,
				score = run.mapScore,
			}
		end
	end

	table.sort(info.runs, function(a, b)
		if a.level == b.level then
			return (a.score or 0) > (b.score or 0)
		end
		return a.level > b.level
	end)

	return attachByMap(info)
end

local function isValidSummary(summary, unit)
	if type(summary) ~= "table" then
		return false
	end

	local hasRuns = false
	if type(summary.runs) == "table" then
		for _, run in ipairs(summary.runs) do
			if run.finishedSuccess and run.bestRunLevel and run.bestRunLevel > 0 then
				hasRuns = true
				break
			end
		end
	end

	local score = summary.currentSeasonScore
	if UnitIsUnit(unit, "player") then
		return type(score) == "number" or hasRuns
	end

	return hasRuns or (type(score) == "number" and score > 0)
end

local function getDB()
	local name = Key.savedVarName
	if not name then
		return nil
	end
	local db = _G[name]
	if type(db) ~= "table" then
		db = {}
		_G[name] = db
	end
	db.completes = db.completes or {}
	return db
end

local function saveCompletes(playerKey, info)
	local db = getDB()
	if not db or not playerKey then
		return
	end
	db.completes[playerKey] = {
		name = playerKey,
		score = info.score,
		updated = info.updated,
		runs = info.runs,
	}
end

local function isPlayerKey(key)
	return type(key) == "string" and key:find("-") and not key:match("^Player%-")
end

function Key.InitCompletesDB()
	local db = getDB()
	if not db then
		return
	end
	for key, info in pairs(db.completes) do
		local playerKey = key
		if not isPlayerKey(key) and isPlayerKey(info.name) then
			playerKey = info.name
			db.completes[playerKey] = info
			db.completes[key] = nil
		end
		if isPlayerKey(playerKey) then
			info.name = playerKey
			Key.mythicPlus.byPlayer[playerKey] = attachByMap(info)
		end
	end
end

function Key.GetMemberCompletes(member)
	if not member then
		return nil
	end
	return Key.mythicPlus.byUnit[member.unit] or (member.name and Key.mythicPlus.byPlayer[member.name])
end

function Key.GetSeasonMaps()
	local maps = {}
	local seen = {}
	local ids = C_ChallengeMode.GetMapTable()
	if ids then
		for _, id in ipairs(ids) do
			local info = mapInfo(id)
			maps[#maps + 1] = info
			seen[info.id] = true
		end
	end
	if #maps == 0 then
		for _, info in pairs(Key.mythicPlus.byUnit) do
			for _, run in ipairs(info.runs) do
				if not seen[run.mapID] then
					seen[run.mapID] = true
					maps[#maps + 1] = mapInfo(run.mapID)
				end
			end
		end
	end
	return maps
end

function Key.RefreshOwnedKey()
	local challengeID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local level = C_MythicPlus.GetOwnedKeystoneLevel()
	if not challengeID or not level or level < 2 then
		Key.ownedKey = nil
		if Key.BroadcastOwnedKey then
			Key.BroadcastOwnedKey()
		end
		return
	end

	local name, _, _, icon = C_ChallengeMode.GetMapUIInfo(challengeID)
	Key.ownedKey = {
		challengeID = challengeID,
		level = level,
		name = name,
		icon = C_Item.GetItemIconByID(180653) or icon,
	}

	if Key.BroadcastOwnedKey then
		Key.BroadcastOwnedKey()
	end
end

function Key.RefreshMythicPlus(requestMaps)
	if requestMaps then
		C_MythicPlus.RequestMapInfo()
	end

	Key.RefreshOwnedKey()

	wipe(Key.mythicPlus.byUnit)

	for _, member in ipairs(Key.group.members) do
		if UnitExists(member.unit) then
			local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(member.unit)
			if isValidSummary(summary, member.unit) then
				local info = normalize(summary)
				info.name = member.name
				info.updated = time()
				Key.mythicPlus.byUnit[member.unit] = info
				if member.name then
					Key.mythicPlus.byPlayer[member.name] = info
					saveCompletes(member.name, info)
				end
			elseif member.name and Key.mythicPlus.byPlayer[member.name] then
				Key.mythicPlus.byUnit[member.unit] = Key.mythicPlus.byPlayer[member.name]
			end
		end
	end

	if Key.UpdateWindow then
		Key.UpdateWindow()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == Key.addonName then
			Key.InitCompletesDB()
		end
		return
	end
	if event == "BAG_UPDATE_DELAYED" then
		Key.RefreshOwnedKey()
		if Key.UpdateWindow then
			Key.UpdateWindow()
		end
		return
	end
	Key.RefreshMythicPlus(false)
end)

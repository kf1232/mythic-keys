local _, Key = ...

local PREFIX = "Keyf"
local DEBOUNCE_SECONDS = 0.5

Key.keys = {
	byPlayer = {},
}

local function playerKeyFromSender(sender)
	if not sender or sender == "" then
		return nil
	end
	if sender:find("-") then
		return sender
	end
	local realm = GetNormalizedRealmName()
	if not realm or realm == "" then
		return sender
	end
	return sender .. "-" .. realm
end

local function saveKey(playerKey, info)
	local db = Key.GetDB and Key.GetDB()
	if not db or not playerKey then
		return
	end
	db.keys = db.keys or {}
	if info then
		db.keys[playerKey] = {
			name = playerKey,
			challengeID = info.challengeID,
			level = info.level,
			updated = info.updated,
		}
	else
		db.keys[playerKey] = nil
	end
end

local function storeKey(playerKey, challengeID, level)
	if not playerKey then
		return
	end

	challengeID = tonumber(challengeID) or 0
	level = tonumber(level) or 0
	if challengeID < 1 or level < 2 then
		Key.keys.byPlayer[playerKey] = nil
		saveKey(playerKey, nil)
		return
	end

	local name = C_ChallengeMode.GetMapUIInfo(challengeID)
	local info = {
		name = playerKey,
		challengeID = challengeID,
		level = level,
		dungeon = name,
		icon = C_Item.GetItemIconByID(180653),
		updated = time(),
	}
	Key.keys.byPlayer[playerKey] = info
	saveKey(playerKey, info)
	if Key.TouchHistory then
		Key.TouchHistory(playerKey, {
			lastKeyChallengeID = challengeID,
			lastKeyLevel = level,
			lastKeyDungeon = name,
		})
	end
end

function Key.InitKeysDB()
	local db = Key.GetDB and Key.GetDB()
	if not db then
		return
	end
	db.keys = db.keys or {}
	for playerKey, info in pairs(db.keys) do
		if type(playerKey) == "string" and playerKey:find("-") and not playerKey:match("^Player%-") then
			if info and tonumber(info.challengeID) and tonumber(info.level) then
				Key.keys.byPlayer[playerKey] = info
			end
		end
	end
end

function Key.GetMemberKey(member)
	if not member or not member.name then
		return nil
	end
	return Key.keys.byPlayer[member.name]
end

local function channel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end
	if IsInRaid() then
		return "RAID"
	end
	if IsInGroup() then
		return "PARTY"
	end
	return nil
end

local function encodeKey()
	local me = Key.FullPlayerName and Key.FullPlayerName("player")
	if not me then
		return nil
	end
	if not Key.ownedKey then
		return "K\t" .. me .. "\t0\t0"
	end
	return string.format("K\t%s\t%d\t%d", me, Key.ownedKey.challengeID, Key.ownedKey.level)
end

local lastSent

function Key.BroadcastOwnedKey(force)
	local me = Key.FullPlayerName and Key.FullPlayerName("player")
	if me then
		if Key.ownedKey then
			storeKey(me, Key.ownedKey.challengeID, Key.ownedKey.level)
		else
			storeKey(me, 0, 0)
		end
	end

	local target = channel()
	local msg = encodeKey()
	if not target or not msg then
		return
	end
	if not force and lastSent == msg then
		return
	end
	lastSent = msg
	C_ChatInfo.SendAddonMessage(PREFIX, msg, target)
end

function Key.RequestGroupKeys()
	local target = channel()
	if not target then
		Key.BroadcastOwnedKey(true)
		return
	end
	C_ChatInfo.SendAddonMessage(PREFIX, "Q", target)
	Key.BroadcastOwnedKey(true)
end

local function handleMessage(text, sender)
	if text == "Q" then
		Key.BroadcastOwnedKey(true)
		return
	end

	local kind, _, challengeID, level = strsplit("\t", text)
	if kind ~= "K" then
		return
	end

	local playerKey = playerKeyFromSender(sender)
	if not playerKey then
		return
	end
	storeKey(playerKey, challengeID, level)
	if Key.UpdateWindow then
		Key.UpdateWindow()
	end
end

local pending

local function scheduleRequest()
	if pending then
		return
	end
	pending = C_Timer.NewTimer(DEBOUNCE_SECONDS, function()
		pending = nil
		Key.RequestGroupKeys()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name == Key.addonName then
			C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
			Key.InitKeysDB()
		end
		return
	end
	if event == "CHAT_MSG_ADDON" then
		local prefix, text, _, sender = ...
		if prefix == PREFIX and text and sender then
			handleMessage(text, sender)
		end
		return
	end
	scheduleRequest()
end)

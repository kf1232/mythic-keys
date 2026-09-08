local _, Key = ...

local SEEN_GAP = 30 * 60
local REJOIN_GAP = 60

Key.history = {
	byPlayer = {},
}

local lastRoster = {}
local activeRun

local function isPlayerKey(key)
	return type(key) == "string" and key:find("-") and not key:match("^Player%-")
end

local function playerSelf()
	return Key.FullPlayerName and Key.FullPlayerName("player")
end

local function isSelf(playerKey)
	local me = playerSelf()
	return me and playerKey == me
end

function Key.IsHistoryEnabled()
	return not IsInRaid()
end

local function getDB()
	local db = Key.GetDB and Key.GetDB()
	if not db then
		return nil
	end
	db.history = db.history or {}
	return db
end

local function copyRecord(info)
	if type(info) ~= "table" then
		return nil
	end
	local copy = {}
	for k, v in pairs(info) do
		if type(v) ~= "table" then
			copy[k] = v
		end
	end
	return copy
end

local function persist(playerKey, entry)
	local db = getDB()
	if not db or not playerKey then
		return
	end
	db.history[playerKey] = entry
end

local function refreshWindow()
	if Key.UpdateHistoryWindow then
		Key.UpdateHistoryWindow()
	end
end

local function currentOpen(entry)
	local list = entry and entry.interactions
	local last = list and list[#list]
	if last and last.open then
		return last
	end
	return nil
end

local function betterComplete(new, old)
	if not new then
		return old
	end
	if not old then
		return new
	end
	if (new.level or 0) ~= (old.level or 0) then
		return (new.level or 0) > (old.level or 0) and new or old
	end
	return (new.score or 0) >= (old.score or 0) and new or old
end

local function bestCompleteFrom(completes)
	local run = completes and completes.runs and completes.runs[1]
	if not run or not run.level then
		return nil
	end
	return {
		challengeID = run.mapID,
		dungeon = run.name,
		level = run.level,
		score = run.score,
	}
end

local function reportedKeyFrom(key)
	if not key or not key.challengeID or not key.level then
		return nil
	end
	return {
		challengeID = key.challengeID,
		dungeon = key.dungeon or key.name or C_ChallengeMode.GetMapUIInfo(key.challengeID),
		level = key.level,
	}
end

local function formatKey(info)
	if not info or not info.level then
		return nil
	end
	local name = info.dungeon or info.name
	if not name and info.challengeID then
		name = C_ChallengeMode.GetMapUIInfo(info.challengeID)
	end
	if not name then
		return "+" .. info.level
	end
	return name .. " +" .. info.level
end

local function makeCompletedKey(challengeID, level, success)
	challengeID = tonumber(challengeID)
	level = tonumber(level)
	if not challengeID or challengeID < 1 or not level or level < 2 then
		return nil
	end
	return {
		challengeID = challengeID,
		dungeon = C_ChallengeMode.GetMapUIInfo(challengeID),
		level = level,
		success = success and true or false,
	}
end

local function isCapturedRun(info)
	return info and info.challengeID and info.level and (info.edited or info.success == true or info.success == false)
end

local function latestCompletedKey(entry)
	if not entry then
		return nil
	end
	for i = #(entry.interactions or {}), 1, -1 do
		local keyDone = entry.interactions[i].keyDone
		if isCapturedRun(keyDone) then
			return copyRecord(keyDone), i
		end
	end
	if isCapturedRun(entry.completedKey) then
		return copyRecord(entry.completedKey)
	end
end

local function refreshCompletedKey(entry)
	local keyDone = latestCompletedKey(entry)
	entry.completedKey = keyDone
	return keyDone
end

local function isChallengeActive()
	if C_ChallengeMode.IsChallengeModeActive then
		return C_ChallengeMode.IsChallengeModeActive() and true or false
	end
	local mapID = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
	return type(mapID) == "number" and mapID > 0
end

local function rememberRunMember(playerKey)
	if not activeRun or not playerKey or isSelf(playerKey) then
		return
	end
	if activeRun.completed or activeRun.reset then
		return
	end
	activeRun.members = activeRun.members or {}
	activeRun.members[playerKey] = true
end

local function snapshotLive(entry, interaction)
	interaction.score = entry.lastScore
	interaction.bestComplete = copyRecord(entry.bestComplete)
	interaction.reportedKey = copyRecord(entry.reportedKey)
end

local function ensureOpen(entry)
	local open = currentOpen(entry)
	if open then
		return open
	end

	entry.interactions = entry.interactions or {}
	local last = entry.interactions[#entry.interactions]
	local now = time()
	if last and last.ended and now - last.ended < REJOIN_GAP then
		last.open = true
		last.ended = nil
		return last
	end

	open = {
		time = now,
		open = true,
	}
	entry.interactions[#entry.interactions + 1] = open
	return open
end

local function ensureEntry(playerKey)
	if not isPlayerKey(playerKey) or isSelf(playerKey) then
		return nil
	end
	local now = time()
	local entry = Key.history.byPlayer[playerKey]
	if not entry then
		entry = {
			name = playerKey,
			playerName = playerKey:match("^([^-]+)") or playerKey,
			firstSeen = now,
			lastSeen = now,
			seenCount = 1,
			interactions = {},
		}
		Key.history.byPlayer[playerKey] = entry
	end
	return entry
end

local function nameMatches(full, short)
	if not full or not short then
		return false
	end
	if full == short then
		return true
	end
	return full:sub(1, #short + 1) == short .. "-"
end

local function resolvePlayerKey(name, guid)
	if guid then
		for _, member in ipairs(Key.group.members) do
			if member.guid == guid and member.name and not isSelf(member.name) then
				return member.name
			end
		end
	end
	if type(name) ~= "string" or name == "" or isSelf(name) then
		return nil
	end
	if isPlayerKey(name) then
		return name
	end
	for _, member in ipairs(Key.group.members) do
		if member.name and not isSelf(member.name) and (member.playerName == name or nameMatches(member.name, name)) then
			return member.name
		end
	end
	for playerKey, entry in pairs(Key.history.byPlayer) do
		if entry.playerName == name or nameMatches(playerKey, name) then
			return playerKey
		end
	end
	return nil
end

function Key.InitHistoryDB()
	local db = getDB()
	if not db then
		return
	end
	for playerKey, entry in pairs(db.history) do
		if isPlayerKey(playerKey) then
			entry.name = playerKey
			entry.interactions = entry.interactions or {}
			refreshCompletedKey(entry)
			Key.history.byPlayer[playerKey] = entry
		end
	end
end

function Key.GetHistory()
	local list = {}
	for _, entry in pairs(Key.history.byPlayer) do
		list[#list + 1] = entry
	end
	table.sort(list, function(a, b)
		return (a.lastSeen or 0) > (b.lastSeen or 0)
	end)
	return list
end

function Key.GetHistoryEntry(playerKey)
	return playerKey and Key.history.byPlayer[playerKey] or nil
end

function Key.GetHistoryCompletedKey(entry)
	local keyDone = latestCompletedKey(entry)
	return keyDone
end

function Key.CountHistoryVotes(entry)
	local up, down = 0, 0
	for _, interaction in ipairs(entry and entry.interactions or {}) do
		if interaction.vote == "up" then
			up = up + 1
		elseif interaction.vote == "down" then
			down = down + 1
		end
	end
	return up, down
end

function Key.FormatHistoryKey(info)
	return formatKey(info)
end

function Key.TouchHistory(playerKey, fields)
	if not Key.IsHistoryEnabled() then
		return
	end
	if not isPlayerKey(playerKey) or isSelf(playerKey) then
		return
	end

	local now = time()
	local entry = ensureEntry(playerKey)
	if not entry then
		return
	end
	if now - (entry.lastSeen or 0) > SEEN_GAP and entry.lastSeen then
		entry.seenCount = (entry.seenCount or 1) + 1
	end

	entry.lastSeen = now
	fields = fields or {}
	if fields.playerName then
		entry.playerName = fields.playerName
	end
	if fields.class then
		entry.class = fields.class
	end
	if fields.classFile then
		entry.classFile = fields.classFile
	end
	if type(fields.lastScore) == "number" then
		entry.lastScore = fields.lastScore
	end
	if fields.bestComplete then
		entry.bestComplete = betterComplete(copyRecord(fields.bestComplete), entry.bestComplete)
	end
	if fields.reportedKey and fields.reportedKey.challengeID and fields.reportedKey.level then
		entry.reportedKey = copyRecord(fields.reportedKey)
	elseif fields.lastKeyChallengeID and fields.lastKeyLevel then
		entry.reportedKey = {
			challengeID = fields.lastKeyChallengeID,
			dungeon = fields.lastKeyDungeon,
			level = fields.lastKeyLevel,
		}
	end

	if isChallengeActive() then
		rememberRunMember(playerKey)
	end
	local open = ensureOpen(entry)
	snapshotLive(entry, open)
	persist(playerKey, entry)
	refreshWindow()
end

function Key.CloseInteraction(playerKey)
	local entry = Key.history.byPlayer[playerKey]
	if not entry then
		return
	end

	local interaction = currentOpen(entry)
	if not interaction then
		return
	end

	interaction.open = nil
	interaction.ended = time()
	snapshotLive(entry, interaction)
	persist(playerKey, entry)
	refreshWindow()
end

function Key.AddHistoryVote(playerKey, vote, note)
	local entry = Key.history.byPlayer[playerKey]
	if not entry then
		return
	end

	note = note and strtrim(note) or ""
	if note == "" then
		note = nil
	end
	if vote ~= "up" and vote ~= "down" then
		vote = nil
	end
	if not vote and not note then
		return
	end

	local interaction = currentOpen(entry) or (entry.interactions and entry.interactions[#entry.interactions])
	local now = time()
	if interaction and (interaction.open or not interaction.vote or (now - (interaction.ended or interaction.time or 0) < REJOIN_GAP)) then
		if vote then
			interaction.vote = vote
		end
		if note then
			interaction.note = note
		end
		if not interaction.open then
			interaction.ended = now
		end
	else
		interaction = {
			time = now,
			vote = vote,
			note = note,
		}
		if currentOpen(entry) then
			interaction.open = true
		end
		entry.interactions = entry.interactions or {}
		entry.interactions[#entry.interactions + 1] = interaction
	end

	snapshotLive(entry, interaction)
	persist(playerKey, entry)
	refreshWindow()
end

function Key.ApplyCompletedKey(playerKey, keyDone)
	if not Key.IsHistoryEnabled() then
		return
	end
	keyDone = copyRecord(keyDone)
	if not keyDone or not keyDone.challengeID or not keyDone.level then
		return
	end
	local entry = ensureEntry(playerKey)
	if not entry then
		return
	end

	local interaction = currentOpen(entry)
	if not interaction then
		interaction = {
			time = time(),
		}
		entry.interactions = entry.interactions or {}
		entry.interactions[#entry.interactions + 1] = interaction
	end
	interaction.keyDone = keyDone
	entry.completedKey = copyRecord(keyDone)
	entry.lastSeen = time()
	persist(playerKey, entry)
	refreshWindow()
end

function Key.SetHistoryInteractionKey(playerKey, index, challengeID, level)
	local entry = Key.history.byPlayer[playerKey]
	if not entry then
		return
	end
	entry.interactions = entry.interactions or {}
	if not index or not entry.interactions[index] then
		index = #entry.interactions
		if index == 0 then
			entry.interactions[1] = { time = time() }
			index = 1
		end
	end
	local interaction = entry.interactions[index]
	local keyDone = makeCompletedKey(challengeID, level, true)
	interaction.keyDone = keyDone
	if keyDone then
		keyDone.edited = true
	end
	refreshCompletedKey(entry)
	persist(playerKey, entry)
	refreshWindow()
end

function Key.DeleteHistoryInteraction(playerKey, index)
	local entry = Key.history.byPlayer[playerKey]
	if not entry or not entry.interactions or not entry.interactions[index] then
		return
	end
	table.remove(entry.interactions, index)
	refreshCompletedKey(entry)
	persist(playerKey, entry)
	refreshWindow()
end

function Key.DeleteHistoryEntry(playerKey)
	if not playerKey then
		return
	end
	Key.history.byPlayer[playerKey] = nil
	local db = getDB()
	if db and db.history then
		db.history[playerKey] = nil
	end
	refreshWindow()
end

function Key.RecordGroupHistory()
	if IsInRaid() then
		for playerKey in pairs(lastRoster) do
			Key.CloseInteraction(playerKey)
		end
		for playerKey, entry in pairs(Key.history.byPlayer) do
			if currentOpen(entry) then
				Key.CloseInteraction(playerKey)
			end
		end
		lastRoster = {}
		activeRun = nil
		return
	end

	local current = {}
	if IsInGroup() then
		if isChallengeActive() and not activeRun then
			Key.SnapshotActiveRun()
		end

		for _, member in ipairs(Key.group.members) do
			if member.name and member.unit ~= "player" and not UnitIsUnit(member.unit, "player") then
				current[member.name] = true
				if isChallengeActive() then
					rememberRunMember(member.name)
				end
				local completes = Key.GetMemberCompletes and Key.GetMemberCompletes(member)
				local key = Key.GetMemberKey and Key.GetMemberKey(member)
				local fields = {
					playerName = member.playerName,
					class = member.class,
					classFile = member.classFile,
					bestComplete = bestCompleteFrom(completes),
					reportedKey = reportedKeyFrom(key),
				}
				if completes and type(completes.score) == "number" then
					fields.lastScore = completes.score
				end
				Key.TouchHistory(member.name, fields)
			end
		end
	end

	for playerKey in pairs(lastRoster) do
		if not current[playerKey] then
			Key.CloseInteraction(playerKey)
		end
	end
	for playerKey, entry in pairs(Key.history.byPlayer) do
		if currentOpen(entry) and not current[playerKey] then
			Key.CloseInteraction(playerKey)
		end
	end
	lastRoster = current
end

function Key.SnapshotActiveRun()
	if not Key.IsHistoryEnabled() or not isChallengeActive() then
		return
	end

	local mapID = C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
	if type(mapID) ~= "number" or mapID < 1 then
		return
	end

	local level
	if C_ChallengeMode.GetActiveKeystoneLevel then
		local activeLevel = C_ChallengeMode.GetActiveKeystoneLevel()
		if type(activeLevel) == "number" and activeLevel >= 2 then
			level = activeLevel
		end
	end
	if not level and C_ChallengeMode.GetSlottedKeystoneInfo then
		local _, _, slottedLevel = C_ChallengeMode.GetSlottedKeystoneInfo()
		if type(slottedLevel) == "number" and slottedLevel >= 2 then
			level = slottedLevel
		end
	end

	local members = (activeRun and not activeRun.completed and activeRun.members) or {}
	for _, member in ipairs(Key.group.members) do
		if member.name and member.unit ~= "player" and not UnitIsUnit(member.unit, "player") then
			members[member.name] = true
		end
	end

	activeRun = {
		mapID = mapID,
		level = level or (activeRun and activeRun.level),
		name = C_ChallengeMode.GetMapUIInfo(mapID),
		members = members,
		started = (activeRun and activeRun.started) or time(),
	}
end

function Key.CompleteActiveRun()
	if not Key.IsHistoryEnabled() then
		return
	end
	local info = { C_ChallengeMode.GetCompletionInfo() }
	local mapID, level, onTime = info[1], info[2], info[4]
	local keyDone = makeCompletedKey(mapID, level, onTime)
	if not keyDone then
		return
	end

	local members
	for i = #info, 1, -1 do
		local value = info[i]
		if type(value) == "table" and value[1] and type(value[1]) ~= "number" then
			members = value
			break
		end
	end

	local targets = {}
	if members then
		for _, memberInfo in ipairs(members) do
			local name, guid
			if type(memberInfo) == "table" then
				name = memberInfo.name or memberInfo.memberName
				guid = memberInfo.memberGUID or memberInfo.guid
			elseif type(memberInfo) == "string" then
				name = memberInfo
			end
			local playerKey = resolvePlayerKey(name, guid)
			if playerKey then
				targets[playerKey] = true
			end
		end
	end

	if not next(targets) then
		for _, member in ipairs(Key.group.members) do
			if member.name and member.unit ~= "player" and not UnitIsUnit(member.unit, "player") then
				targets[member.name] = true
			end
		end
	end

	activeRun = activeRun or { members = {} }
	activeRun.mapID = keyDone.challengeID
	activeRun.level = keyDone.level
	activeRun.name = keyDone.dungeon
	activeRun.success = keyDone.success
	activeRun.completed = time()

	for playerKey in pairs(targets) do
		Key.ApplyCompletedKey(playerKey, keyDone)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("CHALLENGE_MODE_START")
events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
events:RegisterEvent("CHALLENGE_MODE_RESET")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == Key.addonName then
			Key.InitHistoryDB()
		end
		return
	end
	if event == "CHALLENGE_MODE_START" then
		activeRun = nil
		Key.SnapshotActiveRun()
		return
	end
	if event == "CHALLENGE_MODE_COMPLETED" then
		Key.CompleteActiveRun()
		return
	end
	if activeRun and not activeRun.completed then
		activeRun.reset = time()
	end
end)

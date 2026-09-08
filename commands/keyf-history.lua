local addonName, Key = ...

local ROW_HEIGHT = 24
local CLASS_ICON_SIZE = 16
local COLUMNS = {
	{ key = "name", label = "Player", x = 26, width = 160 },
	{ key = "score", label = "Score", x = 190, width = 52 },
	{ key = "key", label = "Ran", x = 246, width = 200 },
	{ key = "votes", label = " + / - ", x = 454, width = 80 },
	{ key = "seen", label = "Last seen", x = 542, width = 140 },
}

local menu = CreateFrame("Frame", "KeyfHistoryMenu", UIParent, "BasicFrameTemplateWithInset")
menu:SetSize(840, 620)
menu:SetPoint("CENTER", -40, 40)
menu:SetFrameStrata("HIGH")
menu:SetMovable(true)
menu:EnableMouse(true)
menu:RegisterForDrag("LeftButton")
menu:SetScript("OnDragStart", menu.StartMoving)
menu:SetScript("OnDragStop", menu.StopMovingOrSizing)
menu:Hide()
tinsert(UISpecialFrames, "KeyfHistoryMenu")

local title = C_AddOns.GetAddOnMetadata(addonName, "Title") or "Mythic Keys"
menu.TitleText:SetText(title .. " History")

local status = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
status:SetPoint("TOPLEFT", 16, -36)
status:SetPoint("TOPRIGHT", -16, -36)
status:SetJustifyH("LEFT")

local listBox = CreateFrame("Frame", nil, menu, "BackdropTemplate")
listBox:SetPoint("TOPLEFT", 14, -58)
listBox:SetPoint("BOTTOMRIGHT", -14, 248)
listBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
listBox:SetBackdropColor(0, 0, 0, 0.8)

local headerBar = CreateFrame("Frame", nil, listBox)
headerBar:SetPoint("TOPLEFT", 8, -6)
headerBar:SetPoint("TOPRIGHT", -28, -6)
headerBar:SetHeight(16)

for _, col in ipairs(COLUMNS) do
	local label = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", col.x, 0)
	label:SetWidth(col.width)
	label:SetJustifyH("LEFT")
	label:SetText(col.label)
	label:SetTextColor(1, 0.82, 0)
end

local scroll = CreateFrame("ScrollFrame", "KeyfHistoryScroll", listBox, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 8, -26)
scroll:SetPoint("BOTTOMRIGHT", -28, 8)

local list = CreateFrame("Frame", nil, scroll)
list:SetPoint("TOPLEFT")
list:SetSize(1, 1)
scroll:SetScrollChild(list)

local detail = CreateFrame("Frame", nil, menu, "BackdropTemplate")
detail:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 0, -8)
detail:SetPoint("BOTTOMRIGHT", -14, 14)
detail:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
detail:SetBackdropColor(0, 0, 0, 0.8)

local detailTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detailTitle:SetPoint("TOPLEFT", 10, -10)
detailTitle:SetPoint("TOPRIGHT", -90, -10)
detailTitle:SetJustifyH("LEFT")
detailTitle:SetText("Select a player to rate or add a note.")

local removeBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
removeBtn:SetSize(72, 20)
removeBtn:SetPoint("TOPRIGHT", -8, -6)
removeBtn:SetText("Remove")

local detailLog = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailLog:SetPoint("TOPLEFT", 10, -30)
detailLog:SetPoint("TOPRIGHT", -10, -30)
detailLog:SetJustifyH("LEFT")
detailLog:SetWordWrap(true)

local interactionList = CreateFrame("Frame", nil, detail)
interactionList:SetPoint("TOPLEFT", 8, -28)
interactionList:SetPoint("TOPRIGHT", -8, -28)
interactionList:SetHeight(78)

local mapBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
mapBtn:SetSize(168, 22)
mapBtn:SetPoint("BOTTOMLEFT", 10, 40)
mapBtn:SetText("Dungeon")

local levelBox = CreateFrame("EditBox", "KeyfHistoryLevelBox", detail, "InputBoxTemplate")
levelBox:SetAutoFocus(false)
levelBox:SetNumeric(true)
levelBox:SetMaxLetters(2)
levelBox:SetSize(36, 20)
levelBox:SetPoint("LEFT", mapBtn, "RIGHT", 8, 0)

local noteBox = CreateFrame("EditBox", "KeyfHistoryNoteBox", detail, "InputBoxTemplate")
noteBox:SetAutoFocus(false)
noteBox:SetMaxLetters(180)
noteBox:SetHeight(20)
noteBox:SetPoint("BOTTOMLEFT", 12, 12)
noteBox:SetPoint("BOTTOMRIGHT", -168, 12)
noteBox:SetText("")

local selectedKey
local selectedInteractionIndex
local selectedMapID
local pendingDeleteKey
local lastDetailToken
local interactionRows = {}

local function classColor(classFile)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local function mapByID(challengeID)
	if not challengeID then
		return nil
	end
	for _, map in ipairs(Key.GetSeasonMaps and Key.GetSeasonMaps() or {}) do
		if map.id == challengeID then
			return map
		end
	end
	local name = C_ChallengeMode.GetMapUIInfo(challengeID)
	if not name then
		return nil
	end
	return { id = challengeID, name = name, short = name }
end

local function setMapSelection(challengeID)
	selectedMapID = challengeID
	local map = mapByID(challengeID)
	mapBtn:SetText(map and (map.short or map.name) or "Dungeon")
end

local function pickDungeon()
	local maps = Key.GetSeasonMaps and Key.GetSeasonMaps() or {}
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(mapBtn, function(_, root)
			for _, map in ipairs(maps) do
				root:CreateButton(map.name, function()
					setMapSelection(map.id)
				end)
			end
		end)
		return
	end
	local menu = {}
	for _, map in ipairs(maps) do
		menu[#menu + 1] = {
			text = map.name,
			func = function()
				setMapSelection(map.id)
			end,
		}
	end
	if not KeyfHistoryMapMenu then
		CreateFrame("Frame", "KeyfHistoryMapMenu", UIParent, "UIDropDownMenuTemplate")
	end
	EasyMenu(menu, KeyfHistoryMapMenu, mapBtn, 0, 0, "MENU")
end

mapBtn:SetScript("OnClick", pickDungeon)

local function saveNote(vote)
	if not selectedKey then
		return
	end
	Key.AddHistoryVote(selectedKey, vote, noteBox:GetText())
	noteBox:SetText("")
	noteBox:ClearFocus()
end

local function saveCapturedKey()
	if not selectedKey then
		return
	end
	local level = tonumber(levelBox:GetText())
	if not selectedMapID or not level then
		return
	end
	Key.SetHistoryInteractionKey(selectedKey, selectedInteractionIndex, selectedMapID, level)
end

local function clearCapturedKey()
	if not selectedKey then
		return
	end
	Key.SetHistoryInteractionKey(selectedKey, selectedInteractionIndex, nil, nil)
	setMapSelection(nil)
	levelBox:SetText("")
end

local function deleteCapturedRecord()
	if not selectedKey then
		return
	end
	if selectedInteractionIndex then
		Key.DeleteHistoryInteraction(selectedKey, selectedInteractionIndex)
		selectedInteractionIndex = nil
		return
	end
	pendingDeleteKey = selectedKey
	StaticPopup_Show("KEYF_DELETE_HISTORY", Key.GetHistoryEntry(selectedKey).playerName or selectedKey)
end

local saveKeyBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
saveKeyBtn:SetSize(48, 22)
saveKeyBtn:SetPoint("LEFT", levelBox, "RIGHT", 6, 0)
saveKeyBtn:SetText("Save")
saveKeyBtn:SetScript("OnClick", saveCapturedKey)

local clearKeyBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
clearKeyBtn:SetSize(48, 22)
clearKeyBtn:SetPoint("LEFT", saveKeyBtn, "RIGHT", 4, 0)
clearKeyBtn:SetText("Clear")
clearKeyBtn:SetScript("OnClick", clearCapturedKey)

local deleteBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
deleteBtn:SetSize(56, 22)
deleteBtn:SetPoint("LEFT", clearKeyBtn, "RIGHT", 4, 0)
deleteBtn:SetText("Delete")
deleteBtn:SetScript("OnClick", deleteCapturedRecord)

local upBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
upBtn:SetSize(44, 22)
upBtn:SetPoint("BOTTOMRIGHT", -108, 10)
upBtn:SetText("(+)")
upBtn:SetScript("OnClick", function()
	saveNote("up")
end)

local downBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
downBtn:SetSize(44, 22)
downBtn:SetPoint("BOTTOMRIGHT", -60, 10)
downBtn:SetText("(-)")
downBtn:SetScript("OnClick", function()
	saveNote("down")
end)

local saveBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
saveBtn:SetSize(44, 22)
saveBtn:SetPoint("BOTTOMRIGHT", -8, 10)
saveBtn:SetText("Note")
saveBtn:SetScript("OnClick", function()
	saveNote(nil)
end)

StaticPopupDialogs["KEYF_DELETE_HISTORY"] = {
	text = "Remove %s from history?",
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		if pendingDeleteKey then
			Key.DeleteHistoryEntry(pendingDeleteKey)
			if selectedKey == pendingDeleteKey then
				selectedKey = nil
				selectedInteractionIndex = nil
			end
			pendingDeleteKey = nil
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

removeBtn:SetScript("OnClick", function()
	if not selectedKey then
		return
	end
	local entry = Key.GetHistoryEntry(selectedKey)
	pendingDeleteKey = selectedKey
	StaticPopup_Show("KEYF_DELETE_HISTORY", entry and (entry.playerName or entry.name) or selectedKey)
end)

local rows = {}

local function acquireRow(index)
	local row = rows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, list)
	row:SetHeight(ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp")
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	if index % 2 == 0 then
		row.bg:SetColorTexture(1, 1, 1, 0.04)
	else
		row.bg:SetColorTexture(1, 1, 1, 0)
	end

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
	row.icon:SetPoint("LEFT", 4, 0)

	for _, col in ipairs(COLUMNS) do
		local cell = row:CreateFontString(nil, "OVERLAY", col.key == "name" and "GameFontHighlight" or "GameFontNormal")
		cell:SetPoint("LEFT", col.x, 0)
		cell:SetWidth(col.width)
		cell:SetJustifyH("LEFT")
		cell:SetWordWrap(false)
		cell:SetMaxLines(1)
		row[col.key] = cell
	end
	row.score:SetTextColor(1, 0.82, 0)
	row.seen:SetTextColor(0.75, 0.75, 0.75)

	row:SetScript("OnClick", function(self)
		if selectedKey ~= self.playerKey then
			selectedInteractionIndex = nil
			lastDetailToken = nil
		end
		selectedKey = self.playerKey
		Key.UpdateHistoryWindow()
	end)

	rows[index] = row
	return row
end

local function acquireInteractionRow(index)
	local row = interactionRows[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, interactionList)
	row:SetHeight(18)
	row:RegisterForClicks("LeftButtonUp")
	row.bg = row:CreateTexture(nil, "BACKGROUND")
	row.bg:SetAllPoints()
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.label:SetPoint("LEFT", 4, 0)
	row.label:SetPoint("RIGHT", -4, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.label:SetMaxLines(1)
	row:SetScript("OnClick", function(self)
		selectedInteractionIndex = self.index
		lastDetailToken = nil
		Key.UpdateHistoryWindow()
	end)
	interactionRows[index] = row
	return row
end

local function interactionLine(interaction)
	local when = interaction.ended or interaction.time
	local stamp = when and date("%m-%d %H:%M", when) or "—"
	local vote = interaction.vote == "up" and "(+)" or interaction.vote == "down" and "(-)" or "—"
	local key = (interaction.keyDone and (interaction.keyDone.edited or interaction.keyDone.success == true or interaction.keyDone.success == false)) and Key.FormatHistoryKey(interaction.keyDone) or "—"
	local note = interaction.note and interaction.note ~= "" and interaction.note or ""
	if note ~= "" then
		return stamp .. "  " .. vote .. "  " .. key .. "  " .. note
	end
	return stamp .. "  " .. vote .. "  " .. key
end

local function setEditorEnabled(enabled)
	local method = enabled and "Enable" or "Disable"
	noteBox[method](noteBox)
	upBtn[method](upBtn)
	downBtn[method](downBtn)
	saveBtn[method](saveBtn)
	mapBtn[method](mapBtn)
	levelBox[method](levelBox)
	saveKeyBtn[method](saveKeyBtn)
	clearKeyBtn[method](clearKeyBtn)
	deleteBtn[method](deleteBtn)
	removeBtn[method](removeBtn)
end

local function setDetail(entry)
	if not entry then
		detailTitle:SetText("Select a player to rate or edit a completed key.")
		detailTitle:SetTextColor(1, 0.82, 0)
		detailLog:Show()
		detailLog:SetText("The Ran column is the key finished with you. Click a record to edit or delete it.")
		setEditorEnabled(false)
		setMapSelection(nil)
		levelBox:SetText("")
		for _, row in ipairs(interactionRows) do
			row:Hide()
		end
		lastDetailToken = nil
		return
	end

	setEditorEnabled(true)
	local name = entry.playerName or entry.name or "?"
	detailTitle:SetText(name)
	detailTitle:SetTextColor(classColor(entry.classFile))

	local interactions = entry.interactions or {}
	if not selectedInteractionIndex or not interactions[selectedInteractionIndex] then
		selectedInteractionIndex = #interactions > 0 and #interactions or nil
	end

	local start = math.max(1, #interactions - 3)
	local shown = 0
	for i = #interactions, start, -1 do
		shown = shown + 1
		local row = acquireInteractionRow(shown)
		row.index = i
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(shown - 1) * 18)
		row:SetPoint("TOPRIGHT", 0, -(shown - 1) * 18)
		row.label:SetText(interactionLine(interactions[i]))
		if i == selectedInteractionIndex then
			row.bg:SetColorTexture(0.2, 0.45, 0.9, 0.28)
		else
			row.bg:SetColorTexture(1, 1, 1, shown % 2 == 0 and 0.04 or 0)
		end
		row:Show()
	end
	for i = shown + 1, #interactionRows do
		interactionRows[i]:Hide()
	end

	if shown == 0 then
		detailLog:Show()
		detailLog:SetText("No group records yet. A completed key is saved when you finish a dungeon with them.")
	else
		detailLog:Hide()
	end

	local token = entry.name .. ":" .. tostring(selectedInteractionIndex)
	if token ~= lastDetailToken then
		local interaction = selectedInteractionIndex and interactions[selectedInteractionIndex]
		local keyDone = interaction and interaction.keyDone
		setMapSelection(keyDone and keyDone.challengeID)
		levelBox:SetText(keyDone and keyDone.level and tostring(keyDone.level) or "")
		lastDetailToken = token
	end
end

function Key.UpdateHistoryWindow()
	if not menu:IsShown() then
		return
	end

	local history = Key.GetHistory and Key.GetHistory() or {}
	status:SetText(#history .. " grouped players")

	local width = math.max(scroll:GetWidth(), 740)
	list:SetWidth(width)

	if selectedKey and not Key.GetHistoryEntry(selectedKey) then
		selectedKey = nil
		selectedInteractionIndex = nil
		lastDetailToken = nil
	end

	for i, entry in ipairs(history) do
		local row = acquireRow(i)
		row.playerKey = entry.name
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
		row:Show()

		if selectedKey == entry.name then
			row.bg:SetColorTexture(0.2, 0.45, 0.9, 0.28)
		elseif i % 2 == 0 then
			row.bg:SetColorTexture(1, 1, 1, 0.04)
		else
			row.bg:SetColorTexture(1, 1, 1, 0)
		end

		if entry.classFile then
			row.icon:SetAtlas("classicon-" .. strlower(entry.classFile))
			row.icon:Show()
		else
			row.icon:Hide()
		end

		row.name:SetText(entry.playerName or entry.name or "?")
		row.name:SetTextColor(classColor(entry.classFile))
		row.score:SetText(entry.lastScore and tostring(entry.lastScore) or "—")
		row.key:SetText(Key.FormatHistoryKey(Key.GetHistoryCompletedKey(entry)) or "—")

		local up, down = Key.CountHistoryVotes(entry)
		row.votes:SetText(up .. " / " .. down)
		row.votes:SetTextColor(0.75, 0.85, 0.75)

		local seen = "—"
		if entry.lastSeen then
			seen = date("%m-%d %H:%M", entry.lastSeen)
			if entry.seenCount and entry.seenCount > 1 then
				seen = seen .. "  x" .. entry.seenCount
			end
		end
		row.seen:SetText(seen)
	end

	for i = #history + 1, #rows do
		rows[i]:Hide()
	end

	list:SetHeight(math.max(#history * ROW_HEIGHT, 1))
	scroll:UpdateScrollChildRect()
	setDetail(selectedKey and Key.GetHistoryEntry(selectedKey))
end

function Key.ShowHistoryWindow()
	menu:Show()
	Key.UpdateHistoryWindow()
end

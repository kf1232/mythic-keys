local addonName, Key = ...

local COL_NAME = 240
local ICON_SIZE = 100
local ICON_MARGIN = 5
local CLASS_ICON_SIZE = 16
local CLASS_BORDER = 2
local CLASS_SLOT = CLASS_ICON_SIZE + CLASS_BORDER * 2
local KEY_ICON_SIZE = 22
local KEY_BORDER = 2
local COL_MAP = ICON_SIZE + ICON_MARGIN * 2
local ROW_HEIGHT = 22
local HEADER_HEIGHT = ICON_SIZE + ICON_MARGIN * 2

local SLOT_COLORS = {
	{ r = 1.00, g = 0.82, b = 0.00 },
	{ r = 0.25, g = 0.72, b = 1.00 },
	{ r = 0.30, g = 0.90, b = 0.40 },
	{ r = 1.00, g = 0.45, b = 0.20 },
	{ r = 0.78, g = 0.40, b = 1.00 },
}

local menu = CreateFrame("Frame", "KeyfMenu", UIParent, "BasicFrameTemplateWithInset")
menu:SetSize(760, 320)
menu:SetPoint("CENTER")
menu:SetFrameStrata("HIGH")
menu:SetMovable(true)
menu:EnableMouse(true)
menu:RegisterForDrag("LeftButton")
menu:SetScript("OnDragStart", menu.StartMoving)
menu:SetScript("OnDragStop", menu.StopMovingOrSizing)
menu:Hide()
tinsert(UISpecialFrames, "KeyfMenu")

menu.TitleText:SetText(C_AddOns.GetAddOnMetadata(addonName, "Title") or "Mythic Keys")

local status = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
status:SetPoint("TOPLEFT", 16, -36)
status:SetPoint("TOPRIGHT", -16, -36)
status:SetJustifyH("LEFT")

local listBox = CreateFrame("Frame", nil, menu, "BackdropTemplate")
listBox:SetPoint("TOPLEFT", 14, -58)
listBox:SetPoint("BOTTOMRIGHT", -14, 14)
listBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
listBox:SetBackdropColor(0, 0, 0, 0.8)

local header = CreateFrame("Frame", nil, listBox)
header:SetPoint("TOPLEFT", 8, -6)
header:SetPoint("TOPRIGHT", -8, -6)
header:SetHeight(HEADER_HEIGHT)

local headerCells = {}

local scroll = CreateFrame("ScrollFrame", "KeyfMenuScroll", listBox, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 8, -(8 + HEADER_HEIGHT))
scroll:SetPoint("BOTTOMRIGHT", -8, 8)

local list = CreateFrame("Frame", nil, scroll)
list:SetPoint("TOPLEFT")
list:SetSize(1, 1)
scroll:SetScrollChild(list)

local rows = {}

local function classColor(classFile)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if color then
		return color.r, color.g, color.b
	end
	return 1, 1, 1
end

local function acquireLabel(parent, pool, index)
	local label = pool[index]
	if label then
		label:Show()
		return label
	end
	label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetJustifyH("LEFT")
	pool[index] = label
	return label
end

local function hideUnused(pool, used)
	for i = used + 1, #pool do
		pool[i]:Hide()
	end
end

local function placeLabel(label, parent, x, width, justify)
	label:ClearAllPoints()
	label:SetPoint("LEFT", parent, "LEFT", x, 0)
	label:SetWidth(width)
	label:SetJustifyH(justify or "LEFT")
end

local function tableWidth(mapCount)
	return 8 + COL_NAME + (mapCount * COL_MAP)
end

local function slotColor(index)
	return SLOT_COLORS[index]
end

local function setClassIcon(texture, classFile)
	if classFile then
		texture:SetAtlas("classicon-" .. strlower(classFile))
		texture:Show()
	else
		texture:Hide()
	end
end

local function acquireRow(index)
	local row = rows[index]
	if row then
		return row
	end

	row = CreateFrame("Frame", nil, list)
	row:SetHeight(ROW_HEIGHT)
	row.cells = {}
	if index % 2 == 0 then
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		row.bg:SetColorTexture(1, 1, 1, 0.04)
	end

	row.classWrap = CreateFrame("Frame", nil, row)
	row.classWrap:SetSize(CLASS_SLOT, CLASS_SLOT)
	row.classWrap:SetPoint("LEFT", 4, 0)
	row.classBorder = row.classWrap:CreateTexture(nil, "BACKGROUND")
	row.classBorder:SetAllPoints()
	row.classIcon = row.classWrap:CreateTexture(nil, "ARTWORK")
	row.classIcon:SetPoint("TOPLEFT", CLASS_BORDER, -CLASS_BORDER)
	row.classIcon:SetPoint("BOTTOMRIGHT", -CLASS_BORDER, CLASS_BORDER)

	rows[index] = row
	return row
end

local function acquireHeaderCell(index)
	local cell = headerCells[index]
	if cell then
		cell:Show()
		return cell
	end

	cell = CreateFrame("Button", nil, header, "SecureActionButtonTemplate")
	cell:RegisterForClicks("AnyUp", "AnyDown")
	cell:EnableMouse(true)
	cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	cell.label:SetAllPoints()
	cell.icon = cell:CreateTexture(nil, "ARTWORK")
	cell.icon:SetSize(ICON_SIZE, ICON_SIZE)
	cell.icon:SetPoint("TOPLEFT", ICON_MARGIN, -ICON_MARGIN)
	cell.icon:SetPoint("BOTTOMRIGHT", -ICON_MARGIN, ICON_MARGIN)

	cell.keyBadges = {}

	cell:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if self.spellID then
			GameTooltip:SetSpellByID(self.spellID)
			if self.keyOwners then
				for _, owner in ipairs(self.keyOwners) do
					GameTooltip:AddLine(owner.text, owner.color.r, owner.color.g, owner.color.b)
				end
			end
			if not self.teleportKnown then
				GameTooltip:AddLine("Teleport locked", 0.6, 0.6, 0.6)
			end
			GameTooltip:Show()
		elseif self.tooltip then
			GameTooltip:SetText(self.tooltip)
			GameTooltip:Show()
		end
	end)
	cell:SetScript("OnLeave", GameTooltip_Hide)
	headerCells[index] = cell
	return cell
end

local function acquireKeyBadge(cell, index)
	local badge = cell.keyBadges[index]
	if badge then
		badge:Show()
		return badge
	end

	badge = CreateFrame("Frame", nil, cell)
	badge:EnableMouse(false)
	badge:SetSize(KEY_ICON_SIZE + KEY_BORDER * 2, KEY_ICON_SIZE + KEY_BORDER * 2)
	badge.border = badge:CreateTexture(nil, "BACKGROUND")
	badge.border:SetAllPoints()
	badge.icon = badge:CreateTexture(nil, "ARTWORK")
	badge.icon:SetPoint("TOPLEFT", KEY_BORDER, -KEY_BORDER)
	badge.icon:SetPoint("BOTTOMRIGHT", -KEY_BORDER, KEY_BORDER)
	cell.keyBadges[index] = badge
	return badge
end

local function memberKeyForSlot(member, slot)
	local key = Key.GetMemberKey and Key.GetMemberKey(member)
	if key then
		return key
	end
	if slot == 1 and Key.ownedKey and member.unit == "player" then
		return Key.ownedKey
	end
	return nil
end

local function keyOwnersForMap(challengeID)
	local owners = {}
	if not challengeID then
		return owners
	end
	for slot, member in ipairs(Key.group.members) do
		if slot > 5 then
			break
		end
		local key = memberKeyForSlot(member, slot)
		if key and key.challengeID == challengeID then
			local color = slotColor(slot)
			local playerName = member.playerName or member.name or "?"
			owners[#owners + 1] = {
				member = member,
				key = key,
				slot = slot,
				color = color,
				text = playerName .. " key +" .. key.level,
			}
		end
	end
	return owners
end

local function setHeader(maps)
	local columns = {
		{ text = "Player", width = COL_NAME, justify = "LEFT" },
	}
	for _, map in ipairs(maps) do
		columns[#columns + 1] = {
			width = COL_MAP,
			icon = map.icon,
			text = map.short,
			tooltip = map.name,
			challengeID = map.id,
			justify = "CENTER",
		}
	end

	local x = 4
	for i, col in ipairs(columns) do
		local cell = acquireHeaderCell(i)
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", x, 0)
		cell:SetSize(col.width, HEADER_HEIGHT)
		cell.tooltip = col.tooltip
		cell.spellID = Key.GetTeleportSpell and Key.GetTeleportSpell(col.challengeID) or nil
		cell.teleportKnown = cell.spellID and IsPlayerSpell(cell.spellID)
		cell.keyOwners = nil

		if col.icon then
			cell.label:SetText("")
			cell.icon:SetTexture(col.icon)
			cell.icon:SetDesaturated(cell.spellID and not cell.teleportKnown)
			cell.icon:Show()
		else
			cell.icon:Hide()
			cell.label:SetText(col.text or "")
			cell.label:SetJustifyH(col.justify or "CENTER")
			cell.label:SetTextColor(1, 0.82, 0)
		end

		if not InCombatLockdown() then
			if cell.teleportKnown then
				cell:SetAttribute("type", "spell")
				cell:SetAttribute("spell", cell.spellID)
			else
				cell:SetAttribute("type", nil)
				cell:SetAttribute("spell", nil)
			end
		end

		local owners = keyOwnersForMap(col.challengeID)
		cell.keyOwners = owners
		local badgeSize = KEY_ICON_SIZE + KEY_BORDER * 2
		for i, owner in ipairs(owners) do
			local badge = acquireKeyBadge(cell, i)
			badge:EnableMouse(false)
			badge:ClearAllPoints()
			badge:SetPoint("BOTTOMRIGHT", cell.icon, "BOTTOMRIGHT", -2 - (i - 1) * (badgeSize + 2), 2)
			badge.border:SetColorTexture(owner.color.r, owner.color.g, owner.color.b, 1)
			setClassIcon(badge.icon, owner.member.classFile)
			badge:Show()
		end
		hideUnused(cell.keyBadges, #owners)
		x = x + col.width
	end
	hideUnused(headerCells, #columns)
end

local pendingMaps

local function applyHeader(maps)
	if InCombatLockdown() then
		pendingMaps = maps
		return
	end
	pendingMaps = nil
	setHeader(maps)
end

local headerEvents = CreateFrame("Frame")
headerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
headerEvents:RegisterEvent("SPELLS_CHANGED")
headerEvents:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and pendingMaps then
		setHeader(pendingMaps)
		pendingMaps = nil
		return
	end
	if event == "SPELLS_CHANGED" and menu:IsShown() and not InCombatLockdown() then
		applyHeader(Key.GetSeasonMaps and Key.GetSeasonMaps() or {})
	end
end)

local function sizeMenu(mapCount, memberCount)
	memberCount = math.max(memberCount, 1)
	local rowsHeight = memberCount * ROW_HEIGHT
	local contentWidth = 4 + COL_NAME + mapCount * COL_MAP
	local width = 14 + 14 + 8 + 8 + contentWidth
	local height = 58 + 14 + 6 + HEADER_HEIGHT + 8 + rowsHeight + 8

	local maxW = UIParent:GetWidth() - 60
	local maxH = UIParent:GetHeight() - 60
	local needsVScroll = height > maxH
	if needsVScroll then
		width = width + 20
		height = maxH
	end
	width = math.min(width, maxW)

	menu:SetSize(width, height)

	local rightPad = needsVScroll and -28 or -8
	header:SetPoint("TOPRIGHT", rightPad, -6)
	scroll:SetPoint("BOTTOMRIGHT", rightPad, 8)

	local scrollBar = _G.KeyfMenuScrollScrollBar
	if scrollBar then
		scrollBar:SetShown(needsVScroll)
	end
end

function Key.UpdateWindow()
	if not menu:IsShown() then
		return
	end

	local group = Key.group
	local maps = Key.GetSeasonMaps and Key.GetSeasonMaps() or {}
	status:SetText(group.type .. " · " .. #group.members)
	sizeMenu(#maps, #group.members)
	applyHeader(maps)

	local width = math.max(scroll:GetWidth(), tableWidth(#maps))
	list:SetWidth(width)

	for i, member in ipairs(group.members) do
		local row = acquireRow(i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
		row:Show()

		local completes = Key.GetMemberCompletes and Key.GetMemberCompletes(member)
		local playerName = member.playerName or (member.name and member.name:match("^([^-]+)")) or member.name or "?"
		local rating = completes and completes.score or "—"
		local color = slotColor(i)
		if color then
			row.classWrap:Show()
			row.classBorder:SetColorTexture(color.r, color.g, color.b, 1)
			setClassIcon(row.classIcon, member.classFile)
		else
			row.classWrap:Hide()
		end
		local values = {
			{ text = playerName .. " - " .. rating, r = 1, g = 1, b = 1, justify = "LEFT" },
		}
		local cr, cg, cb = classColor(member.classFile)
		values[1].r, values[1].g, values[1].b = cr, cg, cb

		for _, map in ipairs(maps) do
			local run = completes and completes.byMap and completes.byMap[map.id]
			if run then
				values[#values + 1] = { text = "+" .. run.level, r = 0.2, g = 1, b = 0.2, justify = "CENTER" }
			else
				values[#values + 1] = { text = "—", r = 0.45, g = 0.45, b = 0.45, justify = "CENTER" }
			end
		end

		local widths = { COL_NAME }
		for _ = 1, #maps do
			widths[#widths + 1] = COL_MAP
		end

		local x = 4
		for c, value in ipairs(values) do
			local cell = acquireLabel(row, row.cells, c)
			local labelX = x
			local labelWidth = widths[c]
			if c == 1 and color then
				labelX = x + CLASS_SLOT + 6
				labelWidth = widths[c] - CLASS_SLOT - 6
			end
			placeLabel(cell, row, labelX, labelWidth, value.justify)
			cell:SetText(value.text)
			cell:SetTextColor(value.r, value.g, value.b)
			cell:SetFontObject(c == 1 and GameFontHighlight or GameFontNormal)
			x = x + widths[c]
		end
		hideUnused(row.cells, #values)
	end

	for i = #group.members + 1, #rows do
		rows[i].classWrap:Hide()
		rows[i]:Hide()
	end

	list:SetHeight(math.max(#group.members * ROW_HEIGHT, 1))
	scroll:UpdateScrollChildRect()
end

function Key.ShowWindow()
	menu:Show()
	Key.RefreshGroup()
end

SLASH_KEYF1 = "/keyf"
SlashCmdList["KEYF"] = function(msg)
	msg = strtrim(msg or "")
	local sub, rest = msg:match("^(%S+)%s*(.*)$")
	if sub and sub:lower() == "command" then
		Key.ShowCommandWindow(rest)
		return
	end
	if sub and sub:lower() == "group" then
		Key.PrintGroup()
		return
	end
	if sub and sub:lower() == "history" then
		Key.ShowHistoryWindow()
		return
	end
	Key.ShowWindow()
end

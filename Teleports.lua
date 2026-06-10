local ADDON_NAME = ...

KeyTeleports = KeyTeleports or {}
local Teleports = KeyTeleports

Teleports.COLUMNS = 8
Teleports.SLOT_MIN = 25
Teleports.SLOT_DEFAULT = 100
Teleports.SLOT_MAX = 150
Teleports.SLOT_LABEL_MIN = 75
Teleports.COMPACT_DOT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
Teleports.MAX_KEY_TOKENS = 40
Teleports.MAX_BEST_ROWS = 40
Teleports.BEST_ROW_GAP = 2
Teleports.BEST_NAME_GAP = 2
Teleports.LEADER_OUTLINE_SIZE = 3
Teleports.LAYOUT_GAP = 4
Teleports.OVERTIME_DESATURATION = 0.72

Teleports.CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"

function Teleports:GetDefaultContentWidth()
    return (self.COLUMNS * self.SLOT_DEFAULT) + ((self.COLUMNS - 1) * self.LAYOUT_GAP)
end

function Teleports:GetDefaultFrameWidth(padding)
    padding = padding or 10
    return self:GetDefaultContentWidth() + (padding * 2)
end

function Teleports:GetMinContentWidth()
    return (self.COLUMNS * self.SLOT_MIN) + ((self.COLUMNS - 1) * self.LAYOUT_GAP)
end

function Teleports:GetMinTeleportBarHeight()
    return self.SLOT_MIN
end

function Teleports:GetMinFrameWidth(padding)
    padding = padding or 10
    return self:GetMinContentWidth() + (padding * 2)
end

function Teleports:GetMaxFrameWidth(padding)
    padding = padding or 10
    return (self.COLUMNS * self.SLOT_MAX) + ((self.COLUMNS - 1) * self.LAYOUT_GAP) + (padding * 2)
end

function Teleports:ComputeLayout(contentWidth)
    local gap = self.LAYOUT_GAP
    local fit = (contentWidth - ((self.COLUMNS - 1) * gap)) / self.COLUMNS
    local slotSize = math.min(self.SLOT_MAX, math.max(self.SLOT_MIN, fit))
    return self.COLUMNS, 1, slotSize
end

function Teleports:IsCompactSlot(slotSize)
    return slotSize < self.SLOT_LABEL_MIN
end

-- Midnight Season 1 M+ pool (MapChallengeMode.ID -> teleport spell)
Teleports.SEASON_DUNGEONS = {
    { challengeModeID = 558, spellID = 1254572, shortName = "Magisters'" },
    { challengeModeID = 560, spellID = 1254559, shortName = "Maisara" },
    { challengeModeID = 559, spellID = 1254563, shortName = "Nexus-Point" },
    { challengeModeID = 557, spellID = 1254400, shortName = "Windrunner" },
    { challengeModeID = 402, spellID = 393273, shortName = "Algeth'ar" },
    { challengeModeID = 556, spellID = 1254555, shortName = "Pit of Saron" },
    { challengeModeID = 239, spellID = 1254551, shortName = "Seat" },
    { challengeModeID = 161, spellID = 159898, shortName = "Skyreach" },
}

Teleports.SLOT_COUNT = #Teleports.SEASON_DUNGEONS

function Teleports:GetDefaultIcon()
    return Key and Key.DEFAULT_ICON or 134400
end

function Teleports:GetGcdSpellId()
    return Key and Key.GCD_SPELL_ID or 61304
end

function Teleports:GetDungeonTexture(challengeModeID)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(challengeModeID)
        if texture then
            return texture
        end
    end
    return self:GetDefaultIcon()
end

function Teleports:IsSpellKnown(spellID)
    if not spellID then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        if C_SpellBook.IsSpellInSpellBook(spellID) then
            return true
        end
        if Enum and Enum.SpellBookSpellBank then
            if C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player) then
                return true
            end
        end
    end

    return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID)
end

function Teleports:GetSpellCooldownRemaining(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellCooldown then
        return 0
    end

    local cooldown = C_Spell.GetSpellCooldown(spellID)
    if not cooldown or cooldown.duration == 0 then
        return 0
    end

    local gcd = C_Spell.GetSpellCooldown(self:GetGcdSpellId())
    if gcd and cooldown.duration == gcd.duration then
        return 0
    end

    return math.max(0, cooldown.startTime + cooldown.duration - GetTime())
end

function Teleports:HandleTeleportClick(spellID)
    if not spellID then
        return
    end

    local now = GetTime()
    if self.lastHandleSpellID == spellID and self.lastHandleTime and (now - self.lastHandleTime) < 0.1 then
        return
    end

    self.lastHandleSpellID = spellID
    self.lastHandleTime = now
    self.lastClickSpellID = spellID
    self.lastClickTime = now

    if not self:IsSpellKnown(spellID) then
        self:LogTeleport(spellID, "unavailable")
        return
    end

    local remaining = self:GetSpellCooldownRemaining(spellID)
    if remaining > 0 then
        self:LogTeleport(spellID, "cooldown", remaining)
    end
end

function Teleports:UpdateSlotTooltip(slot)
    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    GameTooltip:SetText(slot.dungeonName or slot.shortName or "")

    if not slot.spellID or not self:IsSpellKnown(slot.spellID) then
        GameTooltip:AddLine("Teleport not learned", 1, 0.3, 0.3)
        GameTooltip:Show()
        return
    end

    local remaining = self:GetSpellCooldownRemaining(slot.spellID)
    if remaining > 0 then
        GameTooltip:AddLine(string.format("On cooldown (%s)", SecondsToTime(math.ceil(remaining))), 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Click to teleport", 0, 1, 0)
    end

    GameTooltip:Show()
end

function Teleports:ConfigureSlotMouseLayers(slot)
    if not slot then
        return
    end

    slot:EnableMouse(false)

    if slot.labelBar then
        slot.labelBar:EnableMouse(false)
        slot.labelBar:SetPropagateMouseClicks(true)
        slot.labelBar:SetPropagateMouseMotion(true)
    end

    if slot.tokenContainer then
        slot.tokenContainer:EnableMouse(false)
        slot.tokenContainer:SetPropagateMouseClicks(true)
        slot.tokenContainer:SetPropagateMouseMotion(true)
    end

    if slot.leaderOutline then
        slot.leaderOutline:EnableMouse(false)
        slot.leaderOutline:SetPropagateMouseClicks(true)
        slot.leaderOutline:SetPropagateMouseMotion(true)
    end

    if slot.action then
        slot.action:SetFrameLevel(slot:GetFrameLevel() + 50)
        slot.action:Raise()
    end
end

function Teleports:CreateSlot(parent, index, dungeon)
    local slot = CreateFrame("Frame", "KeyTeleportSlot" .. index, parent, "BackdropTemplate")
    slot:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    slot:SetBackdropColor(unpack(KeyUI:GetTheme().slotBg))
    slot:SetBackdropBorderColor(unpack(KeyUI:GetTheme().slotBorder))

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    slot.icon = icon

    local labelBar = CreateFrame("Frame", nil, slot, "BackdropTemplate")
    labelBar:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
    labelBar:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    labelBar:SetHeight(14)
    labelBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    labelBar:SetBackdropColor(0, 0, 0, 0.6)
    labelBar:SetFrameLevel(slot:GetFrameLevel() + 2)
    labelBar:EnableMouse(false)
    labelBar:Hide()
    slot.labelBar = labelBar

    local label = labelBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    slot.label = label

    slot.leaderOutline = CreateFrame("Frame", nil, slot, "BackdropTemplate")
    slot.leaderOutline:SetFrameLevel(slot:GetFrameLevel() + 4)
    slot.leaderOutline:SetPoint("TOPLEFT", -self.LEADER_OUTLINE_SIZE, self.LEADER_OUTLINE_SIZE)
    slot.leaderOutline:SetPoint("BOTTOMRIGHT", self.LEADER_OUTLINE_SIZE, -self.LEADER_OUTLINE_SIZE)
    slot.leaderOutline:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = self.LEADER_OUTLINE_SIZE,
    })
    slot.leaderOutline:SetBackdropColor(0, 0, 0, 0)
    slot.leaderOutline:SetBackdropBorderColor(1, 0.82, 0, 1)
    slot.leaderOutline:EnableMouse(false)
    slot.leaderOutline:Hide()

    self:EnsureTokenPool(slot)

    local action = CreateFrame("Button", nil, slot, "InsecureActionButtonTemplate")
    action:SetAllPoints(slot)
    action:RegisterForClicks("AnyDown")
    action:SetAttribute("type", "spell")
    if dungeon and dungeon.spellID then
        action:SetAttribute("spell", dungeon.spellID)
    end
    slot.action = action

    action:SetScript("OnEnter", function()
        Teleports:UpdateSlotTooltip(slot)
    end)
    action:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    action:SetScript("PostClick", function()
        Teleports:HandleTeleportClick(slot.spellID)
    end)

    self:ConfigureSlotMouseLayers(slot)

    return slot
end

function Teleports:GetClassColor(classFilename)
    if KeyKeystones and KeyKeystones.GetClassColor then
        return KeyKeystones:GetClassColor(classFilename)
    end

    if issecretvalue and issecretvalue(classFilename) then
        return 1, 1, 1
    end

    local color = classFilename and RAID_CLASS_COLORS[classFilename]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function Teleports:SetClassIcon(texture, classFilename)
    if not texture or not classFilename then
        return false
    end

    if issecretvalue and issecretvalue(classFilename) then
        return false
    end

    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFilename]
    if not coords then
        return false
    end

    texture:SetTexture(self.CLASS_ICON_TEXTURE)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    texture:SetBlendMode("BLEND")
    texture:SetVertexColor(1, 1, 1, 1)
    return true
end

function Teleports:CreateKeyToken(parent)
    local token = CreateFrame("Frame", nil, parent)

    token.icon = token:CreateTexture(nil, "ARTWORK")
    token.icon:SetPoint("CENTER")

    token.text = token:CreateFontString(nil, "OVERLAY")
    token.text:SetTextColor(1, 1, 1, 1)

    token:EnableMouse(false)

    return token
end

function Teleports:HideLegacyTokenParts(tokenFrame)
    if not tokenFrame then
        return
    end

    if tokenFrame.bg then
        tokenFrame.bg:Hide()
    end

    if tokenFrame.circle then
        tokenFrame.circle:Hide()
    end

    if tokenFrame.roleIcon then
        tokenFrame.roleIcon:Hide()
    end

    if tokenFrame.roleIconBg then
        tokenFrame.roleIconBg:Hide()
    end

    if tokenFrame.roleBadge then
        tokenFrame.roleBadge:Hide()
    end

    if tokenFrame.roleText then
        tokenFrame.roleText:Hide()
    end
end

function Teleports:EnsureTokenParts(tokenFrame)
    if not tokenFrame then
        return
    end

    if not tokenFrame.icon then
        tokenFrame.icon = tokenFrame:CreateTexture(nil, "ARTWORK")
        tokenFrame.icon:SetPoint("CENTER")
    end

    if not tokenFrame.text then
        tokenFrame.text = tokenFrame:CreateFontString(nil, "OVERLAY")
        tokenFrame.text:SetTextColor(1, 1, 1, 1)
    end

    if not tokenFrame.dot then
        tokenFrame.dot = tokenFrame:CreateTexture(nil, "ARTWORK")
        tokenFrame.dot:SetTexture(self.COMPACT_DOT_TEXTURE)
        tokenFrame.dot:SetPoint("CENTER")
        tokenFrame.dot:Hide()
    end

    self:HideLegacyTokenParts(tokenFrame)
end

function Teleports:UpdateCompactTokenAppearance(tokenFrame, token, cubeSize)
    self:EnsureTokenParts(tokenFrame)

    local dotSize = math.max(4, math.floor(cubeSize / 8))

    tokenFrame.icon:Hide()
    tokenFrame.text:Hide()

    tokenFrame.dot:SetSize(dotSize, dotSize)
    tokenFrame.dot:ClearAllPoints()
    tokenFrame.dot:SetPoint("CENTER")

    local r, g, b = self:GetClassColor(token.classFilename)
    tokenFrame.dot:SetVertexColor(r, g, b, 1)
    tokenFrame.dot:Show()

    return dotSize
end

function Teleports:UpdateTokenAppearance(tokenFrame, token, cubeSize, compact)
    self:EnsureTokenParts(tokenFrame)

    if compact then
        self:UpdateCompactTokenAppearance(tokenFrame, token, cubeSize)
        return math.max(4, math.floor(cubeSize / 8))
    end

    tokenFrame.dot:Hide()

    local iconSize = math.max(10, math.floor(cubeSize / 4))
    local tokenSize = math.max(12, math.floor(cubeSize / 3))

    tokenFrame:SetSize(tokenSize, tokenSize)

    tokenFrame.icon:SetSize(iconSize, iconSize)
    tokenFrame.icon:ClearAllPoints()
    tokenFrame.icon:SetPoint("CENTER", tokenFrame, "CENTER", 0, math.floor(tokenSize * 0.06))
    if not self:SetClassIcon(tokenFrame.icon, token.classFilename) then
        tokenFrame.icon:Hide()
    else
        tokenFrame.icon:Show()
    end

    local fontSize = math.max(7, math.floor(tokenSize * 0.28))
    tokenFrame.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    tokenFrame.text:ClearAllPoints()
    tokenFrame.text:SetPoint("TOP", tokenFrame.icon, "BOTTOM", 0, -1)
    tokenFrame.text:SetText(tostring(token.level))
    tokenFrame.text:Show()

    return tokenSize
end

function Teleports:EnsureTokenPool(slot)
    if slot.tokens then
        for _, tokenFrame in ipairs(slot.tokens) do
            self:EnsureTokenParts(tokenFrame)
        end
        return
    end

    slot.tokenContainer = CreateFrame("Frame", nil, slot)
    slot.tokenContainer:SetFrameLevel(slot:GetFrameLevel() + 3)
    slot.tokenContainer:EnableMouse(false)
    slot.tokens = {}

    for i = 1, self.MAX_KEY_TOKENS do
        slot.tokens[i] = self:CreateKeyToken(slot.tokenContainer)
        slot.tokens[i]:Hide()
    end
end

function Teleports:UpdateSlotTokens(slot, tokens, slotWidth, slotHeight)
    self:EnsureTokenPool(slot)
    self:ConfigureSlotMouseLayers(slot)

    local cubeSize = math.min(slotWidth, slotHeight)
    local compact = self:IsCompactSlot(cubeSize)
    local spacing = compact and 1 or 2
    local tokenSize = compact and math.max(4, math.floor(cubeSize / 8)) or math.max(12, math.floor(cubeSize / 3))
    local tokensPerRow = math.max(1, math.floor((slotWidth - 8) / (tokenSize + spacing)))
    local hasLeaderKey = false

    slot.tokenContainer:ClearAllPoints()
    slot.tokenContainer:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", 2, -2)
    slot.tokenContainer:SetSize(slotWidth - 8, slotHeight - 8)

    for i, tokenFrame in ipairs(slot.tokens) do
        tokenFrame:Hide()
    end

    if not tokens then
        if slot.leaderOutline then
            slot.leaderOutline:Hide()
        end
        return
    end

    for index, token in ipairs(tokens) do
        if token.isLeader then
            hasLeaderKey = true
        end

        local tokenFrame = slot.tokens[index]
        if not tokenFrame then
            break
        end

        local col = (index - 1) % tokensPerRow
        local row = math.floor((index - 1) / tokensPerRow)
        local x = col * (tokenSize + spacing)
        local y = -row * (tokenSize + spacing)

        tokenFrame:SetSize(tokenSize, tokenSize)
        tokenFrame:ClearAllPoints()
        tokenFrame:SetPoint("TOPLEFT", slot.tokenContainer, "TOPLEFT", x, y)

        self:UpdateTokenAppearance(tokenFrame, token, cubeSize, compact)
        tokenFrame:Show()
    end

    if slot.leaderOutline then
        if hasLeaderKey then
            slot.leaderOutline:Show()
        else
            slot.leaderOutline:Hide()
        end
    end
end

function Teleports:UpdateSlotBorder(slot, dungeon)
    slot.spellID = dungeon.spellID
    slot.shortName = dungeon.shortName

    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(dungeon.challengeModeID)
        slot.dungeonName = name or dungeon.shortName
    else
        slot.dungeonName = dungeon.shortName
    end

    slot.icon:SetTexture(self:GetDungeonTexture(dungeon.challengeModeID))
    slot.icon:SetDesaturated(false)
    slot.icon:SetAlpha(1)

    if InCombatLockdown() then
        return
    end

    slot.action:SetAttribute("type", "spell")
    slot.action:SetAttribute("spell", dungeon.spellID)

    if self:IsSpellKnown(dungeon.spellID) then
        local theme = KeyUI:GetTheme()
        slot:SetBackdropBorderColor(unpack(theme.slotActiveBorder))
        slot.action:Enable()
        slot.action:EnableMouse(true)
    else
        slot:SetBackdropBorderColor(unpack(KeyUI:GetTheme().slotBorder))
        slot.icon:SetDesaturated(true)
        slot.icon:SetAlpha(0.45)
        slot.action:Disable()
        slot.action:EnableMouse(false)
    end

    self:ConfigureSlotMouseLayers(slot)
end

function Teleports:ApplySlotLabel(slot, dungeon, slotSize)
    if not slot or not slot.label then
        return
    end

    slotSize = slotSize or slot:GetWidth()
    local showLabel = not self:IsCompactSlot(slotSize)

    if not showLabel then
        slot.label:SetText("")
        slot.label:Hide()
        if slot.labelBar then
            slot.labelBar:Hide()
        end
        return
    end

    local barHeight = math.max(10, math.floor(slotSize * 0.22))
    local fontSize = math.max(7, math.floor(slotSize * 0.11))

    if slot.labelBar then
        slot.labelBar:SetHeight(barHeight)
        slot.labelBar:Show()
    end

    self:ConfigureSlotMouseLayers(slot)

    slot.label:SetWidth(math.max(0, slotSize - 12))
    slot.label:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    slot.label:SetTextColor(1, 1, 1, 1)
    slot.label:SetText(dungeon.shortName)
    slot.label:Show()
end

function Teleports:UpdateSlot(slot, dungeon, tokens, slotWidth, slotHeight)
    self:UpdateSlotBorder(slot, dungeon)
    self:ApplySlotLabel(slot, dungeon, slotWidth)
    self:UpdateSlotTokens(slot, tokens, slotWidth, slotHeight)
end

function Teleports:InitBar()
    if self.bar then
        return self.bar
    end

    -- Pre-create at addon load (Details/DBM pattern) so secure buttons are not tainted.
    local bar = CreateFrame("Frame", "KeyTeleportBar", UIParent)
    bar:Hide()
    bar:EnableMouse(false)
    bar.slots = {}

    for i = 1, self.SLOT_COUNT do
        bar.slots[i] = self:CreateSlot(bar, i, self.SEASON_DUNGEONS[i])
    end

    self.bar = bar
    return bar
end

function Teleports:EnsureBar(parent)
    local bar = self:InitBar()
    if parent and bar:GetParent() ~= parent then
        bar:SetParent(parent)
    end
    if parent then
        bar:Show()
    end
    return bar
end

function Teleports:LayoutBar(bar, contentWidth)
    local columns, rows, slotSize = self:ComputeLayout(contentWidth)
    local gap = self.LAYOUT_GAP
    local pitch = slotSize + gap
    local tokensByMap = KeyKeystones and KeyKeystones:GetPartyKeyTokensByMap() or {}

    for i, dungeon in ipairs(self.SEASON_DUNGEONS) do
        local slot = bar.slots[i]
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)

        slot:SetSize(slotSize, slotSize)
        slot:ClearAllPoints()
        slot:SetPoint(
            "TOPLEFT",
            bar,
            "TOPLEFT",
            col * pitch,
            -(row * pitch)
        )

        slot.icon:SetDesaturated(false)
        slot.icon:SetAlpha(1)
        self:UpdateSlot(slot, dungeon, tokensByMap[dungeon.challengeModeID], slotSize, slotSize)
        self:ConfigureSlotMouseLayers(slot)
        slot:Show()
    end

    local barHeight = (rows * slotSize) + ((rows - 1) * gap)
    bar:SetSize(contentWidth, barHeight)
    return barHeight, slotSize, pitch
end

function Teleports:GetBestTableMetrics(contentWidth)
    local _, _, slotSize = self:ComputeLayout(contentWidth)
    local pitch = slotSize + self.LAYOUT_GAP
    local rowHeight = math.max(16, math.floor(slotSize * 0.34))
    local nameHeight = math.max(10, math.floor(slotSize * 0.16))
    local rowPitch = nameHeight + self.BEST_NAME_GAP + rowHeight + self.BEST_ROW_GAP

    return rowHeight, rowPitch, slotSize, pitch, nameHeight
end

function Teleports:GetBestTableHeight(memberCount, contentWidth)
    if not memberCount or memberCount == 0 then
        return 0
    end

    local rowHeight, rowPitch, _, _, nameHeight = self:GetBestTableMetrics(contentWidth)
    local bandHeight = nameHeight + self.BEST_NAME_GAP + rowHeight
    return (memberCount * bandHeight) + ((memberCount - 1) * self.BEST_ROW_GAP)
end

function Teleports:CreateBestCell(parent, justify)
    local cell = CreateFrame("Frame", nil, parent)
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    justify = justify or "CENTER"
    cell.text:SetJustifyH(justify)
    if justify == "LEFT" then
        cell.text:SetPoint("LEFT", cell, "LEFT", 2, 0)
    else
        cell.text:SetPoint("CENTER")
    end
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function()
        if not cell.tooltipTitle then
            return
        end
        GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
        GameTooltip:SetText(cell.tooltipTitle, 1, 1, 1)
        if cell.tooltipBody then
            GameTooltip:AddLine(cell.tooltipBody, 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return cell
end

function Teleports:EnsureBestTable(parent)
    if self.bestTable then
        for rowIndex = 1, self.MAX_BEST_ROWS do
            local row = self.bestTable.rows[rowIndex]
            if row and not row.name then
                row.name = self:CreateBestCell(self.bestTable, "LEFT")
                row.name:Hide()
            end
        end
        return self.bestTable
    end

    local tableFrame = CreateFrame("Frame", nil, parent)
    tableFrame.rows = {}

    for rowIndex = 1, self.MAX_BEST_ROWS do
        tableFrame.rows[rowIndex] = {
            name = self:CreateBestCell(tableFrame, "LEFT"),
        }
        tableFrame.rows[rowIndex].name:Hide()
        for colIndex = 1, self.SLOT_COUNT do
            tableFrame.rows[rowIndex][colIndex] = self:CreateBestCell(tableFrame)
            tableFrame.rows[rowIndex][colIndex]:Hide()
        end
    end

    self.bestTable = tableFrame
    return tableFrame
end

function Teleports:UpdateBestNameCell(cell, member, nameHeight)
    if not cell or not cell.text then
        return
    end

    local memberName = member and member.name or "Unknown"
    local r, g, b = self:GetClassColor(member and member.classFilename)
    local fontSize = math.max(7, math.floor((nameHeight or 10) * 0.85))

    cell.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    cell.text:SetText(memberName)
    cell.text:SetTextColor(r, g, b)
    cell.tooltipTitle = memberName
    cell.tooltipBody = "Season best completions"
end

function Teleports:UpdateBestCell(cell, member, dungeon, level, overTime)
    if not cell or not cell.text then
        return
    end

    local classFilename = member and member.classFilename
    local dungeonName = self:GetDungeonName(dungeon)
    local memberName = member and member.name or "Unknown"

    if not level or level == 0 then
        cell.text:SetText("—")
        cell.text:SetTextColor(0.45, 0.45, 0.45)
        cell.tooltipTitle = string.format("%s — %s", memberName, dungeonName)
        cell.tooltipBody = "No completed run this season"
        return
    end

    local r, g, b = self:GetClassColor(classFilename)
    if overTime then
        local scale = self.OVERTIME_DESATURATION
        r, g, b = r * scale, g * scale, b * scale
    end

    cell.text:SetText("+" .. tostring(level))
    cell.text:SetTextColor(r, g, b)
    cell.tooltipTitle = string.format("%s — %s", memberName, dungeonName)
    cell.tooltipBody = overTime and string.format("Best: +%d (over time)", level) or string.format("Best: +%d", level)
end

function Teleports:LayoutBestTable(tableFrame, contentWidth, members)
    if not tableFrame then
        return 0
    end

    local rowHeight, rowPitch, slotSize, pitch, nameHeight = self:GetBestTableMetrics(contentWidth)
    local memberCount = members and #members or 0

    for rowIndex = 1, self.MAX_BEST_ROWS do
        local row = tableFrame.rows[rowIndex]
        if row.name then
            row.name:Hide()
        end
        for colIndex = 1, self.SLOT_COUNT do
            row[colIndex]:Hide()
        end
    end

    if memberCount == 0 then
        tableFrame:SetSize(contentWidth, 0)
        return 0
    end

    local fontSize = math.max(8, math.floor(rowHeight * 0.72))

    for rowIndex, member in ipairs(members) do
        if rowIndex > self.MAX_BEST_ROWS then
            break
        end

        local row = tableFrame.rows[rowIndex]
        local y = -((rowIndex - 1) * rowPitch)
        local cellY = y - nameHeight - self.BEST_NAME_GAP

        row.name:SetSize(contentWidth, nameHeight)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, y)
        self:UpdateBestNameCell(row.name, member, nameHeight)
        row.name:Show()

        for colIndex, dungeon in ipairs(self.SEASON_DUNGEONS) do
            local cell = row[colIndex]
            local level, overTime = 0, false
            if KeyKeystones and member.unit then
                level, overTime = KeyKeystones:GetMemberBestForMap(member.unit, dungeon.challengeModeID)
            end

            cell:SetSize(slotSize, rowHeight)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", (colIndex - 1) * pitch, cellY)
            cell.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
            self:UpdateBestCell(cell, member, dungeon, level, overTime)
            cell:Show()
        end
    end

    local tableHeight = self:GetBestTableHeight(memberCount, contentWidth)
    tableFrame:SetSize(contentWidth, tableHeight)
    return tableHeight
end

function Teleports:GetDungeonName(dungeon)
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = C_ChallengeMode.GetMapUIInfo(dungeon.challengeModeID)
        if name then
            return name
        end
    end
    return dungeon.shortName
end

function Teleports:LogTeleport(spellID, reason, extra)
    local dungeon = self.spellToDungeon and self.spellToDungeon[spellID]
    if not dungeon then
        return
    end

    local name = self:GetDungeonName(dungeon)
    local message

    if reason == "unavailable" then
        message = string.format("Teleport unavailable: %s", name)
    elseif reason == "cooldown" then
        message = string.format(
            "Teleport on cooldown: %s (%s)",
            name,
            SecondsToTime(math.ceil(extra or 0))
        )
    elseif reason == "error" then
        message = string.format("Teleport failed: %s (%s)", name, extra or "unknown error")
    else
        message = string.format("Teleporting to %s", name)
    end

    KeyLog:Add(message, "teleport:" .. tostring(spellID) .. ":" .. tostring(reason), 0.5)
end

function Teleports:RefreshActionButtons()
    if not self.bar or InCombatLockdown() then
        return
    end

    for i, dungeon in ipairs(self.SEASON_DUNGEONS) do
        local slot = self.bar.slots[i]
        if slot then
            self:UpdateSlotBorder(slot, dungeon)
        end
    end
end

function Teleports:InitLogging()
    if self.eventFrame then
        return
    end

    self.spellToDungeon = {}
    for _, dungeon in ipairs(self.SEASON_DUNGEONS) do
        self.spellToDungeon[dungeon.spellID] = dungeon
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_ENABLED" then
            Teleports:RefreshActionButtons()
            return
        end

        if event == "UNIT_SPELLCAST_SENT" then
            local unit, _, _, spellID = ...
            if unit ~= "player" then
                return
            end

            if Teleports.spellToDungeon[spellID] then
                Teleports:LogTeleport(spellID, "cast")
            end
            return
        end

        if event == "UI_ERROR_MESSAGE" then
            local arg1, arg2 = ...
            local message = type(arg2) == "string" and arg2 or (type(arg1) == "string" and arg1 or nil)
            if not message or message == "" then
                return
            end

            local spellID = Teleports.lastClickSpellID
            local clickAge = GetTime() - (Teleports.lastClickTime or 0)
            if not spellID or clickAge > 1 or not Teleports.spellToDungeon[spellID] then
                return
            end

            if message:find("not ready", 1, true)
                or message:find("cooldown", 1, true)
                or message:find("Can't do that yet", 1, true)
            then
                Teleports:LogTeleport(spellID, "error", message)
            end
        end
    end)

    self.eventFrame = frame
end

Teleports:InitLogging()
Teleports:InitBar()

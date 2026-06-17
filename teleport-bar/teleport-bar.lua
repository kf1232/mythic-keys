local ADDON_NAME = ...

Key.Teleports = Key.Teleports or {}
local Teleports = Key.Teleports

if not Teleports.SEASON_DUNGEONS then
    error("Key.Teleports.SEASON_DUNGEONS is missing. Load teleport-bar-data.lua before teleport-bar.lua.")
end

Teleports.COLUMNS = 8
Teleports.SLOT_MIN = 25
Teleports.SLOT_DEFAULT = 100
Teleports.SLOT_MAX = 150
Teleports.SLOT_LABEL_MIN = 75
Teleports.COMPACT_DOT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
Teleports.MAX_KEY_TOKENS = 40
Teleports.LEADER_OUTLINE_SIZE = 3
Teleports.LAYOUT_GAP = 4
-- Secure action button must sit above decorative slot children (labelBar +3, leaderOutline +4).
Teleports.ACTION_FRAME_LEVEL_OFFSET = 50
Teleports.COOLDOWN_FRAME_LEVEL_OFFSET = 1
Teleports.COOLDOWN_TICK_INTERVAL = 0.25

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

function Teleports:GetDefaultIcon()
    return Key and Key.DEFAULT_ICON or 134400
end

function Teleports:GetGcdSpellId()
    return Key and Key.GCD_SPELL_ID or 61304
end

function Teleports:GetDungeonTexture(challengeModeID)
    local texture = Key.Api.ChallengeMode:GetMapTexture(false, challengeModeID)
    if texture then
        return texture
    end
    return self:GetDefaultIcon()
end

function Teleports:GetDungeonDisplayName(challengeModeID, fallback)
    if Key.Keystones and Key.Keystones.GetDungeonName then
        local name = Key.Keystones:GetDungeonName(challengeModeID)
        if name and name ~= "Unknown" then
            return name
        end
    end
    return fallback
end

function Teleports:GetDungeonName(dungeon)
    return self:GetDungeonDisplayName(dungeon.challengeModeID, dungeon.shortName)
end

function Teleports:IsSpellKnown(spellID)
    if not spellID then
        return false
    end

    local SpellAPI = Key.Api.Spell
    if SpellAPI:IsSpellInSpellBook(false, spellID) then
        return true
    end
    if Enum and Enum.SpellBookSpellBank then
        if SpellAPI:IsSpellInSpellBook(false, spellID, Enum.SpellBookSpellBank.Player) then
            return true
        end
    end

    return SpellAPI:IsSpellKnown(false, spellID)
end

function Teleports:GetSpellCooldownInfo(spellID)
    if not spellID then
        return nil
    end

    local cooldown = Key.Api.Spell:GetSpellCooldown(false, spellID)
    if not cooldown or cooldown.duration == 0 then
        return nil
    end

    local gcd = Key.Api.Spell:GetSpellCooldown(false, self:GetGcdSpellId())
    if gcd and cooldown.duration == gcd.duration then
        return nil
    end

    return cooldown.startTime, cooldown.duration
end

function Teleports:GetSpellCooldownRemaining(spellID)
    local startTime, duration = self:GetSpellCooldownInfo(spellID)
    if not startTime then
        return 0
    end

    return math.max(0, startTime + duration - Key.Api.Timer:GetTime(false))
end

function Teleports:HandleTeleportClick(spellID)
    if not spellID then
        return
    end

    local now = Key.Api.Timer:GetTime(false)
    if self.lastClickSpellID == spellID and self.lastClickTime and (now - self.lastClickTime) < 0.1 then
        return
    end

    self.lastClickSpellID = spellID
    self.lastClickTime = now

    if Key.Debug.Click and Key.Debug.Click.LogAction then
        Key.Debug.Click:LogAction("teleport.slot.action", spellID)
    end

    if not self:IsSpellKnown(spellID) then
        if Key.TeleportBarLog and Key.TeleportBarLog.LogTeleport then
            Key.TeleportBarLog:LogTeleport(spellID, "unavailable")
        end
        return
    end

    local remaining = self:GetSpellCooldownRemaining(spellID)
    if remaining > 0 and Key.TeleportBarLog and Key.TeleportBarLog.LogTeleport then
        Key.TeleportBarLog:LogTeleport(spellID, "cooldown", remaining)
    end

    self:RefreshCooldownUI()
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
    if not slot or InCombatLockdown() then
        return
    end

    slot:EnableMouse(false)

    for _, child in ipairs({ slot.cooldown, slot.labelBar, slot.tokenContainer, slot.leaderOutline }) do
        if child then
            child:EnableMouse(false)
            if child.SetPropagateMouseClicks then
                child:SetPropagateMouseClicks(true)
                child:SetPropagateMouseMotion(true)
            end
        end
    end

    if slot.action then
        slot.action:SetFrameLevel(slot:GetFrameLevel() + self.ACTION_FRAME_LEVEL_OFFSET)
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
    slot:SetBackdropColor(unpack(Key.UI:GetTheme().slotBg))
    slot:SetBackdropBorderColor(unpack(Key.UI:GetTheme().slotBorder))

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    slot.icon = icon

    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetFrameLevel(slot:GetFrameLevel() + self.COOLDOWN_FRAME_LEVEL_OFFSET)
    cooldown:SetDrawEdge(true)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:EnableMouse(false)
    cooldown:SetScript("OnCooldownDone", function()
        Teleports:UpdateSlotCooldown(slot, slot:GetWidth())
        Teleports:RefreshCooldownUI()
    end)
    slot.cooldown = cooldown

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
    return Key.Keystones:GetClassColor(classFilename)
end

function Teleports:SetClassIcon(texture, classFilename)
    if not texture or not classFilename then
        return false
    end

    if Key.Api.Middleware:Guard(false, classFilename) then
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
    self:EnsureTokenParts(token)
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
    local level = Key.Keystones and Key.Keystones:AsAccessibleNumber(token.level) or nil
    tokenFrame.text:SetText(level and tostring(level) or "?")
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
    slot.dungeonName = self:GetDungeonDisplayName(dungeon.challengeModeID, dungeon.shortName)

    slot.icon:SetTexture(self:GetDungeonTexture(dungeon.challengeModeID))
    slot.icon:SetDesaturated(false)
    slot.icon:SetAlpha(1)

    if InCombatLockdown() then
        return
    end

    slot.action:SetAttribute("type", "spell")
    slot.action:SetAttribute("spell", dungeon.spellID)

    if self:IsSpellKnown(dungeon.spellID) then
        slot.action:Enable()
        slot.action:EnableMouse(true)
    else
        slot:SetBackdropBorderColor(unpack(Key.UI:GetTheme().slotBorder))
        slot.icon:SetDesaturated(true)
        slot.icon:SetAlpha(0.45)
        slot.action:Disable()
        slot.action:EnableMouse(false)
        if slot.cooldown then
            slot.cooldown:Clear()
        end
    end
end

function Teleports:EnsureSlotCooldown(slot)
    if not slot then
        return
    end

    if slot.cooldownTop then
        slot.cooldownTop:Hide()
        slot.cooldownTop = nil
    end

    if slot.cooldownBottom then
        slot.cooldownBottom:Hide()
        slot.cooldownBottom = nil
    end

    if slot.cooldown then
        return
    end

    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints(slot.icon)
    cooldown:SetFrameLevel(slot:GetFrameLevel() + self.COOLDOWN_FRAME_LEVEL_OFFSET)
    cooldown:SetDrawEdge(true)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:EnableMouse(false)
    cooldown:SetScript("OnCooldownDone", function()
        Teleports:UpdateSlotCooldown(slot, slot:GetWidth())
        Teleports:RefreshCooldownUI()
    end)
    slot.cooldown = cooldown
end

function Teleports:UpdateSlotCooldown(slot, slotSize)
    if not slot or not slot.spellID then
        return false
    end

    self:EnsureSlotCooldown(slot)

    if not self:IsSpellKnown(slot.spellID) then
        if slot.cooldown then
            slot.cooldown:Clear()
        end
        return false
    end

    local theme = Key.UI:GetTheme()
    local startTime, duration = self:GetSpellCooldownInfo(slot.spellID)
    local onCooldown = startTime ~= nil

    if slotSize then
        slot.cooldown:SetHideCountdownNumbers(self:IsCompactSlot(slotSize))
    end

    if onCooldown then
        slot:SetBackdropBorderColor(unpack(theme.slotBorder))
        slot.icon:SetDesaturated(true)
        slot.icon:SetAlpha(0.65)

        if slot.cooldownStart ~= startTime or slot.cooldownDuration ~= duration then
            slot.cooldown:SetCooldown(startTime, duration)
            slot.cooldownStart = startTime
            slot.cooldownDuration = duration
        end
    else
        slot:SetBackdropBorderColor(unpack(theme.slotActiveBorder))
        slot.icon:SetDesaturated(false)
        slot.icon:SetAlpha(1)
        slot.cooldown:Clear()
        slot.cooldownStart = nil
        slot.cooldownDuration = nil
    end

    return onCooldown
end

function Teleports:SetCooldownTicker(active)
    if active then
        if self.cooldownTicker then
            return
        end

        self.cooldownTicker = Key.Api.Timer:NewTicker(false, self.COOLDOWN_TICK_INTERVAL, function()
            Teleports:RefreshCooldownUI()
        end)
        return
    end

    if self.cooldownTicker then
        self.cooldownTicker:Cancel()
        self.cooldownTicker = nil
    end
end

function Teleports:RefreshCooldownUI()
    if not self.bar then
        self:SetCooldownTicker(false)
        return
    end

    local anyOnCooldown = false
    for i, dungeon in ipairs(self.SEASON_DUNGEONS) do
        local slot = self.bar.slots[i]
        if slot and self:UpdateSlotCooldown(slot, slot:GetWidth()) then
            anyOnCooldown = true
        end
    end

    self:SetCooldownTicker(anyOnCooldown)
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

    slot.label:SetWidth(math.max(0, slotSize - 12))
    slot.label:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    slot.label:SetTextColor(1, 1, 1, 1)
    slot.label:SetText(dungeon.shortName)
    slot.label:Show()
end

function Teleports:UpdateSlot(slot, dungeon, tokens, slotWidth, slotHeight)
    self:UpdateSlotBorder(slot, dungeon)
    self:UpdateSlotCooldown(slot, slotWidth)
    self:ApplySlotLabel(slot, dungeon, slotWidth)
    self:UpdateSlotTokens(slot, tokens, slotWidth, slotHeight)
    self:ConfigureSlotMouseLayers(slot)
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
        if bar:GetHeight() <= 1 then
            self:LayoutBar(bar, self:GetDefaultContentWidth())
        end
    end
    return bar
end

function Teleports:LayoutBar(bar, contentWidth)
    local function run()
        return self:LayoutBarInternal(bar, contentWidth)
    end

    if Key.Log and Key.Log.RunProtected then
        local ok, height = Key.Log:RunProtected("Teleports:LayoutBar", run)
        if ok and height then
            return height
        end
        return self.SLOT_MIN + self.LAYOUT_GAP
    end

    return run()
end

function Teleports:LayoutBarInternal(bar, contentWidth)
    local columns, rows, slotSize = self:ComputeLayout(contentWidth)
    local gap = self.LAYOUT_GAP
    local pitch = slotSize + gap
    local tokensByMap = Key.Keystones and Key.Keystones:GetPartyKeyTokensByMap() or {}

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

        self:UpdateSlot(slot, dungeon, tokensByMap[dungeon.challengeModeID], slotSize, slotSize)
        slot:Show()
    end

    local barHeight = (rows * slotSize) + ((rows - 1) * gap)
    bar:SetSize(contentWidth, barHeight)

    if Key.TeleportBarLog and Key.TeleportBarLog.LogBarLayout then
        Key.TeleportBarLog:LogBarLayout(contentWidth, barHeight, slotSize)
    end

    self:RefreshCooldownUI()

    return barHeight, slotSize, pitch
end

function Teleports:RefreshActionButtons()
    if not self.bar or InCombatLockdown() then
        return
    end

    for i, dungeon in ipairs(self.SEASON_DUNGEONS) do
        local slot = self.bar.slots[i]
        if slot then
            self:UpdateSlotBorder(slot, dungeon)
            self:ConfigureSlotMouseLayers(slot)
        end
    end

    self:RefreshCooldownUI()
end

function Teleports:BuildSpellIndex()
    self.spellToDungeon = {}
    for _, dungeon in ipairs(self.SEASON_DUNGEONS) do
        self.spellToDungeon[dungeon.spellID] = dungeon
    end
end

function Teleports:IsSeasonTeleport(spellID)
    return self.spellToDungeon and self.spellToDungeon[spellID] ~= nil
end

function Teleports:InitEvents()
    if self.eventFrame then
        return
    end

    self:BuildSpellIndex()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function(_, event, ...)
        local args = { ... }

        local function HandleEvent()
            if event == "PLAYER_REGEN_ENABLED" or event == "SPELLS_CHANGED" then
                Teleports:RefreshActionButtons()
                if event == "SPELLS_CHANGED"
                    and Key.TeleportBarLog
                    and Key.TeleportBarLog.LogRefreshActionButtons
                then
                    Key.TeleportBarLog:LogRefreshActionButtons()
                end
                return
            end

            if event == "SPELL_UPDATE_COOLDOWN" then
                Teleports:RefreshCooldownUI()
                return
            end

            if event == "UNIT_SPELLCAST_SENT" then
                local unit, _, _, spellID = unpack(args)
                if unit ~= "player" or not Teleports:IsSeasonTeleport(spellID) then
                    return
                end

                if Key.TeleportBarLog and Key.TeleportBarLog.LogTeleport then
                    Key.TeleportBarLog:LogTeleport(spellID, "cast")
                end

                Teleports:RefreshCooldownUI()
                return
            end

            if event == "UI_ERROR_MESSAGE" then
                local arg1, arg2 = unpack(args)
                local message = type(arg2) == "string" and arg2 or (type(arg1) == "string" and arg1 or nil)
                if not message or message == "" then
                    return
                end

                local spellID = Teleports.lastClickSpellID
                local clickAge = Key.Api.Timer:GetTime(false) - (Teleports.lastClickTime or 0)
                if not spellID or clickAge > 1 or not Teleports:IsSeasonTeleport(spellID) then
                    return
                end

                if message:find("not ready", 1, true)
                    or message:find("cooldown", 1, true)
                    or message:find("Can't do that yet", 1, true)
                then
                    if Key.TeleportBarLog and Key.TeleportBarLog.LogTeleport then
                        Key.TeleportBarLog:LogTeleport(spellID, "error", message)
                    end
                end
            end
        end

        if Key.Log and Key.Log.RunProtected then
            Key.Log:RunProtected("Teleports:" .. tostring(event), HandleEvent)
        else
            HandleEvent()
        end
    end)

    self.eventFrame = frame
end

Teleports:InitEvents()
Teleports:InitBar()

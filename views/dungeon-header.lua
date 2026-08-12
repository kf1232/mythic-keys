Key.Views = Key.Views or {}

local DungeonHeader = {}
Key.Views.DungeonHeader = DungeonHeader

local Spells = Key.Data.DungeonTeleportSpells
local Spell = Key.Util.Spell
local ActionButton = Key.Util.ActionButton
local Chat = Key.Util.Chat
local CombatLockdown = Key.Util.CombatLockdown
local OwnedKeystone = Key.Data.OwnedKeystone
local ClassIcon = Key.Util.ClassIcon
local ChallengeMode = Key.Util.ChallengeMode

local activeHeaders = {}
local cooldownEvents
local keystoneListenerBound = false

local QUESTION_MARK_ICON = 134400
local BADGE_ICON_SIZE = 22
local BADGE_BORDER = 3
local BADGE_SIZE = BADGE_ICON_SIZE + (BADGE_BORDER * 2)
local BADGE_PAD = 3
local BADGE_GAP = 2
local BADGE_BORDER_COLOR = { 1, 0.82, 0, 1 }

local function ClearButtonArt(button)
    if not button then
        return
    end
    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end
    if button.SetPushedTexture then
        button:SetPushedTexture("")
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("")
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture("")
    end
end

local function ResolveDungeonIcon(dungeon)
    -- Prefer live challenge-mode texture; config FileIDs can go stale across patches.
    if dungeon and dungeon.id and ChallengeMode and ChallengeMode.GetMapUIInfo then
        local info = ChallengeMode.GetMapUIInfo(dungeon.id)
        if info and info.texture and info.texture ~= 0 then
            return info.texture
        end
    end
    if dungeon and dungeon.icon and dungeon.icon ~= 0 then
        return dungeon.icon
    end
    return QUESTION_MARK_ICON
end

local function ApplyDungeonIcon(texture, dungeon)
    if not texture then
        return
    end
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetTexture(ResolveDungeonIcon(dungeon))
end

local function GetSpellForMap(mapChallengeModeID)
    local spellIDs = Spells.GetSpellIDs(mapChallengeModeID, UnitFactionGroup("player"))
    return Spell.ResolveBestKnown(spellIDs)
end

local function RaiseClickSurface(headerFrame)
    if not headerFrame then
        return
    end

    local base = headerFrame:GetFrameLevel()
    if headerFrame.castButton then
        headerFrame.castButton:SetFrameLevel(base + 10)
    end
    if headerFrame.msgButton then
        headerFrame.msgButton:SetFrameLevel(base + 10)
    end
end

local function AttachChromeTo(headerFrame, button)
    local chrome = headerFrame.chrome
    if not chrome or not button then
        return
    end

    chrome:SetParent(button)
    chrome:ClearAllPoints()
    chrome:SetAllPoints(button)
    chrome:EnableMouse(false)
    chrome:SetFrameLevel(button:GetFrameLevel() + 1)
    chrome:Show()
end

local function SetClassIconTexture(texture, classFile)
    ClassIcon.Set(texture, classFile)
end

local function EnsureBadge(headerFrame, index)
    headerFrame.keyBadges = headerFrame.keyBadges or {}
    local badge = headerFrame.keyBadges[index]
    if badge then
        return badge
    end

    local chrome = headerFrame.chrome
    badge = CreateFrame("Frame", nil, chrome)
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    badge:EnableMouse(false)

    badge.border = badge:CreateTexture(nil, "BACKGROUND")
    badge.border:SetAllPoints(badge)
    badge.border:SetColorTexture(
        BADGE_BORDER_COLOR[1],
        BADGE_BORDER_COLOR[2],
        BADGE_BORDER_COLOR[3],
        BADGE_BORDER_COLOR[4]
    )

    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    badge.icon:SetPoint("TOPLEFT", badge, "TOPLEFT", BADGE_BORDER, -BADGE_BORDER)
    badge.icon:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -BADGE_BORDER, BADGE_BORDER)
    if badge.icon.SetMouseClickEnabled then
        badge.icon:SetMouseClickEnabled(false)
    end

    headerFrame.keyBadges[index] = badge
    return badge
end

local function UpdateKeyBadges(headerFrame)
    if not headerFrame or not headerFrame.chrome or not OwnedKeystone then
        return
    end

    local holders = OwnedKeystone.GetHoldersForMap(headerFrame.mapChallengeModeID)
    headerFrame.keyHolders = holders

    local badges = headerFrame.keyBadges or {}
    for i = 1, #badges do
        badges[i]:Hide()
    end

    for i = 1, #holders do
        local badge = EnsureBadge(headerFrame, i)
        local holder = holders[i]
        SetClassIconTexture(badge.icon, holder.classFile)
        badge:ClearAllPoints()
        badge:SetPoint(
            "TOPRIGHT",
            headerFrame.chrome,
            "TOPRIGHT",
            -BADGE_PAD - ((i - 1) * (BADGE_SIZE + BADGE_GAP)),
            -BADGE_PAD
        )
        badge:Show()
    end
end

local function ApplyTooltip(headerFrame, spellID, isKnown)
    local dungeonName = headerFrame.dungeonName or "Dungeon"

    local function ShowTip(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText(dungeonName, 1, 1, 1)
        if spellID and isKnown then
            GameTooltip:AddLine("Click to teleport.", 0.8, 0.8, 0.8)
        elseif spellID then
            GameTooltip:AddLine("Teleport not unlocked.", 1, 0.5, 0.5)
        else
            GameTooltip:AddLine("No teleport available.", 1, 0.5, 0.5)
        end

        local holders = headerFrame.keyHolders
        if holders then
            for i = 1, #holders do
                local holder = holders[i]
                local who
                if holder.unit == "player" then
                    who = "Your key"
                elseif holder.name then
                    who = holder.name
                    if holder.realm and holder.realm ~= "" then
                        who = who .. " - " .. holder.realm
                    end
                else
                    who = "Key"
                end
                if holder.level then
                    GameTooltip:AddLine(string.format("%s: +%d", who, holder.level), 0.6, 0.9, 1)
                else
                    GameTooltip:AddLine(who, 0.6, 0.9, 1)
                end
            end
        end
        GameTooltip:Show()
    end

    local function BindTip(frame)
        if not frame then
            return
        end
        frame:SetScript("OnEnter", function(self)
            ShowTip(self)
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    BindTip(headerFrame)
    BindTip(headerFrame.castButton)
    BindTip(headerFrame.msgButton)
end

local function HandleUnavailableClick(headerFrame)
    local dungeonName = headerFrame.dungeonName or "this dungeon"
    local spellID = GetSpellForMap(headerFrame.mapChallengeModeID)

    if spellID then
        Chat.Print(string.format("You have not unlocked teleport to %s.", dungeonName))
        return
    end

    Chat.Print(string.format("No teleport available for %s.", dungeonName))
end

local function UpdateCooldown(headerFrame, spellID, isKnown)
    local cooldown = headerFrame and headerFrame.cooldown
    if not cooldown then
        return
    end

    if not spellID or not isKnown then
        cooldown:Clear()
        return
    end

    local start, duration, enabled = Spell.GetCooldown(spellID)
    if enabled ~= false and start and duration and duration > 0 then
        cooldown:SetCooldown(start, duration)
    else
        cooldown:Clear()
    end
end

local function RefreshHeader(headerFrame)
    if not headerFrame or not headerFrame.castButton or not headerFrame.msgButton then
        return
    end

    local castButton = headerFrame.castButton
    local msgButton = headerFrame.msgButton
    local spellID, isKnown = GetSpellForMap(headerFrame.mapChallengeModeID)
    headerFrame.spellID = spellID
    headerFrame.isKnown = isKnown

    RaiseClickSurface(headerFrame)
    ApplyTooltip(headerFrame, spellID, isKnown)

    if spellID and isKnown then
        ActionButton.SetSpellCast(castButton, spellID)
        castButton:Show()
        msgButton:Hide()
        AttachChromeTo(headerFrame, castButton)
    else
        ActionButton.ClearCast(castButton)
        castButton:Hide()
        msgButton:Show()
        msgButton:SetScript("OnClick", function()
            HandleUnavailableClick(headerFrame)
        end)
        AttachChromeTo(headerFrame, msgButton)
    end

    UpdateCooldown(headerFrame, spellID, isKnown)
    UpdateKeyBadges(headerFrame)
end

local function RefreshAllCooldowns()
    for i = 1, #activeHeaders do
        local headerFrame = activeHeaders[i]
        if headerFrame and headerFrame:IsShown() then
            UpdateCooldown(headerFrame, headerFrame.spellID, headerFrame.isKnown)
        end
    end
end

local function RefreshAllDungeonIcons()
    for i = 1, #activeHeaders do
        local headerFrame = activeHeaders[i]
        if headerFrame and headerFrame.icon then
            ApplyDungeonIcon(headerFrame.icon, headerFrame.dungeon)
        end
    end
end

local function RefreshAllKeyBadges()
    for i = 1, #activeHeaders do
        local headerFrame = activeHeaders[i]
        if headerFrame and headerFrame:IsShown() then
            UpdateKeyBadges(headerFrame)
        end
    end
end

local function EnsureCooldownEvents()
    if cooldownEvents then
        return
    end

    cooldownEvents = CreateFrame("Frame")
    cooldownEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    cooldownEvents:RegisterEvent("SPELL_UPDATE_USABLE")
    cooldownEvents:RegisterEvent("BAG_UPDATE_COOLDOWN")
    cooldownEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    cooldownEvents:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            RefreshAllDungeonIcons()
        end
        RefreshAllCooldowns()
    end)
end

local function EnsureKeystoneListener()
    if keystoneListenerBound or not OwnedKeystone then
        return
    end
    keystoneListenerBound = true
    OwnedKeystone.OnChanged(RefreshAllKeyBadges)
end

local function AttachHeader(headerFrame, castButton, msgButton, mapChallengeModeID, dungeonName)
    headerFrame.mapChallengeModeID = mapChallengeModeID
    headerFrame.dungeonName = dungeonName
    headerFrame.castButton = castButton
    headerFrame.msgButton = msgButton

    activeHeaders[#activeHeaders + 1] = headerFrame
    EnsureCooldownEvents()
    EnsureKeystoneListener()

    ActionButton.RegisterCastClicks(castButton)
    CombatLockdown.RunWhenSafe(headerFrame, function()
        RefreshHeader(headerFrame)
    end)
end

function DungeonHeader.Create(parent, dungeon, x, y, iconSize, headerHeight)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(iconSize, headerHeight or iconSize)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:EnableMouse(true)

    local castButton = CreateFrame("Button", nil, header, "InsecureActionButtonTemplate")
    castButton:SetAllPoints(header)
    castButton:EnableMouse(true)
    ClearButtonArt(castButton)

    local msgButton = CreateFrame("Button", nil, header)
    msgButton:SetAllPoints(header)
    msgButton:EnableMouse(true)
    msgButton:RegisterForClicks("LeftButtonUp")
    ClearButtonArt(msgButton)

    -- Owned by the active click button so visuals never sit above the hit target.
    local chrome = CreateFrame("Frame", nil, castButton)
    chrome:SetAllPoints(castButton)
    chrome:EnableMouse(false)
    header.chrome = chrome

    -- Icon lives on chrome so it stays visible above empty action-button layers.
    local icon = chrome:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(chrome)
    if icon.SetMouseClickEnabled then
        icon:SetMouseClickEnabled(false)
    end
    ApplyDungeonIcon(icon, dungeon)
    header.icon = icon
    header.dungeon = dungeon

    local cooldown = CreateFrame("Cooldown", nil, chrome, "CooldownFrameTemplate")
    cooldown:SetAllPoints(chrome)
    cooldown:EnableMouse(false)
    cooldown:SetDrawEdge(true)
    cooldown:SetDrawBling(false)
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(false)
    end
    if cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(0, 0, 0, 0.7)
    end
    header.cooldown = cooldown

    local label = chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 2, 3)
    label:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -2, 3)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(dungeon.short or dungeon.name or "")
    header.label = label

    RaiseClickSurface(header)
    AttachChromeTo(header, castButton)
    AttachHeader(header, castButton, msgButton, dungeon.id, dungeon.name)
    return header
end

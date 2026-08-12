Key.Views = Key.Views or {}

local History = {}
Key.Views.KeysHistory = History

local Frame = Key.Views.Frame
local KeysHistory = Key.Data.KeysHistory

local FRAME_WIDTH = 680
local FRAME_HEIGHT = 420
local LIST_WIDTH = 130
local ENTRY_HEIGHT = 34
local PLAYER_ROW_HEIGHT = 30
local RATE_BTN_SIZE = 26
local NAME_WIDTH = 170
local RATING_WIDTH = 48
local ILVL_WIDTH = 40
local DELETE_BTN_SIZE = 22
-- Other players only (local player is never stored). Show delete when over a 5-man party.
local CLEANUP_PLAYER_THRESHOLD = 4
local LAYOUT_VERSION = 9

-- Blizzard ready-check icons (always green / always red).
local TEXTURE_PASS = "Interface\\RaidFrame\\ReadyCheck-Ready"
local TEXTURE_FAIL = "Interface\\RaidFrame\\ReadyCheck-NotReady"

local frame
local entryButtons = {}
local playerRows = {}
local selectedEntryId
local listScroll
local listChild
local detailScroll
local detailChild
local detailTitle
local detailEmpty
local listEmpty

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

local function AttachMouseWheel(scroll, step)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = 0
        local child = self:GetScrollChild()
        if child then
            maxScroll = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
        end
        local nextScroll = math.min(maxScroll, math.max(0, current - (delta * step)))
        self:SetVerticalScroll(nextScroll)
    end)
end

local function CreateMarkButton(parent, kind)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(RATE_BTN_SIZE, RATE_BTN_SIZE)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn.kind = kind

    -- Selection ring (hidden until chosen).
    btn.ring = btn:CreateTexture(nil, "BACKGROUND")
    btn.ring:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
    btn.ring:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
    btn.ring:SetColorTexture(1, 0.82, 0, 0.95)
    btn.ring:Hide()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)

    if kind == KeysHistory.RATING_PASS then
        btn.icon:SetTexture(TEXTURE_PASS)
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 1, 1, 1)
    elseif kind == KeysHistory.RATING_FAIL then
        btn.icon:SetTexture(TEXTURE_FAIL)
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 1, 1, 1)
    else
        btn.icon:Hide()
        btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        btn.label:SetPoint("CENTER", btn, "CENTER", 0, 1)
        btn.label:SetText("~")
        btn.label:SetTextColor(1, 0.82, 0.2)
    end

    return btn
end

local function SetMarkButtonVisual(btn, active)
    btn.active = active and true or false

    -- Colors stay on the icons always. Selection is the gold ring only.
    if btn.kind == KeysHistory.RATING_NEUTRAL then
        btn.label:SetTextColor(1, 0.82, 0.2)
        btn.label:SetAlpha(active and 1 or 0.85)
    else
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 1, 1, 1)
        btn.icon:SetAlpha(active and 1 or 0.85)
    end

    if active then
        btn.ring:Show()
    else
        btn.ring:Hide()
    end
end

local function EnsureEntryButton(index)
    local btn = entryButtons[index]
    if btn then
        return btn
    end

    btn = CreateFrame("Button", nil, listChild)
    btn:SetSize(LIST_WIDTH - 4, ENTRY_HEIGHT)
    btn:RegisterForClicks("LeftButtonUp")

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
    btn.bg:Hide()

    btn.title = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.title:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -4)
    btn.title:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -4)
    btn.title:SetJustifyH("LEFT")
    btn.title:SetWordWrap(false)

    btn.meta = btn:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    btn.meta:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 6, 4)
    btn.meta:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -6, 4)
    btn.meta:SetJustifyH("LEFT")
    btn.meta:SetWordWrap(false)

    btn:SetScript("OnClick", function(self)
        selectedEntryId = self.entryId
        History:Refresh()
    end)

    entryButtons[index] = btn
    return btn
end

local function EnsurePlayerRow(index)
    local row = playerRows[index]
    if row and row.layoutVersion == LAYOUT_VERSION then
        return row
    end

    if row then
        row:Hide()
        row:SetParent(nil)
    end

    row = CreateFrame("Frame", nil, detailChild)
    row:SetHeight(PLAYER_ROW_HEIGHT)
    row.layoutVersion = LAYOUT_VERSION

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.rating = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.rating:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.rating:SetWidth(RATING_WIDTH)
    row.rating:SetJustifyH("RIGHT")

    row.ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.ilvl:SetPoint("LEFT", row.rating, "RIGHT", 8, 0)
    row.ilvl:SetWidth(ILVL_WIDTH)
    row.ilvl:SetJustifyH("RIGHT")

    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(DELETE_BTN_SIZE, DELETE_BTN_SIZE)
    row.deleteBtn:EnableMouse(true)
    row.deleteBtn:RegisterForClicks("LeftButtonUp")
    row.deleteBtn.label = row.deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.deleteBtn.label:SetPoint("CENTER", row.deleteBtn, "CENTER", 0, 0)
    row.deleteBtn.label:SetText("×")
    row.deleteBtn.label:SetTextColor(0.95, 0.35, 0.35)
    row.deleteBtn:SetScript("OnEnter", function(self)
        self.label:SetTextColor(1, 0.55, 0.55)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Remove from this run")
        GameTooltip:Show()
    end)
    row.deleteBtn:SetScript("OnLeave", function(self)
        self.label:SetTextColor(0.95, 0.35, 0.35)
        GameTooltip:Hide()
    end)
    row.deleteBtn:SetScript("OnClick", function()
        if not row.entryId or not row.playerIndex then
            return
        end
        KeysHistory.RemovePlayer(row.entryId, row.playerIndex)
    end)

    row.passBtn = CreateMarkButton(row, KeysHistory.RATING_PASS)
    row.neutralBtn = CreateMarkButton(row, KeysHistory.RATING_NEUTRAL)
    row.failBtn = CreateMarkButton(row, KeysHistory.RATING_FAIL)

    row.neutralBtn:SetPoint("RIGHT", row.failBtn, "LEFT", -4, 0)
    row.passBtn:SetPoint("RIGHT", row.neutralBtn, "LEFT", -4, 0)

    local function BindMark(button, mark)
        button:SetScript("OnClick", function()
            if not row.entryId or not row.playerIndex then
                return
            end
            KeysHistory.SetPlayerMark(row.entryId, row.playerIndex, mark)
        end)
    end

    BindMark(row.passBtn, KeysHistory.RATING_PASS)
    BindMark(row.failBtn, KeysHistory.RATING_FAIL)
    BindMark(row.neutralBtn, KeysHistory.RATING_NEUTRAL)

    playerRows[index] = row
    return row
end

local function PopulateDetail(entry)
    for i = 1, #playerRows do
        playerRows[i]:Hide()
    end

    if not entry then
        detailTitle:SetText("Select a run")
        detailEmpty:SetText("Enter a mythic dungeon or start a keystone to begin tracking.")
        detailEmpty:Show()
        detailChild:SetHeight(1)
        return
    end

    detailTitle:SetText(KeysHistory.FormatEntryTitle(entry) .. "  ·  " .. KeysHistory.FormatEntryDate(entry))
    local players = entry.players or {}
    if #players == 0 then
        detailEmpty:SetText("No players were snapshotted for this run.")
        detailEmpty:Show()
        detailChild:SetHeight(1)
        return
    end

    detailEmpty:Hide()
    local showDelete = #players > CLEANUP_PLAYER_THRESHOLD
    local y = 0
    for i = 1, #players do
        local player = players[i]
        local row = EnsurePlayerRow(i)
        row.entryId = entry.id
        row.playerIndex = i

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", detailChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", detailChild, "TOPRIGHT", 0, -y)

        local color = player.classFile and RAID_CLASS_COLORS[player.classFile]
        row.name:SetText(KeysHistory.FormatPlayerName(player))
        if color then
            row.name:SetTextColor(color.r, color.g, color.b)
        else
            row.name:SetTextColor(1, 1, 1)
        end

        row.rating:SetText(player.rating and tostring(player.rating) or "—")
        row.ilvl:SetText(player.itemLevel and tostring(player.itemLevel) or "—")

        SetMarkButtonVisual(row.passBtn, player.mark == KeysHistory.RATING_PASS)
        SetMarkButtonVisual(row.failBtn, player.mark == KeysHistory.RATING_FAIL)
        SetMarkButtonVisual(row.neutralBtn, player.mark == KeysHistory.RATING_NEUTRAL)

        row.failBtn:ClearAllPoints()
        row.deleteBtn:ClearAllPoints()
        if showDelete then
            row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.failBtn:SetPoint("RIGHT", row.deleteBtn, "LEFT", -4, 0)
            row.deleteBtn:Show()
        else
            row.deleteBtn:Hide()
            row.failBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        end

        row:Show()
        y = y + PLAYER_ROW_HEIGHT
    end

    detailChild:SetHeight(math.max(1, y))
end

function History:Refresh()
    if not frame then
        return
    end

    local entries = KeysHistory.GetEntries()
    for i = 1, #entryButtons do
        entryButtons[i]:Hide()
    end

    if #entries == 0 then
        listEmpty:Show()
        selectedEntryId = nil
        listChild:SetHeight(1)
        PopulateDetail(nil)
        return
    end

    listEmpty:Hide()

    if not selectedEntryId then
        selectedEntryId = entries[1].id
    end

    local selectedStillExists = false
    local y = 0
    for i = 1, #entries do
        local entry = entries[i]
        local btn = EnsureEntryButton(i)
        btn.entryId = entry.id
        btn.title:SetText(KeysHistory.FormatEntryTitle(entry))
        btn.meta:SetText(KeysHistory.FormatEntryDate(entry))
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
        btn:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", 0, -y)

        local selected = entry.id == selectedEntryId
        if selected then
            selectedStillExists = true
            btn.bg:Show()
        else
            btn.bg:Hide()
        end

        btn:Show()
        y = y + ENTRY_HEIGHT + 2
    end

    if not selectedStillExists then
        selectedEntryId = entries[1].id
    end

    listChild:SetHeight(math.max(1, y))
    PopulateDetail(KeysHistory.GetEntry(selectedEntryId))
end

local function CreateView()
    frame = CreateFrame("Frame", "KeyKeysHistoryFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetText("Keys History")

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -28)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)

    listScroll = CreateFrame("ScrollFrame", nil, body)
    listScroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    listScroll:SetWidth(LIST_WIDTH)
    AttachMouseWheel(listScroll, ENTRY_HEIGHT * 2)

    listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(LIST_WIDTH - 4, 1)
    listScroll:SetScrollChild(listChild)

    listEmpty = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    listEmpty:SetPoint("TOPLEFT", listScroll, "TOPLEFT", 8, -8)
    listEmpty:SetWidth(LIST_WIDTH - 24)
    listEmpty:SetJustifyH("LEFT")
    listEmpty:SetText("No mythic runs tracked yet.")
    listEmpty:Hide()

    local divider = body:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.35, 0.35, 0.35, 0.8)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 10, 0)
    divider:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 10, 0)

    local detailPane = CreateFrame("Frame", nil, body)
    detailPane:SetPoint("TOPLEFT", divider, "TOPRIGHT", 10, 0)
    detailPane:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)

    local refreshBtn = CreateFrame("Button", nil, detailPane, "UIPanelButtonTemplate")
    refreshBtn:SetSize(72, 22)
    refreshBtn:SetPoint("TOPRIGHT", detailPane, "TOPRIGHT", 0, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        KeysHistory.RefreshGroup()
        -- Newest matching dungeon first (entries are newest-first).
        if GetInstanceInfo then
            local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
            local entries = KeysHistory.GetEntries()
            for i = 1, #entries do
                if entries[i].instanceID == instanceMapID then
                    selectedEntryId = entries[i].id
                    break
                end
            end
        end
        History:Refresh()
    end)

    detailTitle = detailPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", detailPane, "TOPLEFT", 0, 0)
    detailTitle:SetPoint("TOPRIGHT", refreshBtn, "TOPLEFT", -8, 0)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetWordWrap(false)

    local header = detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 4, -8)
    header:SetText("Player")

    local headerRating = detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerRating:SetPoint("LEFT", header, "LEFT", NAME_WIDTH + 8, 0)
    headerRating:SetWidth(RATING_WIDTH)
    headerRating:SetJustifyH("RIGHT")
    headerRating:SetText("Rating")

    local headerIlvl = detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerIlvl:SetPoint("LEFT", headerRating, "RIGHT", 8, 0)
    headerIlvl:SetWidth(ILVL_WIDTH)
    headerIlvl:SetJustifyH("RIGHT")
    headerIlvl:SetText("iLvl")

    local headerMark = detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerMark:SetPoint("RIGHT", detailPane, "RIGHT", -8, 0)
    headerMark:SetPoint("TOP", header, "TOP", 0, 0)
    headerMark:SetText("Mark")

    detailScroll = CreateFrame("ScrollFrame", nil, detailPane)
    detailScroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    detailScroll:SetPoint("BOTTOMRIGHT", detailPane, "BOTTOMRIGHT", 0, 0)
    AttachMouseWheel(detailScroll, PLAYER_ROW_HEIGHT * 3)

    local detailWidth = FRAME_WIDTH - LIST_WIDTH - 48
    detailChild = CreateFrame("Frame", nil, detailScroll)
    detailChild:SetSize(detailWidth, 1)
    detailScroll:SetScrollChild(detailChild)

    detailEmpty = detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    detailEmpty:SetPoint("TOPLEFT", detailScroll, "TOPLEFT", 4, -4)
    detailEmpty:SetPoint("TOPRIGHT", detailScroll, "TOPRIGHT", -4, -4)
    detailEmpty:SetJustifyH("LEFT")

    CreateCloseButton(frame)
    Frame.RegisterMain(frame)

    KeysHistory.OnChanged(function()
        if frame and frame:IsShown() then
            History:Refresh()
        end
    end)

    frame:Hide()
end

function History:Toggle()
    if frame and frame.layoutVersion ~= LAYOUT_VERSION then
        frame:Hide()
        frame:SetParent(nil)
        frame = nil
        entryButtons = {}
        playerRows = {}
        selectedEntryId = nil
    end

    if not frame then
        CreateView()
        frame.layoutVersion = LAYOUT_VERSION
    end

    if frame:IsShown() then
        frame:Hide()
    else
        self:Refresh()
        Frame.ShowMain(frame)
    end
end

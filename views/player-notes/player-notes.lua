Key.Views = Key.Views or {}

local PlayerNotes = {}
Key.Views.PlayerNotes = PlayerNotes

local Frame = Key.Views.Frame
local PlayerData = Key.Data.PlayerData

local NOTE_BTN_SIZE = 28
local NOTE_BTN_GAP = 6
local NOTE_ACTIONS_WIDTH = NOTE_BTN_SIZE * 2 + NOTE_BTN_GAP
local NOTE_BODY_WIDTH = 300
local CONTENT_PAD = 6
local ROW_PAD = 6
local DATE_TEXT_GAP = 6
local NOTE_ITEM_GAP = 14
local DELETE_BTN_SIZE = 20
local VIEW_LAYOUT_VERSION = 2
local MAX_NOTE_LENGTH = PlayerData.MAX_NOTE_LENGTH or 200

local viewFrame
local addFrame
local eventFrame

local function FormatNoteDate(noteTime)
    if date then
        return date("%Y-%m-%d %H:%M", noteTime)
    end
    return tostring(noteTime)
end

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

local function EnsureViewFrame()
    if viewFrame and viewFrame.layoutVersion == VIEW_LAYOUT_VERSION then
        return
    end

    if viewFrame then
        viewFrame:Hide()
        viewFrame = nil
    end

    viewFrame = CreateFrame("Frame", "KeyPlayerNotesFrame", UIParent, "BasicFrameTemplateWithInset")
    viewFrame:SetSize(360, 280)
    viewFrame:SetPoint("CENTER")
    viewFrame:SetMovable(true)
    viewFrame:EnableMouse(true)
    viewFrame:RegisterForDrag("LeftButton")
    viewFrame:SetScript("OnDragStart", viewFrame.StartMoving)
    viewFrame:SetScript("OnDragStop", viewFrame.StopMovingOrSizing)

    viewFrame.title = viewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    viewFrame.title:SetPoint("TOP", viewFrame, "TOP", 0, -5)
    viewFrame.title:SetWidth(320)
    viewFrame.title:SetJustifyH("CENTER")

    viewFrame.scroll = CreateFrame("ScrollFrame", nil, viewFrame, "UIPanelScrollFrameTemplate")
    viewFrame.scroll:SetPoint("TOPLEFT", viewFrame, "TOPLEFT", 12, -32)
    viewFrame.scroll:SetPoint("BOTTOMRIGHT", viewFrame, "BOTTOMRIGHT", -30, 12)

    viewFrame.content = CreateFrame("Frame", nil, viewFrame.scroll)
    viewFrame.content:SetWidth(NOTE_BODY_WIDTH)

    viewFrame.noteRows = {}
    viewFrame.layoutVersion = VIEW_LAYOUT_VERSION

    viewFrame.scroll:SetScrollChild(viewFrame.content)

    CreateCloseButton(viewFrame)
    Frame.RegisterNote(viewFrame)
    viewFrame:Hide()
end

local function HideNoteRows()
    for i = 1, #viewFrame.noteRows do
        viewFrame.noteRows[i]:Hide()
    end
    if viewFrame.emptyText then
        viewFrame.emptyText:Hide()
    end
end

local function GetOrCreateNoteRow(index)
    local row = viewFrame.noteRows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, viewFrame.content)

    row.date = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.date:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD, -ROW_PAD)
    row.date:SetWidth(NOTE_BODY_WIDTH - DELETE_BTN_SIZE - ROW_PAD * 3)
    row.date:SetJustifyH("LEFT")

    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(DELETE_BTN_SIZE, DELETE_BTN_SIZE)
    row.deleteBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -ROW_PAD, -ROW_PAD)
    row.deleteBtn:SetNormalFontObject("GameFontNormalSmall")
    row.deleteBtn:SetHighlightFontObject("GameFontHighlightSmall")
    row.deleteBtn:SetText("x")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.date, "BOTTOMLEFT", 0, -DATE_TEXT_GAP)
    row.text:SetWidth(NOTE_BODY_WIDTH - ROW_PAD * 2)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.text:SetNonSpaceWrap(true)

    viewFrame.noteRows[index] = row
    return row
end

local function LayoutNoteRows(unit, notes)
    HideNoteRows()

    if #notes == 0 then
        if not viewFrame.emptyText then
            viewFrame.emptyText = viewFrame.content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            viewFrame.emptyText:SetPoint("TOPLEFT", viewFrame.content, "TOPLEFT", CONTENT_PAD, -CONTENT_PAD)
            viewFrame.emptyText:SetWidth(NOTE_BODY_WIDTH - CONTENT_PAD * 2)
            viewFrame.emptyText:SetJustifyH("LEFT")
        end
        viewFrame.emptyText:SetText("No notes saved.")
        viewFrame.emptyText:Show()
        viewFrame.content:SetHeight(24)
        viewFrame.scroll:UpdateScrollChildRect()
        viewFrame.scroll:SetVerticalScroll(0)
        return
    end

    local yOffset = CONTENT_PAD
    for i = 1, #notes do
        local note = notes[i]
        local row = GetOrCreateNoteRow(i)
        local noteIndex = i

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", viewFrame.content, "TOPLEFT", 0, -yOffset)
        row:SetWidth(NOTE_BODY_WIDTH)

        row.date:SetText(FormatNoteDate(note.time))
        row.text:SetText(note.text)

        local rowHeight = ROW_PAD + row.date:GetStringHeight() + DATE_TEXT_GAP + row.text:GetStringHeight() + ROW_PAD
        row:SetHeight(rowHeight)
        row:Show()

        row.deleteBtn:SetScript("OnClick", function()
            PlayerData.DeleteNote(unit, noteIndex)
        end)

        yOffset = yOffset + rowHeight + NOTE_ITEM_GAP
    end

    viewFrame.content:SetHeight(math.max(yOffset - NOTE_ITEM_GAP + CONTENT_PAD, 24))
    viewFrame.scroll:UpdateScrollChildRect()
    viewFrame.scroll:SetVerticalScroll(0)
end

function PlayerNotes.RefreshView(unit)
    if not viewFrame then
        return
    end

    if unit and viewFrame.unit and viewFrame.unit ~= unit then
        return
    end

    unit = viewFrame.unit
    if not unit then
        return
    end

    local player = PlayerData.Get(unit)
    local notes = PlayerData.GetNotes(unit)

    viewFrame.title:SetText("Notes · " .. player.name)
    LayoutNoteRows(unit, notes)
end

local function EnsureAddFrame()
    if addFrame then
        return
    end

    addFrame = CreateFrame("Frame", "KeyPlayerNoteAddFrame", UIParent, "BasicFrameTemplateWithInset")
    addFrame:SetSize(360, 200)
    addFrame:SetPoint("CENTER")
    addFrame:SetMovable(true)
    addFrame:EnableMouse(true)
    addFrame:RegisterForDrag("LeftButton")
    addFrame:SetScript("OnDragStart", addFrame.StartMoving)
    addFrame:SetScript("OnDragStop", addFrame.StopMovingOrSizing)

    addFrame.title = addFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addFrame.title:SetPoint("TOP", addFrame, "TOP", 0, -5)
    addFrame.title:SetWidth(320)
    addFrame.title:SetJustifyH("CENTER")

    addFrame.inputBox = CreateFrame("Frame", nil, addFrame, "TooltipBorderBackdropTemplate")
    addFrame.inputBox:SetPoint("TOPLEFT", addFrame, "TOPLEFT", 16, -36)
    addFrame.inputBox:SetPoint("TOPRIGHT", addFrame, "TOPRIGHT", -16, -36)
    addFrame.inputBox:SetHeight(90)
    addFrame.inputBox:SetBackdropColor(0.05, 0.05, 0.05, 0.85)

    addFrame.input = CreateFrame("EditBox", nil, addFrame.inputBox)
    addFrame.input:SetPoint("TOPLEFT", addFrame.inputBox, "TOPLEFT", 8, -8)
    addFrame.input:SetPoint("BOTTOMRIGHT", addFrame.inputBox, "BOTTOMRIGHT", -8, 8)
    addFrame.input:SetAutoFocus(false)
    addFrame.input:SetFontObject("ChatFontNormal")
    addFrame.input:SetMultiLine(true)
    addFrame.input:SetMaxLetters(MAX_NOTE_LENGTH)
    addFrame.input:EnableMouse(true)
    addFrame.input:SetScript("OnEscapePressed", function()
        addFrame.input:ClearFocus()
        addFrame:Hide()
    end)

    addFrame.saveBtn = CreateFrame("Button", nil, addFrame, "UIPanelButtonTemplate")
    addFrame.saveBtn:SetSize(100, 22)
    addFrame.saveBtn:SetPoint("BOTTOMRIGHT", addFrame, "BOTTOMRIGHT", -16, 16)
    addFrame.saveBtn:SetText(SAVE or "Save")

    addFrame.cancelBtn = CreateFrame("Button", nil, addFrame, "UIPanelButtonTemplate")
    addFrame.cancelBtn:SetSize(100, 22)
    addFrame.cancelBtn:SetPoint("RIGHT", addFrame.saveBtn, "LEFT", -8, 0)
    addFrame.cancelBtn:SetText(CANCEL or "Cancel")

    addFrame.saveBtn:SetScript("OnClick", function()
        if not addFrame.unit then
            return
        end

        if PlayerData.AddNote(addFrame.unit, addFrame.input:GetText()) then
            addFrame.input:SetText("")
            addFrame:Hide()
        end
    end)

    addFrame.cancelBtn:SetScript("OnClick", function()
        addFrame.input:SetText("")
        addFrame:Hide()
    end)

    CreateCloseButton(addFrame)
    Frame.RegisterNote(addFrame)
    addFrame:Hide()
end

local function EnsureEventFrame()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:SetScript("OnEvent", function()
        PlayerNotes.RefreshView()
    end)
end

function PlayerNotes.GetActionsWidth()
    return NOTE_ACTIONS_WIDTH
end

function PlayerNotes.ShowAdd(unit)
    if not unit then
        return
    end

    EnsureAddFrame()

    local player = PlayerData.Get(unit)
    addFrame.unit = unit
    addFrame.title:SetText("Add note · " .. player.name)
    addFrame.input:SetText("")
    Frame.ShowNote(addFrame)
    addFrame.input:SetFocus()
end

function PlayerNotes.ShowView(unit)
    if not unit then
        return
    end

    EnsureViewFrame()
    EnsureEventFrame()

    viewFrame.unit = unit
    Frame.ShowNote(viewFrame)
    PlayerNotes.RefreshView()
end

function PlayerNotes.AttachRow(row)
    row.addBtn = CreateFrame("Button", nil, row)
    row.addBtn:SetSize(NOTE_BTN_SIZE, NOTE_BTN_SIZE)
    row.addBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.addBtn:SetNormalFontObject("GameFontNormal")
    row.addBtn:SetHighlightFontObject("GameFontHighlight")
    row.addBtn:SetText("+")

    row.viewBtn = CreateFrame("Button", nil, row)
    row.viewBtn:SetSize(NOTE_BTN_SIZE, NOTE_BTN_SIZE)
    row.viewBtn:SetPoint("RIGHT", row.addBtn, "LEFT", -NOTE_BTN_GAP, 0)
    row.viewBtn:SetNormalFontObject("GameFontNormal")
    row.viewBtn:SetHighlightFontObject("GameFontHighlight")
    row.viewBtn:SetText("?")

    row.viewBtn:SetScript("OnClick", function()
        if row.unit then
            PlayerNotes.ShowView(row.unit)
        end
    end)

    row.addBtn:SetScript("OnClick", function()
        if row.unit then
            PlayerNotes.ShowAdd(row.unit)
        end
    end)
end

function PlayerNotes.SetRowUnit(row, unit)
    if not row then
        return
    end
    row.unit = unit
    if unit then
        row.addBtn:Show()
        row.viewBtn:Show()
    else
        row.addBtn:Hide()
        row.viewBtn:Hide()
    end
end

PlayerData.OnNotesChanged = function(unit)
    pcall(PlayerNotes.RefreshView, unit)
end

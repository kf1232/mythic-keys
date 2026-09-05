Key.Views = Key.Views or {}

local PlayerNotes = {}
Key.Views.PlayerNotes = PlayerNotes

local NOTE_BTN_SIZE = 28
local NOTE_BTN_GAP = 6
local NOTE_ACTIONS_WIDTH = NOTE_BTN_SIZE * 2 + NOTE_BTN_GAP

function PlayerNotes.GetActionsWidth()
    return NOTE_ACTIONS_WIDTH
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
end

function PlayerNotes.SetRowUnit(row, unit)
    if not row then
        return
    end
    row.unit = unit
    if row.addBtn then
        row.addBtn:Show()
    end
    if row.viewBtn then
        row.viewBtn:Show()
    end
end

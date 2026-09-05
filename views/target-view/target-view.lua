Key.Views = Key.Views or {}

local Target = {}
Key.Views.Target = Target

local Frame = Key.Views.Frame
local DungeonHeader = Key.Views.DungeonHeader
local SeasonDungeons = Key.Data.SeasonDungeons
local PlayerNotes = Key.Views.PlayerNotes

local ROW_COUNT = 2
local ICON_SIZE = 100
local HEADER_HEIGHT = ICON_SIZE
local ROW_HEIGHT = 32
local NAME_WIDTH = 100
local COL_GAP = 8
local NAME_COL_GAP = 12
local TABLE_TOP = 44
local ROW_LABELS = { "You", "Target" }

local function ColumnLeft(columnIndex)
    return NAME_WIDTH + NAME_COL_GAP + (columnIndex - 1) * (ICON_SIZE + COL_GAP)
end

local function TableWidth(dungeonCount)
    if dungeonCount == 0 then
        return NAME_WIDTH + 16
    end
    return NAME_WIDTH + NAME_COL_GAP + dungeonCount * ICON_SIZE + (dungeonCount - 1) * COL_GAP + NAME_COL_GAP + PlayerNotes.GetActionsWidth() + 16
end

local frame
local memberRows = {}
local dungeonHeaders = {}

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

function Target:Refresh()
    if not frame then
        return
    end

    local dungeonCount = #SeasonDungeons.GetAll()
    frame.title:SetText("Compare · " .. SeasonDungeons.GetName())

    for i = 1, #dungeonHeaders do
        dungeonHeaders[i]:Show()
    end

    for i = 1, ROW_COUNT do
        local row = memberRows[i]
        row.name:SetText(ROW_LABELS[i])
        row.name:SetTextColor(1, 1, 1)
        for j = 1, dungeonCount do
            row.cells[j]:SetText("—")
            row.cells[j]:SetTextColor(0.5, 0.5, 0.5)
        end
        PlayerNotes.SetRowUnit(row, nil)
        row:Show()
    end
end

local function ResetFrame()
    if frame then
        frame:Hide()
        frame = nil
    end
    memberRows = {}
    dungeonHeaders = {}
end

local function CreateView()
    local dungeons = SeasonDungeons.GetAll()
    local dungeonCount = #dungeons
    local tableWidth = TableWidth(dungeonCount)

    frame = CreateFrame("Frame", "KeyTargetFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(tableWidth + 24, TABLE_TOP + HEADER_HEIGHT + ROW_COUNT * ROW_HEIGHT + 28)
    frame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetWidth(tableWidth)
    frame.title:SetJustifyH("CENTER")

    for j = 1, dungeonCount do
        dungeonHeaders[j] = DungeonHeader.Create(
            frame,
            dungeons[j],
            12 + ColumnLeft(j),
            -(TABLE_TOP - 4),
            ICON_SIZE,
            HEADER_HEIGHT
        )
    end

    for i = 1, ROW_COUNT do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(tableWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(TABLE_TOP + HEADER_HEIGHT + 4 + (i - 1) * ROW_HEIGHT))

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetWidth(NAME_WIDTH)
        row.name:SetJustifyH("RIGHT")

        row.cells = {}
        for j = 1, dungeonCount do
            local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            cell:SetPoint("LEFT", row, "LEFT", ColumnLeft(j), 0)
            cell:SetWidth(ICON_SIZE)
            cell:SetJustifyH("CENTER")
            row.cells[j] = cell
        end

        memberRows[i] = row
        PlayerNotes.AttachRow(row)
    end

    CreateCloseButton(frame)
    Frame.RegisterMain(frame)
    frame:Hide()
end

function Target:Toggle()
    if not frame or #memberRows == 0 then
        ResetFrame()
        local ok, err = pcall(CreateView)
        if not ok then
            ResetFrame()
            print("|cff00ff00Mythic Keys:|r", err)
            return
        end
    end

    if frame:IsShown() then
        frame:Hide()
    else
        self:Refresh()
        Frame.ShowMain(frame)
    end
end

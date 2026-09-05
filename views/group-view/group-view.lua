Key.Views = Key.Views or {}

local Group = {}
Key.Views.Group = Group

local Frame = Key.Views.Frame
local DungeonHeader = Key.Views.DungeonHeader
local SeasonDungeons = Key.Data.SeasonDungeons
local PlayerNotes = Key.Views.PlayerNotes

local MAX_MEMBERS = 5
local ICON_SIZE = 128
local HEADER_HEIGHT = ICON_SIZE
local ROW_HEIGHT = 32
local NAME_WIDTH = 100
local CLASS_ICON_SIZE = 18
local CLASS_ICON_GAP = 4
local NAME_TEXT_WIDTH = NAME_WIDTH - CLASS_ICON_SIZE - CLASS_ICON_GAP
local COL_GAP = 10
local NAME_COL_GAP = 12
local TABLE_TOP = 44
local EMPTY_SLOT_LABEL = "—"
local LAYOUT_VERSION = 3

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

local function PaintEmptyRow(row, dungeonCount)
    row.name:SetText(EMPTY_SLOT_LABEL)
    row.name:SetTextColor(0.5, 0.5, 0.5)
    if row.classIcon then
        row.classIcon:Hide()
    end
    for j = 1, dungeonCount do
        row.cells[j]:SetText(EMPTY_SLOT_LABEL)
        row.cells[j]:SetTextColor(0.5, 0.5, 0.5)
    end
    PlayerNotes.SetRowUnit(row, nil)
    row:Show()
end

function Group:Refresh()
    if not frame then
        return
    end

    local dungeons = SeasonDungeons.GetAll()
    local dungeonCount = #dungeons
    frame.title:SetText("Party · " .. SeasonDungeons.GetName())

    for i = 1, #dungeonHeaders do
        dungeonHeaders[i]:Show()
    end

    for i = 1, MAX_MEMBERS do
        PaintEmptyRow(memberRows[i], dungeonCount)
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

    frame = CreateFrame("Frame", "KeyGroupFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(tableWidth + 24, TABLE_TOP + HEADER_HEIGHT + MAX_MEMBERS * ROW_HEIGHT + 28)
    frame:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
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

    for i = 1, MAX_MEMBERS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(tableWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(TABLE_TOP + HEADER_HEIGHT + 4 + (i - 1) * ROW_HEIGHT))

        row.classIcon = row:CreateTexture(nil, "OVERLAY")
        row.classIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
        row.classIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.classIcon:Hide()

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row.classIcon, "RIGHT", CLASS_ICON_GAP, 0)
        row.name:SetWidth(NAME_TEXT_WIDTH)
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

function Group:Toggle()
    if frame and frame.layoutVersion ~= LAYOUT_VERSION then
        ResetFrame()
    end

    if not frame or #memberRows == 0 then
        ResetFrame()
        local ok, err = pcall(CreateView)
        if not ok then
            ResetFrame()
            print("|cff00ff00Mythic Keys:|r", err)
            return
        end
        frame.layoutVersion = LAYOUT_VERSION
    end

    if frame:IsShown() then
        frame:Hide()
    else
        self:Refresh()
        Frame.ShowMain(frame)
    end
end

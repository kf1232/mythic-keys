Key.Views = Key.Views or {}

local Target = {}
Key.Views.Target = Target

local Frame = Key.Views.Frame
local DungeonHeader = Key.Views.DungeonHeader
local SeasonDungeons = Key.Data.SeasonDungeons
local KeyData = Key.Data.KeyData
local PlayerData = Key.Data.PlayerData
local PlayerNotes = Key.Views.PlayerNotes

local ROW_COUNT = 2
local ICON_SIZE = 100
local HEADER_HEIGHT = ICON_SIZE
local ROW_HEIGHT = 32
local NAME_WIDTH = 100
local COL_GAP = 8
local NAME_COL_GAP = 12
local TABLE_TOP = 44

local COMPARE_UNITS = { "player", "target" }

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
local statusText

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

local function GetScope()
    if not UnitExists("target") then
        return false, "No player targeted."
    end

    if not UnitIsPlayer("target") then
        return false, "Target is not a player."
    end

    if UnitIsUnit("target", "player") then
        return false, "You cannot compare with yourself."
    end

    return true
end

local function PopulateRow(row, unit, dungeons, dungeonCount)
    PlayerNotes.SetRowUnit(row, unit)
    local player = PlayerData.Get(unit)
    local color = player.classFile and RAID_CLASS_COLORS[player.classFile]

    row.name:SetText(player.name)
    if color then
        row.name:SetTextColor(color.r, color.g, color.b)
    else
        row.name:SetTextColor(1, 1, 1)
    end

    for j = 1, dungeonCount do
        local dungeon = dungeons[j]
        row.cells[j]:SetText(KeyData.FormatSeasonBestForMap(unit, dungeon.id))
        row.cells[j]:SetTextColor(1, 1, 1)
    end

    row:Show()
end

local function WatchTargetKeyData()
    if not frame then
        return
    end

    KeyData.WatchUntilLive("target-view", function()
        local inScope = GetScope()
        if not inScope then
            return {}
        end
        return COMPARE_UNITS
    end, function()
        if frame and frame:IsShown() then
            Target:Refresh()
        end
    end)
end

function Target:Refresh()
    if not frame then
        return
    end

    local dungeons = SeasonDungeons.GetAll()
    local dungeonCount = #dungeons
    local inScope, scopeInfo = GetScope()

    if not inScope then
        KeyData.StopWatch("target-view")
        frame.title:SetText("Compare")
        statusText:SetText(scopeInfo)
        statusText:Show()
        for i = 1, #dungeonHeaders do
            dungeonHeaders[i]:Hide()
        end
        for i = 1, #memberRows do
            memberRows[i]:Hide()
        end
        return
    end

    frame.title:SetText(string.format("Compare · %s · %s", PlayerData.Get("target").name, SeasonDungeons.GetName()))
    statusText:Hide()

    for i = 1, #dungeonHeaders do
        dungeonHeaders[i]:Show()
    end

    for i = 1, ROW_COUNT do
        local row = memberRows[i]
        if not row then
            return
        end

        PopulateRow(row, COMPARE_UNITS[i], dungeons, dungeonCount)
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

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    statusText:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    statusText:SetWidth(tableWidth)
    statusText:SetJustifyH("CENTER")

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

    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            if frame:IsShown() then
                Target:Refresh()
                WatchTargetKeyData()
            end
        end
    end)

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
        KeyData.StopWatch("target-view")
        frame:Hide()
    else
        self:Refresh()
        WatchTargetKeyData()
        Frame.ShowMain(frame)
    end
end

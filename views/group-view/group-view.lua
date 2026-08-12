Key.Views = Key.Views or {}

local Group = {}
Key.Views.Group = Group

local Frame = Key.Views.Frame
local DungeonHeader = Key.Views.DungeonHeader
local SeasonDungeons = Key.Data.SeasonDungeons
local KeyData = Key.Data.KeyData
local PlayerData = Key.Data.PlayerData
local KeySync = Key.Data.KeySync
local PlayerNotes = Key.Views.PlayerNotes
local ClassIcon = Key.Util.ClassIcon

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
local LAYOUT_VERSION = 2

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
    if IsInRaid() then
        return false, "Party view is for 5-player groups (not raids)."
    end

    if not IsInGroup() then
        return true, 1
    end

    local size = GetNumGroupMembers()
    if size > MAX_MEMBERS then
        return false, "Group has more than 5 members."
    end

    return true, size
end

local function GetContextLabel()
    if not IsInGroup() then
        return "Solo"
    end

    if IsInInstance() then
        local instanceType = select(2, GetInstanceInfo())
        if instanceType == "party" then
            return "Instance group"
        end
        return "Instance"
    end
    return "Party"
end

local function CollectUnits()
    local units = { "player" }

    for i = 1, GetNumGroupMembers() do
        local unit = "party" .. i
        if UnitExists(unit) then
            units[#units + 1] = unit
        end
    end

    return units
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

    if player.classFile then
        ClassIcon.Set(row.classIcon, player.classFile)
    else
        ClassIcon.Hide(row.classIcon)
    end

    for j = 1, dungeonCount do
        local dungeon = dungeons[j]
        row.cells[j]:SetText(KeyData.FormatSeasonBestForMap(unit, dungeon.id))
        row.cells[j]:SetTextColor(1, 1, 1)
    end
end

local function WatchPartyKeyData()
    if not frame then
        return
    end

    KeyData.WatchUntilLive("group-view", function()
        local inScope = GetScope()
        if not inScope then
            return {}
        end
        return CollectUnits()
    end, function()
        if frame and frame:IsShown() then
            Group:Refresh()
        end
    end)
end

function Group:Refresh()
    if not frame then
        return
    end

    if KeySync and IsInGroup() then
        KeySync.PushAll(true)
        KeySync.RequestPartyKeys()
    end

    local dungeons = SeasonDungeons.GetAll()
    local dungeonCount = #dungeons
    local inScope, scopeInfo = GetScope()

    if not inScope then
        KeyData.StopWatch("group-view")
        frame.title:SetText("Party")
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

    frame.title:SetText(string.format("%s · %d/%d · %s", GetContextLabel(), scopeInfo, MAX_MEMBERS, SeasonDungeons.GetName()))
    statusText:Hide()

    for i = 1, #dungeonHeaders do
        dungeonHeaders[i]:Show()
    end

    local units = CollectUnits()
    for i = 1, MAX_MEMBERS do
        local row = memberRows[i]
        if not row then
            return
        end

        local unit = units[i]

        if unit then
            PopulateRow(row, unit, dungeons, dungeonCount)
        else
            PlayerNotes.SetRowUnit(row, nil)
            row.name:SetText(EMPTY_SLOT_LABEL)
            row.name:SetTextColor(0.5, 0.5, 0.5)
            ClassIcon.Hide(row.classIcon)
            for j = 1, dungeonCount do
                row.cells[j]:SetText("—")
                row.cells[j]:SetTextColor(0.5, 0.5, 0.5)
            end
        end

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

    for i = 1, MAX_MEMBERS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(tableWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(TABLE_TOP + HEADER_HEIGHT + 4 + (i - 1) * ROW_HEIGHT))

        row.classIcon = row:CreateTexture(nil, "OVERLAY")
        row.classIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
        row.classIcon:SetPoint("LEFT", row, "LEFT", 0, 0)

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

    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_CONNECTION")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            if frame:IsShown() then
                Group:Refresh()
                WatchPartyKeyData()
            else
                -- Warm cache while closed so joins still populate.
                local inScope = GetScope()
                if inScope then
                    local units = CollectUnits()
                    for i = 1, #units do
                        KeyData.GetSeasonRuns(units[i])
                    end
                    WatchPartyKeyData()
                end
            end
            return
        end

        if event == "UNIT_CONNECTION" or event == "UNIT_NAME_UPDATE" then
            if unit == "player" or (type(unit) == "string" and unit:match("^party%d+$")) then
                if frame:IsShown() then
                    Group:Refresh()
                    WatchPartyKeyData()
                end
            end
        end
    end)

    Frame.RegisterMain(frame)

    if KeySync then
        KeySync.OnChanged(function()
            if frame and frame:IsShown() then
                Group:Refresh()
            end
        end)
    end

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
        KeyData.StopWatch("group-view")
        frame:Hide()
    else
        self:Refresh()
        WatchPartyKeyData()
        Frame.ShowMain(frame)
    end
end

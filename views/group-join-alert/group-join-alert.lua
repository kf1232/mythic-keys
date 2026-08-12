Key.Views = Key.Views or {}

local Alert = {}
Key.Views.GroupJoinAlert = Alert

local Frame = Key.Views.Frame
local PlayerData = Key.Data.PlayerData
local KeysHistory = Key.Data.KeysHistory
local PlayerNotes = Key.Views.PlayerNotes

local FRAME_WIDTH = 300
local FRAME_HEIGHT = 220
local BODY_WIDTH = 268
local ROSTER_DEBOUNCE = 0.5
local MAX_NOTE_LINES = 4

local frame
local eventFrame
local rosterTimer
local alertQueue = {}
local rosterInitialized = false
local previousGuids = {}

local function GetDisplayName(unit)
    local record = PlayerData.Fetch(unit)
    local name = record.name or "Unknown"
    if record.realm and record.realm ~= "" then
        return name .. " - " .. record.realm
    end
    return name
end

local function CollectPartyUnits()
    local units = {}
    if not IsInGroup or not IsInGroup() then
        return units
    end

    if IsInRaid and IsInRaid() then
        return units
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            units[#units + 1] = unit
        end
    end
    return units
end

local function ShouldAlertForUnit(unit)
    if not unit or UnitIsUnit(unit, "player") then
        return false
    end

    local summary = KeysHistory.GetPlayerVoteSummary(unit)
    local notes = PlayerData.GetNotes(unit)
    return summary.marked > 0 or #notes > 0
end

local function FormatScoreLine(summary)
    if summary.marked == 0 then
        return "Vote score: —"
    end

    local sign = ""
    if summary.score > 0 then
        sign = "+"
    end

    return string.format(
        "Vote score: %s%d  (%d check, %d neutral, %d x)",
        sign,
        summary.score,
        summary.pass,
        summary.neutral,
        summary.fail
    )
end

local function ScoreColor(summary)
    if summary.marked == 0 then
        return 0.75, 0.75, 0.75
    end
    if summary.score > 0 then
        return 0.3, 0.9, 0.35
    end
    if summary.score < 0 then
        return 0.95, 0.35, 0.35
    end
    return 1, 0.82, 0.2
end

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

local function HideNoteLines()
    if not frame or not frame.noteLines then
        return
    end
    for i = 1, #frame.noteLines do
        frame.noteLines[i]:Hide()
    end
    if frame.notesEmpty then
        frame.notesEmpty:Hide()
    end
end

local function EnsureNoteLine(index)
    frame.noteLines = frame.noteLines or {}
    local line = frame.noteLines[index]
    if line then
        return line
    end

    line = frame.body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetWidth(BODY_WIDTH)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(true)
    frame.noteLines[index] = line
    return line
end

local function PopulateNotes(unit, notes, startY)
    HideNoteLines()

    if #notes == 0 then
        if not frame.notesEmpty then
            frame.notesEmpty = frame.body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            frame.notesEmpty:SetWidth(BODY_WIDTH)
            frame.notesEmpty:SetJustifyH("LEFT")
        end
        frame.notesEmpty:ClearAllPoints()
        frame.notesEmpty:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, startY)
        frame.notesEmpty:SetText("No notes saved.")
        frame.notesEmpty:Show()
        return startY - 18
    end

    local y = startY
    local shown = math.min(#notes, MAX_NOTE_LINES)
    for i = 1, shown do
        local note = notes[i]
        local line = EnsureNoteLine(i)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, y)
        line:SetText("• " .. (note.text or ""))
        line:Show()
        y = y - line:GetStringHeight() - 4
    end

    if #notes > shown then
        local line = EnsureNoteLine(shown + 1)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, y)
        line:SetText(string.format("… and %d more note(s)", #notes - shown))
        line:SetTextColor(0.6, 0.6, 0.6)
        line:Show()
        y = y - line:GetStringHeight() - 4
    end

    return y
end

local function PopulateFrame(unit)
    local player = PlayerData.Get(unit)
    local summary = KeysHistory.GetPlayerVoteSummary(unit)
    local notes = PlayerData.GetNotes(unit)
    local color = player.classFile and RAID_CLASS_COLORS[player.classFile]

    frame.unit = unit
    frame.title:SetText(GetDisplayName(unit))
    if color then
        frame.title:SetTextColor(color.r, color.g, color.b)
    else
        frame.title:SetTextColor(1, 1, 1)
    end

    frame.score:SetText(FormatScoreLine(summary))
    local sr, sg, sb = ScoreColor(summary)
    frame.score:SetTextColor(sr, sg, sb)

    frame.notesHeader:SetText("Notes")
    PopulateNotes(unit, notes, -36)

    frame.notesBtn:Enable()
    frame.notesBtn:SetScript("OnClick", function()
        PlayerNotes.ShowView(unit)
    end)
end

local function EnsureFrame()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "KeyGroupJoinAlertFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -120)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetWidth(BODY_WIDTH)
    frame.title:SetJustifyH("CENTER")
    frame.title:SetWordWrap(false)

    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -28)
    frame.body:SetSize(BODY_WIDTH, FRAME_HEIGHT - 72)

    frame.score = frame.body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.score:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, 0)
    frame.score:SetWidth(BODY_WIDTH)
    frame.score:SetJustifyH("LEFT")

    frame.notesHeader = frame.body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.notesHeader:SetPoint("TOPLEFT", frame.score, "BOTTOMLEFT", 0, -10)
    frame.notesHeader:SetJustifyH("LEFT")

    frame.notesBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.notesBtn:SetSize(90, 22)
    frame.notesBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    frame.notesBtn:SetText("All notes")

    CreateCloseButton(frame)
    Frame.RegisterNote(frame)

    frame:SetScript("OnHide", function()
        if #alertQueue > 0 then
            local nextUnit = table.remove(alertQueue, 1)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, function()
                    Alert.ShowForUnit(nextUnit)
                end)
            else
                Alert.ShowForUnit(nextUnit)
            end
        end
    end)

    frame:Hide()
end

function Alert.ShowForUnit(unit)
    if not unit or not ShouldAlertForUnit(unit) then
        return false
    end

    EnsureFrame()

    if frame:IsShown() then
        alertQueue[#alertQueue + 1] = unit
        return true
    end

    PopulateFrame(unit)
    Frame.ShowNote(frame)
    return true
end

local function ProcessRosterChange()
    rosterTimer = nil

    if not IsInGroup or not IsInGroup() or (IsInRaid and IsInRaid()) then
        rosterInitialized = false
        previousGuids = {}
        return
    end

    local units = CollectPartyUnits()
    local currentGuids = {}

    for i = 1, #units do
        local unit = units[i]
        local guid = UnitGUID(unit)
        if guid then
            currentGuids[guid] = unit
        end
    end

    if not rosterInitialized then
        rosterInitialized = true
        previousGuids = currentGuids
        return
    end

    for guid, unit in pairs(currentGuids) do
        if not previousGuids[guid] then
            Alert.ShowForUnit(unit)
        end
    end

    previousGuids = currentGuids
end

local function ScheduleRosterCheck()
    if rosterTimer and rosterTimer.Cancel then
        rosterTimer:Cancel()
    end

    if not C_Timer or not C_Timer.After then
        ProcessRosterChange()
        return
    end

    rosterTimer = C_Timer.After(ROSTER_DEBOUNCE, ProcessRosterChange)
end

local function ResetRosterState()
    rosterInitialized = false
    previousGuids = {}
    alertQueue = {}
    if rosterTimer and rosterTimer.Cancel then
        rosterTimer:Cancel()
        rosterTimer = nil
    end
end

local function EnsureEvents()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            ResetRosterState()
            if IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid()) then
                ScheduleRosterCheck()
            end
            return
        end

        if event == "GROUP_ROSTER_UPDATE" then
            if not IsInGroup or not IsInGroup() or (IsInRaid and IsInRaid()) then
                ResetRosterState()
                return
            end
            ScheduleRosterCheck()
        end
    end)
end

EnsureEvents()

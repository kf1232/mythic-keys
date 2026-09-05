Key.Views = Key.Views or {}

local History = {}
Key.Views.KeysHistory = History

local Frame = Key.Views.Frame

local FRAME_WIDTH = 680
local FRAME_HEIGHT = 420
local LIST_WIDTH = 130
local NAME_WIDTH = 170
local RATING_WIDTH = 48
local ILVL_WIDTH = 40
local LAYOUT_VERSION = 10

local frame
local listEmpty
local detailTitle
local detailEmpty

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

function History:Refresh()
    if not frame then
        return
    end
    detailTitle:SetText("Select a run")
    listEmpty:Show()
    detailEmpty:SetText("No mythic runs tracked yet.")
    detailEmpty:Show()
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

    local listScroll = CreateFrame("ScrollFrame", nil, body)
    listScroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    listScroll:SetWidth(LIST_WIDTH)

    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(LIST_WIDTH - 4, 1)
    listScroll:SetScrollChild(listChild)

    listEmpty = body:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    listEmpty:SetPoint("TOPLEFT", listScroll, "TOPLEFT", 8, -8)
    listEmpty:SetWidth(LIST_WIDTH - 24)
    listEmpty:SetJustifyH("LEFT")
    listEmpty:SetText("No mythic runs tracked yet.")

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

    detailEmpty = detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    detailEmpty:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
    detailEmpty:SetPoint("TOPRIGHT", detailPane, "TOPRIGHT", -4, -10)
    detailEmpty:SetJustifyH("LEFT")

    CreateCloseButton(frame)
    Frame.RegisterMain(frame)
    frame:Hide()
end

function History:Toggle()
    if frame and frame.layoutVersion ~= LAYOUT_VERSION then
        frame:Hide()
        frame:SetParent(nil)
        frame = nil
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

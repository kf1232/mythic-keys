Key.Views = Key.Views or {}

local Debug = {}
Key.Views.Debug = Debug

local Frame = Key.Views.Frame

local frame

local function CreateCloseButton(parent)
    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
    close:SetScript("OnClick", function()
        parent:Hide()
    end)
end

function Debug:Toggle()
    if not frame then
        frame = CreateFrame("Frame", "KeyDebugFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(320, 120)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
        frame.title:SetText("Mythic Keys Debug")

        local body = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        body:SetPoint("TOP", frame.title, "BOTTOM", 0, -24)
        body:SetWidth(280)
        body:SetJustifyH("CENTER")
        body:SetText("Data tools have been removed.")

        CreateCloseButton(frame)
        Frame.RegisterMain(frame)
        frame:Hide()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        Frame.ShowMain(frame)
    end
end

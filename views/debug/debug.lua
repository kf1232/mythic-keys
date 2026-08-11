Key.Views = Key.Views or {}

local Debug = {}
Key.Views.Debug = Debug

local Frame = Key.Views.Frame
local SeasonDungeons = Key.Data.SeasonDungeons
local InstanceLoot = Key.Data.InstanceLoot

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
        frame:SetSize(320, 188)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
        frame.title:SetText("Mythic Keys Debug")

        local dumpSeasonBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        dumpSeasonBtn:SetSize(220, 22)
        dumpSeasonBtn:SetPoint("TOP", frame, "TOP", 0, -36)
        dumpSeasonBtn:SetText("Dump season config")
        dumpSeasonBtn:SetScript("OnClick", function()
            SeasonDungeons.DumpLiveValues()
        end)

        local dumpLootBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        dumpLootBtn:SetSize(220, 22)
        dumpLootBtn:SetPoint("TOP", dumpSeasonBtn, "BOTTOM", 0, -8)
        dumpLootBtn:SetText("Dump instance loot")
        dumpLootBtn:SetScript("OnClick", function()
            InstanceLoot.DumpLiveValues(false)
        end)

        local dumpLootDebugBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        dumpLootDebugBtn:SetSize(220, 22)
        dumpLootDebugBtn:SetPoint("TOP", dumpLootBtn, "BOTTOM", 0, -8)
        dumpLootDebugBtn:SetText("Dump instance loot (debug)")
        dumpLootDebugBtn:SetScript("OnClick", function()
            InstanceLoot.DumpLiveValues(true)
        end)

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

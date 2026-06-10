local ADDON_NAME = ...

KeyDebugUI = KeyDebugUI or {}
local DebugUI = KeyDebugUI

local UI = KeyUI
local LAYOUT = UI.LAYOUT

local PADDING = LAYOUT.paddingSmall
local LOG_INSET_RIGHT = 28
local CONTENT_WIDTH = 464
local TITLE_TOP = 36
local CHROME_HEIGHT = 60

DebugUI.DESIGN = {
    padding = PADDING,
    contentWidth = CONTENT_WIDTH,
    chromeHeight = CHROME_HEIGHT,

    frame = UI:WindowConfig({
        name = "KeyDebugFrame",
        parent = UIParent,
        size = { 520, 360 },
        anchors = {
            { "CENTER", 0, -120 },
        },
        movable = true,
        dragButton = "LeftButton",
        hidden = true,
    }),

    titleBar = UI:TitleBarConfig(),

    title = UI:TitleBarLabelConfig({
        text = "Key / Debug",
    }),

    closeButton = {
        template = "UIPanelCloseButton",
        anchors = LAYOUT.closeButtonAnchors,
    },

    scrollFrame = {
        template = "UIPanelScrollFrameTemplate",
        anchors = {
            { "TOPLEFT", PADDING, -TITLE_TOP },
            { "BOTTOMRIGHT", -LOG_INSET_RIGHT, PADDING },
        },
    },

    scrollContent = {
        size = { CONTENT_WIDTH, 1 },
    },

    logText = UI:BodyTextConfig({
        justifyH = "LEFT",
        justifyV = "TOP",
        wordWrap = true,
        width = CONTENT_WIDTH,
        anchors = {
            { "TOPLEFT", 0, 0 },
        },
    }),

    prompt = UI:MutedTextConfig({
        text = "> /keyf clear  /keyf dump  /keyf clickdebug",
        anchors = {
            { "BOTTOMLEFT", PADDING, PADDING },
        },
    }),

    actionButton = {
        size = { 52, 20 },
        gap = 4,
        anchors = {
            { "BOTTOMRIGHT", -PADDING, PADDING },
        },
    },
}

local function AppendLine(text, entry, cleared)
    if cleared then
        return ""
    end
    if text == "" then
        return KeyLog:FormatEntry(entry)
    end
    return text .. "\n" .. KeyLog:FormatEntry(entry)
end

function DebugUI:CreateActionButton(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(self.DESIGN.actionButton.size[1], self.DESIGN.actionButton.size[2])
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

function DebugUI:EnsureActionButtons(frame)
    if frame.dumpButton then
        return
    end

    local gap = self.DESIGN.actionButton.gap
    local close = frame.closeButton or UI:CreateCloseButton(frame)
    frame.closeButton = close

    frame.dumpButton = self:CreateActionButton(frame, "Dump", function()
        DebugUI:DumpData()
    end)
    frame.dumpButton:SetPoint("RIGHT", close, "LEFT", -gap, 0)

    frame.clearButton = self:CreateActionButton(frame, "Clear", function()
        DebugUI:ClearLog()
    end)
    frame.clearButton:SetPoint("RIGHT", frame.dumpButton, "LEFT", -gap, 0)
end

function DebugUI:ClearLog()
    if KeyLog and KeyLog.Clear then
        KeyLog:Clear()
    end

    if self.frame then
        self:RenderLog(nil, true)
    end
end

function DebugUI:DumpData()
    self:EnsureFrame()
    self.frame:Show()

    if KeyDebugData and KeyDebugData.DumpToLog then
        KeyDebugData:DumpToLog()
    end

    self:RenderLog(nil, false)
end

function DebugUI:EnsureFrame()
    if self.frame then
        self:EnsureActionButtons(self.frame)
        return
    end

    local design = self.DESIGN
    local frame = UI:CreateFrame(design.frame)

    local titleBar = UI:CreateFrame(design.titleBar, frame)
    UI:CreateFontString(design.title, titleBar)

    frame.closeButton = UI:CreateCloseButton(frame)
    self:EnsureActionButtons(frame)

    local scrollFrame = UI:CreateScrollFrame(design.scrollFrame, frame)
    local content = UI:CreateFrame({
        size = design.scrollContent.size,
    }, scrollFrame)
    scrollFrame:SetScrollChild(content)

    frame.logText = UI:CreateFontString(design.logText, content)
    UI:CreateFontString(design.prompt, frame)

    frame.scrollFrame = scrollFrame
    frame.content = content
    self.frame = frame

    KeyLog:Subscribe(function(entry, cleared)
        if not self.frame or not self.frame:IsShown() then
            return
        end
        self:RenderLog(entry, cleared)
    end)
end

function DebugUI:RenderLog(entry, cleared)
    local frame = self.frame
    local logText = frame.logText
    local design = self.DESIGN

    if cleared then
        logText:SetText("")
    elseif entry then
        local current = logText:GetText() or ""
        logText:SetText(AppendLine(current, entry, cleared))
    else
        logText:SetText(KeyLog:GetText())
    end

    local minHeight = design.frame.size[2] - design.chromeHeight
    local height = math.max(minHeight, logText:GetStringHeight() + design.padding)
    frame.content:SetHeight(height)

    local maxScroll = frame.scrollFrame:GetVerticalScrollRange()
    frame.scrollFrame:SetVerticalScroll(maxScroll)
end

function DebugUI:ShowConsole()
    self:EnsureFrame()
    self.frame:Show()
    self:RenderLog(nil, false)
    if KeyClickDebug and KeyClickDebug.Enable then
        KeyClickDebug:Enable()
    end
    KeyLog:Add("Debug console opened.")
    if KeyLog.LogUnitAuras then
        KeyLog:LogUnitAuras("player", "Snapshot")
    end
end

function DebugUI:IsShown()
    return self.frame and self.frame:IsShown()
end

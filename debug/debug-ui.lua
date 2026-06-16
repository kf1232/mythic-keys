local ADDON_NAME = ...

Key.Debug.UI = Key.Debug.UI or {}
local DebugUI = Key.Debug.UI

local UI = Key.UI
local LAYOUT = UI.LAYOUT

local PADDING = LAYOUT.paddingSmall
local LOG_INSET_RIGHT = 28
local CONTENT_WIDTH = 464
local TITLE_TOP = UI:GetHeaderHeight()
local BOTTOM_CHROME = 30

DebugUI.DESIGN = {
    padding = PADDING,
    contentWidth = CONTENT_WIDTH,
    chromeHeight = TITLE_TOP + BOTTOM_CHROME + PADDING,

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
        anchors = UI:GetCloseButtonAnchors(),
    },

    scrollFrame = {
        template = "UIPanelScrollFrameTemplate",
        anchors = {
            { "TOPLEFT", PADDING, -TITLE_TOP },
            { "BOTTOMRIGHT", -LOG_INSET_RIGHT, BOTTOM_CHROME },
        },
    },

    prompt = UI:MutedTextConfig({
        text = "> Click log, Select All, then Ctrl+C.  /keyf clear  /keyf dump",
        anchors = {
            { "BOTTOMLEFT", PADDING, PADDING },
        },
    }),

    actionButton = {
        gap = 4,
        anchors = {
            { "BOTTOMRIGHT", -PADDING, PADDING },
        },
    },
}

local function PlainLogLine(entry)
    if Key.Log and Key.Log.StripColorCodes and Key.Log.FormatEntry then
        return Key.Log:StripColorCodes(Key.Log:FormatEntry(entry))
    end
    return tostring(entry and entry.message or "")
end

local function AppendLine(text, entry, cleared)
    if cleared then
        return ""
    end
    local line = PlainLogLine(entry)
    if text == "" then
        return line
    end
    return text .. "\n" .. line
end

local function EnsureMeasureString(frame)
    if frame.measureString then
        return frame.measureString
    end

    local bodyText = UI:BodyTextConfig()
    local theme = UI:GetTheme()
    local measureString = frame.scrollFrame:CreateFontString(nil, "ARTWORK")
    measureString:SetFont(bodyText.font.path, bodyText.font.size, bodyText.font.flags or "")
    measureString:SetTextColor(unpack(bodyText.textColor or theme.text))
    measureString:SetWidth(CONTENT_WIDTH)
    measureString:SetWordWrap(true)
    measureString:Hide()
    frame.measureString = measureString
    return measureString
end

local function UpdateLogEditHeight(frame, text)
    local design = DebugUI.DESIGN
    local editBox = frame.logEditBox
    local scrollFrame = frame.scrollFrame
    local measureString = EnsureMeasureString(frame)

    measureString:SetText(text or "")
    local minHeight = design.frame.size[2] - design.chromeHeight
    local height = math.max(minHeight, measureString:GetStringHeight() + design.padding)
    editBox:SetHeight(height)
    scrollFrame:UpdateScrollChildRect()
end

local function SetLogEditText(frame, text, scrollToTop)
    local editBox = frame.logEditBox
    local scrollFrame = frame.scrollFrame

    editBox._suppressTextChange = true
    editBox:SetText(text or "")
    editBox._storedText = text or ""
    editBox._suppressTextChange = false
    UpdateLogEditHeight(frame, text)

    if scrollToTop then
        scrollFrame:SetVerticalScroll(0)
    else
        scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
    end
end

local function FocusLogEditBox(editBox)
    if not editBox then
        return
    end
    editBox:SetFocus()
    editBox:HighlightText()
end

local function CreateLogEditBox(scrollFrame, design)
    local bodyText = UI:BodyTextConfig()
    local theme = UI:GetTheme()

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:SetFont(bodyText.font.path, bodyText.font.size, bodyText.font.flags or "")
    editBox:SetTextColor(unpack(bodyText.textColor or theme.text))
    editBox:SetWidth(CONTENT_WIDTH)
    editBox:SetMaxBytes(999999)
    editBox:SetMaxLetters(999999)
    editBox._storedText = ""
    editBox._suppressTextChange = false

    editBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnKeyDown", function(self, key)
        if (key == "a" or key == "A") and IsControlKeyDown() then
            self:HighlightText()
            return
        end
    end)

    editBox:SetScript("OnTextChanged", function(self, userInput)
        local parentFrame = scrollFrame:GetParent()
        if self._suppressTextChange then
            UpdateLogEditHeight(parentFrame, self._storedText)
            return
        end

        if userInput then
            self._suppressTextChange = true
            self:SetText(self._storedText or "")
            self._suppressTextChange = false
            return
        end

        self._storedText = self:GetText()
        UpdateLogEditHeight(parentFrame, self._storedText)
    end)

    return editBox
end

function DebugUI:EnsureActionButtons(frame)
    local gap = self.DESIGN.actionButton.gap
    local close = frame.closeButton or UI:CreateCloseButton(frame)
    frame.closeButton = close

    if not frame.dumpButton then
        frame.dumpButton = UI:CreateActionButton(frame, "Dump", function()
            DebugUI:DumpData()
        end)
        frame.dumpButton:SetPoint("RIGHT", close, "LEFT", -gap, 0)
    end

    if not frame.clearButton then
        frame.clearButton = UI:CreateActionButton(frame, "Clear", function()
            DebugUI:ClearLog()
        end)
        frame.clearButton:SetPoint("RIGHT", frame.dumpButton, "LEFT", -gap, 0)
    end

    if not frame.selectButton then
        frame.selectButton = UI:CreateActionButton(frame, "Select All", function()
            DebugUI:SelectAllLog()
        end)
        frame.selectButton:SetPoint("RIGHT", frame.clearButton, "LEFT", -gap, 0)
    end

    UI:LayoutTitleBarChrome(frame, {
        titleLabel = frame.titleBar and frame.titleBar.titleLabel,
    })
end

function DebugUI:SelectAllLog()
    self:EnsureFrame()
    FocusLogEditBox(self.frame and self.frame.logEditBox)
end

function DebugUI:ClearLog()
    if Key.Log and Key.Log.Clear then
        Key.Log:Clear()
    end

    if self.frame then
        self:RenderLog(nil, true)
    end
end

function DebugUI:DumpData()
    self:EnsureFrame()
    self.frame:Show()

    self._batchUpdate = true
    if Key.Debug.Data and Key.Debug.Data.DumpToLog then
        Key.Debug.Data:DumpToLog()
    end
    self._batchUpdate = false

    self:RenderLog(nil, false, true)
end

function DebugUI:EnsureFrame()
    if self.frame and not self.frame.logEditBox then
        self.frame:Hide()
        self.frame = nil
    end

    if self.frame then
        self:EnsureActionButtons(self.frame)
        return
    end

    local design = self.DESIGN
    local frame = UI:CreateFrame(design.frame)

    local titleBar = UI:CreateFrame(design.titleBar, frame)
    titleBar.titleLabel = UI:CreateFontString(design.title, titleBar)

    frame.closeButton = UI:CreateCloseButton(frame)
    self:EnsureActionButtons(frame)

    local scrollFrame = UI:CreateScrollFrame(design.scrollFrame, frame)
    scrollFrame:EnableMouse(true)
    scrollFrame:EnableMouseWheel(true)

    local logEditBox = CreateLogEditBox(scrollFrame, design)
    scrollFrame:SetScrollChild(logEditBox)

    scrollFrame:SetScript("OnMouseDown", function()
        FocusLogEditBox(logEditBox)
    end)

    UI:CreateFontString(design.prompt, frame)

    frame.scrollFrame = scrollFrame
    frame.logEditBox = logEditBox
    self.frame = frame

    Key.Log:Subscribe(function(entry, cleared)
        if not self.frame or not self.frame:IsShown() or self._batchUpdate then
            return
        end
        self:RenderLog(entry, cleared)
    end)
end

function DebugUI:RenderLog(entry, cleared, scrollToTop)
    local frame = self.frame
    local logEditBox = frame.logEditBox

    if cleared then
        SetLogEditText(frame, "", scrollToTop)
    elseif entry then
        local current = logEditBox._storedText or ""
        SetLogEditText(frame, AppendLine(current, entry, cleared), scrollToTop)
    else
        local plainText = Key.Log.GetPlainText and Key.Log:GetPlainText() or Key.Log:GetText()
        SetLogEditText(frame, plainText, scrollToTop)
    end
end

function DebugUI:ShowConsole()
    self:EnsureFrame()
    self.frame:Show()
    self:RenderLog(nil, false)
    if Key.Debug.Click and Key.Debug.Click.Enable then
        Key.Debug.Click:Enable()
    end
    Key.Log:WriteEvent(Key.Log.FEATURE.DEBUG, Key.Log.STATUS.INFO, "Debug console opened.", {
        source = "ShowConsole",
    })
    if Key.BDUpdates and Key.BDUpdates.RefreshWatchedUnits then
        Key.BDUpdates:RefreshWatchedUnits("debug-open")
    end
    if Key.BDUpdates and Key.BDUpdates.UpdatePolling then
        Key.BDUpdates:UpdatePolling()
    end
    if Key.AurasLog and Key.AurasLog.LogConsumableDiagnostics then
        Key.AurasLog:LogConsumableDiagnostics("player")
    end
    if Key.AurasLog and Key.AurasLog.LogUnitAuras then
        Key.AurasLog:LogUnitAuras("player", "Snapshot")
    end
    if Key.Log and Key.Log.LogMinimapSnapshot then
        Key.Log:LogMinimapSnapshot()
    end
    if Key.Log and Key.Log.LogTeleportBarSnapshot then
        Key.Log:LogTeleportBarSnapshot()
    end
    if Key.Log and Key.Log.LogPartyCompleteSnapshot then
        Key.Log:LogPartyCompleteSnapshot()
    end
end

function DebugUI:IsShown()
    return self.frame and self.frame:IsShown()
end

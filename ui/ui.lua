local ADDON_NAME = ...

Key.UI = Key.UI or {}

Key.UI.LAYOUT = {
    padding = 10,
    paddingSmall = 8,
    frameInset = 4,
    titleOffsetY = -12,
    titleBarGap = 4,
    buttonHeight = 26,
    buttonPaddingX = 12,
    buttonMinWidth = 72,
    chromeButtonSize = 26,
    refreshButtonGap = 2,
    bottomInset = 34,
    paneBottomPadding = 8,
    sectionGap = 8,
}

Key.UI.FONTS = {
    default = {
        path = "Fonts\\FRIZQT__.TTF",
        size = 11,
        flags = "",
    },
    header = {
        inherit = "GameFontNormalLarge",
    },
    label = {
        inherit = "GameFontHighlightSmall",
    },
}

Key.UI.BACKDROPS = {
    flat = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
    },
    window = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },
    tab = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },
}

Key.UI.THEME = {
    default = {
        panelBg = { 0.10, 0.10, 0.10, 0.97 },
        panelBorder = { 0.35, 0.75, 0.35, 1 },
        titleBarBg = { 0.14, 0.18, 0.14, 1 },
        text = { 0.92, 0.92, 0.92, 1 },
        textMuted = { 0.65, 0.65, 0.65, 1 },
        textHeader = { 1, 1, 1, 1 },
        tabBg = { 0.12, 0.12, 0.12, 0.95 },
        tabBorder = { 0.35, 0.35, 0.35, 1 },
        tabActiveBg = { 0.18, 0.28, 0.18, 1 },
        tabActiveBorder = { 0.35, 0.75, 0.35, 1 },
        tabInactiveText = { 0.75, 0.75, 0.75, 1 },
        tabActiveText = { 1, 1, 1, 1 },
        buttonHoverBg = { 0.16, 0.22, 0.16, 1 },
        buttonHoverBorder = { 0.45, 0.8, 0.45, 1 },
        buttonPressedBg = { 0.12, 0.2, 0.12, 1 },
        buttonPressedBorder = { 0.3, 0.65, 0.3, 1 },
        statusOk = { 0.3, 0.9, 0.35, 1 },
        statusBad = { 0.9, 0.35, 0.35, 1 },
        slotBorder = { 0.35, 0.35, 0.35, 1 },
        slotActiveBorder = { 0.2, 0.55, 0.25, 1 },
        slotBg = { 0.08, 0.08, 0.08, 0.9 },
        textDisabled = { 0.55, 0.55, 0.55, 1 },
    },
}

function Key.UI:GetTheme()
    return self.THEME.default
end

function Key.UI:DisplayText(value, fallback)
    fallback = fallback or "?"

    if value == nil then
        return fallback
    end

    if Key.Log and Key.Log.TryDisplayValue then
        local text = Key.Log:TryDisplayValue(value)
        if text and text ~= "" and text ~= "[secret]" then
            return text
        end
        return fallback
    end

    if Key.Api.Middleware and Key.Api.Middleware.IsAccessible then
        if not Key.Api.Middleware:IsAccessible(value) then
            return fallback
        end
    elseif issecretvalue and issecretvalue(value) then
        return fallback
    end

    return tostring(value)
end

function Key.UI:GetTitleBarHeight()
    return self.LAYOUT.frameInset * 2 + self.LAYOUT.chromeButtonSize
end

function Key.UI:GetHeaderHeight()
    return self:GetTitleBarHeight() + self.LAYOUT.titleBarGap
end

function Key.UI:GetChromeVerticalOffset()
    local inset = self.LAYOUT.frameInset
    local titleHeight = self:GetTitleBarHeight()
    local chromeSize = self.LAYOUT.chromeButtonSize
    return -(inset + (titleHeight - chromeSize) / 2)
end

function Key.UI:GetCloseButtonAnchors()
    local inset = self.LAYOUT.frameInset
    return {
        { "TOPRIGHT", -inset, self:GetChromeVerticalOffset() },
    }
end

function Key.UI:LayoutTitleBarChrome(frame, options)
    options = options or {}
    local titleBar = frame.titleBar
    local close = frame.closeButton
    if not titleBar or not close then
        return
    end

    local inset = self.LAYOUT.frameInset
    local gap = options.buttonGap or self.LAYOUT.refreshButtonGap
    local paddingSmall = self.LAYOUT.paddingSmall
    local titleHeight = self:GetTitleBarHeight()
    local yOffset = self:GetChromeVerticalOffset()
    local refresh = options.refreshButton

    titleBar:SetHeight(titleHeight)
    titleBar:ClearAllPoints()
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)

    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, yOffset)

    if refresh then
        refresh:ClearAllPoints()
        refresh:SetPoint("TOPRIGHT", close, "TOPLEFT", -gap, 0)
    end

    local label = options.titleLabel or titleBar.titleLabel
    local labelRight = refresh or close
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", titleBar, "LEFT", paddingSmall, 0)
        label:SetPoint("RIGHT", labelRight, "LEFT", -gap, 0)
    end

    local baseLevel = titleBar:GetFrameLevel()
    close:SetFrameLevel(baseLevel + 2)
    if refresh then
        refresh:SetFrameLevel(baseLevel + 3)
    end
end

function Key.UI:MergeConfig(base, overrides)
    local merged = {}

    for key, value in pairs(base or {}) do
        merged[key] = value
    end

    for key, value in pairs(overrides or {}) do
        merged[key] = value
    end

    return merged
end

function Key.UI:WindowConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        template = "BackdropTemplate",
        strata = "DIALOG",
        clamped = true,
        backdrop = self.BACKDROPS.window,
        backdropColor = theme.panelBg,
        backdropBorderColor = theme.panelBorder,
    }, overrides)
end

function Key.UI:TitleBarConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        template = "BackdropTemplate",
        height = self:GetTitleBarHeight(),
        anchors = {
            { "TOPLEFT", self.LAYOUT.frameInset, -self.LAYOUT.frameInset },
            { "TOPRIGHT", -self.LAYOUT.frameInset, -self.LAYOUT.frameInset },
        },
        backdrop = self.BACKDROPS.flat,
        backdropColor = theme.titleBarBg,
    }, overrides)
end

function Key.UI:TitleBarLabelConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        inherit = self.FONTS.label.inherit,
        textColor = theme.textHeader,
        anchors = {
            { "LEFT", "$parent", "LEFT", self.LAYOUT.paddingSmall, 0 },
        },
    }, overrides)
end

function Key.UI:BodyTextConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        font = self.FONTS.default,
        textColor = theme.text,
    }, overrides)
end

function Key.UI:MutedTextConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        font = self.FONTS.default,
        textColor = theme.textMuted,
    }, overrides)
end

function Key.UI:GetTextButtonStyle(variant)
    local theme = self:GetTheme()

    if variant == "active" then
        return {
            backdropColor = theme.tabActiveBg,
            backdropBorderColor = theme.tabActiveBorder,
            textColor = theme.tabActiveText,
        }
    end

    if variant == "hover" then
        return {
            backdropColor = theme.buttonHoverBg,
            backdropBorderColor = theme.buttonHoverBorder,
            textColor = theme.tabActiveText,
        }
    end

    if variant == "pressed" then
        return {
            backdropColor = theme.buttonPressedBg,
            backdropBorderColor = theme.buttonPressedBorder,
            textColor = theme.tabActiveText,
        }
    end

    if variant == "disabled" then
        return {
            backdropColor = theme.tabBg,
            backdropBorderColor = theme.tabBorder,
            textColor = theme.textDisabled,
        }
    end

    return {
        backdropColor = theme.tabBg,
        backdropBorderColor = theme.tabBorder,
        textColor = theme.tabInactiveText,
    }
end

function Key.UI:ApplyTextButtonStyle(button, variant)
    if not button then
        return
    end

    local style = self:GetTextButtonStyle(variant)

    button:SetBackdropColor(unpack(style.backdropColor))
    button:SetBackdropBorderColor(unpack(style.backdropBorderColor))

    if button.label then
        button.label:SetTextColor(unpack(style.textColor))
    end

    button._styleVariant = variant
end

function Key.UI:ResolveTextButtonVariant(button)
    if not button:IsEnabled() then
        return "disabled"
    end

    if button._active then
        return "active"
    end

    return "inactive"
end

function Key.UI:RestoreTextButtonStyle(button)
    if not button then
        return
    end

    if button:IsMouseOver() and button:IsEnabled() and not button._active then
        self:ApplyTextButtonStyle(button, "hover")
        return
    end

    self:ApplyTextButtonStyle(button, self:ResolveTextButtonVariant(button))
end

function Key.UI:RefreshTextButtonStyle(button)
    self:RestoreTextButtonStyle(button)
end

function Key.UI:AttachTextButtonInteractions(button, options)
    options = options or {}

    local function OnEnter()
        if button:IsEnabled() and not button._active then
            self:ApplyTextButtonStyle(button, "hover")
        end
        if options.onEnter then
            options.onEnter(button)
        end
    end

    local function OnLeave()
        self:ApplyTextButtonStyle(button, self:ResolveTextButtonVariant(button))
        if options.onLeave then
            options.onLeave(button)
        end
    end

    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    button:SetScript("OnMouseDown", function()
        if button:IsEnabled() then
            self:ApplyTextButtonStyle(button, "pressed")
        end
    end)
    button:SetScript("OnMouseUp", function()
        self:RestoreTextButtonStyle(button)
    end)
    button:SetScript("OnDisable", function()
        self:ApplyTextButtonStyle(button, "disabled")
    end)
    button:SetScript("OnEnable", function()
        self:RestoreTextButtonStyle(button)
    end)

    if options.onClick then
        button:SetScript("OnClick", options.onClick)
    end
end

function Key.UI:MeasureTextButtonWidth(label, minWidth)
    if not self.measureString then
        self.measureString = UIParent:CreateFontString(nil, "ARTWORK", self.FONTS.label.inherit)
    end

    self.measureString:SetText(label or "")
    local textWidth = self.measureString:GetStringWidth() or 0
    return math.max(minWidth or self.LAYOUT.buttonMinWidth, math.ceil(textWidth + (self.LAYOUT.buttonPaddingX * 2)))
end

function Key.UI:PrepareButtonMouse(button)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
end

function Key.UI:CreateTextButton(parent, options)
    options = options or {}
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    self:PrepareButtonMouse(button)

    button:SetBackdrop(self.BACKDROPS.tab)
    button._active = options.active == true

    local label = options.label or ""
    button.label = button:CreateFontString(nil, "OVERLAY", self.FONTS.label.inherit)
    button.label:SetPoint("CENTER")
    button.label:SetText(label)

    local width = options.width or self:MeasureTextButtonWidth(label, options.minWidth)
    local height = options.height or self.LAYOUT.buttonHeight
    button:SetSize(width, height)

    if options.tabId then
        button.tabId = options.tabId
    end

    self:ApplyTextButtonStyle(button, button._active and "active" or "inactive")
    self:AttachTextButtonInteractions(button, options)

    if options.anchors then
        self:ApplyAnchors(button, options.anchors)
    end

    return button
end

function Key.UI:ApplyTabButtonStyle(button, active)
    if not button then
        return
    end

    button._active = active and true or false
    self:RefreshTextButtonStyle(button)
end

function Key.UI:RunSlashCommand(command)
    command = strtrim(command or "")
    if command == "" then
        return
    end

    local editBox = ChatEdit_ChooseBoxForSend()
    if not editBox then
        return
    end

    editBox:SetText(command)
    ChatEdit_SendText(editBox)
end

function Key.UI:CreateActionButton(parent, label, onClick, width, options)
    options = options or {}
    options.label = label
    options.onClick = onClick
    options.width = width
    return self:CreateTextButton(parent, options)
end

function Key.UI:CreateTabButton(parent, label, tabId, onClick)
    return self:CreateTextButton(parent, {
        label = label,
        tabId = tabId,
        onClick = onClick,
    })
end

function Key.UI:CreateChromeButton(parent, options)
    options = options or {}
    local size = options.size or self.LAYOUT.chromeButtonSize
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    self:PrepareButtonMouse(button)

    button:SetBackdrop(self.BACKDROPS.tab)
    button:SetSize(size, size)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(math.floor(size * 0.58), math.floor(size * 0.58))

    if options.icon then
        button.icon:SetTexture(options.icon)
    end
    if options.iconTexCoord then
        button.icon:SetTexCoord(unpack(options.iconTexCoord))
    end

    self:ApplyTextButtonStyle(button, "inactive")
    self:AttachTextButtonInteractions(button, options)

    if options.anchors then
        self:ApplyAnchors(button, options.anchors)
    end

    return button
end

function Key.UI:ResolveParent(parent)
    if parent == nil then
        return UIParent
    end
    if type(parent) == "string" then
        return _G[parent]
    end
    return parent
end

function Key.UI:ResolveAnchorRelative(frame, relativeTo)
    if relativeTo == "$parent" then
        return frame:GetParent()
    end
    if relativeTo == "$self" then
        return frame
    end
    return relativeTo
end

function Key.UI:ApplyAnchors(frame, anchors)
    if not anchors then
        return
    end

    frame:ClearAllPoints()

    for _, anchor in ipairs(anchors) do
        if #anchor == 3 then
            frame:SetPoint(anchor[1], anchor[2], anchor[3])
        elseif #anchor == 5 then
            local relativeTo = self:ResolveAnchorRelative(frame, anchor[2])
            frame:SetPoint(anchor[1], relativeTo, anchor[3], anchor[4], anchor[5])
        end
    end
end

function Key.UI:ApplyBackdrop(frame, config)
    if config.backdrop then
        frame:SetBackdrop(config.backdrop)
    end

    if config.backdropColor then
        frame:SetBackdropColor(unpack(config.backdropColor))
    end

    if config.backdropBorderColor then
        frame:SetBackdropBorderColor(unpack(config.backdropBorderColor))
    end
end

function Key.UI:ApplyFrameBehavior(frame, config)
    if config.strata then
        frame:SetFrameStrata(config.strata)
    end

    if config.frameLevel then
        frame:SetFrameLevel(config.frameLevel)
    end

    if config.clamped then
        frame:SetClampedToScreen(true)
    end

    if config.movable then
        frame:SetMovable(true)
        frame:EnableMouse(true)
    end

    if config.resizable then
        frame:SetResizable(true)
    end

    if config.dragButton then
        frame:RegisterForDrag(config.dragButton)
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    end

    if config.hidden then
        frame:Hide()
    end
end

function Key.UI:ApplySize(frame, config)
    if config.size then
        frame:SetSize(config.size[1], config.size[2])
        return
    end

    if config.width and config.height then
        frame:SetSize(config.width, config.height)
        return
    end

    if config.width then
        frame:SetWidth(config.width)
    end

    if config.height then
        frame:SetHeight(config.height)
    end
end

function Key.UI:ApplyFrameStyle(frame, config)
    self:ApplySize(frame, config)
    self:ApplyAnchors(frame, config.anchors)
    self:ApplyBackdrop(frame, config)
    self:ApplyFrameBehavior(frame, config)
end

function Key.UI:ApplyFontStringStyle(fontString, config)
    if config.inherit then
        -- inherit font from GameFont template; color and text applied below
    elseif config.font then
        fontString:SetFont(config.font.path, config.font.size, config.font.flags or "")
    end

    if config.textColor then
        fontString:SetTextColor(unpack(config.textColor))
    end

    if config.text then
        fontString:SetText(config.text)
    end

    if config.width then
        fontString:SetWidth(config.width)
    end

    if config.justifyH then
        fontString:SetJustifyH(config.justifyH)
    end

    if config.justifyV then
        fontString:SetJustifyV(config.justifyV)
    end

    if config.wordWrap ~= nil then
        fontString:SetWordWrap(config.wordWrap)
    end

    self:ApplyAnchors(fontString, config.anchors)
end

function Key.UI:CreateFrame(config, parent)
    parent = self:ResolveParent(parent or config.parent)
    local frame = CreateFrame(
        config.frameType or "Frame",
        config.name,
        parent,
        config.template
    )
    self:ApplyFrameStyle(frame, config)
    return frame
end

function Key.UI:CreateScrollFrame(config, parent)
    parent = self:ResolveParent(parent or config.parent)
    local scrollFrame = CreateFrame(
        "ScrollFrame",
        config.name,
        parent,
        config.template or "UIPanelScrollFrameTemplate"
    )
    self:ApplyFrameStyle(scrollFrame, config)
    return scrollFrame
end

function Key.UI:CreateFontString(config, parent)
    parent = self:ResolveParent(parent or config.parent)
    local fontString = parent:CreateFontString(
        config.name,
        config.layer or "OVERLAY",
        config.inherit
    )

    if not config.inherit and not config.font then
        config.font = self.FONTS.default
    end

    self:ApplyFontStringStyle(fontString, config)
    return fontString
end

function Key.UI:CreateCloseButton(parent, options)
    options = options or {}
    local size = self.LAYOUT.chromeButtonSize

    return self:CreateTextButton(parent, {
        label = "X",
        width = size,
        height = size,
        minWidth = size,
        anchors = options.anchors or self:GetCloseButtonAnchors(),
        onClick = options.onClick or function(button)
            local frame = button:GetParent()
            if frame and frame.Hide then
                frame:Hide()
            end
        end,
    })
end

function Key.UI:CreateRefreshButton(parent, options)
    options = options or {}
    local size = options.size
    if not size and options.matchSizeTo then
        size = math.max(self.LAYOUT.chromeButtonSize, math.floor(options.matchSizeTo:GetWidth()))
    end
    size = size or self.LAYOUT.chromeButtonSize

    local button = self:CreateChromeButton(parent, {
        size = size,
        icon = "Interface\\Buttons\\UI-RefreshButton",
        onClick = options.onClick,
        onEnter = options.onEnter,
        onLeave = options.onLeave,
        anchors = options.anchors,
    })

    return button
end

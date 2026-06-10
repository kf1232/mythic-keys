local ADDON_NAME = ...

KeyUI = KeyUI or {}

KeyUI.LAYOUT = {
    padding = 10,
    paddingSmall = 8,
    frameInset = 4,
    titleOffsetY = -12,
    closeButtonAnchors = {
        { "TOPRIGHT", -2, -2 },
    },
    refreshButtonScale = 0.9,
    refreshButtonGap = 2,
}

KeyUI.FONTS = {
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

KeyUI.BACKDROPS = {
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

KeyUI.THEME = {
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
        statusOk = { 0.3, 0.9, 0.35, 1 },
        statusBad = { 0.9, 0.35, 0.35, 1 },
        slotBorder = { 0.35, 0.35, 0.35, 1 },
        slotActiveBorder = { 0.2, 0.55, 0.25, 1 },
        slotBg = { 0.08, 0.08, 0.08, 0.9 },
        toggleReadyBg = { 0.14, 0.28, 0.14, 1 },
        toggleUnreadyBg = { 0.28, 0.14, 0.14, 1 },
        toggleUnreadyBorder = { 0.75, 0.35, 0.35, 1 },
        textDisabled = { 0.55, 0.55, 0.55, 1 },
    },
}

function KeyUI:GetTheme()
    return self.THEME.default
end

function KeyUI:MergeConfig(base, overrides)
    local merged = {}

    for key, value in pairs(base or {}) do
        merged[key] = value
    end

    for key, value in pairs(overrides or {}) do
        merged[key] = value
    end

    return merged
end

function KeyUI:WindowConfig(overrides)
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

function KeyUI:TitleBarConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        template = "BackdropTemplate",
        height = 24,
        anchors = {
            { "TOPLEFT", self.LAYOUT.frameInset, -self.LAYOUT.frameInset },
            { "TOPRIGHT", -self.LAYOUT.frameInset, -self.LAYOUT.frameInset },
        },
        backdrop = self.BACKDROPS.flat,
        backdropColor = theme.titleBarBg,
    }, overrides)
end

function KeyUI:TitleConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        inherit = self.FONTS.header.inherit,
        textColor = theme.textHeader,
        anchors = {
            { "TOP", 0, self.LAYOUT.titleOffsetY },
        },
    }, overrides)
end

function KeyUI:TitleBarLabelConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        inherit = self.FONTS.label.inherit,
        textColor = theme.textHeader,
        anchors = {
            { "LEFT", self.LAYOUT.paddingSmall, 0 },
        },
    }, overrides)
end

function KeyUI:BodyTextConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        font = self.FONTS.default,
        textColor = theme.text,
    }, overrides)
end

function KeyUI:MutedTextConfig(overrides)
    local theme = self:GetTheme()

    return self:MergeConfig({
        font = self.FONTS.default,
        textColor = theme.textMuted,
    }, overrides)
end

function KeyUI:GetTabStyle(active)
    local theme = self:GetTheme()

    if active then
        return {
            backdropColor = theme.tabActiveBg,
            backdropBorderColor = theme.tabActiveBorder,
            textColor = theme.tabActiveText,
        }
    end

    return {
        backdropColor = theme.tabBg,
        backdropBorderColor = theme.tabBorder,
        textColor = theme.tabInactiveText,
    }
end

function KeyUI:ApplyTabButtonStyle(button, active)
    if not button then
        return
    end

    local style = self:GetTabStyle(active)

    button:SetBackdropColor(unpack(style.backdropColor))
    button:SetBackdropBorderColor(unpack(style.backdropBorderColor))

    if button.label then
        button.label:SetTextColor(unpack(style.textColor))
    end
end

function KeyUI:ApplyReadyToggleStyle(button, ready, locked)
    if not button then
        return
    end

    local theme = self:GetTheme()

    if ready then
        button:SetBackdropColor(unpack(theme.toggleReadyBg))
        button:SetBackdropBorderColor(unpack(theme.tabActiveBorder))
    else
        button:SetBackdropColor(unpack(theme.toggleUnreadyBg))
        button:SetBackdropBorderColor(unpack(theme.toggleUnreadyBorder))
    end

    if button.label then
        if locked then
            button.label:SetTextColor(unpack(theme.textDisabled))
        else
            button.label:SetTextColor(unpack(theme.tabActiveText))
        end
    end
end

function KeyUI:CreateTabButton(parent, label, tabId, onClick)
    local theme = self:GetTheme()
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")

    button:SetBackdrop(self.BACKDROPS.tab)
    self:ApplyTabButtonStyle(button, false)

    button.label = button:CreateFontString(nil, "OVERLAY", self.FONTS.label.inherit)
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    button.label:SetTextColor(unpack(theme.tabInactiveText))
    button.tabId = tabId

    button:SetScript("OnClick", onClick)

    return button
end

function KeyUI:ResolveParent(parent)
    if parent == nil then
        return UIParent
    end
    if type(parent) == "string" then
        return _G[parent]
    end
    return parent
end

function KeyUI:ResolveAnchorRelative(frame, relativeTo)
    if relativeTo == "$parent" then
        return frame:GetParent()
    end
    if relativeTo == "$self" then
        return frame
    end
    return relativeTo
end

function KeyUI:ApplyAnchors(frame, anchors)
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

function KeyUI:ApplyBackdrop(frame, config)
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

function KeyUI:ApplyFrameBehavior(frame, config)
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

function KeyUI:ApplySize(frame, config)
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

function KeyUI:ApplyFrameStyle(frame, config)
    self:ApplySize(frame, config)
    self:ApplyAnchors(frame, config.anchors)
    self:ApplyBackdrop(frame, config)
    self:ApplyFrameBehavior(frame, config)
end

function KeyUI:ApplyFontStringStyle(fontString, config)
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

function KeyUI:CreateFrame(config, parent)
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

function KeyUI:CreateButton(config, parent)
    parent = self:ResolveParent(parent or config.parent)
    local button = CreateFrame(
        "Button",
        config.name,
        parent,
        config.template or "BackdropTemplate"
    )
    self:ApplyFrameStyle(button, config)
    return button
end

function KeyUI:CreateScrollFrame(config, parent)
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

function KeyUI:CreateFontString(config, parent)
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

function KeyUI:CreateCloseButton(parent)
    return self:CreateButton({
        template = "UIPanelCloseButton",
        anchors = self.LAYOUT.closeButtonAnchors,
    }, parent)
end

function KeyUI:CreateRefreshButton(parent, options)
    options = options or {}
    local button = CreateFrame("Button", nil, parent, "UIPanelSquareButton")

    local size = options.size
    if not size and options.matchSizeTo then
        size = math.max(16, math.floor(options.matchSizeTo:GetWidth() * self.LAYOUT.refreshButtonScale))
    end
    size = size or 24

    button:SetSize(size, size)

    if button.icon then
        button.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("CENTER")
        button.icon:SetSize(math.floor(size * 0.68), math.floor(size * 0.68))
    end

    if options.onClick then
        button:SetScript("OnClick", options.onClick)
    end

    if options.onEnter then
        button:SetScript("OnEnter", options.onEnter)
    end

    if options.onLeave then
        button:SetScript("OnLeave", options.onLeave)
    end

    if options.anchors then
        self:ApplyAnchors(button, options.anchors)
    end

    return button
end

-- Backward compatibility for older references.
KeyUI.BACKDROPS.panelBordered = KeyUI.BACKDROPS.window
KeyUI.THEME.debug = KeyUI.THEME.default

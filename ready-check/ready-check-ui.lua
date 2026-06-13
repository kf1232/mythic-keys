local ADDON_NAME = ...

Key.ReadyCheck = Key.ReadyCheck or {}
Key.ReadyCheck.UI = Key.ReadyCheck.UI or {}
local ReadyCheck = Key.ReadyCheck
local UI = Key.ReadyCheck.UI

UI.FOOTER_HEIGHT = 30
UI.ROW_HEIGHT = 20
UI.HEADER_HEIGHT = 18
UI.MAX_ROWS = 40
UI.ICON_SIZE = 18

UI.REPAIR_THRESHOLDS = {
    { min = 90, r = 0.3, g = 0.9, b = 0.35 },
    { min = 50, r = 0.95, g = 0.75, b = 0.25 },
}

UI.COLUMNS = {
    { key = "repair", label = "Repair", width = 0.11, type = "repair" },
    { key = "food", label = "Food", width = 0.14, type = "consumable_icon", consumableKind = "food" },
    { key = "flask", label = "Flask", width = 0.14, type = "consumable_icon", consumableKind = "flask" },
    { key = "oil", label = "Oil", width = 0.14, type = "consumable_icon", consumableKind = "oil", columnLabel = "Weapon oil" },
    { key = "buffs", label = "Party Buffs", width = 0.29, type = "buffs" },
    { key = "ready", label = "Ready", width = 0.08, type = "ready" },
}

function UI:GetColumnConfig(key)
    for _, column in ipairs(self.COLUMNS) do
        if column.key == key then
            return column
        end
    end
    return nil
end

function UI:GetColumnType(columnOrKey)
    if type(columnOrKey) == "table" then
        return columnOrKey.type
    end

    local column = self:GetColumnConfig(columnOrKey)
    return column and column.type
end

function UI:IsIconColumn(columnOrKey)
    return self:GetColumnType(columnOrKey) == "consumable_icon"
end

function UI:IsCenterColumn(columnOrKey)
    local columnType = self:GetColumnType(columnOrKey)
    return columnType == "consumable_icon" or columnType == "ready"
end

function UI:ComputeColumnWidths(contentWidth)
    local widths = {
        name = math.floor(contentWidth * 0.10),
    }
    local consumed = widths.name
    local lastIndex = #self.COLUMNS

    for index, column in ipairs(self.COLUMNS) do
        if index < lastIndex then
            widths[column.key] = math.floor(contentWidth * column.width)
            consumed = consumed + widths[column.key]
        else
            widths[column.key] = math.max(0, contentWidth - consumed)
        end
    end

    return widths
end

function UI:ApplyCellTextAnchor(cell, justify)
    justify = justify or cell.justify or "LEFT"
    cell.text:ClearAllPoints()
    if justify == "CENTER" then
        cell.text:SetPoint("CENTER", cell, "CENTER", 0, 0)
    else
        cell.text:SetPoint("LEFT", cell, "LEFT", 2, 0)
    end
    cell.text:SetJustifyH(justify)
end

function UI:GetOkColor(ok)
    if ok then
        return 0.3, 0.9, 0.35
    end
    return 0.9, 0.35, 0.35
end

function UI:GetRepairColor(percent)
    if not percent then
        return 0.5, 0.5, 0.5
    end

    for _, threshold in ipairs(self.REPAIR_THRESHOLDS) do
        if percent >= threshold.min then
            return threshold.r, threshold.g, threshold.b
        end
    end

    return 0.9, 0.35, 0.35
end

function UI:GetReadyText(isReady)
    if isReady == nil then
        return "—", 0.5, 0.5, 0.5
    end
    if isReady then
        return "Ready", 0.3, 0.9, 0.35
    end
    return "Unready", 0.9, 0.35, 0.35
end

function UI:UpdateToggleButton()
    local footer = self.tableFrame and self.tableFrame.footer
    local button = footer and footer.toggle
    if not button or not button.label then
        return
    end

    local locked = ReadyCheck:IsToggleLocked()
    local ready = ReadyCheck:GetPlayerReady()

    button:SetEnabled(not locked)

    if ready then
        button.label:SetText(locked and "You: Ready (locked)" or "You: Ready")
    else
        button.label:SetText(locked and "You: Unready (locked)" or "You: Unready")
    end

    Key.UI:ApplyReadyToggleStyle(button, ready, locked)
end

function UI:CreateToggleButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetBackdrop(Key.UI.BACKDROPS.tab)
    Key.UI:ApplyReadyToggleStyle(button, false, false)
    button:SetSize(140, 24)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button:SetScript("OnClick", function()
        ReadyCheck:TogglePlayerReady()
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if ReadyCheck:IsToggleLocked() then
            GameTooltip:SetText("Ready toggle locked", 1, 1, 1)
            GameTooltip:AddLine("Wait 1 second before changing again.", 0.85, 0.85, 0.85)
        elseif ReadyCheck:GetPlayerReady() then
            GameTooltip:SetText("You are ready", 1, 1, 1)
            GameTooltip:AddLine("Click to mark unready.", 0.85, 0.85, 0.85)
        else
            GameTooltip:SetText("You are unready", 1, 1, 1)
            GameTooltip:AddLine("Click to mark ready.", 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

function UI:CreateCell(parent, justify)
    justify = justify or "LEFT"
    local cell = CreateFrame("Frame", nil, parent)
    cell.justify = justify
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self:ApplyCellTextAnchor(cell, justify)
    cell.text:SetWordWrap(false)
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function()
        if not cell.tooltipTitle then
            return
        end
        GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
        GameTooltip:SetText(cell.tooltipTitle, 1, 1, 1)
        if cell.tooltipBody then
            GameTooltip:AddLine(cell.tooltipBody, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return cell
end

function UI:EnsureIconCell(cell)
    if cell.iconFrame then
        return cell
    end

    self:ApplyCellTextAnchor(cell, "CENTER")

    local iconFrame = CreateFrame("Frame", nil, cell, "BackdropTemplate")
    iconFrame:SetSize(self.ICON_SIZE, self.ICON_SIZE)
    iconFrame:SetPoint("CENTER", cell, "CENTER", 0, 0)
    iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    iconFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)

    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetPoint("TOPLEFT", 2, -2)
    iconFrame.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    iconFrame:Hide()

    cell.iconFrame = iconFrame
    return cell
end

function UI:SetIconCellBorder(iconFrame, goldBorder, eating)
    if eating then
        iconFrame:SetBackdropBorderColor(0.95, 0.75, 0.25, 1)
    elseif goldBorder then
        iconFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        iconFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end
end

function UI:SetFlaskIconBorder(iconFrame, goldBorder, lowTime)
    local edgeSize = lowTime and 3 or 1
    iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = edgeSize,
        insets = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize },
    })
    iconFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)

    if lowTime then
        iconFrame:SetBackdropBorderColor(0.9, 0.35, 0.35, 1)
    elseif goldBorder then
        iconFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        iconFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end
end

function UI:LayoutFlaskIconCell(cell, iconFileID, goldBorder, label, lowTime)
    self:EnsureIconCell(cell)

    cell.iconFrame:ClearAllPoints()
    cell.iconFrame:SetPoint("CENTER", cell, "CENTER", 0, 0)

    if not iconFileID then
        cell.iconFrame:Hide()
        self:ApplyCellTextAnchor(cell, "CENTER")
        cell.text:Show()
        cell.text:SetText("—")
        local nr, ng, nb = self:GetOkColor(false)
        cell.text:SetTextColor(nr, ng, nb)
        cell.tooltipTitle = nil
        cell.tooltipBody = nil
        return
    end

    cell.text:Hide()
    cell.iconFrame:Show()
    cell.iconFrame.icon:SetTexture(iconFileID)
    cell.iconFrame.icon:SetDesaturated(false)
    cell.iconFrame.icon:SetAlpha(1)
    self:SetFlaskIconBorder(cell.iconFrame, goldBorder, lowTime)

    cell.tooltipTitle = (label and label ~= "") and label or nil
    cell.tooltipBody = nil
end

function UI:LayoutConsumableIconCell(cell, ok, iconFileID, goldBorder, label, memberName, columnLabel, defaultIcon, premiumTooltip, eating)
    self:EnsureIconCell(cell)

    cell.tooltipTitle = string.format("%s — %s", memberName, columnLabel)
    cell.iconFrame:ClearAllPoints()
    cell.iconFrame:SetPoint("CENTER", cell, "CENTER", 0, 0)

    if not ok and not eating then
        cell.iconFrame:Hide()
        self:ApplyCellTextAnchor(cell, "CENTER")
        cell.text:Show()
        cell.text:SetText("—")
        local nr, ng, nb = self:GetOkColor(false)
        cell.text:SetTextColor(nr, ng, nb)
        cell.tooltipBody = string.format("No %s", columnLabel:lower())
        return
    end

    local icon = iconFileID or defaultIcon
    cell.text:Hide()
    cell.iconFrame:Show()
    cell.iconFrame.icon:SetTexture(icon or ReadyCheck:GetDefaultIcon())
    cell.iconFrame.icon:SetDesaturated(eating == true)
    cell.iconFrame.icon:SetAlpha(eating and 0.85 or 1)
    self:SetIconCellBorder(cell.iconFrame, goldBorder, eating)

    if label and label ~= "" then
        cell.tooltipBody = label
        if eating and premiumTooltip then
            cell.tooltipBody = label .. " (" .. premiumTooltip .. ")"
        elseif goldBorder and premiumTooltip then
            cell.tooltipBody = label .. " (" .. premiumTooltip .. ")"
        end
    else
        cell.tooltipBody = columnLabel .. " active"
        if eating and premiumTooltip then
            cell.tooltipBody = columnLabel .. " — " .. premiumTooltip
        elseif goldBorder and premiumTooltip then
            cell.tooltipBody = columnLabel .. " active (" .. premiumTooltip .. ")"
        end
    end
end

function UI:LayoutTextCell(cell, text, r, g, b, tooltipTitle, tooltipBody, justify)
    if cell.iconFrame then
        cell.iconFrame:Hide()
    end
    self:ApplyCellTextAnchor(cell, justify or "LEFT")
    cell.text:Show()
    cell.text:SetText(text)
    cell.text:SetTextColor(r, g, b)
    cell.tooltipTitle = tooltipTitle
    cell.tooltipBody = tooltipBody
end

function UI:EnsureTable(parent)
    if self.tableFrame then
        if not self.tableFrame.footer then
            self.tableFrame.footer = CreateFrame("Frame", nil, self.tableFrame)
            self.tableFrame.footer.toggle = self:CreateToggleButton(self.tableFrame.footer)
        end
        self:UpdateToggleButton()
        return self.tableFrame
    end

    local tableFrame = CreateFrame("Frame", nil, parent)
    tableFrame.header = self:CreateCell(tableFrame, "LEFT")
    tableFrame.header.text:SetText("Member")
    tableFrame.header.text:SetTextColor(0.8, 0.8, 0.8)

    tableFrame.headerCells = {}
    for _, column in ipairs(self.COLUMNS) do
        local justify = self:IsCenterColumn(column) and "CENTER" or "LEFT"
        local cell = self:CreateCell(tableFrame, justify)
        cell.text:SetText(column.label)
        cell.text:SetTextColor(0.8, 0.8, 0.8)
        tableFrame.headerCells[column.key] = cell
    end

    tableFrame.rows = {}
    for rowIndex = 1, self.MAX_ROWS do
        local row = {}
        row.name = self:CreateCell(tableFrame, "LEFT")
        for _, column in ipairs(self.COLUMNS) do
            local justify = self:IsCenterColumn(column) and "CENTER" or "LEFT"
            local cell = self:CreateCell(tableFrame, justify)
            if self:IsIconColumn(column) then
                self:EnsureIconCell(cell)
            end
            row[column.key] = cell
        end
        tableFrame.rows[rowIndex] = row
    end

    tableFrame.footer = CreateFrame("Frame", nil, tableFrame)
    tableFrame.footer.toggle = self:CreateToggleButton(tableFrame.footer)

    self.tableFrame = tableFrame
    self:UpdateToggleButton()
    return tableFrame
end

function UI:RenderRepairColumn(cell, member, status)
    local rr, rg, rb = self:GetRepairColor(status.repair)
    self:LayoutTextCell(
        cell,
        status.repairText,
        rr, rg, rb,
        string.format("%s — Repair", member.name),
        status.repair and string.format("Average durability: %d%%", status.repair) or "Repair data not shared"
    )
end

function UI:RenderConsumableColumn(cell, member, status, column)
    local kindKey = column.consumableKind
    local fields = ReadyCheck.CONSUMABLE_STATUS_FIELDS[kindKey]
    local columnLabel = column.columnLabel or column.label
    local consumableConfig = Key.Auras and Key.Auras:GetConsumableConfig(kindKey)

    if not fields then
        return
    end

    if kindKey == "flask" then
        local tierMeta = Key.Auras and Key.Auras:GetQualityTierMeta(status[fields.qualityTier])
        self:LayoutFlaskIconCell(
            cell,
            status[fields.icon],
            tierMeta and tierMeta.premiumBorder,
            status[fields.label],
            status[fields.lowTime]
        )
        return
    end

    local goldBorder = false
    local premiumTooltip
    local eating = false

    if kindKey == "food" then
        goldBorder = status[fields.hearty]
        eating = status[fields.eating] == true
        premiumTooltip = consumableConfig and consumableConfig.premiumTooltip
        if eating then
            premiumTooltip = consumableConfig and consumableConfig.eatingTooltip
        end
    elseif kindKey == "oil" and fields.qualityTier then
        local tierMeta = Key.Auras and Key.Auras:GetQualityTierMeta(status[fields.qualityTier])
        goldBorder = tierMeta and tierMeta.premiumBorder
        premiumTooltip = consumableConfig and consumableConfig.premiumTooltip
    end

    self:LayoutConsumableIconCell(
        cell,
        status[fields.ok],
        status[fields.icon],
        goldBorder,
        status[fields.label],
        member.name,
        columnLabel,
        Key.Auras and Key.Auras:GetDefaultIconForKind(kindKey, status[fields.hearty]),
        premiumTooltip,
        eating
    )
end

function UI:RenderBuffsColumn(cell, member, status)
    self:LayoutTextCell(
        cell,
        status.buffsText,
        0.85, 0.85, 0.85,
        string.format("%s — Party buffs", member.name),
        status.buffsText
    )
end

function UI:RenderReadyColumn(cell, member)
    local isReady = ReadyCheck:GetMemberReadyState(member.unit)
    local readyText, rr, rg, rb = self:GetReadyText(isReady)
    local tooltipBody
    if isReady == nil then
        tooltipBody = "Ready state not shared"
    elseif isReady then
        tooltipBody = "Marked ready"
    else
        tooltipBody = "Marked unready"
    end
    self:LayoutTextCell(
        cell,
        readyText,
        rr, rg, rb,
        string.format("%s — Ready state", member.name),
        tooltipBody,
        "CENTER"
    )
end

UI.COLUMN_RENDERERS = {
    repair = UI.RenderRepairColumn,
    consumable_icon = UI.RenderConsumableColumn,
    buffs = UI.RenderBuffsColumn,
    ready = UI.RenderReadyColumn,
}

function UI:RenderColumnCell(cell, member, status, column)
    local renderer = self.COLUMN_RENDERERS[column.type]
    if renderer then
        renderer(self, cell, member, status, column)
    end
end

function UI:LayoutTable(tableFrame, contentWidth, members)
    if not tableFrame then
        return self.HEADER_HEIGHT
    end

    local columnWidths = self:ComputeColumnWidths(contentWidth)
    local nameWidth = columnWidths.name
    local x = nameWidth

    tableFrame.header:SetSize(nameWidth, self.HEADER_HEIGHT)
    tableFrame.header:ClearAllPoints()
    tableFrame.header:SetPoint("TOPLEFT", 0, 0)

    for _, column in ipairs(self.COLUMNS) do
        local width = columnWidths[column.key]
        local cell = tableFrame.headerCells[column.key]
        cell:SetSize(width, self.HEADER_HEIGHT)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", x, 0)
        if self:IsCenterColumn(column) then
            self:ApplyCellTextAnchor(cell, "CENTER")
        end
        x = x + width
    end

    for rowIndex = 1, self.MAX_ROWS do
        local row = tableFrame.rows[rowIndex]
        row.name:Hide()
        for _, column in ipairs(self.COLUMNS) do
            row[column.key]:Hide()
        end
    end

    local memberCount = members and #members or 0
    if memberCount == 0 then
        tableFrame:SetSize(contentWidth, self.HEADER_HEIGHT)
        return self.HEADER_HEIGHT
    end

    for rowIndex, member in ipairs(members) do
        if rowIndex > self.MAX_ROWS then
            break
        end

        local status = ReadyCheck:GetMemberStatus(member.unit)
        local row = tableFrame.rows[rowIndex]
        local y = -(self.HEADER_HEIGHT + ((rowIndex - 1) * self.ROW_HEIGHT))

        row.name:SetSize(nameWidth, self.ROW_HEIGHT)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", 0, y)
        row.name.text:SetText(member.name)
        local nr, ng, nb = 1, 1, 1
        if Key.Keystones and member.classFilename then
            nr, ng, nb = Key.Keystones:GetClassColor(member.classFilename)
        end
        row.name.text:SetTextColor(nr, ng, nb)
        row.name.tooltipTitle = member.name
        row.name:Show()

        x = nameWidth

        for _, column in ipairs(self.COLUMNS) do
            local width = columnWidths[column.key]
            local cell = row[column.key]
            cell:SetSize(width, self.ROW_HEIGHT)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", x, y)

            self:RenderColumnCell(cell, member, status, column)

            cell:Show()
            x = x + width
        end
    end

    local height = self.HEADER_HEIGHT + (memberCount * self.ROW_HEIGHT) + self.FOOTER_HEIGHT

    tableFrame.footer:ClearAllPoints()
    tableFrame.footer:SetPoint("TOPLEFT", 0, -(self.HEADER_HEIGHT + (memberCount * self.ROW_HEIGHT) + 4))
    tableFrame.footer:SetSize(contentWidth, self.FOOTER_HEIGHT)
    tableFrame.footer.toggle:ClearAllPoints()
    tableFrame.footer.toggle:SetPoint("RIGHT", tableFrame.footer, "RIGHT", 0, 0)
    self:UpdateToggleButton()

    tableFrame:SetSize(contentWidth, height)
    return height
end

local ADDON_NAME = ...

KeyReadyCheck = KeyReadyCheck or {}
local ReadyCheck = KeyReadyCheck

ReadyCheck.readyCache = ReadyCheck.readyCache or {}
ReadyCheck.readyCacheByGUID = ReadyCheck.readyCacheByGUID or {}
ReadyCheck.primaryReadyCache = ReadyCheck.primaryReadyCache or {}
ReadyCheck.sessionReadyCache = ReadyCheck.sessionReadyCache or {}
ReadyCheck.sessionReadyCacheByGUID = ReadyCheck.sessionReadyCacheByGUID or {}
ReadyCheck.sessionPrimaryReadyCache = ReadyCheck.sessionPrimaryReadyCache or {}
ReadyCheck.playerReady = ReadyCheck.playerReady or false
ReadyCheck.toggleLockUntil = ReadyCheck.toggleLockUntil or 0
ReadyCheck.TOGGLE_LOCK_SECONDS = 1
ReadyCheck.FOOTER_HEIGHT = 30

ReadyCheck.ROW_HEIGHT = 20
ReadyCheck.HEADER_HEIGHT = 18
ReadyCheck.MAX_ROWS = 40
ReadyCheck.ICON_SIZE = 18
ReadyCheck.FLASK_LOW_TIME_SECONDS = 40 * 60

ReadyCheck.REPAIR_THRESHOLDS = {
    { min = 90, r = 0.3, g = 0.9, b = 0.35 },
    { min = 50, r = 0.95, g = 0.75, b = 0.25 },
}

ReadyCheck.READY_PAYLOAD_FIELDS = { "repair", "food", "flask", "oil", "isReady" }
ReadyCheck.EMPTY_READY_DEFAULTS = { repair = 100, food = 0, flask = 0, oil = 0, isReady = 0 }

ReadyCheck.COLUMNS = {
    { key = "repair", label = "Repair", width = 0.11, type = "repair" },
    { key = "food", label = "Food", width = 0.14, type = "consumable_icon", consumableKind = "food" },
    { key = "flask", label = "Flask", width = 0.14, type = "consumable_icon", consumableKind = "flask" },
    { key = "oil", label = "Oil", width = 0.14, type = "consumable_icon", consumableKind = "oil", columnLabel = "Weapon oil" },
    { key = "buffs", label = "Party Buffs", width = 0.29, type = "buffs" },
    { key = "ready", label = "Ready", width = 0.08, type = "ready" },
}

ReadyCheck.CONSUMABLE_STATUS_FIELDS = {
    food = { ok = "foodOk", icon = "foodIcon", label = "foodLabel", hearty = "foodHearty", eating = "foodEating" },
    flask = {
        ok = "flaskOk",
        icon = "flaskIcon",
        label = "flaskLabel",
        qualityTier = "flaskQualityTier",
        lowTime = "flaskLowTime",
    },
    oil = { ok = "oilOk", icon = "oilIcon", label = "oilLabel", qualityTier = "oilQualityTier" },
}

function ReadyCheck:GetColumnConfig(key)
    for _, column in ipairs(self.COLUMNS) do
        if column.key == key then
            return column
        end
    end
    return nil
end

function ReadyCheck:GetColumnType(columnOrKey)
    if type(columnOrKey) == "table" then
        return columnOrKey.type
    end

    local column = self:GetColumnConfig(columnOrKey)
    return column and column.type
end

function ReadyCheck:IsIconColumn(columnOrKey)
    return self:GetColumnType(columnOrKey) == "consumable_icon"
end

function ReadyCheck:IsCenterColumn(columnOrKey)
    local columnType = self:GetColumnType(columnOrKey)
    return columnType == "consumable_icon" or columnType == "ready"
end

function ReadyCheck:GetDefaultIcon()
    return Key and Key.DEFAULT_ICON or 134400
end

function ReadyCheck:GetReadyPayloadPattern()
    if KeyPartySync and KeyPartySync.PROTOCOL and KeyPartySync.PROTOCOL.READY then
        return KeyPartySync.PROTOCOL.READY.pattern
    end
    return "^P:(%d+):(%d+):(%d+):(%d+):?(%d*)$"
end

function ReadyCheck:GetReadyStatePayloadPattern()
    if KeyPartySync and KeyPartySync.PROTOCOL and KeyPartySync.PROTOCOL.READY_STATE then
        return KeyPartySync.PROTOCOL.READY_STATE.pattern
    end
    return "^Y:(%d+)$"
end

function ReadyCheck:ComputeColumnWidths(contentWidth)
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

function ReadyCheck:ApplyCellTextAnchor(cell, justify)
    justify = justify or cell.justify or "LEFT"
    cell.text:ClearAllPoints()
    if justify == "CENTER" then
        cell.text:SetPoint("CENTER", cell, "CENTER", 0, 0)
    else
        cell.text:SetPoint("LEFT", cell, "LEFT", 2, 0)
    end
    cell.text:SetJustifyH(justify)
end

function ReadyCheck:BuildLookupKeys(name)
    if KeyKeystones and KeyKeystones.BuildLookupKeys then
        return KeyKeystones:BuildLookupKeys(name)
    end
    return name and { name } or {}
end

function ReadyCheck:FindPartyUnitForSender(sender)
    if KeyKeystones and KeyKeystones.FindPartyUnitForSender then
        return KeyKeystones:FindPartyUnitForSender(sender)
    end
    return nil
end

function ReadyCheck:GetPlayerRepairPercent()
    if KeyApiInventoryDurability and KeyApiInventoryDurability.GetRepairPercent then
        return KeyApiInventoryDurability:GetRepairPercent()
    end
    return 100
end

function ReadyCheck:GetConsumableStatus(unit)
    return KeyAuras:GetConsumableStatus(unit)
end

function ReadyCheck:GetPartyBuffText(unit)
    if not KeyApiCUnitAuras or not KeyApiCUnitAuras.GetSelfSourcedBuffNames then
        return "—"
    end

    local buffs = KeyApiCUnitAuras:GetSelfSourcedBuffNames(unit, "HELPFUL|RAID")
    if not buffs or #buffs == 0 then
        return "—"
    end

    return table.concat(buffs, ", ")
end

function ReadyCheck:GetPlayerSnapshot()
    local repair = self:GetPlayerRepairPercent()
    local food, foodLabel, flask, flaskLabel, oil, oilLabel, _, _, _, _, _, _, _, _, foodEating, foodEatingLabel = self:GetConsumableStatus("player")

    return {
        repair = repair,
        food = food and 1 or 0,
        flask = flask and 1 or 0,
        oil = oil and 1 or 0,
        isReady = self.playerReady and 1 or 0,
        foodLabel = foodLabel or (foodEating and foodEatingLabel),
        flaskLabel = flaskLabel,
        oilLabel = oilLabel,
    }
end

function ReadyCheck:BuildReadyPayloadFromSnapshot(snapshot)
    local prefix = "P"
    if KeyPartySync and KeyPartySync.PROTOCOL and KeyPartySync.PROTOCOL.READY then
        prefix = KeyPartySync.PROTOCOL.READY.prefix
    end

    local values = {}
    for _, field in ipairs(self.READY_PAYLOAD_FIELDS) do
        values[#values + 1] = tostring(snapshot[field] or 0)
    end
    return prefix .. ":" .. table.concat(values, ":")
end

function ReadyCheck:BuildReadyPayload()
    return self:BuildReadyPayloadFromSnapshot(self:GetPlayerSnapshot())
end

function ReadyCheck:BuildEmptyReadyPayload()
    return self:BuildReadyPayloadFromSnapshot(self.EMPTY_READY_DEFAULTS)
end

function ReadyCheck:BuildReadyStatePayload()
    local prefix = "Y"
    if KeyPartySync and KeyPartySync.PROTOCOL and KeyPartySync.PROTOCOL.READY_STATE then
        prefix = KeyPartySync.PROTOCOL.READY_STATE.prefix
    end
    return string.format("%s:%d", prefix, self.playerReady and 1 or 0)
end

function ReadyCheck:ParseReadyPayload(message)
    local repair, food, flask, oil, ready = message and message:match(self:GetReadyPayloadPattern())
    if not repair then
        return nil
    end

    local entry = {
        repair = tonumber(repair) or 0,
        food = tonumber(food) == 1,
        flask = tonumber(flask) == 1,
        oil = tonumber(oil) == 1,
    }

    if ready and ready ~= "" then
        entry.isReady = tonumber(ready) == 1
    end

    return entry
end

function ReadyCheck:ParseReadyStatePayload(message)
    local ready = message and message:match(self:GetReadyStatePayloadPattern())
    if not ready then
        return nil
    end

    return tonumber(ready) == 1
end

function ReadyCheck:IsToggleLocked()
    return GetTime() < (self.toggleLockUntil or 0)
end

function ReadyCheck:GetPlayerReady()
    return self.playerReady and true or false
end

function ReadyCheck:GetMemberReadyState(unit)
    if UnitIsUnit(unit, "player") then
        return self:GetPlayerReady()
    end

    local cached = self:LookupCachedReady(unit)
    if cached and cached.isReady ~= nil then
        return cached.isReady and true or false
    end

    return nil
end

function ReadyCheck:SetPartyReadyState(sender, isReady)
    if not sender or sender == "" then
        return
    end

    local entry = self.primaryReadyCache[sender] or {}
    entry.isReady = isReady and true or false
    self:StoreReadyEntry(entry, sender)
end

function ReadyCheck:UpdateToggleButton()
    local footer = self.tableFrame and self.tableFrame.footer
    local button = footer and footer.toggle
    if not button or not button.label then
        return
    end

    local locked = self:IsToggleLocked()
    local ready = self:GetPlayerReady()

    button:SetEnabled(not locked)

    if ready then
        button.label:SetText(locked and "You: Ready (locked)" or "You: Ready")
    else
        button.label:SetText(locked and "You: Unready (locked)" or "You: Unready")
    end

    KeyUI:ApplyReadyToggleStyle(button, ready, locked)
end

function ReadyCheck:TogglePlayerReady()
    if self:IsToggleLocked() then
        return
    end

    self.playerReady = not self.playerReady
    self.toggleLockUntil = GetTime() + self.TOGGLE_LOCK_SECONDS
    self:UpdateToggleButton()

    Key.Dispatch("UI_READY_TOGGLE")

    if self.toggleUnlockTimer then
        self.toggleUnlockTimer:Cancel()
    end

    self.toggleUnlockTimer = C_Timer.NewTimer(self.TOGGLE_LOCK_SECONDS, function()
        self.toggleUnlockTimer = nil
        self:UpdateToggleButton()
    end)
end

function ReadyCheck:StoreReadyEntry(entry, sender)
    if KeyKeystones and KeyKeystones.StoreEntryForSender then
        KeyKeystones:StoreEntryForSender(
            entry,
            sender,
            self.primaryReadyCache,
            self.readyCache,
            self.readyCacheByGUID
        )
    end
end

function ReadyCheck:SetPartyReady(sender, entry)
    if not sender or sender == "" then
        return
    end

    if not entry then
        if KeyKeystones and KeyKeystones.ClearEntryForSender then
            KeyKeystones:ClearEntryForSender(
                sender,
                self.primaryReadyCache,
                self.readyCache,
                self.readyCacheByGUID
            )
        end
        return
    end

    self:StoreReadyEntry(entry, sender)
end

function ReadyCheck:LookupCachedReady(unit)
    if KeyKeystones and KeyKeystones.LookupUnitInCaches then
        return KeyKeystones:LookupUnitInCaches(unit, self.readyCacheByGUID, self.readyCache)
            or KeyKeystones:LookupUnitInCaches(unit, self.sessionReadyCacheByGUID, self.sessionReadyCache)
    end
    return nil
end

function ReadyCheck:RestoreSessionCacheIfNeeded()
    if next(self.primaryReadyCache) or not next(self.sessionPrimaryReadyCache) then
        return
    end

    for sender, entry in pairs(self.sessionPrimaryReadyCache) do
        self:StoreReadyEntry(entry, sender)
    end
end

function ReadyCheck:ClearReadyCache()
    wipe(self.readyCache)
    wipe(self.readyCacheByGUID)
    wipe(self.primaryReadyCache)
    wipe(self.sessionReadyCache)
    wipe(self.sessionReadyCacheByGUID)
    wipe(self.sessionPrimaryReadyCache)
    self.playerReady = false
    self.toggleLockUntil = 0
    if self.toggleUnlockTimer then
        self.toggleUnlockTimer:Cancel()
        self.toggleUnlockTimer = nil
    end
    self:UpdateToggleButton()
end

function ReadyCheck:RebindReadyCache()
    if KeyKeystones and KeyKeystones.RebindCacheByGUID then
        KeyKeystones:RebindCacheByGUID(self.primaryReadyCache, self.readyCacheByGUID)
    end
end

function ReadyCheck:ApplyLiveConsumableStatus(status, unit, liveValues)
    local isPlayer = UnitIsUnit(unit, "player")
    local cached = (not isPlayer) and self:LookupCachedReady(unit) or nil

    for kindKey, fields in pairs(self.CONSUMABLE_STATUS_FIELDS) do
        local active = liveValues[kindKey]
        if active then
            status[fields.ok] = active.ok ~= false
            if fields.icon and active.icon then
                status[fields.icon] = active.icon
            end
            if fields.hearty and active.hearty then
                status[fields.hearty] = active.hearty
            end
            if fields.eating and active.eating then
                status[fields.eating] = true
            end
            if fields.qualityTier and active.qualityTier then
                status[fields.qualityTier] = active.qualityTier
            end
            if fields.label and active.label then
                status[fields.label] = active.label
            end
            if fields.lowTime ~= nil and active.lowTime ~= nil then
                status[fields.lowTime] = active.lowTime
            end
        elseif cached and cached[kindKey] then
            status[fields.ok] = true
        end
    end
end

function ReadyCheck:GetMemberStatus(unit)
    local status = {
        repair = nil,
        repairText = "—",
        buffsText = "—",
        foodOk = false,
        flaskOk = false,
        oilOk = false,
        foodIcon = nil,
        foodHearty = false,
        foodEating = false,
        oilIcon = nil,
        oilQualityTier = nil,
        flaskIcon = nil,
        flaskQualityTier = nil,
        flaskLowTime = false,
    }

    if UnitIsUnit(unit, "player") then
        status.repair = self:GetPlayerRepairPercent()
        status.repairText = string.format("%d%%", status.repair)
    else
        local cached = self:LookupCachedReady(unit)
        if cached and cached.repair then
            status.repair = cached.repair
            status.repairText = string.format("%d%%", cached.repair)
        end
    end

    local food, foodLabel, flaskReady, flaskLabel, oil, oilLabel, foodIcon, foodHearty, oilIcon, flaskIcon, flaskQualityTier, flaskRemaining, oilQualityTier,
        foodEating, foodEatingLabel, foodEatingIcon = self:GetConsumableStatus(unit)
    self:ApplyLiveConsumableStatus(status, unit, {
        food = food and { ok = true, icon = foodIcon, hearty = foodHearty, label = foodLabel }
            or foodEating and { ok = false, eating = true, icon = foodEatingIcon, label = foodEatingLabel }
            or nil,
        flask = flaskIcon and {
            icon = flaskIcon,
            qualityTier = flaskQualityTier,
            label = flaskLabel,
            ok = flaskReady,
            lowTime = flaskRemaining ~= nil and flaskRemaining < self.FLASK_LOW_TIME_SECONDS,
        } or nil,
        oil = oil and { icon = oilIcon, label = oilLabel, qualityTier = oilQualityTier } or nil,
    })

    status.buffsText = self:GetPartyBuffText(unit)

    return status
end

function ReadyCheck:GetOkColor(ok)
    if ok then
        return 0.3, 0.9, 0.35
    end
    return 0.9, 0.35, 0.35
end

function ReadyCheck:GetRepairColor(percent)
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

function ReadyCheck:GetReadyText(isReady)
    if isReady == nil then
        return "—", 0.5, 0.5, 0.5
    end
    if isReady then
        return "Ready", 0.3, 0.9, 0.35
    end
    return "Unready", 0.9, 0.35, 0.35
end

function ReadyCheck:CreateToggleButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetBackdrop(KeyUI.BACKDROPS.tab)
    KeyUI:ApplyReadyToggleStyle(button, false, false)
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

function ReadyCheck:CreateCell(parent, justify)
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

function ReadyCheck:EnsureIconCell(cell)
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

function ReadyCheck:SetIconCellBorder(iconFrame, goldBorder, eating)
    if eating then
        iconFrame:SetBackdropBorderColor(0.95, 0.75, 0.25, 1)
    elseif goldBorder then
        iconFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        iconFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end
end

function ReadyCheck:SetFlaskIconBorder(iconFrame, goldBorder, lowTime)
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

function ReadyCheck:LayoutFlaskIconCell(cell, iconFileID, goldBorder, label, lowTime)
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

function ReadyCheck:LayoutConsumableIconCell(cell, ok, iconFileID, goldBorder, label, memberName, columnLabel, defaultIcon, premiumTooltip, eating)
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
    cell.iconFrame.icon:SetTexture(icon or self:GetDefaultIcon())
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

function ReadyCheck:LayoutTextCell(cell, text, r, g, b, tooltipTitle, tooltipBody, justify)
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

function ReadyCheck:EnsureTable(parent)
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

function ReadyCheck:RenderRepairColumn(cell, member, status)
    local rr, rg, rb = self:GetRepairColor(status.repair)
    self:LayoutTextCell(
        cell,
        status.repairText,
        rr, rg, rb,
        string.format("%s — Repair", member.name),
        status.repair and string.format("Average durability: %d%%", status.repair) or "Repair data not shared"
    )
end

function ReadyCheck:RenderConsumableColumn(cell, member, status, column)
    local kindKey = column.consumableKind
    local fields = self.CONSUMABLE_STATUS_FIELDS[kindKey]
    local columnLabel = column.columnLabel or column.label
    local consumableConfig = KeyAuras and KeyAuras:GetConsumableConfig(kindKey)

    if not fields then
        return
    end

    if kindKey == "flask" then
        local tierMeta = KeyAuras and KeyAuras:GetQualityTierMeta(status[fields.qualityTier])
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
        local tierMeta = KeyAuras and KeyAuras:GetQualityTierMeta(status[fields.qualityTier])
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
        KeyAuras and KeyAuras:GetDefaultIconForKind(kindKey, status[fields.hearty]),
        premiumTooltip,
        eating
    )
end

function ReadyCheck:RenderBuffsColumn(cell, member, status)
    self:LayoutTextCell(
        cell,
        status.buffsText,
        0.85, 0.85, 0.85,
        string.format("%s — Party buffs", member.name),
        status.buffsText
    )
end

function ReadyCheck:RenderReadyColumn(cell, member)
    local isReady = self:GetMemberReadyState(member.unit)
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

ReadyCheck.COLUMN_RENDERERS = {
    repair = ReadyCheck.RenderRepairColumn,
    consumable_icon = ReadyCheck.RenderConsumableColumn,
    buffs = ReadyCheck.RenderBuffsColumn,
    ready = ReadyCheck.RenderReadyColumn,
}

function ReadyCheck:RenderColumnCell(cell, member, status, column)
    local renderer = self.COLUMN_RENDERERS[column.type]
    if renderer then
        renderer(self, cell, member, status, column)
    end
end

function ReadyCheck:LayoutTable(tableFrame, contentWidth, members)
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

        local status = self:GetMemberStatus(member.unit)
        local row = tableFrame.rows[rowIndex]
        local y = -(self.HEADER_HEIGHT + ((rowIndex - 1) * self.ROW_HEIGHT))

        row.name:SetSize(nameWidth, self.ROW_HEIGHT)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", 0, y)
        row.name.text:SetText(member.name)
        local nr, ng, nb = 1, 1, 1
        if KeyKeystones and member.classFilename then
            nr, ng, nb = KeyKeystones:GetClassColor(member.classFilename)
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

local ADDON_NAME = ...

Key.Teleports = Key.Teleports or {}
local Teleports = Key.Teleports

if not Teleports.SEASON_DUNGEONS then
    error("Key.Teleports.SEASON_DUNGEONS is missing. Load teleport-bar-data.lua before party-complete.lua.")
end

Teleports.MAX_BEST_ROWS = 40
Teleports.BEST_ROW_GAP = 2
Teleports.BEST_NAME_GAP = 2
Teleports.OVERTIME_DESATURATION = 0.72

function Teleports:GetBestTableMetrics(contentWidth)
    local _, _, slotSize = self:ComputeLayout(contentWidth)
    local pitch = slotSize + self.LAYOUT_GAP
    local rowHeight = math.max(16, math.floor(slotSize * 0.34))
    local nameHeight = math.max(10, math.floor(slotSize * 0.16))
    local rowPitch = nameHeight + self.BEST_NAME_GAP + rowHeight + self.BEST_ROW_GAP

    return rowHeight, rowPitch, slotSize, pitch, nameHeight
end

function Teleports:GetBestTableHeight(memberCount, contentWidth)
    if not memberCount or memberCount == 0 then
        return 0
    end

    local rowHeight, rowPitch, _, _, nameHeight = self:GetBestTableMetrics(contentWidth)
    local bandHeight = nameHeight + self.BEST_NAME_GAP + rowHeight
    return (memberCount * bandHeight) + ((memberCount - 1) * self.BEST_ROW_GAP)
end

function Teleports:CreateBestCell(parent, justify)
    local cell = CreateFrame("Frame", nil, parent)
    cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    justify = justify or "CENTER"
    cell.text:SetJustifyH(justify)
    if justify == "LEFT" then
        cell.text:SetPoint("LEFT", cell, "LEFT", 2, 0)
    else
        cell.text:SetPoint("CENTER")
    end
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function()
        if not cell.tooltipTitle then
            return
        end
        GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
        GameTooltip:SetText(cell.tooltipTitle, 1, 1, 1)
        if cell.tooltipBody then
            GameTooltip:AddLine(cell.tooltipBody, 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return cell
end

function Teleports:EnsureBestTable(parent)
    if self.bestTable then
        for rowIndex = 1, self.MAX_BEST_ROWS do
            local row = self.bestTable.rows[rowIndex]
            if row and not row.name then
                row.name = self:CreateBestCell(self.bestTable, "LEFT")
                row.name:Hide()
            end
        end
        return self.bestTable
    end

    local tableFrame = CreateFrame("Frame", nil, parent)
    tableFrame.rows = {}

    for rowIndex = 1, self.MAX_BEST_ROWS do
        tableFrame.rows[rowIndex] = {
            name = self:CreateBestCell(tableFrame, "LEFT"),
        }
        tableFrame.rows[rowIndex].name:Hide()
        for colIndex = 1, self.SLOT_COUNT do
            tableFrame.rows[rowIndex][colIndex] = self:CreateBestCell(tableFrame)
            tableFrame.rows[rowIndex][colIndex]:Hide()
        end
    end

    self.bestTable = tableFrame
    return tableFrame
end

function Teleports:UpdateBestNameCell(cell, member, nameHeight)
    if not cell or not cell.text then
        return
    end

    local memberName = member and member.name or "Unknown"
    local r, g, b = self:GetClassColor(member and member.classFilename)
    local fontSize = math.max(7, math.floor((nameHeight or 10) * 0.85))

    cell.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    cell.text:SetText(memberName)
    cell.text:SetTextColor(r, g, b)
    cell.tooltipTitle = memberName
    cell.tooltipBody = "Season best completions"
end

function Teleports:UpdateBestCell(cell, member, dungeon, level, overTime)
    if not cell or not cell.text then
        return
    end

    local classFilename = member and member.classFilename
    local dungeonName = self:GetDungeonName(dungeon)
    local memberName = member and member.name or "Unknown"

    if not level or level == 0 then
        cell.text:SetText("—")
        cell.text:SetTextColor(0.45, 0.45, 0.45)
        cell.tooltipTitle = string.format("%s — %s", memberName, dungeonName)
        cell.tooltipBody = "No completed run this season"
        return
    end

    local r, g, b = self:GetClassColor(classFilename)
    if overTime then
        local scale = self.OVERTIME_DESATURATION
        r, g, b = r * scale, g * scale, b * scale
    end

    cell.text:SetText("+" .. tostring(level))
    cell.text:SetTextColor(r, g, b)
    cell.tooltipTitle = string.format("%s — %s", memberName, dungeonName)
    cell.tooltipBody = overTime and string.format("Best: +%d (over time)", level) or string.format("Best: +%d", level)
end

function Teleports:LayoutBestTable(tableFrame, contentWidth, members)
    if not tableFrame then
        return 0
    end

    local rowHeight, rowPitch, slotSize, pitch, nameHeight = self:GetBestTableMetrics(contentWidth)
    local memberCount = members and #members or 0

    for rowIndex = 1, self.MAX_BEST_ROWS do
        local row = tableFrame.rows[rowIndex]
        if row.name then
            row.name:Hide()
        end
        for colIndex = 1, self.SLOT_COUNT do
            row[colIndex]:Hide()
        end
    end

    if memberCount == 0 then
        tableFrame:SetSize(contentWidth, 0)
        return 0
    end

    local fontSize = math.max(8, math.floor(rowHeight * 0.72))

    for rowIndex, member in ipairs(members) do
        if rowIndex > self.MAX_BEST_ROWS then
            break
        end

        local row = tableFrame.rows[rowIndex]
        local y = -((rowIndex - 1) * rowPitch)
        local cellY = y - nameHeight - self.BEST_NAME_GAP

        row.name:SetSize(contentWidth, nameHeight)
        row.name:ClearAllPoints()
        row.name:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, y)
        self:UpdateBestNameCell(row.name, member, nameHeight)
        row.name:Show()

        for colIndex, dungeon in ipairs(self.SEASON_DUNGEONS) do
            local cell = row[colIndex]
            local level, overTime = 0, false
            if Key.Keystones and member.unit then
                level, overTime = Key.Keystones:GetMemberBestForMap(member.unit, dungeon.challengeModeID)
            end

            cell:SetSize(slotSize, rowHeight)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", (colIndex - 1) * pitch, cellY)
            cell.text:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
            self:UpdateBestCell(cell, member, dungeon, level, overTime)
            cell:Show()
        end
    end

    local tableHeight = self:GetBestTableHeight(memberCount, contentWidth)
    tableFrame:SetSize(contentWidth, tableHeight)

    if Key.PartyCompleteLog and Key.PartyCompleteLog.LogBestTableLayout then
        Key.PartyCompleteLog:LogBestTableLayout(contentWidth, memberCount, tableHeight)
    end

    return tableHeight
end

Key.Views = Key.Views or {}

local DungeonHeader = {}
Key.Views.DungeonHeader = DungeonHeader

local QUESTION_MARK_ICON = 134400

local function ResolveDungeonIcon(dungeon)
    if dungeon and dungeon.icon and dungeon.icon ~= 0 then
        return dungeon.icon
    end
    return QUESTION_MARK_ICON
end

function DungeonHeader.Create(parent, dungeon, x, y, iconSize, headerHeight)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(iconSize, headerHeight or iconSize)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:EnableMouse(true)

    local icon = header:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(header)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetTexture(ResolveDungeonIcon(dungeon))
    header.icon = icon
    header.dungeon = dungeon

    local label = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 2, 3)
    label:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -2, 3)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(dungeon.short or dungeon.name or "")
    header.label = label

    return header
end

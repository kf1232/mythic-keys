local ADDON_NAME = ...

KeyApiMinimap = KeyApiMinimap or {}
local API = KeyApiMinimap

local MINIMAP_SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

function API:GetOffsetForAngle(minimap, angleDegrees, buttonRadius)
    if not minimap then
        return 0, 0
    end

    local angle = math.rad(angleDegrees)
    local x, y, q = math.cos(angle), math.sin(angle), 1
    if x < 0 then
        q = q + 1
    end
    if y > 0 then
        q = q + 2
    end

    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local quadTable = MINIMAP_SHAPES[shape] or MINIMAP_SHAPES["ROUND"]
    local w = (minimap:GetWidth() / 2) + (buttonRadius or 0)
    local h = (minimap:GetHeight() / 2) + (buttonRadius or 0)

    if quadTable[q] then
        return x * w, y * h
    end

    local diagRadiusW = math.sqrt(2 * w * w) - 10
    local diagRadiusH = math.sqrt(2 * h * h) - 10
    return math.max(-w, math.min(x * diagRadiusW, w)), math.max(-h, math.min(y * diagRadiusH, h))
end

function API:GetAngleFromCursor(frame)
    if not frame then
        return 0
    end

    local centerX, centerY = frame:GetCenter()
    if not centerX or not centerY then
        return 0
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    if scale and scale > 0 then
        cursorX = cursorX / scale
        cursorY = cursorY / scale
    end

    return math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
end

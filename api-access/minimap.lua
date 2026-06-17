local ADDON_NAME = ...

Key.Api.Minimap = Key.Api.Minimap or {}
local API = Key.Api.Minimap
local Middleware = Key.Api.Middleware

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

function API:GetShape(isSecret)
    if Middleware:Guard(isSecret) then
        return "ROUND"
    end
    if not GetMinimapShape then
        return "ROUND"
    end

    local shape, secret = Middleware:Call(false, GetMinimapShape)
    if secret or not Middleware:IsAccessible(shape) then
        return "ROUND"
    end

    return shape
end

function API:GetOffsetForAngle(isSecret, minimap, angleDegrees, buttonRadius)
    if Middleware:Guard(isSecret, minimap, angleDegrees, buttonRadius) then
        return 0, 0
    end
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

    local shape = self:GetShape(false)

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

function API:GetAngleFromCursor(isSecret, frame)
    if Middleware:Guard(isSecret, frame) then
        return 0
    end
    if not frame then
        return 0
    end

    local centerX, centerY = frame:GetCenter()
    if Middleware:CheckSecret(centerX, centerY) then
        return 0
    end

    local values, secret = Middleware:PCall(false, GetCursorPosition)
    if secret or not values then
        return 0
    end

    local cursorX = values[1]
    local cursorY = values[2]

    local scale = frame:GetEffectiveScale()
    if scale and scale > 0 then
        cursorX = cursorX / scale
        cursorY = cursorY / scale
    end

    return math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
end

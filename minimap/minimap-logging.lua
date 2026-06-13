local ADDON_NAME = ...

KeyMinimapLog = KeyMinimapLog or {}
local MinimapLog = KeyMinimapLog

local BUTTON_RADIUS = 5

local function Log()
    return KeyLog
end

function MinimapLog:GetAngle()
    KeyDB = KeyDB or {}
    KeyDB.minimap = KeyDB.minimap or {}
    return KeyDB.minimap.angle or 225
end

function MinimapLog:GetShape()
    return (GetMinimapShape and GetMinimapShape()) or "ROUND"
end

function MinimapLog:GetOffset()
    if not KeyApiMinimap or not KeyApiMinimap.GetOffsetForAngle or not Minimap then
        return 0, 0
    end
    return KeyApiMinimap:GetOffsetForAngle(Minimap, self:GetAngle(), BUTTON_RADIUS)
end

function MinimapLog:ShouldLog()
    return KeyDebugUI and KeyDebugUI.IsShown and KeyDebugUI:IsShown()
end

function MinimapLog:Log(message, dedupeKey, dedupeWindow)
    local keyLog = Log()
    if not keyLog or not self:ShouldLog() then
        return
    end

    keyLog:Add("Minimap: " .. message, dedupeKey, dedupeWindow)
end

function MinimapLog:LogSnapshot()
    local keyLog = Log()
    if not keyLog then
        return
    end

    local x, y = self:GetOffset()
    keyLog:Add("Minimap:")
    keyLog:Add(string.format(
        "  angle=%d shape=%s offset=(%.1f, %.1f) button=%s",
        self:GetAngle(),
        self:GetShape(),
        x,
        y,
        (KeyMinimap and KeyMinimap.button) and "yes" or "no"
    ))
end

function MinimapLog:LogInit()
    self:Log(
        string.format("initialized angle=%d shape=%s", self:GetAngle(), self:GetShape()),
        "minimap:init",
        30
    )
end

function MinimapLog:LogClick(mouseButton)
    local action = mouseButton == "RightButton" and "open debug console" or "toggle party list"
    self:Log(
        string.format("click %s -> %s", mouseButton or "?", action),
        "minimap:click:" .. tostring(mouseButton or ""),
        0.5
    )
end

function MinimapLog:LogDragStart()
    self:Log(
        string.format("drag started angle=%d", self:GetAngle()),
        "minimap:drag:start",
        0.5
    )
end

function MinimapLog:LogDragStop()
    self:Log(
        string.format("drag ended angle=%d", math.floor(self:GetAngle() + 0.5)),
        "minimap:drag",
        0.2
    )
end

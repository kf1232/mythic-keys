local ADDON_NAME = ...

KeyMinimapLog = KeyMinimapLog or {}
local MinimapLog = KeyMinimapLog

local FEATURE = KeyLog and KeyLog.FEATURE and KeyLog.FEATURE.MINIMAP or "MINI"
local BUTTON_RADIUS = 5

local function Log()
    return KeyLog
end

local function WriteEvent(status, payload, options)
    local keyLog = Log()
    if not keyLog or not keyLog.WriteEvent then
        return
    end

    options = options or {}
    if not options.source and debug and debug.getinfo then
        local info = debug.getinfo(2, "n")
        if info and info.name and info.name ~= "" then
            options.source = info.name
        end
    end

    keyLog:WriteEvent(FEATURE, status, payload, options)
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
    if not self:ShouldLog() then
        return
    end

    WriteEvent(KeyLog.STATUS.DEBUG, message, {
        dedupeKey = dedupeKey,
        dedupeWindow = dedupeWindow,
    })
end

function MinimapLog:LogSnapshot()
    local x, y = self:GetOffset()
    WriteEvent(KeyLog.STATUS.DEBUG, string.format(
        "angle=%d shape=%s offset=(%.1f, %.1f) button=%s",
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

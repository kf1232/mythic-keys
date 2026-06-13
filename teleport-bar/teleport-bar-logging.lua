local ADDON_NAME = ...

KeyTeleportBarLog = KeyTeleportBarLog or {}
local TeleportBarLog = KeyTeleportBarLog

local function Log()
    return KeyLog
end

local function Teleports()
    return KeyTeleports
end

function TeleportBarLog:LogTeleport(spellID, reason, extra)
    local keyLog = Log()
    if not keyLog then
        return
    end

    local teleports = Teleports()
    local dungeon = teleports and teleports.spellToDungeon and teleports.spellToDungeon[spellID]
    if not dungeon or not teleports then
        return
    end

    local name = teleports:GetDungeonName(dungeon)
    local message

    if reason == "unavailable" then
        message = string.format("Teleport unavailable: %s", name)
    elseif reason == "cooldown" then
        message = string.format(
            "Teleport on cooldown: %s (%s)",
            name,
            SecondsToTime(math.ceil(extra or 0))
        )
    elseif reason == "error" then
        message = string.format("Teleport failed: %s (%s)", name, extra or "unknown error")
    else
        message = string.format("Teleporting to %s", name)
    end

    keyLog:Add(message, "teleport:" .. tostring(spellID) .. ":" .. tostring(reason), 0.5)
end

function TeleportBarLog:ShouldLogUpdates()
    return KeyDebugUI and KeyDebugUI.IsShown and KeyDebugUI:IsShown()
end

function TeleportBarLog:LogUpdate(message, dedupeKey, dedupeWindow)
    local keyLog = Log()
    if not keyLog or not self:ShouldLogUpdates() then
        return
    end

    keyLog:Add("Teleport bar: " .. message, dedupeKey, dedupeWindow)
end

function TeleportBarLog:LogBarLayout(contentWidth, barHeight, slotSize)
    self:LogUpdate(
        string.format("layout width=%d height=%d slot=%d", contentWidth or 0, barHeight or 0, slotSize or 0),
        "teleport-bar:layout",
        0.2
    )
end

function TeleportBarLog:LogRefreshActionButtons()
    self:LogUpdate("refresh action buttons", "teleport-bar:refresh-actions", 0.5)
end

function TeleportBarLog:LogInit()
    local teleports = Teleports()
    local slotCount = teleports and teleports.SLOT_COUNT or 0
    self:LogUpdate(
        string.format("initialized slots=%d bar=%s", slotCount, (teleports and teleports.bar) and "yes" or "no"),
        "teleport-bar:init",
        30
    )
end

function TeleportBarLog:LogSnapshot()
    local keyLog = Log()
    local teleports = Teleports()
    if not keyLog or not teleports then
        return
    end

    keyLog:Add("Teleport bar:")
    keyLog:Add(string.format(
        "  slots=%d bar=%s contentWidth=%d",
        teleports.SLOT_COUNT or 0,
        teleports.bar and "yes" or "no",
        teleports:GetDefaultContentWidth()
    ))

    if teleports.bar then
        keyLog:Add(string.format(
            "  size=%dx%d parent=%s",
            teleports.bar:GetWidth(),
            teleports.bar:GetHeight(),
            teleports.bar:GetParent() and teleports.bar:GetParent():GetName() or "(none)"
        ))
    end
end

TeleportBarLog:LogInit()

local ADDON_NAME = ...

KeyTeleportBarLog = KeyTeleportBarLog or {}
local TeleportBarLog = KeyTeleportBarLog

local FEATURE = KeyLog and KeyLog.FEATURE and KeyLog.FEATURE.TELEPORT_BAR or "TPBR"

local function Log()
    return KeyLog
end

local function Teleports()
    return KeyTeleports
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

function TeleportBarLog:LogTeleport(spellID, reason, extra)
    local teleports = Teleports()
    local dungeon = teleports and teleports.spellToDungeon and teleports.spellToDungeon[spellID]
    if not dungeon or not teleports then
        return
    end

    local name = teleports:GetDungeonName(dungeon)
    local payload
    local status = KeyLog.STATUS.INFO

    if reason == "unavailable" then
        payload = string.format("Teleport unavailable: %s", name)
        status = KeyLog.STATUS.WARN
    elseif reason == "cooldown" then
        payload = string.format(
            "Teleport on cooldown: %s (%s)",
            name,
            SecondsToTime(math.ceil(extra or 0))
        )
        status = KeyLog.STATUS.WARN
    elseif reason == "error" then
        payload = string.format("Teleport failed: %s (%s)", name, extra or "unknown error")
        status = KeyLog.STATUS.ERROR
    else
        payload = string.format("Teleporting to %s", name)
    end

    WriteEvent(status, payload, {
        dedupeKey = "teleport:" .. tostring(spellID) .. ":" .. tostring(reason),
        dedupeWindow = 0.5,
    })
end

function TeleportBarLog:ShouldLogUpdates()
    return KeyDebugUI and KeyDebugUI.IsShown and KeyDebugUI:IsShown()
end

function TeleportBarLog:LogUpdate(message, dedupeKey, dedupeWindow)
    if not self:ShouldLogUpdates() then
        return
    end

    WriteEvent(KeyLog.STATUS.DEBUG, message, {
        dedupeKey = dedupeKey,
        dedupeWindow = dedupeWindow,
    })
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
    local teleports = Teleports()
    if not teleports then
        return
    end

    WriteEvent(KeyLog.STATUS.DEBUG, string.format(
        "slots=%d bar=%s contentWidth=%d",
        teleports.SLOT_COUNT or 0,
        teleports.bar and "yes" or "no",
        teleports:GetDefaultContentWidth()
    ))

    if teleports.bar then
        WriteEvent(KeyLog.STATUS.DEBUG, string.format(
            "size=%dx%d parent=%s",
            teleports.bar:GetWidth(),
            teleports.bar:GetHeight(),
            teleports.bar:GetParent() and teleports.bar:GetParent():GetName() or "(none)"
        ))
    end
end

TeleportBarLog:LogInit()

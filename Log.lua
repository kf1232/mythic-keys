local ADDON_NAME = ...

KeyLog = KeyLog or {}
local Log = KeyLog

Log.entries = Log.entries or {}
Log.listeners = Log.listeners or {}
Log.maxEntries = 500
Log.dedupeCache = Log.dedupeCache or {}

Log.STATUS = {
    INFO = "info",
    WARN = "warn",
    ERROR = "error",
    DEBUG = "debug",
}

Log.FEATURE = {
    CORE = "CORE",
    PARTY_SYNC = "SYNC",
    INTEGRATIONS = "EXTK",
    TELEPORT_BAR = "TPBR",
    PARTY_COMPLETE = "PCMP",
    MINIMAP = "MINI",
    BUFFS_DEBUFFS = "B&DB",
    DEBUG = "DBUG",
    CLICK_DEBUG = "CLIK",
}

local function ResolveCaller(level)
    if not debug or not debug.getinfo then
        return nil
    end

    local info = debug.getinfo(level or 2, "n")
    if info and info.name and info.name ~= "" then
        return info.name
    end

    return nil
end

function Log:FormatOrigin(entry)
    local code = entry.featureCode or self.FEATURE.CORE
    if entry.source and entry.source ~= "" then
        return code .. "/" .. entry.source
    end
    return code
end

local STATUS_COLORS = {
    [Log.STATUS.ERROR] = "ff6666",
    [Log.STATUS.WARN] = "ffcc44",
    [Log.STATUS.INFO] = "ffffff",
    [Log.STATUS.DEBUG] = "aaaaaa",
}

local function NormalizeStatus(status)
    status = type(status) == "string" and status:lower() or Log.STATUS.INFO
    if not STATUS_COLORS[status] then
        return Log.STATUS.INFO
    end
    return status
end

local function NormalizeFeatureCode(featureCode)
    if type(featureCode) ~= "string" or featureCode == "" then
        return Log.FEATURE.CORE
    end
    return featureCode
end

local function AppendEntry(log, entry, dedupeKey, dedupeWindow)
    if dedupeKey then
        local now = GetTime()
        local lastAt = log.dedupeCache[dedupeKey]
        if lastAt and (now - lastAt) < (dedupeWindow or 2) then
            return
        end
        log.dedupeCache[dedupeKey] = now
    end

    table.insert(log.entries, entry)

    while #log.entries > log.maxEntries do
        table.remove(log.entries, 1)
    end

    for _, listener in ipairs(log.listeners) do
        listener(entry)
    end
end

function Log:WriteEvent(featureCode, status, payload, options)
    if type(payload) ~= "string" or payload == "" then
        return
    end

    featureCode = NormalizeFeatureCode(featureCode)
    status = NormalizeStatus(status)
    options = options or {}

    local source = options.source
    if not source then
        source = ResolveCaller(2)
    end

    local entry = {
        time = date("%H:%M:%S"),
        featureCode = featureCode,
        source = source,
        status = status,
        payload = payload,
        message = payload,
    }

    local dedupeKey = options.dedupeKey
    if dedupeKey == nil and options.dedupe ~= false then
        dedupeKey = string.format("%s:%s:%s:%s", featureCode, source or "", status, payload)
    end

    AppendEntry(self, entry, dedupeKey, options.dedupeWindow)
end

function Log:SafeValue(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return "[secret]"
    end
    return tostring(value)
end

function Log:TryDisplayValue(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        local ok, result = pcall(string.format, "%s", value)
        if ok and result and result ~= "" then
            return result
        end
        return "[secret]"
    end
    return tostring(value)
end

function Log:ResolveSpellName(spellId, displayName)
    if KeyApiCSpell and KeyApiCSpell.GetSpellName then
        return KeyApiCSpell:GetSpellName(spellId, displayName)
    end
    return nil
end

function Log:ShouldLogAuras(unit)
    if KeyAurasLog and KeyAurasLog.ShouldLogAuras then
        return KeyAurasLog:ShouldLogAuras(unit)
    end
    return false
end

function Log:LogConsumableDiagnostics(unit)
    if KeyAurasLog and KeyAurasLog.LogConsumableDiagnostics then
        KeyAurasLog:LogConsumableDiagnostics(unit)
    end
end

function Log:LogUnitAuras(unit, reason)
    if KeyAurasLog and KeyAurasLog.LogUnitAuras then
        KeyAurasLog:LogUnitAuras(unit, reason)
    end
end

function Log:LogMinimapSnapshot()
    if KeyMinimapLog and KeyMinimapLog.LogSnapshot then
        KeyMinimapLog:LogSnapshot()
    end
end

function Log:LogTeleportBarSnapshot()
    if KeyTeleportBarLog and KeyTeleportBarLog.LogSnapshot then
        KeyTeleportBarLog:LogSnapshot()
    end
end

function Log:LogPartyCompleteSnapshot()
    if KeyPartyCompleteLog and KeyPartyCompleteLog.LogSnapshot then
        KeyPartyCompleteLog:LogSnapshot()
    end
end

function Log:FormatEntry(entry)
    local status = entry.status or Log.STATUS.INFO
    local color = STATUS_COLORS[status] or STATUS_COLORS[Log.STATUS.INFO]
    local origin = self:FormatOrigin(entry)
    local payload = entry.payload or entry.message or ""
    return string.format(
        "|cffcccccc[%s]|r |cff%s%s|r |cff888888(%s)|r %s",
        entry.time or "??:??:??",
        color,
        origin,
        status,
        payload
    )
end

function Log:FormatKeystone(key)
    return KeyKeystones:FormatKey(key)
end

function Log:LogKeystone(sender, key)
    if not sender or sender == "" then
        return
    end

    local shortName = Ambiguate(sender, "short")
    local summary = self:FormatKeystone(key)
    self:WriteEvent(
        self.FEATURE.PARTY_SYNC,
        self.STATUS.INFO,
        string.format("%s: %s", shortName, summary),
        {
            source = "LogKeystone",
            dedupeKey = "keystone:" .. shortName .. ":" .. summary,
            dedupeWindow = 10,
        }
    )
end

function Log:Subscribe(callback)
    if type(callback) ~= "function" then
        return
    end
    table.insert(self.listeners, callback)
end

function Log:StripColorCodes(text)
    if not text then
        return ""
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

function Log:GetText()
    local lines = {}
    for _, entry in ipairs(self.entries) do
        lines[#lines + 1] = self:FormatEntry(entry)
    end
    return table.concat(lines, "\n")
end

function Log:GetPlainText()
    local lines = {}
    for _, entry in ipairs(self.entries) do
        lines[#lines + 1] = self:StripColorCodes(self:FormatEntry(entry))
    end
    return table.concat(lines, "\n")
end

function Log:Clear()
    wipe(self.entries)
    wipe(self.dedupeCache)
    for _, listener in ipairs(self.listeners) do
        listener(nil, true)
    end
end

function Log:FormatError(message, context)
    message = tostring(message or "unknown error")
    if context and context ~= "" then
        return string.format("[%s] %s", context, message)
    end
    return message
end

function Log:PrintError(message, context)
    local text = self:FormatError(message, context)
    local prefix = "|cffFF4444Key error:|r "
    if DEFAULT_CHAT_FRAME then
        for line in string.gmatch(text, "[^\n]+") do
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. line)
        end
    else
        print(prefix .. text)
    end
end

function Log:LogError(message, context, dedupeKey)
    local payload = self:FormatError(message, context)
    self:WriteEvent(self.FEATURE.CORE, self.STATUS.ERROR, payload, {
        source = context or "LogError",
        dedupeKey = dedupeKey or ("error:" .. payload),
        dedupeWindow = 1,
    })
    self:PrintError(message, context)
end

function Log:CaptureError(err)
    local message = tostring(err or "unknown error")
    if debugstack then
        local stack = debugstack(2, 12, 12)
        if stack and stack ~= "" then
            return message .. "\n" .. stack
        end
    end
    return message
end

function Log:RunProtected(context, fn, ...)
    if type(fn) ~= "function" then
        return false, "invalid function"
    end

    local ok, result = xpcall(fn, function(err)
        return self:CaptureError(err)
    end, ...)

    if not ok then
        self:LogError(result, context)
    end

    return ok, result
end

function Log:InstallErrorHandler()
    if self.errorHandlerInstalled or not seterrorhandler or not geterrorhandler then
        return
    end

    self.errorHandlerInstalled = true
    local previous = geterrorhandler()

    seterrorhandler(function(message)
        self:LogError(message, "global")
        if previous then
            return previous(message)
        end
    end)
end

function Log:InstallActionBlockedHandler()
    if self.actionBlockedInstalled then
        return
    end
    self.actionBlockedInstalled = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_ACTION_BLOCKED")
    frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    frame:SetScript("OnEvent", function(_, event, addonName, action)
        if addonName ~= ADDON_NAME then
            return
        end
        self:LogError(string.format("%s: %s", tostring(event), tostring(action)), "restricted-api")
    end)
end

Log:InstallErrorHandler()
Log:InstallActionBlockedHandler()

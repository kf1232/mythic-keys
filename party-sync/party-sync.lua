local ADDON_NAME = ...

Key.PartySync = Key.PartySync or {}
local Sync = Key.PartySync

Sync.PREFIX = "KeyF"
Sync.rosterDebounce = 0.25
Sync.followUpDelay = 3

Sync.PROTOCOL = {
    KEY = { prefix = "K", pattern = "^K:(%d+):(%d+)$" },
    BEST = { prefix = "M", pattern = "^M:(.+)$" },
    READY = { prefix = "P", pattern = "^P:(%d+):(%d+):(%d+):(%d+):?(%d*)$" },
    READY_STATE = { prefix = "Y", pattern = "^Y:(%d+)$" },
    REQUEST = "R",
}

function Sync:Init()
    if self.initialized then
        return
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
        local function HandleEvent()
            if event == "CHAT_MSG_ADDON" then
                Key.Dispatch("CHAT_MSG_ADDON", {
                    prefix = prefix,
                    message = message,
                    channel = channel,
                    sender = sender,
                })
            end
        end

        if Key.Log and Key.Log.RunProtected then
            Key.Log:RunProtected("PartySync:" .. tostring(event), HandleEvent)
        else
            HandleEvent()
        end
    end)

    self.eventFrame = frame
    self.initialized = true
end

function Sync:CanSend()
    if not IsInGroup() then
        return false
    end

    return C_ChatInfo and C_ChatInfo.SendAddonMessage
end

function Sync:GetChannel()
    if IsInRaid() then
        return "RAID"
    end
    return "PARTY"
end

function Sync:Send(message)
    if not message or message == "" or not self:CanSend() then
        return false
    end

    local ok = pcall(C_ChatInfo.SendAddonMessage, self.PREFIX, message, self:GetChannel())
    if not ok then
        Key.Log:WriteEvent(
            Key.Log.FEATURE.PARTY_SYNC,
            Key.Log.STATUS.WARN,
            "Party keystone share skipped (addon messages blocked).",
            { source = "SendAddonMessage", dedupeKey = "sync:blocked", dedupeWindow = 30 }
        )
    end
    return ok
end

function Sync:BuildBestPayload()
    if Key.Keystones and Key.Keystones.BuildBestPayload then
        return Key.Keystones:BuildBestPayload()
    end
    if Key.Keystones and Key.Keystones.BuildEmptyBestPayload then
        return Key.Keystones:BuildEmptyBestPayload()
    end
    return self.PROTOCOL.BEST.prefix .. ":"
end

function Sync:PushBest(force)
    local payload = self:BuildBestPayload()
    if not force and payload == self.lastBestPayload then
        return
    end

    self.lastBestPayload = payload
    self:Send(payload)
end

function Sync:BuildReadyPayload()
    if Key.ReadyCheck and Key.ReadyCheck.BuildReadyPayload then
        return Key.ReadyCheck:BuildReadyPayload()
    end
    if Key.ReadyCheck and Key.ReadyCheck.BuildEmptyReadyPayload then
        return Key.ReadyCheck:BuildEmptyReadyPayload()
    end
    return self.PROTOCOL.READY.prefix .. ":100:0:0:0:0"
end

function Sync:BuildReadyStatePayload()
    if Key.ReadyCheck and Key.ReadyCheck.BuildReadyStatePayload then
        return Key.ReadyCheck:BuildReadyStatePayload()
    end
    return string.format("%s:0", self.PROTOCOL.READY_STATE.prefix)
end

function Sync:PushReadyState(force)
    local payload = self:BuildReadyStatePayload()
    if not force and payload == self.lastReadyStatePayload then
        return
    end

    self.lastReadyStatePayload = payload
    self:Send(payload)
end

function Sync:PushReady(force)
    local payload = self:BuildReadyPayload()
    if not force and payload == self.lastReadyPayload then
        return
    end

    self.lastReadyPayload = payload
    self:Send(payload)
end

function Sync:BuildPayload()
    local key = Key.Keystones:GetOwnKeystone()
    if not key then
        return string.format("%s:0:0", self.PROTOCOL.KEY.prefix)
    end
    return string.format("%s:%d:%d", self.PROTOCOL.KEY.prefix, key.level, key.mapID)
end

function Sync:PushKey(force)
    local payload = self:BuildPayload()
    if not force and payload == self.lastPayload then
        return
    end

    self.lastPayload = payload
    self:Send(payload)
end

function Sync:RequestPartyKeys()
    self:Send(self.PROTOCOL.REQUEST)

    if Key.Integrations.ExternalKeystones and Key.Integrations.ExternalKeystones.RequestPartyKeys then
        Key.Integrations.ExternalKeystones:RequestPartyKeys()
    end
end

function Sync:PushAll(force)
    self:PushKey(force)
    self:PushBest(force)
    self:PushReady(force)
    self:PushReadyState(force)
end

function Sync:InvalidatePayloadCache(scope)
    if not scope or scope == "key" then
        self.lastPayload = nil
    end
    if not scope or scope == "best" then
        self.lastBestPayload = nil
    end
    if not scope or scope == "ready" then
        self.lastReadyPayload = nil
        self.lastReadyStatePayload = nil
    end
end

function Sync:ClearLocalPayloadCache()
    self:InvalidatePayloadCache()
end

function Sync:CancelFollowUpSync()
    if self.followUpTimer then
        self.followUpTimer:Cancel()
        self.followUpTimer = nil
    end
end

function Sync:ScheduleFollowUpSync()
    self:CancelFollowUpSync()

    if not IsInGroup() then
        return
    end

    self.followUpTimer = C_Timer.NewTimer(self.followUpDelay, function()
        self.followUpTimer = nil
        if not IsInGroup() then
            return
        end

        self:PushAll(true)
        self:RequestPartyKeys()
    end)
end

function Sync:OnPartyChanged()
    if not IsInGroup() then
        self:CancelFollowUpSync()
        return
    end

    if Key.Keystones and Key.Keystones.RebindPartyCache then
        Key.Keystones:RebindPartyCache()
    end
    if Key.ReadyCheck and Key.ReadyCheck.RebindReadyCache then
        Key.ReadyCheck:RebindReadyCache()
    end

    self:PushAll(true)
    self:RequestPartyKeys()
    self:ScheduleFollowUpSync()
end

function Sync:OnGroupLeft()
    self:CancelFollowUpSync()
    if Key.Keystones and Key.Keystones.ClearPartyCache then
        Key.Keystones:ClearPartyCache()
    end
    if Key.ReadyCheck and Key.ReadyCheck.ClearReadyCache then
        Key.ReadyCheck:ClearReadyCache()
    end
    self:ClearLocalPayloadCache()
end

function Sync:SchedulePartySync()
    if self.rosterTimer then
        self.rosterTimer:Cancel()
    end

    self.rosterTimer = C_Timer.NewTimer(self.rosterDebounce, function()
        self.rosterTimer = nil
        Key.Dispatch("PARTY_CHANGED")
    end)
end

function Sync:BootstrapIfGrouped()
    if IsInGroup() then
        self:SchedulePartySync()
    end
end

function Sync:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.PREFIX then
        return
    end

    if channel ~= "PARTY" and channel ~= "RAID" then
        return
    end

    if Key.Keystones and Key.Keystones.NormalizeSender then
        sender = Key.Keystones:NormalizeSender(sender) or sender
    end

    if message == self.PROTOCOL.REQUEST then
        self:PushAll(true)
        return
    end

    local level, mapID = message:match(self.PROTOCOL.KEY.pattern)
    if level then
        level = tonumber(level)
        mapID = tonumber(mapID)
        if Key.Keystones:SetPartyKey(sender, level, mapID) then
            Key.Log:LogKeystone(sender, Key.Keystones:LookupCachedKeyBySender(sender))
        end

        Key.Dispatch("REFRESH_UI", { ifShown = true })
        return
    end

    if message:match("^" .. self.PROTOCOL.BEST.prefix .. ":") then
        local bests = Key.Keystones:ParseBestPayload(message)
        if bests then
            Key.Keystones:SetPartyBest(sender, bests)
            Key.Dispatch("REFRESH_UI", { ifShown = true })
        end
        return
    end

    local ready = Key.ReadyCheck and Key.ReadyCheck:ParseReadyPayload(message)
    if ready then
        Key.ReadyCheck:SetPartyReady(sender, ready)
        Key.Dispatch("REFRESH_UI", { ifShown = true })
        return
    end

    local readyState = Key.ReadyCheck and Key.ReadyCheck:ParseReadyStatePayload(message)
    if readyState ~= nil then
        Key.ReadyCheck:SetPartyReadyState(sender, readyState)
        Key.Dispatch("REFRESH_UI", { ifShown = true })
        return
    end
end

Sync:Init()

Key.RegisterTrigger("ADDON_LOADED", function()
    Sync:BootstrapIfGrouped()
end)

Key.RegisterTrigger("GROUP_LEFT", function()
    Sync:OnGroupLeft()
end)

Key.RegisterTrigger("GROUP_CHANGED", function()
    Key.Dispatch("PARTY_SYNC_SCHEDULE")
end)

Key.RegisterTrigger("PLAYER_ENTERING_WORLD", function()
    Key.Dispatch("PARTY_SYNC_SCHEDULE")
end)

Key.RegisterTrigger("KEYSTONE_DATA_CHANGED", function()
    Sync:InvalidatePayloadCache("key")
    Sync:InvalidatePayloadCache("best")
    Key.Dispatch("PARTY_SYNC_SCHEDULE")
end)

Key.RegisterTrigger("CHAT_MSG_ADDON", function(ctx)
    Sync:OnAddonMessage(ctx.prefix, ctx.message, ctx.channel, ctx.sender)
end)

Key.RegisterTrigger("PARTY_SYNC_SCHEDULE", function()
    if IsInGroup() then
        Sync:SchedulePartySync()
        return
    end
    Key.Dispatch("REFRESH_UI", { ifShown = true })
end)

Key.RegisterTrigger("PARTY_CHANGED", function()
    Sync:OnPartyChanged()
end)

Key.RegisterTrigger("UI_PANEL_OPEN", function()
    if IsInGroup() then
        Sync:OnPartyChanged()
    else
        Sync:PushAll(true)
    end
end)

Key.RegisterTrigger("UI_REFRESH_CLICK", function()
    if IsInGroup() then
        Key.Dispatch("PARTY_CHANGED", { immediate = true })
        return
    end
    Sync:PushBest(true)
    Sync:PushReady(true)
end)

Key.RegisterTrigger("UI_READY_TOGGLE", function()
    Sync:PushReadyState(true)
    Sync.lastReadyPayload = nil
    Sync:PushReady(true)
end)

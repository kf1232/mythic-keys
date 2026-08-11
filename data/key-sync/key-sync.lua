Key.Data = Key.Data or {}

local KeySync = {}
Key.Data.KeySync = KeySync

local Guard = Key.Guard
local Chat = Key.Util.Chat
local OwnedKeystone = Key.Data.OwnedKeystone
local PlayerData = Key.Data.PlayerData

KeySync.PREFIX = "KeyF"
KeySync.PROTOCOL = {
    KEY = { prefix = "K", pattern = "^K:(%d+):(%d+)$" },
    REQUEST = "R",
}

local ROSTER_DEBOUNCE = 0.25
local FOLLOW_UP_DELAY = 3

local eventFrame
local rosterTimer
local followUpTimer
local lastPayload
local listeners = {}

local function NotifyChanged()
    for i = 1, #listeners do
        pcall(listeners[i])
    end
end

local function NormalizeSender(sender)
    if not Guard.usable(sender) or sender == "" then
        return nil
    end
    if Ambiguate then
        return Ambiguate(sender, "none")
    end
    return sender
end

local LE_PARTY_CATEGORY_HOME = LE_PARTY_CATEGORY_HOME or 1
local LE_PARTY_CATEGORY_INSTANCE = LE_PARTY_CATEGORY_INSTANCE or 2

local function IsInSyncGroup()
    return IsInGroup and IsInGroup()
end

local function GetChannel()
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "PARTY"
    end
    return nil
end

local function CanSendToChannel(channel)
    if channel == "RAID" then
        return IsInRaid and IsInRaid()
    end
    if channel == "INSTANCE_CHAT" then
        return IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    end
    if channel == "PARTY" then
        return IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME)
    end
    return false
end

local function SenderIsGroupMember(senderKey)
    if not senderKey or not IsInSyncGroup() then
        return false
    end

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                if PlayerData.GetCacheKey(unit) == senderKey then
                    return true
                end
                local nameResult = Guard.call(UnitName, unit)
                if nameResult.ok and nameResult[1] == senderKey then
                    return true
                end
            end
        end
        return false
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            if PlayerData.GetCacheKey(unit) == senderKey then
                return true
            end
            local nameResult = Guard.call(UnitName, unit)
            if nameResult.ok and nameResult[1] == senderKey then
                return true
            end
        end
    end

    return false
end

local function RegisterPrefix()
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then
        return false
    end
    C_ChatInfo.RegisterAddonMessagePrefix(KeySync.PREFIX)
    return true
end

local function Send(message)
    if not message or message == "" or not IsInSyncGroup() then
        return false
    end

    local channel = GetChannel()
    if not channel or not CanSendToChannel(channel) or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then
        return false
    end

    local ok = pcall(C_ChatInfo.SendAddonMessage, KeySync.PREFIX, message, channel)
    if not ok then
        Chat.Print("Party keystone share skipped (addon messages blocked).")
    end
    return ok
end

function KeySync.OnChanged(listener)
    if type(listener) == "function" then
        listeners[#listeners + 1] = listener
    end
end

function KeySync.NotifyChanged()
    NotifyChanged()
end

function KeySync.PushKey(force)
    if not IsInSyncGroup() then
        return false
    end

    local payload = OwnedKeystone.GetSyncPayload()
    if not force and payload == lastPayload then
        return false
    end

    lastPayload = payload
    return Send(payload)
end

function KeySync.RequestPartyKeys()
    Send(KeySync.PROTOCOL.REQUEST)
    if Key.Integrations and Key.Integrations.ExternalKeystones then
        Key.Integrations.ExternalKeystones:RequestPartyKeys()
    end
    return true
end

function KeySync.PushAll(force)
    KeySync.PushKey(force)
end

function KeySync.InvalidatePayloadCache()
    lastPayload = nil
end

function KeySync.ClearLocalState()
    KeySync.InvalidatePayloadCache()
    if followUpTimer and followUpTimer.Cancel then
        followUpTimer:Cancel()
        followUpTimer = nil
    end
    if rosterTimer and rosterTimer.Cancel then
        rosterTimer:Cancel()
        rosterTimer = nil
    end
end

local function OnPartyChanged()
    if not IsInSyncGroup() then
        return
    end

    OwnedKeystone.RebindPartyUnits()
    KeySync.PushAll(true)
    KeySync.RequestPartyKeys()
    KeySync.ScheduleFollowUp()
end

function KeySync.ScheduleFollowUp()
    if followUpTimer and followUpTimer.Cancel then
        followUpTimer:Cancel()
        followUpTimer = nil
    end

    if not IsInSyncGroup() or not C_Timer or not C_Timer.After then
        return
    end

    followUpTimer = C_Timer.After(FOLLOW_UP_DELAY, function()
        followUpTimer = nil
        if not IsInSyncGroup() then
            return
        end
        KeySync.PushAll(true)
        KeySync.RequestPartyKeys()
    end)
end

function KeySync.ScheduleRosterSync()
    if rosterTimer and rosterTimer.Cancel then
        rosterTimer:Cancel()
        rosterTimer = nil
    end

    if not C_Timer or not C_Timer.After then
        OnPartyChanged()
        return
    end

    rosterTimer = C_Timer.After(ROSTER_DEBOUNCE, function()
        rosterTimer = nil
        OnPartyChanged()
    end)
end

function KeySync.OnGroupLeft()
    KeySync.ClearLocalState()
    OwnedKeystone.ClearParty()
    NotifyChanged()
end

function KeySync.OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= KeySync.PREFIX then
        return
    end

    if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then
        return
    end

    if not Guard.usable(message) or type(message) ~= "string" then
        return
    end

    local senderKey = NormalizeSender(sender)
    if not senderKey then
        return
    end

    if message == KeySync.PROTOCOL.REQUEST then
        KeySync.PushAll(true)
        return
    end

    local level, mapID = message:match(KeySync.PROTOCOL.KEY.pattern)
    if not level then
        return
    end

    if not SenderIsGroupMember(senderKey) then
        return
    end

    level = tonumber(level)
    mapID = tonumber(mapID)
    if not level or not mapID then
        return
    end

    if not OwnedKeystone.Validate(level, mapID) then
        return
    end

    if OwnedKeystone.SetParty(senderKey, level, mapID) then
        NotifyChanged()
    end
end

local function EnsureEvents()
    if eventFrame then
        return
    end

    RegisterPrefix()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
        if event == "CHAT_MSG_ADDON" then
            KeySync.OnAddonMessage(arg1, arg2, arg3, arg4)
            return
        end

        if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            if not IsInSyncGroup() then
                KeySync.OnGroupLeft()
                return
            end
            KeySync.ScheduleRosterSync()
            return
        end
    end)

    OwnedKeystone.OnChanged(function()
        KeySync.InvalidatePayloadCache()
        if IsInSyncGroup() then
            KeySync.PushKey(false)
        end
    end)
end

function KeySync.GetChannel()
    return GetChannel()
end

function KeySync.Init()
    EnsureEvents()
    if IsInSyncGroup() then
        KeySync.ScheduleRosterSync()
    end
end

EnsureEvents()

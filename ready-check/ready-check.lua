local ADDON_NAME = ...

Key.ReadyCheck = Key.ReadyCheck or {}
local ReadyCheck = Key.ReadyCheck
local Cache = Key.Cache

ReadyCheck.targetZone = ReadyCheck.targetZone or nil
ReadyCheck.lastPushedZone = ReadyCheck.lastPushedZone or nil
ReadyCheck.ZONE_UPDATE_INTERVAL = 10
ReadyCheck.FLASK_LOW_TIME_SECONDS = 40 * 60

ReadyCheck.READY_PAYLOAD_FIELDS = { "repair", "food", "flask", "oil", "isReady" }
ReadyCheck.EMPTY_READY_DEFAULTS = { repair = 100, food = 0, flask = 0, oil = 0, isReady = 0 }

ReadyCheck.CONSUMABLE_STATUS_FIELDS = {
    food = { ok = "foodOk", icon = "foodIcon", label = "foodLabel", hearty = "foodHearty", eating = "foodEating" },
    flask = {
        ok = "flaskOk",
        icon = "flaskIcon",
        label = "flaskLabel",
        qualityTier = "flaskQualityTier",
        lowTime = "flaskLowTime",
    },
    oil = { ok = "oilOk", icon = "oilIcon", label = "oilLabel", qualityTier = "oilQualityTier" },
}

function ReadyCheck:GetReadyStore()
    return Cache:GetStore(Cache.STORE.READY)
end

function ReadyCheck:GetDefaultIcon()
    return Key and Key.DEFAULT_ICON or 134400
end

function ReadyCheck:GetReadyPayloadPattern()
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.READY then
        return Key.PartySync.PROTOCOL.READY.pattern
    end
    return "^P:(%d+):(%d+):(%d+):(%d+):?(%d*)$"
end

function ReadyCheck:GetZonePayloadPattern()
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.ZONE then
        return Key.PartySync.PROTOCOL.ZONE.pattern
    end
    return "^Z:(.+)$"
end

function ReadyCheck:GetZoneTargetPayloadPattern()
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.ZONE_TARGET then
        return Key.PartySync.PROTOCOL.ZONE_TARGET.pattern
    end
    return "^T:(.+)$"
end

function ReadyCheck:GetPlayerZoneText()
    return GetZoneText() or ""
end

function ReadyCheck:ZonesMatch(left, right)
    if not left or not right or left == "" or right == "" then
        return false
    end
    return left == right
end

function ReadyCheck:GetTargetZone()
    return self.targetZone
end

function ReadyCheck:SetTargetZone(zone, broadcast)
    if not zone or zone == "" then
        return
    end

    self.targetZone = zone

    if broadcast then
        Key.Dispatch("UI_ZONE_TARGET_SET")
    end

    if Key.ReadyCheck.UI and Key.ReadyCheck.UI.UpdateZoneStatus then
        Key.ReadyCheck.UI:UpdateZoneStatus()
    end
end

function ReadyCheck:SetTargetZoneFromPlayer()
    self:SetTargetZone(self:GetPlayerZoneText(), true)
end

function ReadyCheck:SetPartyTargetZone(sender, zone)
    if not sender or sender == "" or not zone or zone == "" then
        return
    end

    self:SetTargetZone(zone, false)
end

function ReadyCheck:SetPartyZone(sender, zone)
    if not sender or sender == "" then
        return
    end

    if not zone or zone == "" then
        return
    end

    Cache:UpdateBySender(self:GetReadyStore(), sender, function(entry)
        entry.zone = zone
    end)
end

function ReadyCheck:GetMemberZoneText(unit)
    if UnitIsUnit(unit, "player") then
        return self:GetPlayerZoneText()
    end

    local cached = self:LookupCachedReady(unit)
    return cached and cached.zone
end

function ReadyCheck:GetLocalZoneStatusDisplay()
    local target = self:GetTargetZone()

    if not target or target == "" then
        return "Not set", 0.5, 0.5, 0.5
    end

    return target, 0.85, 0.85, 0.85
end

function ReadyCheck:GetMemberZoneCheckDisplay(unit)
    local target = self:GetTargetZone()
    local zone = self:GetMemberZoneText(unit)

    if not target or target == "" then
        if zone and zone ~= "" then
            return zone, 0.5, 0.5, 0.5, "No target zone set"
        end
        return "—", 0.5, 0.5, 0.5, "Zone not shared"
    end

    if not zone or zone == "" then
        return "—", 0.5, 0.5, 0.5, "Zone not shared"
    end

    if self:ZonesMatch(zone, target) then
        return "Ready", 0.3, 0.9, 0.35, "In target zone"
    end

    return zone, 0.9, 0.35, 0.35, "Not in target zone"
end

function ReadyCheck:BuildZonePayload()
    local prefix = "Z"
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.ZONE then
        prefix = Key.PartySync.PROTOCOL.ZONE.prefix
    end

    return prefix .. ":" .. (self:GetPlayerZoneText() or "")
end

function ReadyCheck:BuildZoneTargetPayload()
    local prefix = "T"
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.ZONE_TARGET then
        prefix = Key.PartySync.PROTOCOL.ZONE_TARGET.prefix
    end

    local zone = self:GetTargetZone() or ""
    return prefix .. ":" .. zone
end

function ReadyCheck:ParseZonePayload(message)
    local zone = message and message:match(self:GetZonePayloadPattern())
    if zone == nil then
        return nil
    end
    return zone
end

function ReadyCheck:ParseZoneTargetPayload(message)
    local zone = message and message:match(self:GetZoneTargetPayloadPattern())
    if zone == nil then
        return nil
    end
    return zone
end

function ReadyCheck:RefreshZoneDisplay()
    if Key.ReadyCheck.UI and Key.ReadyCheck.UI.UpdateZoneStatus then
        Key.ReadyCheck.UI:UpdateZoneStatus()
    end

    if Key.PartyUI and Key.PartyUI.IsReadyTabActive and Key.PartyUI:IsReadyTabActive()
        and Key.PartyUI:IsShown() then
        Key.Dispatch("REFRESH_UI", { ifShown = true, readyOnly = true })
    end
end

function ReadyCheck:MaybePushZoneChange()
    local zone = self:GetPlayerZoneText()
    if zone == self.lastPushedZone then
        return
    end

    self.lastPushedZone = zone
    Key.Dispatch("UI_ZONE_CHANGED")
end

function ReadyCheck:OnZoneEvent()
    self:RefreshZoneDisplay()

    local now = GetTime()
    if now < (self.zonePushNotBefore or 0) then
        return
    end

    self.zonePushNotBefore = now + self.ZONE_UPDATE_INTERVAL
    self:MaybePushZoneChange()
end

function ReadyCheck:OnZoneTick()
    self.zonePushNotBefore = GetTime() + self.ZONE_UPDATE_INTERVAL
    self:MaybePushZoneChange()
    self:RefreshZoneDisplay()
end

function ReadyCheck:InitZoneTracking()
    if self.zoneInitialized then
        return
    end

    self.zoneInitialized = true
    self.lastPushedZone = self:GetPlayerZoneText()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", function()
        ReadyCheck:OnZoneEvent()
    end)
    self.zoneEventFrame = frame

    self.zoneTicker = C_Timer.NewTicker(self.ZONE_UPDATE_INTERVAL, function()
        ReadyCheck:OnZoneTick()
    end)
end

function ReadyCheck:GetPlayerRepairPercent()
    if Key.Api.InventoryDurability and Key.Api.InventoryDurability.GetRepairPercent then
        return Key.Api.InventoryDurability:GetRepairPercent()
    end
    return 100
end

function ReadyCheck:GetConsumableStatus(unit)
    return Key.Auras:GetConsumableStatus(unit)
end

function ReadyCheck:GetPartyBuffText(unit)
    if not Key.Api.UnitAuras or not Key.Api.UnitAuras.GetSelfSourcedBuffNames then
        return "—"
    end

    local buffs = Key.Api.UnitAuras:GetSelfSourcedBuffNames(unit, "HELPFUL|RAID")
    if not buffs or #buffs == 0 then
        return "—"
    end

    return table.concat(buffs, ", ")
end

function ReadyCheck:GetPlayerSnapshot()
    local repair = self:GetPlayerRepairPercent()
    local food, foodLabel, flask, flaskLabel, oil, oilLabel, _, _, _, _, _, _, _, _, foodEating, foodEatingLabel = self:GetConsumableStatus("player")

    return {
        repair = repair,
        food = food and 1 or 0,
        flask = flask and 1 or 0,
        oil = oil and 1 or 0,
        isReady = 0,
        foodLabel = foodLabel or (foodEating and foodEatingLabel),
        flaskLabel = flaskLabel,
        oilLabel = oilLabel,
    }
end

function ReadyCheck:BuildReadyPayloadFromSnapshot(snapshot)
    local prefix = "P"
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.READY then
        prefix = Key.PartySync.PROTOCOL.READY.prefix
    end

    local values = {}
    for _, field in ipairs(self.READY_PAYLOAD_FIELDS) do
        values[#values + 1] = tostring(snapshot[field] or 0)
    end
    return prefix .. ":" .. table.concat(values, ":")
end

function ReadyCheck:BuildReadyPayload()
    return self:BuildReadyPayloadFromSnapshot(self:GetPlayerSnapshot())
end

function ReadyCheck:BuildEmptyReadyPayload()
    return self:BuildReadyPayloadFromSnapshot(self.EMPTY_READY_DEFAULTS)
end

function ReadyCheck:BuildReadyStatePayload()
    local prefix = "Y"
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.READY_STATE then
        prefix = Key.PartySync.PROTOCOL.READY_STATE.prefix
    end
    return string.format("%s:0", prefix)
end

function ReadyCheck:GetReadyStatePayloadPattern()
    if Key.PartySync and Key.PartySync.PROTOCOL and Key.PartySync.PROTOCOL.READY_STATE then
        return Key.PartySync.PROTOCOL.READY_STATE.pattern
    end
    return "^Y:(%d+)$"
end

function ReadyCheck:ParseReadyPayload(message)
    local repair, food, flask, oil, ready = message and message:match(self:GetReadyPayloadPattern())
    if not repair then
        return nil
    end

    local entry = {
        repair = tonumber(repair) or 0,
        food = tonumber(food) == 1,
        flask = tonumber(flask) == 1,
        oil = tonumber(oil) == 1,
    }

    if ready and ready ~= "" then
        entry.isReady = tonumber(ready) == 1
    end

    return entry
end

function ReadyCheck:ParseReadyStatePayload(message)
    local ready = message and message:match(self:GetReadyStatePayloadPattern())
    if not ready then
        return nil
    end

    return tonumber(ready) == 1
end

function ReadyCheck:SetPartyReadyState(sender, isReady)
    if not sender or sender == "" then
        return
    end

    Cache:UpdateBySender(self:GetReadyStore(), sender, function(entry)
        entry.isReady = isReady and true or false
    end)
end

function ReadyCheck:SetPartyReady(sender, entry)
    if not sender or sender == "" then
        return
    end

    if not entry then
        Cache:Clear(self:GetReadyStore(), sender)
        return
    end

    Cache:Write(self:GetReadyStore(), sender, entry)
end

function ReadyCheck:LookupCachedReady(unit)
    return Cache:ReadByUnit(self:GetReadyStore(), unit, true)
end

function ReadyCheck:RestoreSessionCacheIfNeeded()
    Cache:RestoreSession(self:GetReadyStore())
end

function ReadyCheck:ClearCache()
    Cache:Wipe(self:GetReadyStore())
    self.targetZone = nil
    self.lastPushedZone = nil
    if Key.ReadyCheck.UI and Key.ReadyCheck.UI.UpdateZoneStatus then
        Key.ReadyCheck.UI:UpdateZoneStatus()
    end
end

function ReadyCheck:RebindCache()
    Cache:RebindByGUID(self:GetReadyStore())
end

function ReadyCheck:ApplyLiveConsumableStatus(status, unit, liveValues)
    local isPlayer = UnitIsUnit(unit, "player")
    local cached = (not isPlayer) and self:LookupCachedReady(unit) or nil

    for kindKey, fields in pairs(self.CONSUMABLE_STATUS_FIELDS) do
        local active = liveValues[kindKey]
        if active then
            status[fields.ok] = active.ok ~= false
            if fields.icon and active.icon then
                status[fields.icon] = active.icon
            end
            if fields.hearty and active.hearty then
                status[fields.hearty] = active.hearty
            end
            if fields.eating and active.eating then
                status[fields.eating] = true
            end
            if fields.qualityTier and active.qualityTier then
                status[fields.qualityTier] = active.qualityTier
            end
            if fields.label and active.label then
                status[fields.label] = active.label
            end
            if fields.lowTime ~= nil and active.lowTime ~= nil then
                status[fields.lowTime] = active.lowTime
            end
        elseif cached and cached[kindKey] then
            status[fields.ok] = true
        end
    end
end

function ReadyCheck:GetMemberStatus(unit)
    local status = {
        repair = nil,
        repairText = "—",
        buffsText = "—",
        foodOk = false,
        flaskOk = false,
        oilOk = false,
        foodIcon = nil,
        foodHearty = false,
        foodEating = false,
        oilIcon = nil,
        oilQualityTier = nil,
        flaskIcon = nil,
        flaskQualityTier = nil,
        flaskLowTime = false,
    }

    if UnitIsUnit(unit, "player") then
        status.repair = self:GetPlayerRepairPercent()
        status.repairText = string.format("%d%%", status.repair)
    else
        local cached = self:LookupCachedReady(unit)
        if cached and cached.repair then
            status.repair = cached.repair
            status.repairText = string.format("%d%%", cached.repair)
        end
    end

    local food, foodLabel, flaskReady, flaskLabel, oil, oilLabel, foodIcon, foodHearty, oilIcon, flaskIcon, flaskQualityTier, flaskRemaining, oilQualityTier,
        foodEating, foodEatingLabel, foodEatingIcon = self:GetConsumableStatus(unit)
    self:ApplyLiveConsumableStatus(status, unit, {
        food = food and { ok = true, icon = foodIcon, hearty = foodHearty, label = foodLabel }
            or foodEating and { ok = false, eating = true, icon = foodEatingIcon, label = foodEatingLabel }
            or nil,
        flask = flaskIcon and {
            icon = flaskIcon,
            qualityTier = flaskQualityTier,
            label = flaskLabel,
            ok = flaskReady,
            lowTime = flaskRemaining ~= nil and flaskRemaining < self.FLASK_LOW_TIME_SECONDS,
        } or nil,
        oil = oil and { icon = oilIcon, label = oilLabel, qualityTier = oilQualityTier } or nil,
    })

    status.buffsText = self:GetPartyBuffText(unit)

    return status
end

ReadyCheck:InitZoneTracking()

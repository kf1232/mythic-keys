Key.Integrations = Key.Integrations or {}

local External = {}
Key.Integrations.ExternalKeystones = External

local Guard = Key.Guard
local OwnedKeystone = Key.Data.OwnedKeystone
local KeySync = Key.Data.KeySync
local PlayerData = Key.Data.PlayerData

External.providers = External.providers or {}

local KEYSTONE_PROVIDERS = {
    Key.Integrations.LibKeystone,
    Key.Integrations.LibOpenRaid,
}

local ADDON_NAME = Key.name

local function NormalizeSender(sender)
    if not Guard.usable(sender) or sender == "" then
        return nil
    end
    if Ambiguate then
        return Ambiguate(sender, "none")
    end
    return sender
end

local function SenderIsGroupMember(senderKey)
    if not senderKey or not IsInGroup or not IsInGroup() then
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

function External:ApplyPartyKey(sender, level, mapID)
    sender = NormalizeSender(sender)
    if not sender then
        return false
    end

    if not Guard.usable(level) or not Guard.usable(mapID) then
        return false
    end

    level = tonumber(level)
    mapID = tonumber(mapID)
    if level == nil or mapID == nil then
        return false
    end

    if not OwnedKeystone.Validate(level, mapID) then
        return false
    end

    if not SenderIsGroupMember(sender) then
        return false
    end

    if not OwnedKeystone.SetParty(sender, level, mapID) then
        return false
    end

    if KeySync and KeySync.NotifyChanged then
        KeySync.NotifyChanged()
    end

    return true
end

function External:Init()
    local added = false

    for i = 1, #KEYSTONE_PROVIDERS do
        local provider = KEYSTONE_PROVIDERS[i]
        if provider and provider.TryInit and provider:TryInit(self) then
            self.providers[provider.id] = true
            added = true
        end
    end

    if self.providers.LibOpenRaid and Key.Integrations.LibOpenRaid then
        Key.Integrations.LibOpenRaid:ImportPartyCache(self)
    end

    return added
end

function External:RequestPartyKeys()
    self:Init()

    for i = 1, #KEYSTONE_PROVIDERS do
        local provider = KEYSTONE_PROVIDERS[i]
        if provider and provider.Request then
            provider:Request(self)
        end
    end
end

function External:GetProviderSummary()
    local names = {}
    for i = 1, #KEYSTONE_PROVIDERS do
        local provider = KEYSTONE_PROVIDERS[i]
        if provider and provider.id and self.providers[provider.id] then
            names[#names + 1] = provider.id
        end
    end

    if #names == 0 then
        return "none"
    end

    return table.concat(names, ", ")
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then
        External:Init()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if External:Init() and External.providers.LibOpenRaid and Key.Integrations.LibOpenRaid then
            Key.Integrations.LibOpenRaid:ImportPartyCache(External)
        end
    end
end)

External:Init()

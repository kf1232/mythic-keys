local ADDON_NAME = ...

Key.Integrations.ExternalKeystones = Key.Integrations.ExternalKeystones or {}
local External = Key.Integrations.ExternalKeystones

External.providers = External.providers or {}

local KEYSTONE_PROVIDERS = {
    Key.Integrations.LibKeystone,
    Key.Integrations.LibOpenRaid,
}

function External:NormalizeSender(sender)
    if Key.Keystones and Key.Keystones.NormalizeSender then
        return Key.Keystones:NormalizeSender(sender)
    end
    if not Key.Keystones:IsAccessible(sender) or sender == "" then
        return nil
    end
    return Ambiguate(sender, "none")
end

function External:ApplyPartyKey(sender, level, mapID)
    if not Key.Keystones or not Key.Keystones.SetPartyKey then
        return false
    end

    sender = self:NormalizeSender(sender)
    if not sender then
        return false
    end

    if not Key.Keystones:IsAccessible(level) or not Key.Keystones:IsAccessible(mapID) then
        return false
    end

    level = tonumber(level)
    mapID = tonumber(mapID)
    if not level or not mapID then
        return false
    end

    if level < 0 or mapID < 0 then
        return false
    end

    if not Key.Keystones:SetPartyKey(sender, level, mapID) then
        return false
    end

    if Key.Log and Key.Log.LogKeystone then
        Key.Log:LogKeystone(sender, Key.Keystones:LookupCachedKeyBySender(sender))
    end

    if Key and Key.Dispatch then
        Key.Dispatch("REFRESH_UI", { ifShown = true })
    end

    return true
end

function External:Init()
    local added = false

    for _, provider in ipairs(KEYSTONE_PROVIDERS) do
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

    for _, provider in ipairs(KEYSTONE_PROVIDERS) do
        if provider and provider.Request then
            provider:Request(self)
        end
    end
end

function External:GetProviderSummary()
    local names = {}
    for _, provider in ipairs(KEYSTONE_PROVIDERS) do
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
    local function HandleEvent()
        if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then
            External:Init()
            return
        end

        if event == "PLAYER_ENTERING_WORLD" then
            if External:Init() and External.providers.LibOpenRaid and Key.Integrations.LibOpenRaid then
                Key.Integrations.LibOpenRaid:ImportPartyCache(External)
            end
        end
    end

    if Key.Log and Key.Log.RunProtected then
        Key.Log:RunProtected("ExternalKeystones:" .. tostring(event), HandleEvent)
    else
        HandleEvent()
    end
end)

External:Init()

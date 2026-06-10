local ADDON_NAME = ...

KeyExternalKeystones = KeyExternalKeystones or {}
local External = KeyExternalKeystones

External.providers = External.providers or {}

function External:IsAccessible(value)
    if KeyKeystones and KeyKeystones.IsAccessible then
        return KeyKeystones:IsAccessible(value)
    end
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

function External:NormalizeSender(sender)
    if not self:IsAccessible(sender) or sender == "" then
        return nil
    end
    return Ambiguate(sender, "none")
end

function External:ResolveChallengeMapID(keystoneInfo)
    if not keystoneInfo then
        return nil
    end

    local mapID = keystoneInfo.challengeMapID
    if self:IsAccessible(mapID) and mapID ~= 0 then
        return mapID
    end

    mapID = keystoneInfo.mapID
    if self:IsAccessible(mapID) and mapID ~= 0 then
        return mapID
    end

    mapID = keystoneInfo.mythicPlusMapID
    if self:IsAccessible(mapID) and mapID ~= 0 then
        return mapID
    end

    return nil
end

function External:ApplyPartyKey(sender, level, mapID)
    if not KeyKeystones or not KeyKeystones.SetPartyKey then
        return false
    end

    sender = self:NormalizeSender(sender)
    if not sender then
        return false
    end

    if not self:IsAccessible(level) or not self:IsAccessible(mapID) then
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

    if not KeyKeystones:SetPartyKey(sender, level, mapID) then
        return false
    end

    if KeyLog and KeyLog.LogKeystone then
        KeyLog:LogKeystone(sender, KeyKeystones:LookupCachedKeyBySender(sender))
    end

    if Key and Key.Dispatch then
        Key.Dispatch("REFRESH_UI", { ifShown = true })
    end

    return true
end

function External:OnLibKeystoneUpdate(keyLevel, mapID, playerRating, sender, channel)
    if channel ~= "PARTY" then
        return
    end

    self:ApplyPartyKey(sender, keyLevel, mapID)
end

function External:OnOpenRaidKeystoneUpdate(unitName, keystoneInfo)
    if not unitName or not keystoneInfo then
        return
    end

    local mapID = self:ResolveChallengeMapID(keystoneInfo)
    self:ApplyPartyKey(unitName, keystoneInfo.level, mapID)
end

function External:TryInitLibKeystone()
    if self.libKeystone then
        return true
    end

    local libStub = LibStub
    if not libStub then
        return false
    end

    local ok, LKS = pcall(libStub, "LibKeystone", true)
    if not ok or not LKS or not LKS.Register then
        return false
    end

    local registered, registerError = pcall(LKS.Register, self, function(...)
        self:OnLibKeystoneUpdate(...)
    end)
    if not registered then
        return false
    end

    self.libKeystone = LKS
    self.providers.LibKeystone = true
    return true
end

function External:TryInitLibOpenRaid()
    if self.openRaid then
        return true
    end

    local libStub = LibStub
    if not libStub then
        return false
    end

    local ok, openRaid = pcall(libStub, "LibOpenRaid-1.0", true)
    if not ok or not openRaid or not openRaid.RegisterCallback then
        return false
    end

    local registered, registerResult = pcall(openRaid.RegisterCallback, openRaid, self, "KeystoneUpdate", "OnOpenRaidKeystoneUpdate")
    if not registered or registerResult ~= true then
        return false
    end

    self.openRaid = openRaid
    self.providers.LibOpenRaid = true
    return true
end

function External:ImportOpenRaidPartyCache()
    if not self.openRaid or not KeyKeystones or not KeyKeystones.GetPartyUnits then
        return
    end

    if not self.openRaid.GetKeystoneInfo then
        return
    end

    for _, unit in ipairs(KeyKeystones:GetPartyUnits()) do
        if unit ~= "player" and UnitExists(unit) then
            local ok, keystoneInfo = pcall(self.openRaid.GetKeystoneInfo, unit)
            if ok and keystoneInfo then
                self:OnOpenRaidKeystoneUpdate(GetUnitName(unit, true) or UnitName(unit), keystoneInfo)
            end
        end
    end
end

function External:Init()
    local addedLibKeystone = self:TryInitLibKeystone()
    local addedOpenRaid = self:TryInitLibOpenRaid()

    if addedOpenRaid then
        self:ImportOpenRaidPartyCache()
    end

    return addedLibKeystone or addedOpenRaid
end

function External:RequestPartyKeys()
    self:Init()

    if self.libKeystone and self.libKeystone.Request then
        pcall(self.libKeystone.Request, "PARTY")
    end

    if self.openRaid and self.openRaid.RequestKeystoneDataFromParty then
        pcall(self.openRaid.RequestKeystoneDataFromParty)
    end
end

function External:GetProviderSummary()
    local names = {}
    if self.providers.LibKeystone then
        names[#names + 1] = "LibKeystone"
    end
    if self.providers.LibOpenRaid then
        names[#names + 1] = "LibOpenRaid"
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
        if External:Init() and External.providers.LibOpenRaid then
            External:ImportOpenRaidPartyCache()
        end
    end
end)

External:Init()

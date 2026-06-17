local ADDON_NAME = ...

Key.Party = Key.Party or {}
local Party = Key.Party
local Cache = Key.Cache
local UnitAPI = Key.Api.Unit
local GroupAPI = Key.Api.Group
local StringsAPI = Key.Api.Strings

local function GetMemberDisplayName(unit)
    local name = UnitAPI:GetName(false, unit)
    if name then
        return name
    end

    if UnitAPI:IsPlayer(false, unit) then
        return "You"
    end

    return "Member"
end

function Party:NormalizeSender(sender)
    if not Cache:IsAccessible(sender) or sender == "" then
        return nil
    end
    return StringsAPI:Ambiguate(false, sender, "none")
end

function Party:BuildLookupKeys(name)
    if not Cache:IsAccessible(name) or name == "" then
        return {}
    end

    local keys = {
        name,
        StringsAPI:Ambiguate(false, name, "none"),
        StringsAPI:Ambiguate(false, name, "short"),
        StringsAPI:Ambiguate(false, name, "guild"),
    }

    local seen = {}
    local result = {}
    for _, key in ipairs(keys) do
        if key and key ~= "" and not seen[key] then
            seen[key] = true
            result[#result + 1] = key
        end
    end
    return result
end

function Party:CollectMembers()
    local members = {}

    local function AddMember(unit)
        if not UnitAPI:Exists(false, unit) then
            return
        end

        members[#members + 1] = {
            unit = unit,
            name = GetMemberDisplayName(unit),
            classFilename = UnitAPI:GetClassFilename(false, unit),
        }
    end

    AddMember("player")

    if GroupAPI:IsInRaid(false) then
        for i = 1, GroupAPI:GetNumMembers(false) do
            local unit = "raid" .. i
            if UnitAPI:Exists(false, unit) and not UnitAPI:IsPlayer(false, unit) then
                AddMember(unit)
            end
        end
    elseif GroupAPI:IsInGroup(false) then
        for i = 1, GroupAPI:GetNumSubgroupMembers(false) do
            AddMember("party" .. i)
        end
    end

    return members
end

function Party:GetPartyUnits()
    local units = {}

    if GroupAPI:IsInRaid(false) then
        for i = 1, GroupAPI:GetNumMembers(false) do
            units[#units + 1] = "raid" .. i
        end
        return units
    end

    units[#units + 1] = "player"
    if GroupAPI:IsInGroup(false) then
        for i = 1, GroupAPI:GetNumSubgroupMembers(false) do
            units[#units + 1] = "party" .. i
        end
    end

    return units
end

function Party:FindPartyUnitForSender(sender)
    local senderKeys = self:BuildLookupKeys(sender)
    if #senderKeys == 0 then
        return nil
    end

    local senderSet = {}
    for _, key in ipairs(senderKeys) do
        senderSet[key] = true
    end

    for _, unit in ipairs(self:GetPartyUnits()) do
        local fullName = UnitAPI:GetUnitName(false, unit, true)
        if Cache:IsAccessible(fullName) then
            if senderSet[fullName] then
                return unit
            end
            for _, key in ipairs(self:BuildLookupKeys(fullName)) do
                if senderSet[key] then
                    return unit
                end
            end
        end

        local name, realm = UnitAPI:GetFullName(false, unit)
        if Cache:IsAccessible(name) and Cache:IsAccessible(realm) and realm ~= "" then
            local combined = name .. "-" .. realm
            if senderSet[combined] then
                return unit
            end
            for _, key in ipairs(self:BuildLookupKeys(combined)) do
                if senderSet[key] then
                    return unit
                end
            end
        end

        local unitName = UnitAPI:GetName(false, unit)
        if Cache:IsAccessible(unitName) then
            for _, key in ipairs(self:BuildLookupKeys(unitName)) do
                if senderSet[key] then
                    return unit
                end
            end
        end
    end

    return nil
end

local ADDON_NAME = ...

Key.Party = Key.Party or {}
local Party = Key.Party
local Cache = Key.Cache

local function GetUnitClassFilename(unit)
    if not unit or not UnitExists(unit) or not UnitClass then
        return nil
    end

    local _, classFilename = UnitClass(unit)
    if Cache:IsAccessible(classFilename) then
        return classFilename
    end

    return nil
end

local function GetMemberDisplayName(unit)
    local name = UnitName(unit)
    if Cache:IsAccessible(name) and name ~= "" then
        return name
    end

    if UnitIsUnit(unit, "player") then
        return "You"
    end

    return "Member"
end

function Party:NormalizeSender(sender)
    if not Cache:IsAccessible(sender) or sender == "" then
        return nil
    end
    return Ambiguate(sender, "none")
end

function Party:BuildLookupKeys(name)
    if not Cache:IsAccessible(name) or name == "" then
        return {}
    end

    local keys = {
        name,
        Ambiguate(name, "none"),
        Ambiguate(name, "short"),
        Ambiguate(name, "guild"),
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
        if not UnitExists(unit) then
            return
        end

        members[#members + 1] = {
            unit = unit,
            name = GetMemberDisplayName(unit),
            classFilename = GetUnitClassFilename(unit),
        }
    end

    AddMember("player")

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                AddMember(unit)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            AddMember("party" .. i)
        end
    end

    return members
end

function Party:GetPartyUnits()
    local units = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
        return units
    end

    units[#units + 1] = "player"
    if IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
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
        local fullName = GetUnitName and GetUnitName(unit, true)
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

        if UnitFullName then
            local name, realm = UnitFullName(unit)
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
        end

        local name = UnitName(unit)
        if Cache:IsAccessible(name) then
            for _, key in ipairs(self:BuildLookupKeys(name)) do
                if senderSet[key] then
                    return unit
                end
            end
        end
    end

    return nil
end

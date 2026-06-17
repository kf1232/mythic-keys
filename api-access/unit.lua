local ADDON_NAME = ...

Key.Api.Unit = Key.Api.Unit or {}
Key.Api.Group = Key.Api.Group or {}
local UnitAPI = Key.Api.Unit
local GroupAPI = Key.Api.Group
local Middleware = Key.Api.Middleware

function UnitAPI:Exists(isSecret, unit)
    if Middleware:Guard(isSecret, unit) then
        return false
    end

    local exists, secret = Middleware:Call(false, UnitExists, unit)
    if secret then
        return false
    end

    return exists and true or false
end

function UnitAPI:IsUnit(isSecret, leftUnit, rightUnit)
    if Middleware:Guard(isSecret, leftUnit, rightUnit) then
        return false
    end

    local sameUnit, secret = Middleware:Call(false, UnitIsUnit, leftUnit, rightUnit)
    if secret then
        return false
    end

    return sameUnit and true or false
end

function UnitAPI:IsPlayer(isSecret, unit)
    return self:IsUnit(isSecret, unit, "player")
end

function UnitAPI:GetGUID(isSecret, unit)
    if Middleware:Guard(isSecret, unit) then
        return nil
    end

    local guid, secret = Middleware:Call(false, UnitGUID, unit)
    if secret or not Middleware:IsAccessible(guid) then
        return nil
    end

    return guid
end

function UnitAPI:GetName(isSecret, unit)
    if Middleware:Guard(isSecret, unit) then
        return nil
    end

    local name, secret = Middleware:Call(false, UnitName, unit)
    if secret or not Middleware:IsAccessible(name) or name == "" then
        return nil
    end

    return name
end

function UnitAPI:GetFullName(isSecret, unit)
    if Middleware:Guard(isSecret, unit) or not UnitFullName then
        return nil, nil
    end

    local values, secret = Middleware:PCall(false, UnitFullName, unit)
    if secret or not values then
        return nil, nil
    end

    local name = values[1]
    local realm = values[2]

    if not Middleware:IsAccessible(name) then
        return nil, nil
    end

    if realm and not Middleware:IsAccessible(realm) then
        realm = nil
    end

    return name, realm
end

function UnitAPI:GetUnitName(isSecret, unit, showServer)
    if Middleware:Guard(isSecret, unit) or not GetUnitName then
        return nil
    end

    local name, secret = Middleware:Call(false, GetUnitName, unit, showServer)
    if secret or not Middleware:IsAccessible(name) or name == "" then
        return nil
    end

    return name
end

function UnitAPI:GetClass(isSecret, unit)
    if Middleware:Guard(isSecret, unit) or not UnitClass then
        return nil, nil
    end

    local values, secret = Middleware:PCall(false, UnitClass, unit)
    if secret or not values then
        return nil, nil
    end

    local localizedName = values[1]
    local classFilename = values[2]

    if not Middleware:IsAccessible(classFilename) then
        return nil, nil
    end

    if localizedName and not Middleware:IsAccessible(localizedName) then
        localizedName = nil
    end

    return localizedName, classFilename
end

function UnitAPI:GetClassFilename(isSecret, unit)
    local _, classFilename = self:GetClass(isSecret, unit)
    return classFilename
end

function UnitAPI:IsGroupLeader(isSecret, unit)
    if Middleware:Guard(isSecret, unit) or not UnitIsGroupLeader then
        return false
    end

    local isLeader, secret = Middleware:Call(false, UnitIsGroupLeader, unit)
    if secret or not Middleware:IsAccessible(isLeader) then
        return false
    end

    return isLeader and true or false
end

function UnitAPI:GetGroupRole(isSecret, unit)
    if Middleware:Guard(isSecret, unit) or not UnitGroupRolesAssigned then
        return nil
    end

    local role, secret = Middleware:Call(false, UnitGroupRolesAssigned, unit)
    if secret or not Middleware:IsAccessible(role) then
        return nil
    end

    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
    end

    return nil
end

function GroupAPI:IsInGroup(isSecret)
    if Middleware:Guard(isSecret) then
        return false
    end

    return IsInGroup() and true or false
end

function GroupAPI:IsInRaid(isSecret)
    if Middleware:Guard(isSecret) then
        return false
    end

    return IsInRaid() and true or false
end

function GroupAPI:GetNumMembers(isSecret)
    if Middleware:Guard(isSecret) then
        return 0
    end

    return GetNumGroupMembers() or 0
end

function GroupAPI:GetNumSubgroupMembers(isSecret)
    if Middleware:Guard(isSecret) then
        return 0
    end

    return GetNumSubgroupMembers() or 0
end

function GroupAPI:GetChannel(isSecret)
    if self:IsInRaid(isSecret) then
        return "RAID"
    end
    return "PARTY"
end

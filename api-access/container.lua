local ADDON_NAME = ...

Key.Api.Container = Key.Api.Container or {}
local API = Key.Api.Container
local Middleware = Key.Api.Middleware
local ChallengeMode = Key.Api.ChallengeMode

function API:GetContainerNumSlots(isSecret, bag)
    if Middleware:Guard(isSecret, bag) then
        return 0
    end
    if not C_Container or not C_Container.GetContainerNumSlots then
        return 0
    end

    local numSlots, secret = Middleware:Call(false, C_Container.GetContainerNumSlots, bag)
    if secret then
        return 0
    end

    return Middleware:AsNumber(false, numSlots) or 0
end

function API:GetContainerItemInfo(isSecret, bag, slot)
    if Middleware:Guard(isSecret, bag, slot) then
        return nil
    end
    if not C_Container or not C_Container.GetContainerItemInfo then
        return nil
    end

    local itemInfo, secret = Middleware:Call(false, C_Container.GetContainerItemInfo, bag, slot)
    if secret or not itemInfo then
        return nil
    end

    if itemInfo.hyperlink and Middleware:IsSecret(itemInfo.hyperlink) then
        return nil
    end

    return itemInfo
end

function API:IsItemKeystone(isSecret, link)
    if Middleware:Guard(isSecret, link) then
        return false
    end
    if not link or not C_Item or not C_Item.IsItemKeystone then
        return false
    end

    local isKeystone, secret = Middleware:Call(false, C_Item.IsItemKeystone, link)
    if secret then
        return false
    end

    return isKeystone and true or false
end

function API:FindKeystoneInBags(isSecret)
    if Middleware:Guard(isSecret) then
        return nil
    end
    if not C_Container or not C_Item then
        return nil
    end

    local numBags = NUM_BAG_SLOTS or 4
    for bag = 0, numBags do
        local numSlots = self:GetContainerNumSlots(false, bag)
        for slot = 1, numSlots do
            local itemInfo = self:GetContainerItemInfo(false, bag, slot)
            local link = itemInfo and itemInfo.hyperlink
            if link and self:IsItemKeystone(false, link) then
                local level, mapID = ChallengeMode:GetKeystoneLevelAndMapID(false, link)
                if level and level > 0 and mapID and mapID ~= 0 then
                    return {
                        level = level,
                        mapID = mapID,
                        link = link,
                    }
                end
            end
        end
    end

    return nil
end

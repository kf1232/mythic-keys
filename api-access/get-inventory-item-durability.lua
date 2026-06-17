local ADDON_NAME = ...

Key.Api.InventoryDurability = Key.Api.InventoryDurability or {}
local API = Key.Api.InventoryDurability
local Middleware = Key.Api.Middleware

function API:GetSlotDurability(isSecret, slot)
    if Middleware:Guard(isSecret, slot) then
        return nil, nil
    end
    if not GetInventoryItemDurability then
        return nil, nil
    end

    local current, maximum = GetInventoryItemDurability(slot)
    if Middleware:CheckSecret(current, maximum) then
        return nil, nil
    end

    return current, maximum
end

function API:GetRepairPercent(isSecret, firstSlot, lastSlot)
    if Middleware:Guard(isSecret) then
        return nil
    end
    if not GetInventoryItemDurability then
        return 100
    end

    firstSlot = firstSlot or INVSLOT_HEAD
    lastSlot = lastSlot or INVSLOT_OFFHAND

    local totalCurrent, totalMax = 0, 0
    for slot = firstSlot, lastSlot do
        local current, maximum = self:GetSlotDurability(false, slot)
        if current and maximum and maximum > 0 then
            totalCurrent = totalCurrent + current
            totalMax = totalMax + maximum
        end
    end

    if totalMax == 0 then
        return 100
    end

    return math.floor((totalCurrent / totalMax) * 100 + 0.5)
end

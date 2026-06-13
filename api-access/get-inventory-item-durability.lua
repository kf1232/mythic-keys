local ADDON_NAME = ...

KeyApiInventoryDurability = KeyApiInventoryDurability or {}
local API = KeyApiInventoryDurability

function API:GetSlotDurability(slot)
    if not GetInventoryItemDurability then
        return nil, nil
    end
    return GetInventoryItemDurability(slot)
end

function API:GetRepairPercent(firstSlot, lastSlot)
    if not GetInventoryItemDurability then
        return 100
    end

    firstSlot = firstSlot or INVSLOT_HEAD
    lastSlot = lastSlot or INVSLOT_OFFHAND

    local totalCurrent, totalMax = 0, 0
    for slot = firstSlot, lastSlot do
        local current, maximum = self:GetSlotDurability(slot)
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

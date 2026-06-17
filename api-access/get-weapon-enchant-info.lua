local ADDON_NAME = ...

Key.Api.WeaponEnchant = Key.Api.WeaponEnchant or {}
local API = Key.Api.WeaponEnchant
local Middleware = Key.Api.Middleware

function API:GetInfo(isSecret)
    if Middleware:Guard(isSecret) then
        return nil
    end
    if not GetWeaponEnchantInfo then
        return nil
    end

    local hasMainHand, _, _, mainEnchantId, hasOffHand, _, _, offEnchantId = GetWeaponEnchantInfo()
    if Middleware:CheckSecret(hasMainHand, mainEnchantId, hasOffHand, offEnchantId) then
        return nil
    end

    if not hasMainHand and not hasOffHand then
        return nil
    end

    return {
        hasMainHand = hasMainHand,
        hasOffHand = hasOffHand,
        mainEnchantId = mainEnchantId,
        offEnchantId = offEnchantId,
        enchantId = (hasMainHand and mainEnchantId) or offEnchantId,
    }
end

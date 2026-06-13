local ADDON_NAME = ...

KeyApiWeaponEnchant = KeyApiWeaponEnchant or {}
local API = KeyApiWeaponEnchant

function API:GetInfo()
    if not GetWeaponEnchantInfo then
        return nil
    end

    local hasMainHand, _, _, mainEnchantId, hasOffHand, _, _, offEnchantId = GetWeaponEnchantInfo()
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

function API:GetActiveEnchantId()
    local info = self:GetInfo()
    return info and info.enchantId or nil
end

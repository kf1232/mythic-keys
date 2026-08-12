Key.Util = Key.Util or {}

local CombatLockdown = {}
Key.Util.CombatLockdown = CombatLockdown

function CombatLockdown.RunWhenSafe(owner, fn)
    if not owner or type(fn) ~= "function" then
        return
    end

    if InCombatLockdown() then
        if not owner.combatLockdownHook then
            owner.combatLockdownHook = true
            owner:RegisterEvent("PLAYER_REGEN_ENABLED")
            owner:SetScript("OnEvent", function(self, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    self.combatLockdownHook = nil
                    fn()
                end
            end)
        end
        return
    end

    fn()
end

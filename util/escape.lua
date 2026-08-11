Key.Util = Key.Util or {}

local Escape = {}
Key.Util.Escape = Escape

function Escape.RemoveFromUISpecialFrames(frameNames)
    for i = 1, #frameNames do
        local name = frameNames[i]
        for j = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[j] == name then
                tremove(UISpecialFrames, j)
            end
        end
    end
end

function Escape.InstallLayeredClose(frameNames, closeTopmost)
    Escape.RemoveFromUISpecialFrames(frameNames)

    local blizzardCloseSpecialWindows = CloseSpecialWindows
    function CloseSpecialWindows()
        if closeTopmost() then
            return true
        end
        return blizzardCloseSpecialWindows()
    end
end

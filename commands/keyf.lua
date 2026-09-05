SLASH_KEYF1 = "/keyf"

SlashCmdList["KEYF"] = function(msg)
    local ok, err = pcall(function()
        local sub = (strtrim and strtrim(msg or "") or msg or ""):lower()
        if sub == "t" then
            Key.Commands.KeyfT()
        elseif sub == "h" or sub:match("^h%s+") then
            Key.Commands.KeyfH()
        elseif sub == "d" or sub == "debug" then
            Key.Commands.KeyfD()
        else
            Key.Views.Group:Toggle()
        end
    end)
    if not ok then
        print("|cff00ff00Mythic Keys:|r", err)
    end
end

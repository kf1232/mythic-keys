Key.Commands = Key.Commands or {}

Key.Commands.KeyfH = function(arg)
    local rest = (arg and strtrim and strtrim(arg) or arg or ""):lower()
    if rest == "refresh" or rest == "r" then
        Key.Data.KeysHistory.RefreshGroup()
        return
    end
    Key.Views.KeysHistory:Toggle()
end

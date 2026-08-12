Key.Util = Key.Util or {}

local Chat = {}
Key.Util.Chat = Chat

local PREFIX = "|cff00ff00Mythic Keys:|r"

function Chat.Print(message)
    print(PREFIX, message)
end

function Chat.Icon(fileID, size)
    if not fileID then
        return ""
    end
    size = size or 16
    return string.format("|T%d:%d:%d:0:0|t", fileID, size, size)
end

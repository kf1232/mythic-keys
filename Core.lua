Key = Key or {}
Key.name = ...

KeyBetaDB = KeyBetaDB or {}
if type(KeyBetaDB.playerData) ~= "table" then
    KeyBetaDB.playerData = {}
end
if type(KeyBetaDB.keyData) ~= "table" then
    KeyBetaDB.keyData = {}
end
if type(KeyBetaDB.playerGuidIndex) ~= "table" then
    KeyBetaDB.playerGuidIndex = {}
end
if type(KeyBetaDB.keysHistory) ~= "table" then
    KeyBetaDB.keysHistory = {}
end
if type(KeyBetaDB.keysHistory.entries) ~= "table" then
    KeyBetaDB.keysHistory.entries = {}
end

Key.db = KeyBetaDB

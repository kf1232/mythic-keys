Key.Data = Key.Data or {}

local PlayerData = {}
Key.Data.PlayerData = PlayerData

PlayerData.MAX_NOTE_LENGTH = 200

local Guard = Key.Guard

local function DB()
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
    return KeyBetaDB
end

local function NormalizeRealm(realm)
    if realm and realm ~= "" then
        return realm
    end
    if GetRealmName then
        return GetRealmName()
    end
    return ""
end

local function BuildStorageKey(name, realm)
    if not name or name == "" then
        return nil
    end

    local normalizedRealm = NormalizeRealm(realm)
    if normalizedRealm ~= "" then
        return name .. "-" .. normalizedRealm
    end

    return name
end

local function MergeRecords(into, from)
    if not from then
        return into
    end

    into = into or {}

    if from.notes then
        into.notes = into.notes or {}
        for i = 1, #from.notes do
            into.notes[#into.notes + 1] = from.notes[i]
        end
    end

    into.name = into.name or from.name
    into.realm = into.realm or from.realm
    into.classFile = into.classFile or from.classFile

    return into
end

local function MigrateAliasData(storageKey, aliasKey)
    if not aliasKey or aliasKey == storageKey or not DB().playerData[aliasKey] then
        return
    end

    DB().playerData[storageKey] = MergeRecords(DB().playerData[storageKey], DB().playerData[aliasKey])
    DB().playerData[aliasKey] = nil

    if DB().keyData[aliasKey] and not DB().keyData[storageKey] then
        DB().keyData[storageKey] = DB().keyData[aliasKey]
    end
    DB().keyData[aliasKey] = nil
end

local function LinkGuidToKey(unit, storageKey)
    if not storageKey then
        return
    end

    local guidResult = Guard.call(UnitGUID, unit)
    if guidResult.ok and guidResult[1] then
        DB().playerGuidIndex[guidResult[1]] = storageKey
    end
end

local function MigrateAliases(unit, storageKey)
    if not storageKey then
        return
    end

    LinkGuidToKey(unit, storageKey)

    local nameResult = Guard.call(UnitName, unit)
    if nameResult.ok and nameResult[1] then
        MigrateAliasData(storageKey, nameResult[1])
    end

    local guidResult = Guard.call(UnitGUID, unit)
    if guidResult.ok and guidResult[1] then
        MigrateAliasData(storageKey, guidResult[1])
    end
end

function PlayerData.GetCacheKey(unit)
    local nameResult = Guard.call(UnitName, unit)
    if nameResult.ok and nameResult[1] then
        local storageKey = BuildStorageKey(nameResult[1], nameResult[2])
        LinkGuidToKey(unit, storageKey)
        return storageKey
    end

    local guidResult = Guard.call(UnitGUID, unit)
    if guidResult.ok and guidResult[1] then
        local indexed = DB().playerGuidIndex[guidResult[1]]
        if indexed then
            return indexed
        end
        return guidResult[1]
    end

    return unit
end

function PlayerData.Save(unit, record)
    local key = PlayerData.GetCacheKey(unit)
    if not key or not record then
        return
    end

    MigrateAliases(unit, key)

    local existing = DB().playerData[key]
    if existing and existing.notes and not record.notes then
        record.notes = existing.notes
    end

    record.realm = record.realm or NormalizeRealm(record.realm)
    DB().playerData[key] = record
end

function PlayerData.Load(unit)
    local key = PlayerData.GetCacheKey(unit)
    if not key then
        return nil
    end

    MigrateAliases(unit, key)

    return DB().playerData[key]
end

function PlayerData.Fetch(unit)
    local nameResult = Guard.call(UnitName, unit)
    local classResult = Guard.call(UnitClass, unit)
    local storageKey = PlayerData.GetCacheKey(unit)

    MigrateAliases(unit, storageKey)

    local cached = DB().playerData[storageKey]
    local record = {
        name = nameResult.ok and nameResult[1] or (cached and cached.name) or nil,
        realm = nameResult.ok and NormalizeRealm(nameResult[2]) or (cached and cached.realm) or nil,
        classFile = classResult.ok and classResult[2] or (cached and cached.classFile) or nil,
        notes = cached and cached.notes or nil,
        time = time(),
    }

    if record.name or record.classFile then
        PlayerData.Save(unit, record)
        return DB().playerData[storageKey] or record
    end

    if cached then
        return cached
    end

    return record
end

function PlayerData.Get(unit)
    local record = PlayerData.Fetch(unit)
    local displayName = record.name

    if not displayName then
        local nameResult = Guard.call(UnitName, unit)
        if nameResult.secret then
            displayName = "—"
        else
            displayName = unit
        end
    end

    return {
        name = displayName,
        classFile = record.classFile,
    }
end

function PlayerData.GetNotes(unit)
    MigrateAliases(unit, PlayerData.GetCacheKey(unit))

    local record = PlayerData.Load(unit)
    if record and record.notes then
        return record.notes
    end
    return {}
end

function PlayerData.AddNote(unit, text)
    local trimmed = strtrim and strtrim(text or "") or (text or ""):match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return false
    end

    if #trimmed > PlayerData.MAX_NOTE_LENGTH then
        trimmed = trimmed:sub(1, PlayerData.MAX_NOTE_LENGTH)
    end

    local key = PlayerData.GetCacheKey(unit)
    if not key then
        return false
    end

    MigrateAliases(unit, key)

    local nameResult = Guard.call(UnitName, unit)
    local classResult = Guard.call(UnitClass, unit)
    local record = DB().playerData[key] or {}

    if nameResult.ok and nameResult[1] then
        record.name = nameResult[1]
        record.realm = NormalizeRealm(nameResult[2])
    end
    if classResult.ok and classResult[2] then
        record.classFile = classResult[2]
    end

    record.notes = record.notes or {}
    record.notes[#record.notes + 1] = {
        text = trimmed,
        time = time(),
    }
    record.time = time()

    DB().playerData[key] = record
    LinkGuidToKey(unit, key)

    if PlayerData.OnNotesChanged then
        pcall(PlayerData.OnNotesChanged, unit)
    end

    return true
end

function PlayerData.DeleteNote(unit, index)
    if not index or index < 1 then
        return false
    end

    local key = PlayerData.GetCacheKey(unit)
    if not key then
        return false
    end

    MigrateAliases(unit, key)

    local record = DB().playerData[key]
    if not record or not record.notes or not record.notes[index] then
        return false
    end

    table.remove(record.notes, index)
    record.time = time()
    DB().playerData[key] = record

    if PlayerData.OnNotesChanged then
        pcall(PlayerData.OnNotesChanged, unit)
    end

    return true
end

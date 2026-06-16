local ADDON_NAME = ...

Key.Cache = Key.Cache or {}
local Cache = Key.Cache

Cache.STORE = {
    KEYSTONE = "keystone",
    SEASON_BEST = "seasonBest",
    READY = "ready",
}

Cache.stores = Cache.stores or {}

function Cache:IsAccessible(value)
    return value ~= nil and (not issecretvalue or not issecretvalue(value))
end

function Cache:BuildLookupKeys(name)
    if Key.Party and Key.Party.BuildLookupKeys then
        return Key.Party:BuildLookupKeys(name)
    end

    if not self:IsAccessible(name) or name == "" then
        return {}
    end

    return { name }
end

function Cache:FindPartyUnitForSender(sender)
    if Key.Party and Key.Party.FindPartyUnitForSender then
        return Key.Party:FindPartyUnitForSender(sender)
    end
    return nil
end

function Cache:CreateStore(id)
    if not id or id == "" then
        return nil
    end

    local store = {
        id = id,
        primary = {},
        byName = {},
        byGUID = {},
        sessionPrimary = {},
        sessionByName = {},
        sessionByGUID = {},
    }

    self.stores[id] = store
    return store
end

function Cache:GetStore(id)
    return self.stores[id] or self:CreateStore(id)
end

function Cache:GetPrimary(store)
    return store and store.primary or {}
end

function Cache:MirrorEntryToSession(store, sender, entry)
    if not store then
        return
    end

    store.sessionPrimary[sender] = entry

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        store.sessionByName[key] = entry
    end

    local unit = self:FindPartyUnitForSender(sender)
    if unit then
        local guid = UnitGUID(unit)
        if self:IsAccessible(guid) then
            store.sessionByGUID[guid] = entry
            return
        end
    end

    for guid, cachedEntry in pairs(store.byGUID) do
        if cachedEntry == entry then
            store.sessionByGUID[guid] = entry
            break
        end
    end
end

function Cache:ClearSessionEntryForSender(store, sender)
    if not store then
        return
    end

    local entry = store.sessionPrimary[sender]
    store.sessionPrimary[sender] = nil

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        store.sessionByName[key] = nil
    end

    if not entry then
        return
    end

    for guid, cachedEntry in pairs(store.sessionByGUID) do
        if cachedEntry == entry then
            store.sessionByGUID[guid] = nil
        end
    end
end

function Cache:Write(store, sender, entry)
    if not store or not sender or sender == "" then
        return false
    end

    store.primary[sender] = entry

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        store.byName[key] = entry
    end

    local unit = self:FindPartyUnitForSender(sender)
    if unit then
        local guid = UnitGUID(unit)
        if self:IsAccessible(guid) then
            store.byGUID[guid] = entry
        end
    end

    self:MirrorEntryToSession(store, sender, entry)
    return true
end

function Cache:Clear(store, sender)
    if not store or not sender or sender == "" then
        return false
    end

    self:ClearSessionEntryForSender(store, sender)
    store.primary[sender] = nil

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        store.byName[key] = nil
    end

    local unit = self:FindPartyUnitForSender(sender)
    if unit then
        local guid = UnitGUID(unit)
        if self:IsAccessible(guid) then
            store.byGUID[guid] = nil
        end
    end

    return true
end

function Cache:ReadBySender(store, sender, includeSession)
    if not store or not sender or sender == "" then
        return nil
    end

    if store.primary[sender] then
        return store.primary[sender]
    end

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        if store.byName[key] then
            return store.byName[key]
        end
    end

    if not includeSession then
        return nil
    end

    if store.sessionPrimary[sender] then
        return store.sessionPrimary[sender]
    end

    for _, key in ipairs(self:BuildLookupKeys(sender)) do
        if store.sessionByName[key] then
            return store.sessionByName[key]
        end
    end

    return nil
end

function Cache:ReadByUnit(store, unit, includeSession)
    if not store or not unit then
        return nil
    end

    local guid = UnitGUID(unit)
    if self:IsAccessible(guid) and store.byGUID[guid] then
        return store.byGUID[guid]
    end

    local fullName = GetUnitName and GetUnitName(unit, true)
    if self:IsAccessible(fullName) then
        for _, key in ipairs(self:BuildLookupKeys(fullName)) do
            if store.byName[key] then
                return store.byName[key]
            end
        end
    end

    if UnitFullName then
        local name, realm = UnitFullName(unit)
        if self:IsAccessible(name) and self:IsAccessible(realm) and realm ~= "" then
            for _, key in ipairs(self:BuildLookupKeys(name .. "-" .. realm)) do
                if store.byName[key] then
                    return store.byName[key]
                end
            end
        end
    end

    local name = UnitName(unit)
    if self:IsAccessible(name) then
        for _, key in ipairs(self:BuildLookupKeys(name)) do
            if store.byName[key] then
                return store.byName[key]
            end
        end
    end

    if not includeSession then
        return nil
    end

    if self:IsAccessible(guid) and store.sessionByGUID[guid] then
        return store.sessionByGUID[guid]
    end

    if self:IsAccessible(fullName) then
        for _, key in ipairs(self:BuildLookupKeys(fullName)) do
            if store.sessionByName[key] then
                return store.sessionByName[key]
            end
        end
    end

    if UnitFullName then
        local unitName, realm = UnitFullName(unit)
        if self:IsAccessible(unitName) and self:IsAccessible(realm) and realm ~= "" then
            for _, key in ipairs(self:BuildLookupKeys(unitName .. "-" .. realm)) do
                if store.sessionByName[key] then
                    return store.sessionByName[key]
                end
            end
        end
    end

    if self:IsAccessible(name) then
        for _, key in ipairs(self:BuildLookupKeys(name)) do
            if store.sessionByName[key] then
                return store.sessionByName[key]
            end
        end
    end

    return nil
end

function Cache:UpdateBySender(store, sender, mutator)
    if not store or not sender or sender == "" or type(mutator) ~= "function" then
        return false
    end

    local entry = self:ReadBySender(store, sender, false) or {}
    mutator(entry)
    return self:Write(store, sender, entry)
end

function Cache:RebindByGUID(store)
    if not store then
        return
    end

    wipe(store.byGUID)

    for sender in pairs(store.primary) do
        local unit = self:FindPartyUnitForSender(sender)
        if unit then
            local guid = UnitGUID(unit)
            if self:IsAccessible(guid) then
                store.byGUID[guid] = store.primary[sender]
            end
        end
    end
end

function Cache:WipeSession(store)
    if not store then
        return
    end

    wipe(store.sessionByName)
    wipe(store.sessionByGUID)
    wipe(store.sessionPrimary)
end

function Cache:Wipe(store)
    if not store then
        return
    end

    wipe(store.byName)
    wipe(store.byGUID)
    wipe(store.primary)
    self:WipeSession(store)
end

function Cache:RestoreSession(store)
    if not store then
        return
    end

    if next(store.primary) or not next(store.sessionPrimary) then
        return
    end

    for sender, entry in pairs(store.sessionPrimary) do
        self:Write(store, sender, entry)
    end
end

Cache:CreateStore(Cache.STORE.KEYSTONE)
Cache:CreateStore(Cache.STORE.SEASON_BEST)
Cache:CreateStore(Cache.STORE.READY)

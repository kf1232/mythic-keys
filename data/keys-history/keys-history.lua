Key.Data = Key.Data or {}

local KeysHistory = {}
Key.Data.KeysHistory = KeysHistory

local Guard = Key.Guard
local PlayerData = Key.Data.PlayerData
local KeyData = Key.Data.KeyData
local ChallengeMode = Key.Util.ChallengeMode
local Chat = Key.Util.Chat

KeysHistory.RATING_PASS = "pass"
KeysHistory.RATING_FAIL = "fail"
KeysHistory.RATING_NEUTRAL = "neutral"

local MAX_ENTRIES = 100
local MYTHIC_KEYSTONE_DIFFICULTY = 8
local MYTHIC_DUNGEON_DIFFICULTY = 23

local listeners = {}
local eventFrame
local inspectQueue = {}
local inspectPendingGuid
local inspectEntryId

local function DB()
    KeyBetaDB = KeyBetaDB or {}
    if type(KeyBetaDB.keysHistory) ~= "table" then
        KeyBetaDB.keysHistory = {}
    end
    if type(KeyBetaDB.keysHistory.entries) ~= "table" then
        KeyBetaDB.keysHistory.entries = {}
    end
    return KeyBetaDB.keysHistory
end

local function NotifyChanged()
    for i = 1, #listeners do
        pcall(listeners[i])
    end
end

local function NextId()
    local store = DB()
    store.nextId = (store.nextId or 0) + 1
    return store.nextId
end

local function GetUnitItemLevel(unit)
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        if GetAverageItemLevel then
            local overall, equipped = GetAverageItemLevel()
            local value = equipped or overall
            if type(value) == "number" then
                return math.floor(value + 0.5)
            end
        end
        return nil
    end

    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local result = Guard.call(C_PaperDollInfo.GetInspectItemLevel, unit)
        if result.ok and type(result[1]) == "number" and result[1] > 0 then
            return math.floor(result[1] + 0.5)
        end
    end

    return nil
end

local function GetUnitRating(unit)
    local summary = KeyData.GetRatingSummary(unit)
    if summary and type(summary.currentSeasonScore) == "number" then
        return math.floor(summary.currentSeasonScore + 0.5)
    end
    return nil
end

local function IsSelfRecord(player)
    if not player then
        return true
    end
    if player.isPlayer then
        return true
    end

    local guidResult = Guard.call(UnitGUID, "player")
    local myGuid = guidResult.ok and guidResult[1] or nil
    if myGuid and player.guid and player.guid == myGuid then
        return true
    end

    return false
end

local function StripSelfPlayers(entry)
    if not entry or type(entry.players) ~= "table" then
        return entry
    end

    local kept = {}
    for i = 1, #entry.players do
        local player = entry.players[i]
        if not IsSelfRecord(player) then
            player.isPlayer = nil
            kept[#kept + 1] = player
        end
    end
    entry.players = kept
    return entry
end

-- Other party/raid members only. Never includes the local player.
local function CollectGroupUnits()
    local units = {}
    if not IsInGroup or not IsInGroup() then
        return units
    end

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                units[#units + 1] = unit
            end
        end
        return units
    end

    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            units[#units + 1] = unit
        end
    end
    return units
end

local function SnapshotPlayer(unit)
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        return nil
    end

    local player = PlayerData.Fetch(unit)
    local guidResult = Guard.call(UnitGUID, unit)
    local guid = guidResult.ok and guidResult[1] or nil

    local name = player and player.name or nil
    local realm = player and player.realm or nil
    if (not name or name == "") and UnitName then
        local unitName, unitRealm = UnitName(unit)
        name = unitName or unit
        if (not realm or realm == "") and unitRealm and unitRealm ~= "" then
            realm = unitRealm
        end
    end
    if (not realm or realm == "") and GetRealmName then
        realm = GetRealmName()
    end

    return {
        guid = guid,
        name = name or unit,
        realm = realm,
        classFile = player and player.classFile or select(2, UnitClass(unit)),
        rating = GetUnitRating(unit),
        itemLevel = GetUnitItemLevel(unit),
        mark = nil,
    }
end

local function FindEntryById(entryId)
    local entries = DB().entries
    for i = 1, #entries do
        if entries[i].id == entryId then
            return entries[i]
        end
    end
    return nil
end

-- GetInstanceInfo()'s 8th return is an InstanceMapID (same for every Magisters visit),
-- not a unique run id. Active entry tracks the current visit so later runs don't merge.
local function ClearActiveEntry()
    local store = DB()
    store.activeEntryId = nil
    store.activeInstanceMapID = nil
end

local function SetActiveEntry(entry, instanceMapID)
    local store = DB()
    if not entry or not instanceMapID then
        ClearActiveEntry()
        return
    end
    store.activeEntryId = entry.id
    store.activeInstanceMapID = instanceMapID
end

local function GetActiveEntry(instanceMapID)
    local store = DB()
    if not store.activeEntryId then
        return nil
    end
    if instanceMapID and store.activeInstanceMapID ~= instanceMapID then
        return nil
    end

    local entry = FindEntryById(store.activeEntryId)
    if not entry then
        ClearActiveEntry()
        return nil
    end
    return entry
end

local function TrimEntries()
    local entries = DB().entries
    while #entries > MAX_ENTRIES do
        table.remove(entries)
    end
end

local function RequestInspects(entry)
    if not entry or not entry.players then
        return
    end

    for i = #inspectQueue, 1, -1 do
        inspectQueue[i] = nil
    end
    for i = 1, #entry.players do
        local player = entry.players[i]
        if player.guid and not player.itemLevel then
            inspectQueue[#inspectQueue + 1] = {
                entryId = entry.id,
                guid = player.guid,
            }
        end
    end
end

local function UnitTokenFromGUID(guid)
    if not guid then
        return nil
    end
    if UnitGUID("player") == guid then
        return nil
    end
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitGUID(unit) == guid and not UnitIsUnit(unit, "player") then
                return unit
            end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitGUID(unit) == guid then
                return unit
            end
        end
    end
    return nil
end

local function ProcessInspectQueue()
    if inspectPendingGuid or #inspectQueue == 0 then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local nextItem = table.remove(inspectQueue, 1)
    if not nextItem then
        return
    end

    local unit = UnitTokenFromGUID(nextItem.guid)
    if not unit or not CanInspect or not CanInspect(unit) then
        ProcessInspectQueue()
        return
    end

    inspectPendingGuid = nextItem.guid
    inspectEntryId = nextItem.entryId
    NotifyInspect(unit)
end

local function UpdatePlayerItemLevel(entryId, guid, itemLevel)
    local entry = FindEntryById(entryId)
    if not entry or not entry.players then
        return
    end

    for i = 1, #entry.players do
        local player = entry.players[i]
        if player.guid == guid then
            if player.itemLevel ~= itemLevel then
                player.itemLevel = itemLevel
                NotifyChanged()
            end
            return
        end
    end
end

local function EnrichChallengeInfo(entry)
    if not entry then
        return
    end

    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        entry.difficultyID = MYTHIC_KEYSTONE_DIFFICULTY
        if C_ChallengeMode.GetActiveKeystoneInfo then
            local level = C_ChallengeMode.GetActiveKeystoneInfo()
            if type(level) == "number" and level > 0 then
                entry.keyLevel = level
            end
        end
        if C_ChallengeMode.GetActiveChallengeMapID then
            local mapID = C_ChallengeMode.GetActiveChallengeMapID()
            if mapID then
                entry.mapChallengeModeID = mapID
                local info = ChallengeMode.GetMapUIInfo(mapID)
                if info and info.name then
                    entry.instanceName = info.name
                end
            end
        end
    end
end

local function PlayerIdentityKey(player)
    if not player or not player.name or player.name == "" then
        return nil
    end
    return string.lower(player.name) .. "-" .. string.lower(player.realm or "")
end

local function ApplySnapshotFields(existing, snapshot, overwriteStats)
    if snapshot.name and snapshot.name ~= "" then
        existing.name = snapshot.name
    end
    if snapshot.realm and snapshot.realm ~= "" then
        existing.realm = snapshot.realm
    end
    if snapshot.classFile then
        existing.classFile = snapshot.classFile
    end
    if snapshot.guid and not existing.guid then
        existing.guid = snapshot.guid
    end
    if overwriteStats then
        if snapshot.rating then
            existing.rating = snapshot.rating
        end
        if snapshot.itemLevel then
            existing.itemLevel = snapshot.itemLevel
        end
    else
        if not existing.rating and snapshot.rating then
            existing.rating = snapshot.rating
        end
        if not existing.itemLevel and snapshot.itemLevel then
            existing.itemLevel = snapshot.itemLevel
        end
    end
end

-- Add newly present members; keep existing rows/marks. Fill missing rating/ilvl.
local function MergeGroupIntoEntry(entry)
    if not entry then
        return 0
    end

    StripSelfPlayers(entry)
    entry.players = entry.players or {}

    local byGuid = {}
    local byIdentity = {}
    for i = 1, #entry.players do
        local player = entry.players[i]
        if player.guid then
            byGuid[player.guid] = player
        end
        local key = PlayerIdentityKey(player)
        if key then
            byIdentity[key] = player
        end
    end

    local added = 0
    local units = CollectGroupUnits()
    for i = 1, #units do
        local snapshot = SnapshotPlayer(units[i])
        if snapshot then
            local existing = (snapshot.guid and byGuid[snapshot.guid])
                or byIdentity[PlayerIdentityKey(snapshot)]
            if existing then
                ApplySnapshotFields(existing, snapshot, false)
            else
                entry.players[#entry.players + 1] = snapshot
                if snapshot.guid then
                    byGuid[snapshot.guid] = snapshot
                end
                local key = PlayerIdentityKey(snapshot)
                if key then
                    byIdentity[key] = snapshot
                end
                added = added + 1
            end
        end
    end

    return added
end

-- Replace roster with current group. Keep marks for players still present.
local function SyncGroupToEntry(entry)
    if not entry then
        return 0, 0
    end

    StripSelfPlayers(entry)
    entry.players = entry.players or {}
    local previousCount = #entry.players

    local byGuid = {}
    local byIdentity = {}
    for i = 1, #entry.players do
        local player = entry.players[i]
        if player.guid then
            byGuid[player.guid] = player
        end
        local key = PlayerIdentityKey(player)
        if key then
            byIdentity[key] = player
        end
    end

    local nextPlayers = {}
    local kept = 0
    local units = CollectGroupUnits()
    for i = 1, #units do
        local snapshot = SnapshotPlayer(units[i])
        if snapshot then
            local existing = (snapshot.guid and byGuid[snapshot.guid])
                or byIdentity[PlayerIdentityKey(snapshot)]
            if existing then
                ApplySnapshotFields(existing, snapshot, true)
                nextPlayers[#nextPlayers + 1] = existing
                kept = kept + 1
            else
                nextPlayers[#nextPlayers + 1] = snapshot
            end
        end
    end

    entry.players = nextPlayers
    return #nextPlayers, math.max(0, previousCount - kept)
end

local function IsMythicPartyInstance()
    if not GetInstanceInfo then
        return false
    end
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "party" then
        return false
    end
    if difficultyID == MYTHIC_KEYSTONE_DIFFICULTY or difficultyID == MYTHIC_DUNGEON_DIFFICULTY then
        return true
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
        return true
    end
    return false
end

local function CreateSnapshot(reason, challengeMapID)
    if not GetInstanceInfo then
        return nil
    end

    -- instanceMapID identifies the dungeon map, not a unique run/copy.
    local name, instanceType, difficultyID, difficultyName, _, _, _, instanceMapID = GetInstanceInfo()
    if instanceType ~= "party" then
        return nil
    end
    if difficultyID ~= MYTHIC_KEYSTONE_DIFFICULTY and difficultyID ~= MYTHIC_DUNGEON_DIFFICULTY then
        -- Key start can fire before difficulty settles; still allow challenge snapshots.
        if reason ~= "challenge_start" then
            return nil
        end
    end

    local existing = GetActiveEntry(instanceMapID)
    if existing then
        local added = MergeGroupIntoEntry(existing)
        if challengeMapID then
            existing.mapChallengeModeID = challengeMapID
            local info = ChallengeMode.GetMapUIInfo(challengeMapID)
            if info and info.name then
                existing.instanceName = info.name
            end
        end
        EnrichChallengeInfo(existing)
        SetActiveEntry(existing, instanceMapID)
        if added > 0 then
            RequestInspects(existing)
            ProcessInspectQueue()
            Chat.Print(string.format(
                "Keys history updated: %s (+%d player%s, %d total).",
                existing.instanceName or "run",
                added,
                added == 1 and "" or "s",
                #(existing.players or {})
            ))
        end
        NotifyChanged()
        return existing
    end

    local players = {}
    local units = CollectGroupUnits()
    for i = 1, #units do
        local snapshot = SnapshotPlayer(units[i])
        if snapshot then
            players[#players + 1] = snapshot
        end
    end

    local entry = {
        id = NextId(),
        time = time(),
        instanceID = instanceMapID, -- InstanceMapID (dungeon identity), not unique per visit
        instanceName = name or "Mythic dungeon",
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        keyLevel = nil,
        mapChallengeModeID = nil,
        reason = reason,
        players = players,
    }

    if challengeMapID then
        entry.mapChallengeModeID = challengeMapID
        local info = ChallengeMode.GetMapUIInfo(challengeMapID)
        if info and info.name then
            entry.instanceName = info.name
        end
    end

    EnrichChallengeInfo(entry)

    local entries = DB().entries
    table.insert(entries, 1, entry)
    TrimEntries()
    SetActiveEntry(entry, instanceMapID)
    RequestInspects(entry)
    ProcessInspectQueue()
    NotifyChanged()

    Chat.Print(string.format(
        "Keys history saved: %s%s (%d players).",
        entry.instanceName,
        entry.keyLevel and (" +" .. entry.keyLevel) or "",
        #players
    ))

    return entry
end

local function TrySnapshot(reason, challengeMapID)
    local ok, err = pcall(CreateSnapshot, reason, challengeMapID)
    if not ok then
        print("|cff00ff00Mythic Keys:|r Keys history error:", err)
    end
end

local rosterMergePending = false

local function ScheduleRosterMerge()
    if rosterMergePending then
        return
    end
    if not IsMythicPartyInstance() then
        return
    end

    rosterMergePending = true
    local function run()
        rosterMergePending = false
        if IsMythicPartyInstance() then
            TrySnapshot("roster")
        end
    end

    -- New members often lack name/guid for a moment after roster events.
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, run)
    else
        run()
    end
end

local function EnsureEvents()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("INSPECT_READY")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Leaving the dungeon ends the visit so the next Magisters (etc.) is a new run.
            if not IsMythicPartyInstance() then
                ClearActiveEntry()
            end
            TrySnapshot("enter")
            return
        end

        if event == "CHALLENGE_MODE_START" then
            TrySnapshot("challenge_start", arg1)
            return
        end

        if event == "GROUP_ROSTER_UPDATE" then
            ScheduleRosterMerge()
            return
        end

        if event == "PLAYER_REGEN_ENABLED" then
            ProcessInspectQueue()
            return
        end

        if event == "INSPECT_READY" then
            local guid = arg1
            if guid and guid == inspectPendingGuid then
                local unit = UnitTokenFromGUID(guid)
                if unit then
                    local itemLevel = GetUnitItemLevel(unit)
                    if itemLevel then
                        UpdatePlayerItemLevel(inspectEntryId, guid, itemLevel)
                    end
                    -- Refresh rating if it was missing at snapshot time.
                    local entry = FindEntryById(inspectEntryId)
                    if entry then
                        for i = 1, #entry.players do
                            local player = entry.players[i]
                            if player.guid == guid and not player.rating then
                                player.rating = GetUnitRating(unit)
                                NotifyChanged()
                            end
                        end
                    end
                end
                inspectPendingGuid = nil
                inspectEntryId = nil
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.35, ProcessInspectQueue)
                else
                    ProcessInspectQueue()
                end
            end
        end
    end)
end

function KeysHistory.OnChanged(listener)
    if type(listener) == "function" then
        listeners[#listeners + 1] = listener
    end
end

function KeysHistory.GetEntries()
    EnsureEvents()
    local entries = DB().entries
    for i = 1, #entries do
        StripSelfPlayers(entries[i])
    end
    return entries
end

function KeysHistory.GetEntry(entryId)
    EnsureEvents()
    return StripSelfPlayers(FindEntryById(entryId))
end

function KeysHistory.SetPlayerMark(entryId, playerIndex, mark)
    local entry = StripSelfPlayers(FindEntryById(entryId))
    if not entry or not entry.players or not entry.players[playerIndex] then
        return false
    end

    if mark ~= nil
        and mark ~= KeysHistory.RATING_PASS
        and mark ~= KeysHistory.RATING_FAIL
        and mark ~= KeysHistory.RATING_NEUTRAL
    then
        return false
    end

    local player = entry.players[playerIndex]
    if player.mark == mark then
        player.mark = nil
    else
        player.mark = mark
    end

    NotifyChanged()
    return true
end

function KeysHistory.RemovePlayer(entryId, playerIndex)
    local entry = StripSelfPlayers(FindEntryById(entryId))
    if not entry or not entry.players or not entry.players[playerIndex] then
        return false
    end

    table.remove(entry.players, playerIndex)
    NotifyChanged()
    return true
end

function KeysHistory.DeleteEntry(entryId)
    local entries = DB().entries
    for i = 1, #entries do
        if entries[i].id == entryId then
            table.remove(entries, i)
            NotifyChanged()
            return true
        end
    end
    return false
end

-- List/detail title: "Instance - Key Level"
function KeysHistory.FormatEntryTitle(entry)
    if not entry then
        return "Unknown run"
    end

    local instanceName = entry.instanceName or "Mythic dungeon"
    local level = entry.keyLevel
    if not level then
        return instanceName .. " - —"
    end
    return string.format("%s - %d", instanceName, level)
end

-- List date line: yy-mm-dd
function KeysHistory.FormatEntryDate(entry)
    if not entry or not entry.time then
        return ""
    end
    if date then
        return date("%y-%m-%d", entry.time)
    end
    return tostring(entry.time)
end

function KeysHistory.FormatEntryTime(entry)
    return KeysHistory.FormatEntryDate(entry)
end

-- Display as "Name - Realm".
function KeysHistory.FormatPlayerName(player)
    if not player then
        return "Unknown"
    end
    local name = player.name or "Unknown"
    local realm = player.realm
    if realm and realm ~= "" then
        return name .. " - " .. realm
    end
    return name
end

local function NormalizeIdentityKey(name, realm)
    if not name or name == "" then
        return nil
    end
    return string.lower(name) .. "-" .. string.lower(realm or "")
end

local function BuildUnitLookup(unit)
    local guidResult = Guard.call(UnitGUID, unit)
    local nameResult = Guard.call(UnitName, unit)
    local cacheKey = PlayerData.GetCacheKey(unit)

    local name = nameResult.ok and nameResult[1] or nil
    local realm = nameResult.ok and nameResult[2] or nil

    return {
        guid = guidResult.ok and guidResult[1] or nil,
        cacheKey = cacheKey,
        identityKey = NormalizeIdentityKey(name, realm)
            or (cacheKey and string.lower(cacheKey) or nil),
    }
end

local function HistoryPlayerMatches(player, lookup)
    if not player or not lookup then
        return false
    end

    if lookup.guid and player.guid and player.guid == lookup.guid then
        return true
    end

    local playerKey = PlayerIdentityKey(player)
    if playerKey and lookup.identityKey and playerKey == lookup.identityKey then
        return true
    end

    if lookup.cacheKey and player.name then
        local cacheLower = string.lower(lookup.cacheKey)
        if playerKey == cacheLower then
            return true
        end
        if string.lower(player.name) == cacheLower then
            return true
        end
    end

    return false
end

local function MarkScore(mark)
    if mark == KeysHistory.RATING_PASS then
        return 1
    end
    if mark == KeysHistory.RATING_FAIL then
        return -1
    end
    if mark == KeysHistory.RATING_NEUTRAL then
        return 0
    end
    return nil
end

-- Sum pass (+1), neutral (0), and fail (-1) marks across all history runs for a unit.
function KeysHistory.GetPlayerVoteSummary(unit)
    EnsureEvents()

    local lookup = BuildUnitLookup(unit)
    local summary = {
        score = 0,
        pass = 0,
        fail = 0,
        neutral = 0,
        marked = 0,
    }

    if not lookup.guid and not lookup.identityKey and not lookup.cacheKey then
        return summary
    end

    local entries = DB().entries
    for i = 1, #entries do
        local entry = StripSelfPlayers(entries[i])
        local players = entry and entry.players or {}
        for j = 1, #players do
            local player = players[j]
            if HistoryPlayerMatches(player, lookup) and player.mark then
                local delta = MarkScore(player.mark)
                if delta ~= nil then
                    summary.marked = summary.marked + 1
                    summary.score = summary.score + delta
                    if player.mark == KeysHistory.RATING_PASS then
                        summary.pass = summary.pass + 1
                    elseif player.mark == KeysHistory.RATING_FAIL then
                        summary.fail = summary.fail + 1
                    else
                        summary.neutral = summary.neutral + 1
                    end
                end
            end
        end
    end

    return summary
end

function KeysHistory.UnitHasVoteHistory(unit)
    return KeysHistory.GetPlayerVoteSummary(unit).marked > 0
end

-- Manual refresh: snapshot current group and drop anyone no longer present.
function KeysHistory.RefreshGroup()
    EnsureEvents()

    if not IsMythicPartyInstance() then
        Chat.Print("Keys history refresh needs an active mythic dungeon.")
        return false
    end

    local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    local entry = GetActiveEntry(instanceMapID)
    if not entry then
        TrySnapshot("refresh")
        return true
    end

    local total, removed = SyncGroupToEntry(entry)
    EnrichChallengeInfo(entry)
    SetActiveEntry(entry, instanceMapID)
    RequestInspects(entry)
    ProcessInspectQueue()
    NotifyChanged()

    Chat.Print(string.format(
        "Keys history refreshed: %s (%d players%s).",
        entry.instanceName or "run",
        total,
        removed > 0 and (", removed " .. removed) or ""
    ))
    return true
end

EnsureEvents()

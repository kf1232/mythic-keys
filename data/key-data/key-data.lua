Key.Data = Key.Data or {}

local KeyData = {}
Key.Data.KeyData = KeyData

local Guard = Key.Guard
local PlayerData = Key.Data.PlayerData
local SeasonDungeons = Key.Data.SeasonDungeons

Key.db.keyData = KeyBetaDB.keyData

local watches = {}
local DEFAULT_WATCH_INTERVAL = 1
local DEFAULT_WATCH_DURATION = 15

local function GetCacheKey(unit)
    return PlayerData.GetCacheKey(unit)
end

local function ParseSeasonRuns(summary)
    local ok, runs = pcall(function()
        local byMap = {}
        if summary.runs then
            for _, run in ipairs(summary.runs) do
                if run.finishedSuccess and run.bestRunLevel and run.bestRunLevel > 0 and run.challengeModeID then
                    byMap[run.challengeModeID] = run.bestRunLevel
                end
            end
        end
        return byMap
    end)

    if ok then
        return runs
    end

    return nil
end

function KeyData.Save(unit, runs)
    local key = GetCacheKey(unit)
    if not key or not runs then
        return
    end

    Key.db.keyData[key] = {
        runs = runs,
        time = time(),
    }
end

function KeyData.Load(unit)
    local key = GetCacheKey(unit)
    if not key then
        return nil
    end

    local entry = Key.db.keyData[key]
    if entry and entry.runs then
        return entry.runs
    end

    return nil
end

function KeyData.GetRatingSummary(unit)
    if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        return nil, "unavailable"
    end

    local result = Guard.call(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if not result.ok then
        return nil, "error"
    end
    if result.secret then
        return nil, "secret"
    end
    if not result[1] then
        return nil, "empty"
    end

    return result[1], "ok"
end

function KeyData.GetSeasonRuns(unit)
    local summary, status = KeyData.GetRatingSummary(unit)

    if summary then
        local runs = ParseSeasonRuns(summary)
        if runs then
            KeyData.Save(unit, runs)
            return runs
        end
    end

    if status ~= "ok" then
        return KeyData.Load(unit)
    end

    return KeyData.Load(unit)
end

function KeyData.GetSeasonBestForMap(unit, mapID)
    if not mapID then
        return nil
    end

    local runs = KeyData.GetSeasonRuns(unit)
    if not runs then
        return nil
    end

    return runs[mapID]
end

function KeyData.FormatSeasonBestForMap(unit, mapID)
    local level = KeyData.GetSeasonBestForMap(unit, mapID)
    if level then
        return "+" .. level
    end
    return "—"
end

-- True when Blizzard currently returns a rating summary for the unit.
function KeyData.HasLiveSummary(unit)
    local summary = KeyData.GetRatingSummary(unit)
    return summary ~= nil
end

function KeyData.StopWatch(name)
    local watch = watches[name]
    if watch then
        watch:Cancel()
        watches[name] = nil
    end
end

-- Party/target M+ summaries often arrive after GROUP_ROSTER_UPDATE / target change.
-- Poll until every unit has a live summary, or until maxDuration elapses.
function KeyData.WatchUntilLive(name, getUnits, onUpdate, options)
    if type(name) ~= "string" or type(getUnits) ~= "function" then
        return
    end

    options = options or {}
    local interval = options.interval or DEFAULT_WATCH_INTERVAL
    local maxDuration = options.maxDuration or DEFAULT_WATCH_DURATION

    KeyData.StopWatch(name)

    local function AnyPending()
        local units = getUnits() or {}
        local pending = false
        for i = 1, #units do
            -- Warm cache; summary may populate after roster/target changes.
            KeyData.GetSeasonRuns(units[i])
            if not KeyData.HasLiveSummary(units[i]) then
                pending = true
            end
        end
        return pending
    end

    if not AnyPending() then
        return
    end

    if not C_Timer or not C_Timer.NewTicker then
        if onUpdate then
            onUpdate()
        end
        return
    end

    local elapsed = 0
    watches[name] = C_Timer.NewTicker(interval, function(ticker)
        elapsed = elapsed + interval
        local pending = AnyPending()

        if onUpdate then
            pcall(onUpdate)
        end

        if not pending or elapsed >= maxDuration then
            ticker:Cancel()
            watches[name] = nil
        end
    end)
end

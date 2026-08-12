-- Compact secret guard for unit/group API reads (Midnight 12.0+).
-- https://warcraft.wiki.gg/wiki/Secret_Values
--
-- Group modules call Guard.call() with any unit token + WoW API.
-- Returns a small result table — same shape for party, raid, or custom rosters.

Key.Guard = Key.Guard or {}

local Guard = Key.Guard

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function isBlockedTable(value)
    return type(value) == "table"
        and ((issecrettable and issecrettable(value)) or (canaccesstable and not canaccesstable(value)))
end

local function hasSecrets(a1, a2, a3, a4, a5, a6, a7, a8)
    if hasanysecretvalues then
        return hasanysecretvalues(a1, a2, a3, a4, a5, a6, a7, a8)
    end
    return isSecret(a1) or isSecret(a2) or isSecret(a3) or isSecret(a4)
        or isSecret(a5) or isSecret(a6) or isSecret(a7) or isSecret(a8)
end

local function scrubOne(value)
    if isSecret(value) or isBlockedTable(value) then
        return nil
    end
    return value
end

local function scrub(a1, a2, a3, a4, a5, a6, a7, a8)
    if scrubsecretvalues then
        return scrubsecretvalues(a1, a2, a3, a4, a5, a6, a7, a8)
    end
    return scrubOne(a1), scrubOne(a2), scrubOne(a3), scrubOne(a4),
        scrubOne(a5), scrubOne(a6), scrubOne(a7), scrubOne(a8)
end

local function fail(err)
    return { ok = false, err = err, secret = false }
end

-- True when value is safe for Lua logic (compare, format, math, #).
function Guard.usable(value)
    if value == nil then
        return true
    end
    if isBlockedTable(value) then
        return false
    end
    if isSecret(value) and canaccessvalue and not canaccessvalue(value) then
        return false
    end
    return not isSecret(value)
end

-- Scrub known values without calling an API.
function Guard.scrub(a1, a2, a3, a4, a5, a6, a7, a8)
    return scrub(a1, a2, a3, a4, a5, a6, a7, a8)
end

-- Primary entry: call any WoW API, catch errors, scrub secrets for Lua-safe reads.
-- Result: { ok, err?, secret, [1]..[8] } — scrubbed returns in [1], [2], ...
function Guard.call(fn, ...)
    if type(fn) ~= "function" then
        return fail("Guard.call requires a function")
    end

    local argc = select("#", ...)
    local args = { ... }

    local function invoke()
        if argc == 0 then
            return fn()
        end
        return fn(unpack(args, 1, argc))
    end

    local ok, r1, r2, r3, r4, r5, r6, r7, r8 = pcall(invoke)
    if not ok then
        return fail(r1)
    end

    local result = {
        ok = true,
        secret = hasSecrets(r1, r2, r3, r4, r5, r6, r7, r8),
    }

    r1, r2, r3, r4, r5, r6, r7, r8 = scrub(r1, r2, r3, r4, r5, r6, r7, r8)
    result[1], result[2], result[3], result[4] = r1, r2, r3, r4
    result[5], result[6], result[7], result[8] = r5, r6, r7, r8

    return result
end

-- Raw API read — no scrub. Use only to pass returns directly to secret-aware widgets.
function Guard.pass(fn, ...)
    if type(fn) ~= "function" then
        return false, "Guard.pass requires a function"
    end

    local argc = select("#", ...)
    local args = { ... }

    if argc == 0 then
        return pcall(fn)
    end
    return pcall(fn, unpack(args, 1, argc))
end

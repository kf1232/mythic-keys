Key.Util = Key.Util or {}

local ChallengeMode = {}
Key.Util.ChallengeMode = ChallengeMode

local Guard = Key.Guard

function ChallengeMode.GetMapTable()
    if not C_ChallengeMode or not C_ChallengeMode.GetMapTable then
        return {}
    end
    return C_ChallengeMode.GetMapTable()
end

function ChallengeMode.GetMapUIInfo(mapChallengeModeID)
    if not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return nil
    end

    local result = Guard.call(C_ChallengeMode.GetMapUIInfo, mapChallengeModeID)
    if not result.ok or not result[1] then
        return nil
    end

    return {
        name = result[1],
        id = result[2] or mapChallengeModeID,
        timeLimit = result[3],
        texture = result[4],
        backgroundTexture = result[5],
        mapID = result[6],
    }
end

function ChallengeMode.GetMapsByName()
    local byName = {}
    for _, mapChallengeModeID in ipairs(ChallengeMode.GetMapTable()) do
        local info = ChallengeMode.GetMapUIInfo(mapChallengeModeID)
        if info and info.name then
            byName[info.name] = info
        end
    end
    return byName
end

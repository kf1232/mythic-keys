Key = Key or {}

Key.refreshDebounce = 0.1

local refreshTimer
local pendingRefreshCtx

local function MergeRefreshContext(existing, incoming)
    existing = existing or {}
    incoming = incoming or {}
    return {
        ifShown = existing.ifShown or incoming.ifShown,
        readyOnly = existing.readyOnly == true and incoming.readyOnly == true,
        immediate = incoming.immediate or existing.immediate,
    }
end

local function RunRefreshUI(ctx)
    if not Key.PartyUI then
        return
    end
    if ctx.ifShown and not Key.PartyUI:IsShown() then
        return
    end

    local function Refresh()
        if ctx.readyOnly then
            if Key.PartyUI.RefreshReadyOnly then
                Key.PartyUI:RefreshReadyOnly()
            end
            return
        end
        Key.PartyUI:Refresh()
    end

    if Key.Log and Key.Log.RunProtected then
        Key.Log:RunProtected("RefreshUI", Refresh)
    else
        Refresh()
    end
end

local function CancelRefreshSchedule()
    if refreshTimer then
        refreshTimer:Cancel()
        refreshTimer = nil
    end
end

Key.RegisterTrigger("REFRESH_UI", function(ctx)
    if ctx.immediate then
        CancelRefreshSchedule()
        if pendingRefreshCtx then
            ctx = MergeRefreshContext(pendingRefreshCtx, ctx)
            pendingRefreshCtx = nil
        end
        RunRefreshUI(ctx)
        return
    end

    pendingRefreshCtx = MergeRefreshContext(pendingRefreshCtx, ctx)
    CancelRefreshSchedule()
    refreshTimer = Key.Api.Timer:NewTimer(false, Key.refreshDebounce, function())
        refreshTimer = nil
        local pending = pendingRefreshCtx
        pendingRefreshCtx = nil
        RunRefreshUI(pending or {})
    end)
end)

local REFRESH_TRIGGER_POLICIES = {
    GROUP_LEFT = { ifShown = true },
    PLAYER_ENTERING_WORLD = { ifShown = true },
    KEYSTONE_DATA_CHANGED = { ifShown = true },
    PARTY_CHANGED = function(ctx)
        return { ifShown = true, immediate = ctx and ctx.immediate }
    end,
    UI_PANEL_OPEN = { immediate = true },
    UI_REFRESH_CLICK = { immediate = true },
    UI_ZONE_TARGET_SET = { ifShown = true, immediate = true },
    UI_ZONE_CHANGED = { ifShown = true, readyOnly = true },
    UI_RESIZE = {},
}

local function ResolveRefreshContext(policy, ctx)
    if type(policy) == "function" then
        return policy(ctx)
    end
    return policy
end

for trigger, policy in pairs(REFRESH_TRIGGER_POLICIES) do
    Key.RegisterTrigger(trigger, function(ctx)
        Key.Dispatch("REFRESH_UI", ResolveRefreshContext(policy, ctx))
    end)
end

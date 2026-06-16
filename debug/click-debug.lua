local ADDON_NAME = ...

Key.Debug.Click = Key.Debug.Click or {}
local ClickDebug = Key.Debug.Click

ClickDebug.enabled = ClickDebug.enabled or false
ClickDebug.attached = ClickDebug.attached or {}

function ClickDebug:IsEnabled()
    return self.enabled and true or false
end

function ClickDebug:Log(message, label)
    if not self.enabled or not Key.Log or not Key.Log.WriteEvent then
        return
    end

    Key.Log:WriteEvent(Key.Log.FEATURE.CLICK_DEBUG, Key.Log.STATUS.DEBUG, message, {
        source = label or "Log",
        dedupeKey = "click:" .. (label or message),
        dedupeWindow = 0.05,
    })
end

function ClickDebug:LogAction(label, detail)
    if not self.enabled then
        return
    end

    self:Log(
        string.format("[click] %s — action (%s)", label, tostring(detail or "?")),
        label
    )
end

function ClickDebug:GetScriptSafe(frame, scriptType)
    if not frame or not frame.GetScript then
        return nil
    end

    local ok, script = pcall(frame.GetScript, frame, scriptType)
    if ok then
        return script
    end

    return nil
end

function ClickDebug:SupportsOnClick(frame)
    return frame and frame.RegisterForClicks ~= nil
end

function ClickDebug:CanSetPropagateMouse(frame)
    if not frame or InCombatLockdown() then
        return false
    end

    if frame.IsProtected and frame:IsProtected() then
        return false
    end

    -- Teleport shells sit above spell action buttons; WoW blocks propagation changes there.
    if frame.action or frame.slots then
        return false
    end

    return frame.SetPropagateMouseClicks ~= nil and frame.SetPropagateMouseMotion ~= nil
end

function ClickDebug:GetPropagateMouseSafe(frame)
    if not frame then
        return nil, nil
    end

    local clicks, motion
    if frame.GetPropagateMouseClicks then
        local ok, value = pcall(frame.GetPropagateMouseClicks, frame)
        if ok then
            clicks = value
        end
    end
    if frame.GetPropagateMouseMotion then
        local ok, value = pcall(frame.GetPropagateMouseMotion, frame)
        if ok then
            motion = value
        end
    end

    return clicks, motion
end

function ClickDebug:SetPropagateMouseSafe(frame, clicks, motion)
    if not self:CanSetPropagateMouse(frame) then
        return false
    end

    local ok = true
    if clicks ~= nil then
        ok = pcall(frame.SetPropagateMouseClicks, frame, clicks) and ok
    end
    if motion ~= nil then
        ok = pcall(frame.SetPropagateMouseMotion, frame, motion) and ok
    end

    return ok
end

function ClickDebug:RestoreFrame(frame)
    local state = self.attached[frame]
    if not state then
        return
    end

    frame:SetScript("OnMouseDown", state.onMouseDown)
    frame:SetScript("OnMouseUp", state.onMouseUp)
    if state.wrappedOnClick then
        frame:SetScript("OnClick", state.onClick)
    end

    if state.propagateClicks ~= nil or state.propagateMotion ~= nil then
        self:SetPropagateMouseSafe(frame, state.propagateClicks, state.propagateMotion)
    end
    if state.mouseEnabled ~= nil then
        frame:EnableMouse(state.mouseEnabled)
    end

    self.attached[frame] = nil
end

function ClickDebug:DetachAll()
    for frame in pairs(self.attached) do
        self:RestoreFrame(frame)
    end
end

-- Only hooks mouse/click scripts. Never attach to InsecureActionButtonTemplate frames.
function ClickDebug:Attach(frame, label, options)
    if not frame or not label then
        return
    end

    options = options or {}

    if self.attached[frame] then
        self:RestoreFrame(frame)
    end

    local mouseEnabled = frame.IsMouseEnabled and frame:IsMouseEnabled()
    local propagateClicks, propagateMotion = self:GetPropagateMouseSafe(frame)

    local supportsOnClick = self:SupportsOnClick(frame)

    local wrappedOnClick = supportsOnClick and not options.skipOnClick

    local state = {
        onMouseDown = self:GetScriptSafe(frame, "OnMouseDown"),
        onMouseUp = self:GetScriptSafe(frame, "OnMouseUp"),
        onClick = wrappedOnClick and self:GetScriptSafe(frame, "OnClick") or nil,
        wrappedOnClick = wrappedOnClick,
        mouseEnabled = mouseEnabled,
        propagateClicks = propagateClicks,
        propagateMotion = propagateMotion,
    }
    self.attached[frame] = state

    if options.passThrough and not options.skipPropagate then
        -- Keep original mouse state; only propagate so clicks reach secure children.
        self:SetPropagateMouseSafe(frame, true, true)
    elseif options.forceMouse then
        frame:EnableMouse(true)
    end

    frame:SetScript("OnMouseDown", function(self, button)
        ClickDebug:Log(string.format("[click] %s — mouse down (%s)", label, button or "?"), label)
        if state.onMouseDown then
            state.onMouseDown(self, button)
        end
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        ClickDebug:Log(string.format("[click] %s — mouse up (%s)", label, button or "?"), label)
        if state.onMouseUp then
            state.onMouseUp(self, button)
        end
    end)

    if supportsOnClick and not options.skipOnClick then
        frame:SetScript("OnClick", function(self, button)
            ClickDebug:Log(string.format("[click] %s — click (%s)", label, button or "?"), label)
            if state.onClick then
                state.onClick(self, button)
            end
        end)
    end
end

function ClickDebug:WireTeleportSlots()
    if not Key.Teleports or not Key.Teleports.bar then
        return
    end

    local Teleports = Key.Teleports
    -- Mouse layers already configured in Teleports:ConfigureSlotMouseLayers; skip SetPropagate here.
    local teleportOpts = { passThrough = true, skipPropagate = true }
    self:Attach(Teleports.bar, "teleport.bar", teleportOpts)

    for index, slot in ipairs(Teleports.bar.slots or {}) do
        local prefix = "teleport.slot" .. index
        self:Attach(slot, prefix .. ".shell", teleportOpts)

        if slot.labelBar then
            self:Attach(slot.labelBar, prefix .. ".labelBar", teleportOpts)
        end
        if slot.tokenContainer then
            self:Attach(slot.tokenContainer, prefix .. ".tokens", teleportOpts)
        end
        if slot.leaderOutline then
            self:Attach(slot.leaderOutline, prefix .. ".leaderOutline", teleportOpts)
        end
        -- Never hook secure action buttons — replacing mouse/click scripts breaks spell casts.
    end
end

function ClickDebug:WireBestTable()
    if not Key.PartyComplete or not Key.PartyComplete.bestTable then
        return
    end

    local tableFrame = Key.PartyComplete.bestTable
    self:Attach(tableFrame, "bestTable.root", { passThrough = true })

    for rowIndex, row in ipairs(tableFrame.rows or {}) do
        if row.name and row.name:IsShown() then
            self:Attach(row.name, "bestTable.row" .. rowIndex .. ".name")
        end
        for colIndex = 1, (Key.PartyComplete.SLOT_COUNT or 8) do
            local cell = row[colIndex]
            if cell and cell:IsShown() then
                self:Attach(cell, string.format("bestTable.row%d.col%d", rowIndex, colIndex))
            end
        end
    end
end

function ClickDebug:WirePartyUI()
    if not Key.PartyUI or not Key.PartyUI.frame then
        return
    end

    local frame = Key.PartyUI.frame
    self:Attach(frame, "party.frame", { forceMouse = true })

    if frame.titleBar then
        self:Attach(frame.titleBar, "party.titleBar")
    end
    if frame.closeButton then
        self:Attach(frame.closeButton, "party.closeButton")
    end
    if frame.refreshButton then
        self:Attach(frame.refreshButton, "party.refreshButton")
    end

    local completions = frame.completionsPane
    if completions then
        self:Attach(completions, "party.completionsPane", { passThrough = true })

        if completions.teleportBar then
            self:Attach(completions.teleportBar, "party.teleportBar", { passThrough = true, skipPropagate = true })
        end
        if completions.scrollFrame then
            self:Attach(completions.scrollFrame, "party.scrollFrame", { forceMouse = true })
        end
        if completions.scrollChild then
            self:Attach(completions.scrollChild, "party.scrollChild", { passThrough = true })
        end
    end

    if frame.readyPane then
        self:Attach(frame.readyPane, "party.readyPane", { passThrough = true })
        if frame.readyPane.readyTable then
            self:Attach(frame.readyPane.readyTable, "party.readyTable", { passThrough = true })
        end
    end

    if frame.tabBar then
        self:Attach(frame.tabBar, "party.tabBar", { passThrough = true })
    end
    if frame.tabs then
        for tabId, button in pairs(frame.tabs) do
            self:Attach(button, "party.tab." .. tostring(tabId))
        end
    end
end

function ClickDebug:ScheduleRewireAfterCombat()
    if self.rewirePending then
        return
    end

    self.rewirePending = true
    local regenFrame = self.regenFrame
    if not regenFrame then
        regenFrame = CreateFrame("Frame")
        self.regenFrame = regenFrame
        regenFrame:SetScript("OnEvent", function(frame)
            frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            ClickDebug.rewirePending = false
            if ClickDebug.enabled then
                ClickDebug:RewireAll()
            end
        end)
    end

    regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ClickDebug:RewireAll()
    if not self.enabled then
        return
    end

    if InCombatLockdown() then
        self:ScheduleRewireAfterCombat()
        return
    end

    self.rewirePending = false
    self:DetachAll()
    self:WirePartyUI()
    self:WireTeleportSlots()
    self:WireBestTable()
    self:Log("Click debug rewired — click UI layers to trace hit order (top → bottom).")
end

function ClickDebug:Enable()
    if self.enabled then
        self:RewireAll()
        return true
    end

    self.enabled = true
    self:Log("Click debug ON — open /keyf debug to watch hit order.")
    self:RewireAll()
    return true
end

function ClickDebug:Disable()
    if not self.enabled then
        return false
    end

    self.enabled = false
    self:DetachAll()
    self:Log("Click debug OFF")
    return true
end

function ClickDebug:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
    return self.enabled
end

local ADDON_NAME = ...

Key = Key or {}

Key.DEFAULT_ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\media\\icon"
Key.GCD_SPELL_ID = 61304

local function PrintMessage(text)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

Key.RegisterTrigger("ADDON_LOADED", function()
    if not Key.PartyUI or not Key.PartyUI.TogglePanel then
        PrintMessage("|cffFF0000Key:|r PartyUI failed to load. Enable /console scriptErrors 1 and /reload.")
    else
        PrintMessage("|cff55FF55Key|r loaded. |cffFFFFFF/keyf|r party list, |cffFFFFFF/keyf debug|r console.")
    end
end)

local function RunSlashCommand(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "debug" then
        if Key.Debug.UI and Key.Debug.UI.ShowConsole then
            Key.Debug.UI:ShowConsole()
        else
            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")
        end
        return
    end

    if msg == "clear" then
        if Key.Debug.UI and Key.Debug.UI.ClearLog then
            Key.Debug.UI:ClearLog()
            PrintMessage("|cff55FF55Key:|r debug log cleared.")
        else
            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")
        end
        return
    end

    if msg == "dump" then
        if Key.Debug.UI and Key.Debug.UI.DumpData then
            Key.Debug.UI:DumpData()
            PrintMessage("|cff55FF55Key:|r addon data dumped to debug log.")
        else
            PrintMessage("|cffFF8800Key:|r debug UI not loaded.")
        end
        return
    end

    if msg == "clickdebug" or msg == "click" then
        if Key.Debug.Click and Key.Debug.Click.Toggle then
            local on = Key.Debug.Click:Toggle()
            PrintMessage(on
                and "|cff55FF55Key:|r click debug ON — use /keyf debug and click teleport icons."
                or "|cff55FF55Key:|r click debug OFF.")
            if on and Key.PartyUI and Key.PartyUI.frame and Key.PartyUI.frame:IsShown() then
                Key.Debug.Click:RewireAll()
            end
        else
            PrintMessage("|cffFF8800Key:|r click debug not loaded.")
        end
        return
    end

    if msg ~= "" then
        return
    end

    if Key.PartyUI and Key.PartyUI.TogglePanel then
        Key.PartyUI:TogglePanel()
    else
        PrintMessage("|cffFF8800Key:|r party UI not loaded.")
    end
end

SLASH_KEYF1 = "/keyf"
SlashCmdList["KEYF"] = function(msg)
    local ok, err = pcall(RunSlashCommand, msg)
    if not ok then
        PrintMessage("|cffFF0000Key error:|r " .. tostring(err))
    end
end

local KEYSTONE_DATA_EVENTS = {}

local function SafeRegisterEvent(frame, event)
    if not frame or not frame.RegisterEvent then
        return false
    end
    return pcall(frame.RegisterEvent, frame, event)
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "GROUP_JOINED",
    "GROUP_LEFT",
    "GROUP_ROSTER_UPDATE",
}) do
    SafeRegisterEvent(eventFrame, event)
end

for _, event in ipairs({
    "CHALLENGE_MODE_MAPS_UPDATE",
    "MYTHIC_PLUS_NEW_SEASON_RECORD",
    "BAG_UPDATE_DELAYED",
}) do
    if SafeRegisterEvent(eventFrame, event) then
        KEYSTONE_DATA_EVENTS[event] = true
    end
end
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then
        return
    end

    local function HandleEvent()
        if KEYSTONE_DATA_EVENTS[event] then
            Key.Dispatch("KEYSTONE_DATA_CHANGED")
            return
        end

        if event == "ADDON_LOADED" then
            Key.Dispatch("ADDON_LOADED")
            return
        end

        if event == "GROUP_JOINED" or event == "GROUP_ROSTER_UPDATE" then
            Key.Dispatch("GROUP_CHANGED")
            return
        end
        Key.Dispatch(event)
    end

    if Key.Log and Key.Log.RunProtected then
        Key.Log:RunProtected("Core:" .. tostring(event), HandleEvent)
    else
        HandleEvent()
    end
end)

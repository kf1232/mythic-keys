Key.Views = Key.Views or {}

local Frame = {}
Key.Views.Frame = Frame

local Escape = Key.Util.Escape

local MAIN_STRATA = "DIALOG"
local MAIN_LEVEL = 200
local NOTE_LEVEL = 300

local ESCAPE_ORDER = {
    "KeyPlayerNoteAddFrame",
    "KeyPlayerNotesFrame",
    "KeyKeysHistoryFrame",
    "KeyTargetFrame",
    "KeyGroupFrame",
    "KeyDebugFrame",
}

function Frame.Configure(frame, level)
    frame:SetFrameStrata(MAIN_STRATA)
    frame:SetFrameLevel(level or MAIN_LEVEL)
    frame:SetToplevel(true)
end

function Frame.RegisterMain(frame)
    Frame.Configure(frame, MAIN_LEVEL)
end

function Frame.RegisterNote(frame)
    Frame.Configure(frame, NOTE_LEVEL)
end

function Frame.ShowMain(frame)
    Frame.Configure(frame, MAIN_LEVEL)
    frame:Show()
    frame:Raise()
end

function Frame.ShowNote(frame)
    Frame.Configure(frame, NOTE_LEVEL)
    frame:Show()
    frame:Raise()
end

function Frame.CloseTopmost()
    for i = 1, #ESCAPE_ORDER do
        local named = _G[ESCAPE_ORDER[i]]
        if named and named:IsShown() then
            named:Hide()
            return true
        end
    end
    return false
end

Escape.InstallLayeredClose(ESCAPE_ORDER, Frame.CloseTopmost)

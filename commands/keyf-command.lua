local addonName, Key = ...

local CAPTURE_SECONDS = 2

local originals = {}
local sink
local expireAt
local ticker

local function hookedFrames()
	local seen = {}
	local frames = {}
	local function add(frame)
		if frame and not seen[frame] then
			seen[frame] = true
			frames[#frames + 1] = frame
		end
	end
	add(DEFAULT_CHAT_FRAME)
	add(SELECTED_CHAT_FRAME)
	return frames
end

local function restoreChat()
	for frame, original in pairs(originals) do
		frame.AddMessage = original
	end
	wipe(originals)
	sink = nil
	expireAt = nil
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function captureMessage(msg, r, g, b)
	if sink and msg then
		sink(msg, r, g, b)
		expireAt = GetTime() + CAPTURE_SECONDS
	end
end

local function hookChat()
	if next(originals) then
		return
	end
	for _, frame in ipairs(hookedFrames()) do
		originals[frame] = frame.AddMessage
		frame.AddMessage = function(self, msg, r, g, b, ...)
			captureMessage(msg, r, g, b)
			return originals[frame](self, msg, r, g, b, ...)
		end
	end
end

local function startCapture(onMessage)
	sink = onMessage
	hookChat()
	expireAt = GetTime() + CAPTURE_SECONDS
	if ticker then
		return
	end
	ticker = C_Timer.NewTicker(0.25, function()
		if not expireAt or GetTime() >= expireAt then
			restoreChat()
		end
	end)
end

function Key.RunChatCommand(text, onMessage)
	text = strtrim(text or "")
	if text == "" then
		return
	end
	if not text:find("^/") then
		text = "/" .. text
	end

	startCapture(onMessage)

	local script = text:match("^/[Rr][Uu][Nn]%s+(.*)") or text:match("^/[Ss][Cc][Rr][Ii][Pp][Tt]%s+(.*)")
	if script then
		pcall(RunScript, script)
		return
	end

	local editBox = ChatEdit_ChooseBoxForSend() or ChatFrame1EditBox
	local previousMax = editBox:GetMaxLetters()
	editBox:SetMaxLetters(0)
	editBox:SetText(text)
	ChatEdit_ParseText(editBox, 1)
	editBox:SetMaxLetters(previousMax)
end

local commandMenu = CreateFrame("Frame", "KeyfCommandMenu", UIParent, "BasicFrameTemplateWithInset")
commandMenu:SetSize(480, 480)
commandMenu:SetPoint("CENTER", 240, 0)
commandMenu:SetFrameStrata("HIGH")
commandMenu:SetMovable(true)
commandMenu:EnableMouse(true)
commandMenu:RegisterForDrag("LeftButton")
commandMenu:SetScript("OnDragStart", commandMenu.StartMoving)
commandMenu:SetScript("OnDragStop", commandMenu.StopMovingOrSizing)
commandMenu:Hide()
tinsert(UISpecialFrames, "KeyfCommandMenu")

local title = C_AddOns.GetAddOnMetadata(addonName, "Title") or "Mythic Keys"
commandMenu.TitleText:SetText(title .. " Command")

local run = CreateFrame("Button", nil, commandMenu, "UIPanelButtonTemplate")
run:SetSize(60, 22)
run:SetPoint("TOPRIGHT", -16, -32)
run:SetText("Run")

local copy = CreateFrame("Button", nil, commandMenu, "UIPanelButtonTemplate")
copy:SetSize(60, 22)
copy:SetPoint("RIGHT", run, "LEFT", -6, 0)
copy:SetText("Copy")

local inputBox = CreateFrame("Frame", nil, commandMenu, "BackdropTemplate")
inputBox:SetPoint("TOPLEFT", 14, -58)
inputBox:SetPoint("TOPRIGHT", -14, -58)
inputBox:SetHeight(88)
inputBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
inputBox:SetBackdropColor(0, 0, 0, 0.8)

local inputScroll = CreateFrame("ScrollFrame", nil, inputBox, "UIPanelScrollFrameTemplate")
inputScroll:SetPoint("TOPLEFT", 8, -8)
inputScroll:SetPoint("BOTTOMRIGHT", -28, 8)

local input = CreateFrame("EditBox", "KeyfCommandInput", inputScroll)
input:SetMultiLine(true)
input:SetAutoFocus(false)
input:SetFontObject(ChatFontNormal)
input:SetJustifyH("LEFT")
input:SetMaxLetters(0)
input:SetTextInsets(0, 0, 0, 0)
inputScroll:SetScrollChild(input)

local function layoutInput()
	local width = inputScroll:GetWidth()
	if width < 1 then
		width = 400
	end
	input:SetWidth(width)
	local fontHeight = select(2, input:GetFont()) or 14
	local text = input:GetText() or ""
	local lines = 1
	for _ in text:gmatch("\n") do
		lines = lines + 1
	end
	lines = math.max(lines, math.ceil(#text / math.max(math.floor(width / 7), 1)))
	input:SetHeight(math.max(inputScroll:GetHeight(), lines * (fontHeight + 2)))
end

inputScroll:SetScript("OnSizeChanged", layoutInput)
input:SetScript("OnTextChanged", layoutInput)
input:SetScript("OnCursorChanged", function(self, _, y, _, lineHeight)
	local offset = inputScroll:GetVerticalScroll()
	local height = inputScroll:GetHeight()
	if -y < offset then
		inputScroll:SetVerticalScroll(-y)
	elseif (-y - lineHeight) > (offset + height - lineHeight) then
		inputScroll:SetVerticalScroll(-y - lineHeight + height)
	end
end)

local outputBox = CreateFrame("Frame", nil, commandMenu, "BackdropTemplate")
outputBox:SetPoint("TOPLEFT", inputBox, "BOTTOMLEFT", 0, -8)
outputBox:SetPoint("BOTTOMRIGHT", -14, 14)
outputBox:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
outputBox:SetBackdropColor(0, 0, 0, 0.8)

local scroll = CreateFrame("ScrollFrame", nil, outputBox, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 8, -8)
scroll:SetPoint("BOTTOMRIGHT", -28, 8)

local output = CreateFrame("EditBox", "KeyfCommandOutput", scroll)
output:SetMultiLine(true)
output:SetAutoFocus(false)
output:SetFontObject(ChatFontNormal)
output:SetJustifyH("LEFT")
output:SetMaxLetters(0)
output:SetTextInsets(0, 0, 0, 0)
scroll:SetScrollChild(output)

local log = ""

local measure = outputBox:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
measure:Hide()
measure:SetJustifyH("LEFT")
measure:SetWordWrap(true)

local function stripMarkup(msg)
	msg = tostring(msg)
	msg = msg:gsub("|c%x%x%x%x%x%x%x%x", "")
	msg = msg:gsub("|cn[^:]+:", "")
	msg = msg:gsub("|r", "")
	msg = msg:gsub("|H.-|h(.-)|h", "%1")
	msg = msg:gsub("|T.-|t", "")
	msg = msg:gsub("|A.-|a", "")
	return msg
end

local function contentHeight()
	local width = scroll:GetWidth()
	if width < 1 then
		width = 300
	end
	measure:SetWidth(width)
	measure:SetText(log ~= "" and log or " ")
	local height = measure:GetStringHeight()
	if not height or height < 1 then
		local fontHeight = select(2, output:GetFont()) or 14
		local lines = 1
		for _ in log:gmatch("\n") do
			lines = lines + 1
		end
		height = lines * (fontHeight + 2)
	end
	return math.max(scroll:GetHeight(), height + 8)
end

local function layoutOutput()
	output:SetWidth(scroll:GetWidth())
	output:SetHeight(contentHeight())
end

local function refreshOutput()
	output:SetText(log)
	layoutOutput()
	scroll:UpdateScrollChildRect()
	scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
end

scroll:SetScript("OnSizeChanged", layoutOutput)

output:SetScript("OnTextChanged", function(self, userInput)
	if userInput then
		self:SetText(log)
	end
	layoutOutput()
end)

output:SetScript("OnEscapePressed", function(self)
	self:HighlightText(0, 0)
	self:ClearFocus()
end)

output:SetScript("OnCursorChanged", function(self, _, y, _, lineHeight)
	local offset = scroll:GetVerticalScroll()
	local height = scroll:GetHeight()
	if -y < offset then
		scroll:SetVerticalScroll(-y)
	elseif (-y - lineHeight) > (offset + height - lineHeight) then
		scroll:SetVerticalScroll(-y - lineHeight + height)
	end
end)

copy:SetScript("OnClick", function()
	output:SetFocus()
	output:HighlightText()
end)

local function appendOutput(msg)
	msg = stripMarkup(msg)
	if log == "" then
		log = msg
	else
		log = log .. "\n" .. msg
	end
	refreshOutput()
end

local function runInput()
	local text = strtrim(input:GetText() or "")
	if text == "" then
		return
	end
	if not text:find("^/") then
		text = "/" .. text
	end
	appendOutput("|cff888888> " .. text .. "|r")
	Key.RunChatCommand(text, appendOutput)
	input:ClearFocus()
end

input:SetScript("OnEnterPressed", runInput)
input:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)
run:SetScript("OnClick", runInput)

function Key.ShowCommandWindow(command)
	commandMenu:Show()
	command = strtrim(command or "")
	if command ~= "" then
		input:SetText(command)
		runInput()
		return
	end
	input:SetFocus()
end

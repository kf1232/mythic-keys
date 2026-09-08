local _, Key = ...

local DEBOUNCE_SECONDS = 0.25

Key.group = {
	type = "solo",
	home = false,
	instance = false,
	members = {},
}

function Key.GetGroupType()
	if not IsInGroup() then
		return "solo"
	end
	if IsInRaid() then
		return "raid"
	end
	return "party"
end

function Key.IsGrouped()
	return IsInGroup()
end

function Key.FullPlayerName(unit)
	local name, realm = UnitFullName(unit)
	if not name then
		return nil
	end
	if not realm or realm == "" then
		realm = GetNormalizedRealmName()
	end
	if not realm or realm == "" then
		return name
	end
	return name .. "-" .. realm
end

local function addMember(members, unit)
	if not UnitExists(unit) then
		return
	end
	local className, classFile = UnitClass(unit)
	local fullName = Key.FullPlayerName(unit)
	local playerName = fullName and fullName:match("^([^-]+)") or fullName
	members[#members + 1] = {
		unit = unit,
		guid = UnitGUID(unit),
		name = fullName,
		playerName = playerName,
		class = className,
		classFile = classFile,
		role = UnitGroupRolesAssigned(unit),
	}
end

function Key.RefreshGroup()
	local members = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			addMember(members, "raid" .. i)
		end
	else
		addMember(members, "player")
		if IsInGroup() then
			for i = 1, 4 do
				addMember(members, "party" .. i)
			end
		end
	end

	Key.group.type = Key.GetGroupType()
	Key.group.home = IsInGroup(LE_PARTY_CATEGORY_HOME)
	Key.group.instance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
	Key.group.members = members

	if Key.RefreshMythicPlus then
		Key.RefreshMythicPlus(true)
	elseif Key.UpdateWindow then
		Key.UpdateWindow()
	end

	if Key.RecordGroupHistory then
		Key.RecordGroupHistory()
	end
end

function Key.PrintGroup()
	Key.RefreshGroup()
	print(Key.group.type, "members=" .. #Key.group.members, "home=" .. tostring(Key.group.home), "instance=" .. tostring(Key.group.instance))
	for _, member in ipairs(Key.group.members) do
		print(member.name, member.class, member.role)
	end
end

local pending

local function scheduleRefresh()
	if pending then
		return
	end
	pending = C_Timer.NewTimer(DEBOUNCE_SECONDS, function()
		pending = nil
		Key.RefreshGroup()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", scheduleRefresh)

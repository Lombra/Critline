local addon = Critline

local NUM_BUTTONS = 8
local BUTTON_HEIGHT = 32

local band = bit.band
local CombatLog_Object_IsA = CombatLog_Object_IsA
local IsSpellKnown = IsSpellKnown
local UnitAura = UnitAura
local UnitName = UnitName
local UnitGUID = UnitGUID
local IsInInstance = IsInInstance

local COMBATLOG_FILTER_ME = COMBATLOG_FILTER_ME
local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY

local session = {}
local instance = {}
local lastFight = {}

-- name of current instance
local currentInstance = "n/a"

local frame = CreateFrame("Frame", nil, UIParent)
frame:SetFrameStrata("DIALOG")
frame:EnableMouse(true)
frame:SetSize(440, 88 + NUM_BUTTONS * BUTTON_HEIGHT)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetScript("OnHide", frame.StopMovingOrSizing)

frame:SetBackdrop({
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 14,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
})
frame:SetBackdropColor(0, 0, 0)
frame:SetBackdropBorderColor(0.5, 0.5, 0.5)
frame:Hide()

frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT")

addon.SlashCmdHandlers["aura"] = function() frame:Show() end

local currentFilter = session

local function auraSort(a, b)
	local nameA, nameB = currentFilter[a].spellName, currentFilter[b].spellName
	if nameA == nameB then
		return a < b
	else
		return nameA < nameB
	end
end

local function sourceSort(a, b)
	local spellA, spellB = currentFilter[a], currentFilter[b]
	if spellA.source == spellB.source then
		return auraSort(a, b)
	else
		return spellA.source < spellB.source
	end
end

local function targetSort(a, b)
	local spellA, spellB = currentFilter[a], currentFilter[b]
	if spellA.target == spellB.target then
		return auraSort(a, b)
	else
		return spellA.target < spellB.target
	end
end

local sortMethod = auraSort

local filters = {
	-- self = true,
	-- hostile = true,
	-- npc = true,
	-- pvp = true,
	-- BUFF = true,
	-- DEBUFF = true,
}

local function onClick(self)
	local menu = self.menu
	menu.displayMode = "MENU"
	ToggleDropDownMenu(nil, nil, menu, self, 0, 0)
	menu.displayMode = nil
	PlaySound("igMainMenuOptionCheckBoxOn")
end

local function createMenuButton(name)
	local menu = CreateFrame("Frame")
	
	local button = CreateFrame("Button", name, frame, "UIMenuButtonStretchTemplate")
	button:SetScript("OnClick", onClick)
	button.rightArrow:Show()
	button.menu = menu
	return button
end

local scopeFilter = createMenuButton("CritlineAuraTrackerScope")
scopeFilter:SetPoint("TOPLEFT", 16, -16)
scopeFilter:SetWidth(192)
scopeFilter:SetText("Current session")

do
	local function onClick(self, scope, text)
		scopeFilter:SetFormattedText(text, currentInstance)
		currentFilter = scope
		frame:Update()
	end

	local menuList = {
		{
			text = "Current fight",
			value = lastFight,
		},
		{
			text = "Current instance (%s)",
			value = instance,
		},
		{
			text = "Current session",
			value = session,
		},
	}

	scopeFilter.menu.initialize = function(self)
		for i, v in ipairs(menuList) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = format(v.text, currentInstance)
			info.checked = currentFilter == v.value
			info.func = onClick
			info.arg1 = v.value
			info.arg2 = v.text
			info.owner = self
			UIDropDownMenu_AddButton(info)
		end
	end
end

local sortMethodMenu = createMenuButton("CritlineAuraTrackerAuraType")
sortMethodMenu:SetWidth(96)
sortMethodMenu:SetPoint("LEFT", scopeFilter, "RIGHT", 8, 0)
sortMethodMenu:SetText("Sort by")

do
	local function onClick(self, func)
		sortMethod = func
		frame:Update()
	end

	local menuList = {
		{
			text = "Sort by aura name",
			value = auraSort,
		},
		{
			text = "Sort by source name",
			value = sourceSort,
		},
		{
			text = "Sort by target name",
			value = targetSort,
		},
	}
	
	sortMethodMenu.menu.initialize = function(self)
		for i, v in ipairs(menuList) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = v.text
			info.func = onClick
			info.arg1 = v.value
			info.checked = sortMethod == v.value
			UIDropDownMenu_AddButton(info)
		end
	end
end

local filterOptions = createMenuButton("CritlineAuraTrackerFilterOptions")
filterOptions:SetWidth(96)
filterOptions:SetPoint("TOP", sortMethodMenu, "BOTTOM", 0, -4)
filterOptions:SetText(FILTERS)

do
	local function onClick(self, key, arg2, checked)
		filters[key] = not checked
		frame:Update()
	end
	
	local menu = {
		BUFF = "Buffs",
		DEBUFF = "Debuffs",
		self = "Cast on me",
		hostile = "Cast on hostile NPCs",
		npc = "Cast by NPCs",
		pvp = "Cast by players",
	}

	local menuValues = {
		"self",
		"hostile",
		"npc",
		"pvp",
		"BUFF",
		"DEBUFF",
	}
	
	filterOptions.menu.initialize = function(self)
		for i, v in ipairs(menuValues) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = menu[v]
			info.func = onClick
			info.arg1 = v
			info.checked = not filters[v]
			info.isNotRadio = true
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton(info)
		end
	end
end

local search = CreateFrame("EditBox", "CritlineAuraTrackerTextFilter", frame, "SearchBoxTemplate")
search:SetHeight(20)
search:SetPoint("TOPLEFT", scopeFilter, "BOTTOMLEFT", 8, -5)
search:SetPoint("TOPRIGHT", scopeFilter, "BOTTOMRIGHT", 0, -5)
search:SetFontObject("ChatFontSmall")
search:SetTextColor(0.5, 0.5, 0.5)
search:SetScript("OnTextChanged", function() frame:Update() end)
search:SetScript("OnEscapePressed", search.ClearFocus)
search:SetScript("OnEnterPressed", EditBox_ClearFocus)
search:HookScript("OnEditFocusLost", function(self)
	self:SetFontObject("ChatFontSmall")
	self:SetTextColor(0.5, 0.5, 0.5)
end)
search:HookScript("OnEditFocusGained", function(self)
	self:SetTextColor(1, 1, 1)
end)

local function onClick(self, spellID, arg2, checked)
	if checked then
		addon.filters:AddFilterEntry("auras", spellID)
	else
		addon.filters:RemoveFilterEntry("auras", spellID)
	end
	addon.filters.scrollFrame:Update()
	frame:Update()
end

local menu = CreateFrame("Frame")
menu.displayMode = "MENU"
menu.initialize = function(self)
	local spellID = UIDROPDOWNMENU_MENU_VALUE
	
	local info = UIDropDownMenu_CreateInfo()
	info.text = GetSpellInfo(spellID)
	info.isTitle = true
	info.notCheckable = true
	UIDropDownMenu_AddButton(info)
	
	local info = UIDropDownMenu_CreateInfo()
	info.text = "Filter"
	info.func = onClick
	info.arg1 = spellID
	info.checked = addon.filters:IsFilteredAura(spellID)
	info.disabled = addon.filters:IsFilteredAura(spellID) and not addon.filters.db.global.auras[spellID]
	info.isNotRadio = true
	info.keepShownOnClick = true
	UIDropDownMenu_AddButton(info)
end

local function onClick(self)
	if UIDropDownMenu_GetCurrentDropDown() == menu and UIDROPDOWNMENU_MENU_VALUE ~= self.spellID then
		CloseDropDownMenus()
	end
	ToggleDropDownMenu(nil, self.spellID, menu, self, 0, 0)
	PlaySound("igMainMenuOptionCheckBoxOn")
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetSpellByID(self.spellID)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(format("Spell ID: |cffffffff%d|r", self.spellID))
	GameTooltip:Show()
end

local function createButton()
	local btn = CreateFrame("Button", nil, frame)
	btn:SetPushedTextOffset(0, 0)
	btn:RegisterForClicks("RightButtonUp")
	btn:SetScript("OnClick", onClick)
	btn:SetScript("OnEnter", onEnter)
	btn:SetScript("OnLeave", GameTooltip_Hide)
	
	local icon = btn:CreateTexture()
	icon:SetSize(28, 28)
	icon:SetPoint("LEFT", 2, 0)
	btn.icon = icon
	
	local text = btn:CreateFontString(nil, nil, "GameFontNormal")
	text:SetPoint("BOTTOMLEFT", icon, "RIGHT", 4, 1)
	text:SetPoint("RIGHT")
	text:SetJustifyH("LEFT")
	btn:SetFontString(text)
	btn.text = text
	
	local source = btn:CreateFontString(nil, nil, "GameFontHighlightSmall")
	source:SetPoint("TOPLEFT", icon, "RIGHT", 4, -1)
	source:SetPoint("RIGHT")
	source:SetJustifyH("LEFT")
	btn.source = source
	
	local target = btn:CreateFontString(nil, nil, "GameFontHighlightSmall")
	target:SetPoint("TOPRIGHT", btn, "RIGHT", -4, -1)
	-- target:SetPoint("RIGHT")
	-- target:SetJustifyH("RIGHT")
	btn.target = target
	
	return btn
end

local sortedAuras = {}

local scrollFrame = addon.templates.CreateScrollFrame(template, "CritlineAuraTrackerScrollFrame", frame, NUM_BUTTONS, BUTTON_HEIGHT, createButton)
scrollFrame:SetHeight(NUM_BUTTONS * BUTTON_HEIGHT)
scrollFrame:SetPoint("BOTTOM", 0, 16)
scrollFrame:SetPoint("LEFT", 16, 0)
scrollFrame:SetPoint("RIGHT", -36, 0)

scrollFrame.GetList = function(self)
	wipe(sortedAuras)
	
	local n = 0
	local search = search:GetText():lower()
	for spellID, v in pairs(currentFilter) do
		local include = true
		for filter, active in pairs(filters) do
			if v[filter] and active then
				include = false
				break
			end
		end
		if include and (search == "search" or v.spellName:lower():find(search, nil, true) or v.sourceName:lower():find(search, nil, true) or v.targetName:lower():find(search, nil, true)) then
			n = n + 1
			sortedAuras[n] = spellID
		end
	end
	
	sort(sortedAuras, sortMethod)
	
	return sortedAuras
end

scrollFrame.OnButtonShow = function(self, button, spellID)
	button:SetFormattedText("%s (%d)", currentFilter[spellID].spellName, spellID)
	button.source:SetText(currentFilter[spellID].source)
	button.target:SetText(currentFilter[spellID].target)
	button.icon:SetTexture(addon:GetSpellTexture(spellID))
	button.spellID = spellID
	local disabled = addon.filters:IsFilteredAura(spellID)
	button.icon:SetDesaturated(disabled)
	button.text:SetFontObject(disabled and "GameFontDisable" or "GameFontNormal")
	if GameTooltip:IsOwned(button) then
		onEnter(button)
	end
end

for i, btn in ipairs(scrollFrame.buttons) do
	if i % 2 == 0 then
		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(1, 1, 1, 0.1)
	end
end

function frame:COMBAT_LOG_EVENT_UNFILTERED(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, spellID, spellName, spellSchool, auraType)
	if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH" then
		local targetType
		if CombatLog_Object_IsA(destFlags, COMBATLOG_FILTER_ME) or addon:IsMyPet(destFlags, destGUID) then
			-- register our own and our pet's auras
			targetType = "self"
		elseif not self:IsPvPTarget(destGUID) and band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
			-- and also those of non friendly NPCs
			targetType = "hostile"
		end
		
		if targetType then
			self:RegisterAura(targetType, spellID, spellName, auraType, sourceName, sourceGUID, destName, destGUID)
		end
	end
end

function frame:UNIT_NAME_UPDATE()
	self:ScanAuras()
	self:UnregisterEvent("UNIT_NAME_UPDATE")
end

-- reset current fight auras upon entering combat
function frame:PLAYER_REGEN_DISABLED()
	wipe(lastFight)
	self:Update()
end

function frame:PLAYER_ENTERING_WORLD()
	-- wipe instance buff data when entering a new instance
	local instanceName = GetInstanceInfo()
	if IsInInstance() and instanceName ~= currentInstance then
		wipe(instance)
		currentInstance = instanceName
		if currentFilter == instance then
			scopeFilter:SetFormattedText("Current instance (%s)", currentInstance)
		end
		self:Update()
	end
end

function frame:Update()
	self.scrollFrame:Update()
end

local auraTypes = {
	BUFF = "HELPFUL",
	DEBUFF = "HARMFUL",
}

function frame:ScanAuras()
	local auras = {}
	for auraType, filter in pairs(auraTypes) do
		for i = 1, 40 do
			local spellName, _, _, _, _, _, _, source, _, _, spellID = UnitAura("player", i, filter)
			if not spellID then break end
			self:RegisterAura("self", spellID, spellName, auraType, source and UnitName(source), source and UnitGUID(source), UnitName("player"), UnitGUID("player"))
		end
	end
	self:Update()
end

frame.PLAYER_LOGIN = frame.ScanAuras
frame.UNIT_AURA = frame.ScanAuras

function frame:RegisterAura(targetType, spellID, spellName, auraType, sourceName, sourceGUID, destName, destGUID)
	if session[spellID] and (session[spellID].source or not sourceName) or IsSpellKnown(spellID) or IsPlayerSpell(spellID) then
		return 
	end

	local source = "n/a"
	local sourceType
	
	if sourceGUID and sourceGUID ~= "" then
		if self:IsPvPTarget(sourceGUID) then
			-- this is a player or a player's permanent pet
			source = PVP
			sourceType = "pvp"
		else
			source = tonumber(sourceGUID:sub(7, 10), 16)
			sourceType = "npc"
		end
	end

	local dest = "n/a"
	local destType
	
	if destGUID and destGUID ~= "" then
		if self:IsPvPTarget(destGUID) then
			-- this is a player or a player's permanent pet
			dest = PVP
			destType = "pvp"
		else
			dest = tonumber(destGUID:sub(7, 10), 16)
			destType = "npc"
		end
	end
	
	local aura = {
		[targetType] = true,
		spellName = spellName,
		[auraType] = true,
		source = sourceName and format("%s (%s)", sourceName, source) or source,
		sourceName = sourceName or "",
		target = destName and format("%s (%s)", destName, dest) or dest,
		targetName = destName or "",
	}
	if sourceType then
		aura[sourceType] = true
	end
	if destType then
		aura[destType] = true
	end
	
	lastFight[spellID] = aura
	if IsInInstance() then
		instance[spellID] = aura
	end
	session[spellID] = aura
	self:Update()
end

function frame:IsPvPTarget(guid)
	local unitType = band(guid:sub(1, 5), 0x007)
	return unitType == 0 or unitType == 4
end
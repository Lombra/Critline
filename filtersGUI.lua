local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local templates = addon.templates

-- amount of buttons in the spell, mob and aura filter scroll lists
local NUMSPELLBUTTONS = 20
local SPELLBUTTONHEIGHT = 22

local NUMFILTERBUTTONS = 25
local FILTERBUTTONHEIGHT = 16


local filters = templates:CreateConfigFrame(FILTERS, addonName, true)
filters:SetScript("OnEvent", function(self, event, ...)
	return self[event] and self[event](self, ...)
end)
addon.filters = filters

local activeAuras = {
	player = {},
	pet = {},
}
filters.activeAuras = activeAuras


local function resetScroll(self)
	FauxScrollFrame_SetOffset(self, 0)
	self.ScrollBar:SetValue(0)
	self:Update()
end

local function onVerticalScroll(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, self.buttonHeight, self.Update)
end

local function filterFrameOnShow(self)
	local scrollFrame = self.scrollFrame
	if scrollFrame.selected then
		local prevHilite = scrollFrame.buttons[scrollFrame.selected - FauxScrollFrame_GetOffset(scrollFrame)]
		if prevHilite then
			prevHilite:UnlockHighlight()
		end
		scrollFrame.selected = nil
		self.delete:Disable()
	end
end

local function addButtonOnClick(self)
	StaticPopup_Show(self.popup)
end

local function deleteButtonOnClick(self)
	local scrollFrame = self.scrollFrame
	local filterName = scrollFrame.filter
	local selection = scrollFrame.selected
	if selection then
		local filter = filters.db.global[filterName]
		local selectedEntry = filter[selection]
		tremove(filter, selection)
		local prevHighlight = scrollFrame.buttons[selection - FauxScrollFrame_GetOffset(scrollFrame)]
		if prevHighlight then
			prevHighlight:UnlockHighlight()
		end
		scrollFrame.selected = nil
		scrollFrame:Update()
		self:Disable()
		addon:Message(self.msg:format(GetSpellInfo(selectedEntry) or selectedEntry))
		if self.func then
			self.func(selectedEntry)
		end
	end
end

local function createFilterFrame(name, parent, numButtons, buttonHeight)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(numButtons * buttonHeight)
	parent[name] = frame

	local scrollFrame = CreateFrame("ScrollFrame", "CritlineFilters"..name.."ScrollFrame", frame, "FauxScrollFrameTemplate")
	scrollFrame:SetAllPoints()
	scrollFrame:SetScript("OnShow", resetScroll)
	scrollFrame:SetScript("OnVerticalScroll", onVerticalScroll)
	scrollFrame.numButtons = numButtons
	scrollFrame.buttonHeight = buttonHeight
	scrollFrame.filter = name
	frame.scrollFrame = scrollFrame
	
	if name ~= "spell" then
		frame:SetScript("OnShow", filterFrameOnShow)

		local add = templates:CreateButton(frame)
		add:SetScript("OnClick", addButtonOnClick)
		frame.add = add

		local delete = templates:CreateButton(frame)
		delete:Disable()
		delete:SetScript("OnClick", deleteButtonOnClick)
		delete.scrollFrame = scrollFrame
		frame.delete = delete
	end
	
	return frame
end


do
	local options = {}
	filters.options = options

	local checkButtons = {
		{
			text = L["Filter new spells"],
			tooltipText = L["Enable to filter out new spell entries by default."],
			setting = "filterNew",
		},
		{
			text = L["Ignore mob filter"],
			tooltipText = L["Enable to ignore integrated mob filter."],
			setting = "ignoreMobFilter",
		},
		{
			text = L["Ignore aura filter"],
			tooltipText = L["Enable to ignore integrated aura filter."],
			setting = "ignoreAuraFilter",
		},
		{
			text = L["Only known spells"],
			tooltipText = L["Enable to ignore spells that are not in your (or your pet's) spell book."],
			setting = "onlyKnown",
		},
		{
			text = L["Suppress mind control"],
			tooltipText = L["Suppress all records while mind controlled."],
			setting = "suppressMC",
		},
		{
			text = L["Don't filter magic"],
			tooltipText = L["Enable to let magical damage ignore the level filter."],
			setting = "dontFilterMagic",
		},
	}

	options.checkButtons = checkButtons
	
	local columnEnd = #checkButtons

	for i, v in ipairs(checkButtons) do
		local btn = templates:CreateCheckButton(filters, v)
		if i == 1 then
			btn:SetPoint("TOPLEFT", filters.title, "BOTTOMLEFT", -2, -16)
		elseif btn.newColumn then
			btn:SetPoint("TOPLEFT", filters.title, "BOTTOM", 0, -16)
			columnEnd = i - 1
		else
			btn:SetPoint("TOP", checkButtons[i - 1], "BOTTOM", 0, -8)
		end
		btn.module = filters
		checkButtons[i] = btn
	end
	
	local slider = templates:CreateSlider(filters, {
		text = L["Level filter"],
		tooltipText = L["If level difference between you and the target is greater than this setting, records will not be registered."],
		minValue = -1,
		maxValue = 10,
		valueStep = 1,
		minText = OFF,
		maxText = 10,
		func = function(self)
			local value = self:GetValue()
			self.value:SetText(value == -1 and OFF or value)
			filters.profile.levelFilter = value
		end,
	})
	slider:SetPoint("TOPLEFT", checkButtons[#checkButtons], "BOTTOMLEFT", 9, -19)
	options.slider = slider
end

local filterTypes = {}

do	-- spell filter frame
	local spellFilter = createFilterFrame("spell", filters, NUMSPELLBUTTONS, SPELLBUTTONHEIGHT)
	spellFilter:SetPoint("TOPLEFT", filters.title, "BOTTOM", -32, -48)
	spellFilter:SetPoint("RIGHT", -48, 0)
	filterTypes.spell = spellFilter
	
	do	-- spell filter buttons
		local function spellButtonOnClick(self)
			local checked = self:GetChecked() == 1
			PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
			filters:FilterSpell(not checked, filters.spell.tree:GetSelectedValue(), self.data)
		end
		
		local function spellButtonOnEnter(self)
			-- prevent records being added twice
			GameTooltip.Critline = true
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
			GameTooltip:SetSpellByID(self.data.spellID)
			GameTooltip:AddLine(" ")
			addon:AddTooltipLine(self.data)
			GameTooltip:Show()
		end
		
		local buttons = {}
		for i = 1, NUMSPELLBUTTONS do
			local btn = templates:CreateCheckButton(spellFilter)
			if i == 1 then
				btn:SetPoint("TOPLEFT")
			else
				btn:SetPoint("TOP", buttons[i - 1], "BOTTOM", 0, 4)
			end
			btn:SetScript("OnClick", spellButtonOnClick)
			btn:SetScript("OnEnter", spellButtonOnEnter)
			buttons[i] = btn
		end
		spellFilter.scrollFrame.buttons = buttons
	end
	
	-- spell filter scroll frame
	local spellScrollFrame = spellFilter.scrollFrame

	function spellScrollFrame:Update()
		local selectedTree = self.tree:GetSelectedValue()
		local spells = addon:GetSpellArray(selectedTree)
		local size = #spells
		
		FauxScrollFrame_Update(self, size, self.numButtons, self.buttonHeight)
		
		local offset = FauxScrollFrame_GetOffset(self)
		local buttons = self.buttons
		for line = 1, NUMSPELLBUTTONS do
			local button = buttons[line]
			local lineplusoffset = line + offset
			if lineplusoffset <= size then
				local data = spells[lineplusoffset]
				button.data = data
				button:SetText(addon:GetFullSpellName(data.spellID, data.periodic))
				button:SetChecked(not data.filtered)
				button:Show()
			else
				button:Hide()
			end
		end
	end
	
	-- spell filter tree dropdown
	local menu = {
		{text = L["Damage"],	value = "dmg"},
		{text = L["Healing"],	value = "heal"},
		{text = L["Pet"],		value = "pet"},
	}

	local spellFilterTree = templates:CreateDropDownMenu("CritlineSpellFilterTree", spellFilter, menu)
	spellFilterTree:SetFrameWidth(120)
	spellFilterTree:SetPoint("BOTTOMRIGHT", spellFilter, "TOPRIGHT", 16, 0)
	spellFilterTree:SetSelectedValue("dmg")
	spellFilterTree.onClick = function(self)
		self.owner:SetSelectedValue(self.value)
		FauxScrollFrame_SetOffset(spellScrollFrame, 0)
		spellScrollFrame.ScrollBar:SetValue(0)
		spellScrollFrame:Update()
	end
	spellFilter.tree = spellFilterTree
	spellScrollFrame.tree = spellFilter.tree
end

local function filterButtonOnClick(self)
	local module = self.module
	local scrollFrame = module.scrollFrame
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local id = self:GetID()
	
	local selection = scrollFrame.selected
	if selection then
		if selection - offset == id then
			-- clicking the selected button, clear selection
			self:UnlockHighlight()
			selection = nil
		else
			-- clear selection if visible, and set new selection
			local prevHilite = scrollFrame.buttons[selection - offset]
			if prevHilite then
				prevHilite:UnlockHighlight()
			end
			self:LockHighlight()
			selection = id + offset
		end
	else
		-- no previous selection, just set new and lock highlight
		self:LockHighlight()
		selection = id + offset
	end
	
	-- enable/disable "Delete" button depending on if selection exists
	if selection then
		module.delete:Enable()
	else
		module.delete:Disable()
	end
	scrollFrame.selected = selection
end

-- template function for mob filter buttons
local function createFilterButton(parent)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetHeight(FILTERBUTTONHEIGHT)
	btn:SetPoint("LEFT")
	btn:SetPoint("RIGHT")
	btn:SetNormalFontObject("GameFontNormal")
	btn:SetHighlightFontObject("GameFontHighlight")
	btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	btn:SetPushedTextOffset(0, 0)
	btn:SetScript("OnClick", filterButtonOnClick)
	return btn
end

local function createFilterButtons(parent, onEnter)
	local buttons = {}
	for i = 1, NUMFILTERBUTTONS do
		local btn = createFilterButton(parent)
		if i == 1 then
			btn:SetPoint("TOP")
		else
			btn:SetPoint("TOP", buttons[i - 1], "BOTTOM")
		end
		btn:SetID(i)
		if onEnter then
			btn:SetScript("OnEnter", onEnter)
			btn:SetScript("OnLeave", GameTooltip_Hide)
		end
		btn.module = parent
		buttons[i] = btn
	end
	parent.scrollFrame.buttons = buttons
end

local function updateFilter(self)
	local filter = filters.db.global[self.filter]
	local size = #filter
	
	FauxScrollFrame_Update(self, size, self.numButtons, self.buttonHeight)
	
	local offset = FauxScrollFrame_GetOffset(self)
	local buttons = self.buttons
	for line = 1, self.numButtons do
		local button = buttons[line]
		local lineplusoffset = line + offset
		if lineplusoffset <= size then
			if self.selected then
				if self.selected - offset == line then
					button:LockHighlight()
				else
					button:UnlockHighlight()
				end
			end
			local entry = filter[lineplusoffset]
			button.spellID = entry
			button:SetText(type(entry) == "number" and GetSpellInfo(entry) or entry)
			button:Show()
		else
			button:Hide()
		end
	end
end

do	-- mob filter frame
	local spellFilter = filterTypes.spell
	local mobFilter = createFilterFrame("mobs", filters, NUMFILTERBUTTONS, FILTERBUTTONHEIGHT)
	mobFilter:SetPoint("TOPLEFT", spellFilter)
	mobFilter:SetPoint("TOPRIGHT", spellFilter)
	mobFilter:Hide()
	filterTypes.mobs = mobFilter
	
	mobFilter.scrollFrame.Update = updateFilter
	
	createFilterButtons(mobFilter)
	
	local addTarget = templates:CreateButton(mobFilter)
	addTarget:SetSize(96, 22)
	addTarget:SetPoint("TOPLEFT", mobFilter, "BOTTOMLEFT", 0, -8)
	addTarget:SetText(L["Add target"])
	addTarget:SetScript("OnClick", function()
		local targetName = UnitName("target")
		if targetName then
			-- we don't want to add PCs to the filter
			if UnitIsPlayer("target") then
				addon:Message(L["Cannot add players to mob filter."])
			else
				filters:AddMob(targetName)
			end
		else
			addon:Message(L["No target selected."])
		end
	end)
	
	local add = mobFilter.add
	add:SetSize(96, 22)
	add:SetPoint("TOP", mobFilter, "BOTTOM", 0, -8)
	add:SetText(L["Add by name"])
	add.popup = "CRITLINE_ADD_MOB_BY_NAME"
	
	local delete = mobFilter.delete
	delete:SetSize(96, 22)
	delete:SetPoint("TOPRIGHT", mobFilter, "BOTTOMRIGHT", 0, -8)
	delete:SetText(L["Delete mob"])
	delete.msg = L["%s removed from mob filter."]
end

do	-- aura filter frame
	local spellFilter = filterTypes.spell
	local auraFilter = createFilterFrame("auras", filters, NUMFILTERBUTTONS, FILTERBUTTONHEIGHT)
	auraFilter:SetPoint("TOPLEFT", spellFilter)
	auraFilter:SetPoint("TOPRIGHT", spellFilter)
	auraFilter:Hide()
	filterTypes.auras = auraFilter
	
	auraFilter.scrollFrame.Update = updateFilter

	createFilterButtons(auraFilter, function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
		GameTooltip:SetHyperlink("spell:"..self.spellID)
	end)
	
	local add = auraFilter.add
	add:SetSize(128, 22)
	add:SetPoint("TOPLEFT", auraFilter, "BOTTOMLEFT", 0, -8)
	add:SetText(L["Add by spell ID"])
	add.popup = "CRITLINE_ADD_AURA_BY_ID"
	
	local delete = auraFilter.delete
	delete:SetSize(128, 22)
	delete:SetPoint("TOPRIGHT", auraFilter, "BOTTOMRIGHT", 0, -8)
	delete:SetText(L["Delete aura"])
	delete.msg = L["%s removed from aura filter."]
	delete.func = function(spellID)
		activeAuras.player[spellID] = nil
		activeAuras.pet[spellID] = nil
		if not filters:IsEmpowered("player") then
			addon:Debug("No filtered aura detected on player. Resuming record tracking.")
		end
		if not filters:IsEmpowered("pet") then
			addon:Debug("No filtered aura detected on pet. Resuming record tracking.")
		end
	end
end

do	-- filter tree dropdown
	local menu = {
		{
			text = L["Spell filter"],
			value = "spell",
		},
		{
			text = L["Mob filter"],
			value = "mobs",
		},
		{
			text = L["Aura filter"],
			value = "auras",
		},
	}
	
	local filterType = templates:CreateDropDownMenu("CritlineFilterType", filters, menu)
	filterType:SetPoint("BOTTOMLEFT", filterTypes.spell, "TOPLEFT", -16, 0)
	filterType:SetFrameWidth(120)
	filterType:SetSelectedValue("spell")
	filterType.onClick = function(self)
		self.owner:SetSelectedValue(self.value)
		for k, v in pairs(filterTypes) do
			if k == self.value then
				v:Show()
			else
				v:Hide()
			end
		end
	end
	filters.type = filterType
end


StaticPopupDialogs["CRITLINE_ADD_MOB_BY_NAME"] = {
	text = L["Enter mob name:"],
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	OnAccept = function(self)
		local name = self.editBox:GetText():trim()
		if not name:match("%S+") then
			addon:Message(L["Invalid mob name."])
			return
		end
		filters:AddMob(name)
	end,
	EditBoxOnEnterPressed = function(self)
		local name = self:GetText():trim()
		if not name:match("%S+") then
			addon:Message(L["Invalid mob name."])
			return
		end
		filters:AddMob(name)
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	OnShow = function(self)
		self.editBox:SetFocus()
	end,
	whileDead = true,
	timeout = 0,
}

StaticPopupDialogs["CRITLINE_ADD_AURA_BY_ID"] = {
	text = L["Enter spell ID:"],
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	OnAccept = function(self)
		local id = tonumber(self.editBox:GetText())
		if not id then
			addon:Message(L["Invalid input. Please enter a spell ID."])
			return
		elseif not GetSpellInfo(id) then
			addon:Message(L["Invalid spell ID. No such spell."])
			return
		end
		filters:AddAura(id)
	end,
	EditBoxOnEnterPressed = function(self)
		local id = tonumber(self:GetText())
		if not id then
			addon:Message(L["Invalid input. Please enter a spell ID."])
			return
		elseif not GetSpellInfo(id) then
			addon:Message(L["Invalid spell ID. No such spell exists."])
			return
		end
		filters:AddAura(id)
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end,
	OnShow = function(self)
		self.editBox:SetFocus()
	end,
	whileDead = true,
	timeout = 0,
}
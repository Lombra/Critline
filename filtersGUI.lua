local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local filters = addon:AddCategory(FILTERS, true, nil, addon.filters)

do
	local options = {
		{
			type = "CheckButton",
			label = L["Filter new spells"],
			tooltipText = L["Enable to filter out new spell entries by default."],
			setting = "filterNew",
		},
		{
			type = "CheckButton",
			label = L["Ignore mob filter"],
			tooltipText = L["Enable to ignore integrated mob filter."],
			setting = "ignoreMobFilter",
		},
		{
			type = "CheckButton",
			label = L["Ignore aura filter"],
			tooltipText = L["Enable to ignore integrated aura filter."],
			setting = "ignoreAuraFilter",
			func = function(self, checked)
				if checked then
					filters:ResetEmpowered()
				else
					filters:ScanAuras()
				end
			end,
		},
		{
			type = "CheckButton",
			label = L["Only known spells"],
			tooltipText = L["Enable to ignore spells that are not in your (or your pet's) spell book."],
			setting = "onlyKnown",
		},
		{
			type = "CheckButton",
			label = L["Suppress mind control"],
			tooltipText = L["Suppress all records while mind controlled."],
			setting = "suppressMC",
		},
		{
			type = "CheckButton",
			label = L["Don't filter magic"],
			tooltipText = L["Enable to let magical damage ignore the level filter."],
			setting = "dontFilterMagic",
		},
		{
			type = "Slider",
			label = L["Level filter"],
			tooltipText = L["If level difference between you and the target is greater than this setting, records will not be registered."],
			setting = "levelFilter",
			minValue = -1,
			maxValue = 10,
			valueStep = 1,
			minText = OFF,
			func = function(self, value)
				if value == -1 then
					self.currentValue:SetText(OFF)
				end
			end,
		}
	}

	filters:CreateOptions(options)
end

addon.spellList:AddSpellOption({
	text = ENABLE,
	func = function(self, tree, arg2, checked)
		filters:FilterSpell(checked, tree, self.value)
	end,
	checked = function(self)
		return not self.value.filtered
	end,
	isNotRadio = true,
})

local NUMFILTERBUTTONS = 24
local FILTERBUTTONHEIGHT = 18
local BUTTON_OFFSET_TOP = 2

local filterList = filters:CreateTabInterface()
filterList:SetPoint("TOPLEFT", filters.title, "BOTTOM", -32, -40)
filterList:SetPoint("RIGHT", -48, 0)
filterList:SetHeight(NUMFILTERBUTTONS * FILTERBUTTONHEIGHT + BUTTON_OFFSET_TOP)

local function resetScroll(self)
	FauxScrollFrame_SetOffset(self, 0)
	self.ScrollBar:SetValue(0)
	self:Update()
end

local function onVerticalScroll(self, offset)
	FauxScrollFrame_OnVerticalScroll(self, offset, FILTERBUTTONHEIGHT, self.Update)
end

local function updateFilter(self)
	local filter = filters.db.global[self.filter]
	local size = #filter
	
	FauxScrollFrame_Update(self, size, NUMFILTERBUTTONS, FILTERBUTTONHEIGHT)
	
	local offset = FauxScrollFrame_GetOffset(self)
	local buttons = self.buttons
	for line = 1, NUMFILTERBUTTONS do
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
	local selection = scrollFrame.selected
	if selection then
		local filter = filters.db.global[scrollFrame.filter]
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
			self.func(filters, selectedEntry)
		end
	end
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
	
	local highlight = btn:CreateTexture()
	highlight:SetPoint("TOPLEFT", 0, 1)
	highlight:SetPoint("BOTTOMRIGHT", 0, 1)
	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
	highlight:SetVertexColor(.196, .388, .8)
	btn:SetHighlightTexture(highlight)
	
	btn:SetScript("OnClick", filterButtonOnClick)
	
	return btn
end

local function createFilterFrame(name, onEnter)
	local frame = CreateFrame("Frame", nil, filters)
	frame:SetAllPoints(filterList)
	filters[name] = frame

	local scrollFrame = CreateFrame("ScrollFrame", "CritlineFilters"..name.."ScrollFrame", frame, "FauxScrollFrameTemplate")
	scrollFrame:SetAllPoints()
	scrollFrame:SetScript("OnShow", resetScroll)
	scrollFrame:SetScript("OnVerticalScroll", onVerticalScroll)
	scrollFrame.Update = updateFilter
	scrollFrame.filter = name
	frame.scrollFrame = scrollFrame
	
	frame:SetScript("OnShow", filterFrameOnShow)

	local add = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	add:SetScript("OnClick", addButtonOnClick)
	frame.add = add

	local delete = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	delete:Disable()
	delete:SetText(DELETE)
	delete:SetScript("OnClick", deleteButtonOnClick)
	delete.scrollFrame = scrollFrame
	frame.delete = delete
	
	local buttons = {}
	for i = 1, NUMFILTERBUTTONS do
		local btn = createFilterButton(frame)
		if i == 1 then
			btn:SetPoint("TOP", 0, -BUTTON_OFFSET_TOP)
		else
			btn:SetPoint("TOP", buttons[i - 1], "BOTTOM")
		end
		btn:SetID(i)
		if onEnter then
			btn:SetScript("OnEnter", onEnter)
			btn:SetScript("OnLeave", GameTooltip_Hide)
		end
		btn.module = frame
		buttons[i] = btn
	end
	scrollFrame.buttons = buttons
	
	return frame
end

do	-- mob filter frame
	local mobFilter = createFilterFrame("mobs")
	
	local addTarget = CreateFrame("Button", nil, mobFilter, "UIPanelButtonTemplate")
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
	delete.msg = L["%s removed from mob filter."]
end

do	-- aura filter frame
	local function onEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetSpellByID(self.spellID)
	end
	
	local auraFilter = createFilterFrame("auras", onEnter)
	auraFilter:Hide()
	
	local add = auraFilter.add
	add:SetSize(128, 22)
	add:SetPoint("TOPLEFT", auraFilter, "BOTTOMLEFT", 0, -8)
	add:SetText(L["Add by spell ID"])
	add.popup = "CRITLINE_ADD_AURA_BY_ID"
	
	local delete = auraFilter.delete
	delete:SetSize(128, 22)
	delete:SetPoint("TOPRIGHT", auraFilter, "BOTTOMRIGHT", 0, -8)
	delete.func = filters.RemoveAura
	delete.msg = L["%s removed from aura filter."]
end

do	-- filter tabs
	local tabs = {
		{
			text = L["Mob filter"],
			value = "mobs",
		},
		{
			text = L["Aura filter"],
			value = "auras",
		},
	}
	
	for i, v in ipairs(tabs) do
		local tab = filterList:CreateTab()
		tab:SetLabel(v.text)
		tab.frame = filters[v.value]
	end

	filterList:SelectTab(1)
end

addon:CreatePopup("CRITLINE_ADD_MOB_BY_NAME", {
	text = L["Enter mob name"],
	button1 = ACCEPT,
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
})

addon:CreatePopup("CRITLINE_ADD_AURA_BY_ID", {
	text = L["Enter spell ID"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	OnAccept = function(self)
		local id = tonumber(self.editBox:GetText())
		if not id then
			addon:Message(L["Invalid input. Please enter a spell ID."])
			return
		elseif not GetSpellInfo(id) then
			addon:Message(L["Invalid spell ID. No such spell exists."])
			return
		end
		filters:AddAura(id)
	end,
})
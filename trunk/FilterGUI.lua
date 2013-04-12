local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local GetSpellInfo, tostring = GetSpellInfo, tostring
local scrollFrame
local selectedFilter

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

local NUMFILTERBUTTONS = 22
local FILTERBUTTONHEIGHT = 18
local BUTTON_OFFSET_TOP = 2

local filterList = filters:CreateTabInterface()
filterList:SetPoint("TOPLEFT", filters.title, "BOTTOM", -32, -40)
filterList:SetPoint("RIGHT", -48, 0)
filterList:SetHeight(NUMFILTERBUTTONS * FILTERBUTTONHEIGHT + BUTTON_OFFSET_TOP)

local add = CreateFrame("Button", nil, filterList, "UIPanelButtonTemplate")
add:SetSize(80, 22)
add:SetPoint("TOPLEFT", filterList, "BOTTOMLEFT", 0, -4)
add:SetText(ADD)
add:SetScript("OnClick", function(self)
	StaticPopup_Show(self.popup)
end)

local delete = CreateFrame("Button", nil, filterList, "UIPanelButtonTemplate")
delete:SetSize(80, 22)
delete:SetPoint("LEFT", add, "RIGHT", 4, 0)
delete:Disable()
delete:SetText(DELETE)
delete:SetScript("OnClick", function(self)
	local selection = scrollFrame.selected
	filters:RemoveFilterEntry(selectedFilter, selection)
	scrollFrame.selected = nil
	scrollFrame:Update()
	self:Disable()
	addon:Message(L["%s removed from %s."]:format(GetSpellInfo(selection) or selection, self.filterName))
end)

local info = filters:CreateFontString(nil, nil, "GameFontNormalSmallLeft")
info:SetPoint("TOPLEFT", filterList, "BOTTOMLEFT", 4, -32)
info:SetPoint("TOPRIGHT", filterList, "BOTTOMRIGHT", -4, -32)
info:SetPoint("BOTTOM")
info:SetJustifyV("TOP")

local function filterButtonOnClick(self)
	local selection = scrollFrame.selected
	local doUpdate
	if selection == self.value then
		-- clicking the selected button, clear selection
		self:UnlockHighlight()
		selection = nil
	else
		if selection then
			-- clear selection if visible, and set new selection
			doUpdate = true
		end
		-- no previous selection, just set new and lock highlight
		self:LockHighlight()
		selection = self.value
	end
	
	-- enable/disable "Delete" button depending on if selection exists
	delete:SetEnabled(selection)
	scrollFrame.selected = selection
	scrollFrame:Update()
end

local function onEnter(self)
	if type(self.value) == "number" then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetSpellByID(self.value)
	end
end

-- template function for mob filter buttons
local function createFilterButton()
	local btn = CreateFrame("Button", nil, filterList)
	btn:SetNormalFontObject("GameFontNormal")
	btn:SetHighlightFontObject("GameFontHighlight")
	btn:SetScript("OnClick", filterButtonOnClick)
	btn:SetScript("OnEnter", onEnter)
	btn:SetScript("OnLeave", GameTooltip_Hide)
	
	local highlight = btn:CreateTexture()
	highlight:SetPoint("TOPLEFT", 0, 1)
	highlight:SetPoint("BOTTOMRIGHT", 0, 1)
	highlight:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
	highlight:SetVertexColor(.196, .388, .8)
	btn:SetHighlightTexture(highlight)
	
	return btn
end

local sortedList = {}

local function spellSort(a, b)
	return (GetSpellInfo(a) or tostring(a)) < (GetSpellInfo(b) or tostring(b))
end

scrollFrame = filters:CreateScrollFrame("CritlineFiltersScrollFrame", filters, NUMFILTERBUTTONS, FILTERBUTTONHEIGHT, createFilterButton, 0, -BUTTON_OFFSET_TOP)
scrollFrame:SetAllPoints(filterList)
scrollFrame.PreUpdate = function(self)
	return self.selected
end
scrollFrame.GetList = function(self)
	if not filters.db then
		return
	end
	
	wipe(sortedList)
	
	for k, v in pairs(filters.db.global[selectedFilter]) do
		tinsert(sortedList, k)
	end
	
	sort(sortedList, spellSort)
	
	return sortedList
end
scrollFrame.OnButtonShow = function(self, button, entry, selected)
	if selected and selected == entry then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end
	button.value = entry
	button:SetText(type(entry) == "number" and GetSpellInfo(entry) or entry)
end
scrollFrame.doUpdate = true

do	-- filter tabs
	local function setShown(self, show)
		if show then
			add.popup = self.popupDialog
			delete.filterName = self.name
			scrollFrame.selected = nil
			delete:Disable()
		end
		if self.extra then
			for k, child in pairs(self.extra) do
				child:SetShown(show)
			end
		end
	end
	
	-- mob filter frame
	local addTarget = CreateFrame("Button", nil, filterList, "UIPanelButtonTemplate")
	addTarget:SetSize(128, 22)
	addTarget:SetPoint("TOPRIGHT", filterList, "BOTTOMRIGHT", 0, -4)
	addTarget:SetText(L["Add target"])
	addTarget:SetScript("OnClick", function()
		local targetName = UnitName("target")
		if targetName then
			-- we don't want to add PCs to the filter
			if UnitIsPlayer("target") then
				addon:Message(L["Cannot add players to mob filter."])
			else
				filters:AddFilterEntry("mobs", targetName)
			end
		else
			addon:Message(L["No target selected."])
		end
	end)
	
	local tabs = {
		{
			text = L["Include"],
			value = "include",
			name = L["included spells"],
			info = L["Spells in this list will be considered known spells for the purposes of the 'Only known spells' option."],
			popupDialog = "CRITLINE_FILTERS_INCLUDE_SPELL",
			popupText = L["Enter spell name or ID"],
			popupOnAccept = function(self)
				local spell = self.editBox:GetText():trim()
				filters:AddFilterEntry("include", tonumber(spell) or spell)
			end,
		},
		{
			text = L["Exclude"],
			value = "exclude",
			name = L["excluded spells"],
			info = L["Spells in this list will not be registered."],
			popupDialog = "CRITLINE_FILTERS_EXCLUDE_SPELL",
			popupText = L["Enter spell name or ID"],
			popupOnAccept = function(self)
				local spell = self.editBox:GetText():trim()
				filters:AddFilterEntry("exclude", tonumber(spell) or spell)
			end,
		},
		{
			text = L["Auras"],
			value = "auras",
			name = L["aura filter"],
			info = L["When an aura in this list is gained, records will be disabled for the remainder of the combat duration."],
			popupDialog = "CRITLINE_FILTERS_ADD_AURA",
			popupText = L["Enter spell ID"],
			popupOnAccept = function(self)
				local id = tonumber(self.editBox:GetText())
				if not id then
					addon:Message(L["Invalid input. Please enter a spell ID."])
					return
				elseif not GetSpellInfo(id) then
					addon:Message(L["Invalid spell ID."])
					return
				end
				filters:AddFilterEntry("auras", id)
			end,
		},
		{
			text = L["Mobs"],
			value = "mobs",
			name = L["mob filter"],
			info = L["Spells cast on targets in this list will not be registered."],
			popupDialog = "CRITLINE_FILTERS_ADD_MOB",
			popupText = L["Enter mob name"],
			popupOnAccept = function(self)
				filters:AddFilterEntry("mobs", self.editBox:GetText():trim())
			end,
			extra = {
				addTarget,
			}
		},
	}
	
	for i, v in ipairs(tabs) do
		local frame = {
			SetShown = setShown,
			name = v.name,
			popupDialog = v.popupDialog,
			deleteMsg = v.deleteMsg,
			extra = v.extra,
		}
		filters[v.value] = frame
		addon:CreatePopup(v.popupDialog, {
			text = v.popupText,
			OnAccept = v.popupOnAccept,
		}, true)
		local tab = filterList:CreateTab()
		tab:SetLabel(v.text)
		tab.frame = frame
	end

	filterList.OnTabSelected = function(self, tabIndex)
		selectedFilter = tabs[tabIndex].value
		scrollFrame:Reset()
		info:SetText(tabs[tabIndex].info)
	end

	filterList:SelectTab(1)
end
local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local NUM_BUTTONS = 12
local BUTTON_HEIGHT = 36

local selectedTree

local spellList = addon:AddCategory("Spells", true, true)
addon.spellList = spellList

spellList.desc:SetText("This is where you can review and manage all your registered spells. Click the button on the right hand side of a spell for options.")

-- this table gets populated with "Filter", "Reset", "Announce" etc
local spellOptions = {}

local dropdown = CreateFrame("Frame")
dropdown.displayMode = "MENU"
dropdown.initialize = function(self, level, menuList)
	for i, info in ipairs(menuList) do
		info.value = UIDROPDOWNMENU_MENU_VALUE
		info.arg1 = selectedTree
		UIDropDownMenu_AddButton(info, level)
	end
end

local spellListContainer = spellList:CreateTabInterface()
spellListContainer:SetHeight(NUM_BUTTONS * BUTTON_HEIGHT + 4)
spellListContainer:SetPoint("TOP", spellList.title, "BOTTOM", 0, -68)
spellListContainer:SetPoint("LEFT", 32, 0)
spellListContainer:SetPoint("RIGHT", -32, 0)

for i, v in ipairs(addon.treeIndex) do
	local tab = spellListContainer:CreateTab()
	tab:SetLabel(addon.trees[v].title)
end

local scrollFrame = CreateFrame("ScrollFrame", "CritlineSpellsScrollFrame", spellListContainer, "FauxScrollFrameTemplate")
scrollFrame:SetAllPoints()
scrollFrame:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, BUTTON_HEIGHT, self.Update) end)
scrollFrame.Update = function(self, event, tree)
	local spells = addon:GetSpellArray(selectedTree)
	local size = #spells
	FauxScrollFrame_Update(self, size, NUM_BUTTONS, BUTTON_HEIGHT)
	local offset = FauxScrollFrame_GetOffset(self)
	local owner = GameTooltip:GetOwner()
	for line = 1, NUM_BUTTONS do
		local item = self.buttons[line]
		local lineplusoffset = line + offset
		if lineplusoffset <= size then
			local data = spells[lineplusoffset]
			item.data = data
			item.button.data = data
			local normal = data.normal
			local crit = data.crit
			item.icon:SetTexture(addon:GetSpellTexture(data.spellID))
			if addon.filters then
				item.icon:SetDesaturated(data.filtered)
				item.spellName:SetFontObject(data.filtered and "GameFontDisable" or "GameFontNormal")
			end
			item.spellName:SetText(addon:GetFullSpellName(data.spellID, data.periodic))
			item.target:SetFormattedText("%s\n%s",
				normal and normal.target or "-",
				crit and crit.target or "-")
			item.record:SetFormattedText("%s\n%s",
				spellList:GetTextColor(data, "normal"),
				spellList:GetTextColor(data, "crit"))
			if item == owner then
				item:OnEnter()
			end
			item:Show()
		else
			item:Hide()
		end
	end
	
	-- hide the menu since we can't tell if it's still referring to the same spell (no need if a different tree was updated)
	if DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dropdown and tree == selectedTree then
		CloseDropDownMenus()
	end
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip.Critline = true
	GameTooltip:SetSpellByID(self.data.spellID)
	GameTooltip:AddLine(" ")
	addon:AddTooltipLine(self.data)
	if addon.GetPreviousRecord then
		local prevRecord = addon:GetPreviousRecord(self.data, selectedTree)
		if prevRecord then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L["Previous record:"])
			addon:AddTooltipLine(prevRecord)
		end
	end
	GameTooltip:Show()
end

local function onClick(self)
	if DropDownList1:IsShown() and UIDROPDOWNMENU_MENU_VALUE ~= self.data then
		CloseDropDownMenus()
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	ToggleDropDownMenu(nil, self.data, dropdown, self, 0, 0, spellOptions)
end

-- create list of check buttons
local buttons = {}
for i = 1, NUM_BUTTONS do
	local item = CreateFrame("Frame", nil, spellListContainer)
	item:SetHeight(BUTTON_HEIGHT)
	if i == 1 then
		item:SetPoint("TOPLEFT", 4, -2)
	else
		item:SetPoint("TOP", buttons[i - 1], "BOTTOM")
	end
	item:SetPoint("RIGHT")
	item:SetScript("OnEnter", onEnter)
	item:SetScript("OnLeave", GameTooltip_Hide)
	item.OnEnter = onEnter
	
	local icon = item:CreateTexture()
	icon:SetSize(32, 32)
	icon:SetPoint("LEFT")
	item.icon = icon

	local spellName = item:CreateFontString(nil, nil, "GameFontNormal")
	spellName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, -4)
	spellName:SetJustifyH("LEFT")
	item.spellName = spellName

	local target = item:CreateFontString(nil, nil, "GameFontDisableSmall")
	target:SetPoint("TOPRIGHT", -80, 0)
	target:SetPoint("BOTTOMRIGHT", -80, 0)
	target:SetJustifyH("RIGHT")
	target:SetSpacing(2)
	item.target = target
	
	local button = CreateFrame("Button", nil, item)
	button:SetPoint("RIGHT", -2, 0)
	button:SetSize(32, 32)
	button:SetNormalTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Up]])
	button:SetPushedTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Down]])
	button:SetDisabledTexture([[Interface\ChatFrame\UI-ChatIcon-ScrollDown-Disabled]])
	button:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]])
	button:SetScript("OnClick", onClick)
	item.button = button
	
	-- font string for record amounts
	local record = item:CreateFontString(nil, nil, "GameFontHighlightSmall")
	record:SetPoint("TOPRIGHT", -36, 0)
	record:SetPoint("BOTTOMRIGHT", -36, 0)
	record:SetJustifyH("RIGHT")
	record:SetSpacing(2)
	item.record = record
	
	buttons[i] = item
end
scrollFrame.buttons = buttons

spellListContainer.OnTabSelected = function(self, tabIndex)
	selectedTree = addon.treeIndex[tabIndex]
	FauxScrollFrame_SetOffset(scrollFrame, 0)
	scrollFrame.ScrollBar:SetValue(0)
	scrollFrame:Update()
end

spellListContainer:SelectTab(1)

addon.RegisterCallback(scrollFrame, "PerCharSettingsLoaded", "Update")
addon.RegisterCallback(scrollFrame, "RecordsChanged", "Update")
addon.RegisterCallback(scrollFrame, "SpellsChanged", "Update")
addon.RegisterCallback(scrollFrame, "HistoryCleared", "Update")
addon.RegisterCallback(scrollFrame, "FormatChanged", "Update")

function spellList:AddSpellOption(info)
	tinsert(spellOptions, info)
end

function spellList:GetSelectedTree()
	return selectedTree
end

local textColorMod

-- color text yellow if the record can be reverted
function spellList:GetTextColor(data, hitType)
	local amount = data[hitType] and addon:ShortenNumber(data[hitType].amount)
	if not amount then
		return 0
	end
	local colorFormat = textColorMod and textColorMod(data, selectedTree, hitType)
	return colorFormat and format(colorFormat, amount) or amount
end

function spellList:SetSpellColorMod(func)
	textColorMod = func
end
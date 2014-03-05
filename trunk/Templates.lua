local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local Libra = LibStub("Libra")

local templates = {}
addon.templates = templates

local function onSet(self, value)
	addon:Debug(self.setting..":", value)
	local func = self.func
	if func then
		if type(func) == "string" then
			self = self.module
			func = self[func]
		end
		func(self, value)
	end
end

do
	local objectData = {
		CheckButton = {
			x = -2,
			y = -16,
			bottomOffset = 8,
		},
		ColorButton = {
			x = 3,
			y = -21,
			bottomOffset = 3,
		},
		Slider = {
			x = 7,
			y = -27,
			bottomOffset = -5,
		},
		DropDownMenu = {
			x = -17,
			y = -32,
			bottomOffset = 8,
		},
	}
	
	local function loadOptions(self, module, perchar)
		module = module or self
		for i, v in ipairs(self.options) do
			if v.perchar == perchar then
				v.db = module[perchar and "percharDB" or "db"].profile
				v:LoadSetting(v.db[v.setting])
				onSet(v, v.db[v.setting])
			end
		end
	end
	
	--[[
	
	standard option fields:
	
		type (string) - type of widget
		label (string) - label of the option
		tooltipText (string) - description of the option
		setting (string) - key in the database that this option relates to
		perchar (boolean) - if true, this option will use .percharDB instead of .db
		func (string | functon) - function to be called when this option is changed, if a string, will look for a method in the module table
									gets passed the option widget and its value
	
	]]
	
	function templates:Add(object)
		local options = self.options
		local objectType = object.type
		local option = self["Create"..objectType](self, object)
		option.type = objectType
		option.tooltipText = object.tooltipText
		option.setting = object.setting
		option.perchar = object.perchar
		option.func = object.func
		local data = objectData[objectType]
		local previousOption = options[#options]
		if object.newColumn or not previousOption then
			option:SetPoint("TOPLEFT", self.title, object.newColumn and "BOTTOM" or "BOTTOMLEFT", data.x, data.y)
		else
			local previousData = objectData[previousOption.type]
			option:SetPoint("TOPLEFT", previousOption, "BOTTOMLEFT", data.x - previousData.x, data.y + previousData.bottomOffset - (object.gap or 0))
		end
		tinsert(options, option)
		self.registry[object.setting] = option
		return option
	end
	
	-- specify a module if your config frame is not the same as your main module table
	function templates:CreateOptions(options, module)
		self.options = {}
		self.registry = {}
		self.LoadOptions = loadOptions
		for i, v in ipairs(options) do
			local option = templates.Add(self, v)
			option.module = module or self
		end
	end
end

do	-- config frame
	local function createTitle(frame)
		local title = frame:CreateFontString(nil, nil, "GameFontNormalLarge")
		title:SetPoint("TOPLEFT", 16, -16)
		title:SetPoint("RIGHT", -16, 0)
		title:SetJustifyH("LEFT")
		title:SetJustifyV("TOP")
		title:SetText(frame.name)
		frame.title = title
	end

	local function createDesc(frame)
		local desc = frame:CreateFontString(nil, nil, "GameFontHighlightSmall")
		desc:SetHeight(32)
		desc:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
		desc:SetPoint("RIGHT", -32, 0)
		desc:SetJustifyH("LEFT")
		desc:SetJustifyV("TOP")
		desc:SetNonSpaceWrap(true)
		frame.desc = desc
	end
	
	local embed = {
		"CreateOptions",
		"CreateCheckButton",
		"CreateSlider",
		"CreateColorButton",
		"CreateEditBox",
		"CreateDropDownMenu",
		"CreateScrollFrame",
		"CreateTabInterface",
	}
	
	local function createConfigFrame(name, addTitle, addDesc, frame)
		frame = frame or CreateFrame("Frame")
		for i, v in ipairs(embed) do
			frame[v] = templates[v]
		end
		frame.name = name
		if name ~= addonName then
			frame.parent = addonName
		end
		if addTitle then
			createTitle(frame)
			if addDesc then
				createDesc(frame)
			end
		end
		InterfaceOptions_AddCategory(frame)
		return frame
	end
	
	local function createModuleConfigFrame(self, name, addTitle, addDesc, frame)
		return createConfigFrame(name, addTitle, addDesc, frame)
	end
	
	function addon:CreateConfigFrame()
		local frame = createConfigFrame(addonName, true)
		self.AddCategory = createModuleConfigFrame
		return frame
	end
end

do	-- check button
	local function onClick(self)
		local checked = self:GetChecked() ~= nil
		PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		self.db[self.setting] = checked
		onSet(self, checked)
	end
	
	function templates:CreateCheckButton(data)
		local btn = CreateFrame("CheckButton", nil, self, "OptionsBaseCheckButtonTemplate")
		btn:SetPushedTextOffset(0, 0)
		btn:SetScript("OnClick", onClick)
		btn.LoadSetting = btn.SetChecked
		
		local text = btn:CreateFontString(nil, nil, "GameFontHighlight")
		text:SetPoint("LEFT", btn, "RIGHT", 0, 1)
		btn:SetFontString(text)
		btn:SetText(data.label)
		
		return btn
	end
end

do	-- slider template
	local function setText(self, value, isPercent)
		if isPercent then
			self:SetFormattedText("%.0f%%", value * 100)
		else
			self:SetText(value)
		end
	end
	
	local function onValueChanged(self, value, isUserInput)
		setText(self.currentValue, value, self.isPercent)
		-- only set values if the value was set by a human; they will already have been set by LoadSettings
		if isUserInput then
			self.db[self.setting] = value
			onSet(self, value)
		end
	end
	
	function templates:CreateSlider(data)
		local slider = Libra:CreateSlider(self)
		slider:SetHitRectInsets(0, 0, -10, -10)
		slider.LoadSetting = slider.SetValue
		
		if data then
			slider:SetMinMaxValues(data.minValue, data.maxValue)
			slider:SetValueStep(data.valueStep)
			slider:SetScript("OnValueChanged", onValueChanged)
			slider.label:SetText(data.label)
			slider.isPercent = data.isPercent
			setText(slider.min, data.minText or data.minValue, data.isPercent)
			setText(slider.max, data.maxText or data.maxValue, data.isPercent)
		end
		
		return slider
	end
end

do	-- swatch button template
	local ColorPickerFrame = ColorPickerFrame
	
	local function setColor(self, r, g, b)
		self.swatch:SetVertexColor(r, g, b)
	end
	
	local function saveColor(self, r, g, b)
		setColor(self, r, g, b)
		local color = self.color
		color.r = r
		color.g = g
		color.b = b
		onSet(self, color)
	end
	
	local function loadSetting(self, value)
		local color = self.db[self.setting]
		self.color = color
		setColor(self, color.r, color.g, color.b)
	end
	
	local function swatchFunc()
		saveColor(ColorPickerFrame.extraInfo, ColorPickerFrame:GetColorRGB())
	end

	local function cancelFunc(prev)
		saveColor(ColorPickerFrame.extraInfo, ColorPicker_GetPreviousValues())
	end

	local function onClick(self)
		local info = UIDropDownMenu_CreateInfo()
		local color = self.color
		info.r, info.g, info.b = color.r, color.g, color.b
		info.swatchFunc = swatchFunc
		info.cancelFunc = cancelFunc
		info.extraInfo = self
		OpenColorPicker(info)
	end
	
	local function onEnter(self)
		self.bg:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		if self.tooltipText then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
		end
	end
	
	local function onLeave(self)
		self.bg:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:Hide()
	end

	function templates:CreateColorButton(data)
		local btn = CreateFrame("Button", nil, self)
		btn:SetSize(16, 16)
		btn:SetPushedTextOffset(0, 0)
		btn:SetScript("OnClick", onClick)
		btn:SetScript("OnEnter", onEnter)
		btn:SetScript("OnLeave", onLeave)
		
		btn.LoadSetting = loadSetting
		
		btn:SetNormalTexture([[Interface\ChatFrame\ChatFrameColorSwatch]])
		btn.swatch = btn:GetNormalTexture()
		
		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture(1.0, 1.0, 1.0)
		bg:SetSize(14, 14)
		bg:SetPoint("CENTER")
		btn.bg = bg
		
		local text = btn:CreateFontString(nil, nil, "GameFontHighlight")
		text:SetPoint("LEFT", btn, "RIGHT", 5, 1)
		text:SetJustifyH("LEFT")
		btn:SetFontString(text)
		
		btn:SetText(data.label)
		
		return btn
	end
end

do	-- editbox
	function templates:CreateEditBox()
		local editbox = CreateFrame("EditBox", nil, self)
		editbox:SetAutoFocus(false)
		editbox:SetHeight(20)
		editbox:SetFontObject("ChatFontNormal")
		editbox:SetTextInsets(5, 0, 0, 0)

		local left = editbox:CreateTexture("BACKGROUND")
		left:SetTexture([[Interface\Common\Common-Input-Border]])
		left:SetTexCoord(0, 0.0625, 0, 0.625)
		left:SetWidth(8)
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT")

		local right = editbox:CreateTexture("BACKGROUND")
		right:SetTexture([[Interface\Common\Common-Input-Border]])
		right:SetTexCoord(0.9375, 1, 0, 0.625)
		right:SetWidth(8)
		right:SetPoint("TOPRIGHT")
		right:SetPoint("BOTTOMRIGHT")

		local mid = editbox:CreateTexture("BACKGROUND")
		mid:SetTexture([[Interface\Common\Common-Input-Border]])
		mid:SetTexCoord(0.0625, 0.9375, 0, 0.625)
		mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
		mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
		
		local label = editbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("BOTTOMLEFT", editbox, "TOPLEFT", 0, -2)
		label:SetPoint("BOTTOMRIGHT", editbox, "TOPRIGHT", 0, -2)
		label:SetJustifyH("LEFT")
		label:SetHeight(18)
		editbox.label = label
		
		return editbox
	end
end

do	-- dropdown menu frame
	local function onClick(self)
		self.owner:SetSelectedValue(self.value)
		self.owner.db[self.owner.setting] = self.value
		onSet(self.owner, self.value)
	end
	
	local function setSelectedValue(self, value)
		self._selectedValue = value
		self.selectedValue = value
		self:Refresh(useValue)
		self.selectedValue = nil
		self:SetText(self.menu and self.menu[value] or value)
	end
	
	local function initialize(self)
		local onClick = self.onClick
		for _, v in ipairs(self.menu) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = v.text
			info.value = v.value
			info.func = onClick or v.func
			info.owner = self
			info.fontObject = v.fontObject
			self:AddButton(info)
		end
	end
	
	function templates:CreateDropDownMenu(data)
		local frame = Libra:CreateDropdown("Frame", self)
		
		frame.SetSelectedValue = setSelectedValue
		frame.LoadSetting = setSelectedValue
		
		frame.initialize = initialize
		
		if data then
			if data.menu then
				for i, v in ipairs(data.menu) do
					data.menu[v.value] = v.text
				end
			end
			frame.menu = data.menu
			frame.onClick = onClick
			frame.initialize = data.initialize or initialize
			frame:SetLabel(data.label)
			frame:SetWidth(data.width)
		end
		
		return frame
	end
end

do	-- faux scroll frame
	local function dummy() end
	
	local function onShow(self)
		if self.doUpdate then
			self:Update()
		end
	end
	
	local function onParentShow(self)
		onShow(self.scrollFrame)
	end

	local function onVerticalScroll(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, self.buttonHeight, self.Update)
	end
	
	local scrollPrototype = {}

	function scrollPrototype:Reset()
		self:SetOffset(0)
		self.ScrollBar:SetValue(0)
		self:Update()
	end
	
	function scrollPrototype:Update(...)
		if not self.parent:IsVisible() then
			self.doUpdate = true
			return
		end
		
		self:SetupButtons(self:PreUpdate())
		
		self:PostUpdate(...)
	end

	function scrollPrototype:SetupButtons(...)
		local list = self:GetList()
		if not list then return end
		
		local length = #list
		local buttons = self.buttons
		FauxScrollFrame_Update(self, length, #buttons, self.buttonHeight)
		local offset = self:GetOffset()
		for line = 1, #buttons do
			local lineplusoffset = line + offset
			local button = buttons[line]
			local show = lineplusoffset <= length
			if show then
				self:OnButtonShow(button, list[lineplusoffset], ...)
			end
			button:SetShown(show)
		end
		self.doUpdate = nil
	end

	function templates:CreateScrollFrame(name, parent, numButtons, buttonHeight, buttonFactory, initialXOffset, initialYOffset)
		local scrollFrame = CreateFrame("ScrollFrame", name, parent, "FauxScrollFrameTemplate")
		scrollFrame:SetScript("OnShow", onShow)
		scrollFrame:SetScript("OnVerticalScroll", onVerticalScroll)
		scrollFrame.GetOffset = FauxScrollFrame_GetOffset
		scrollFrame.SetOffset = FauxScrollFrame_SetOffset
		scrollFrame.Reset = scrollPrototype.Reset
		scrollFrame.PreUpdate = dummy
		scrollFrame.PostUpdate = dummy
		scrollFrame.Update = scrollPrototype.Update
		scrollFrame.SetupButtons = scrollPrototype.SetupButtons
		scrollFrame.buttonHeight = buttonHeight
		scrollFrame.buttons = {}
		for i = 1, numButtons do
			local button = buttonFactory(parent)
			if i == 1 then
				button:SetPoint("TOPLEFT", scrollFrame, initialXOffset, initialYOffset)
			else
				button:SetPoint("TOPLEFT", scrollFrame.buttons[i - 1], "BOTTOMLEFT")
			end
			button:SetPoint("RIGHT", scrollFrame.buttons[i - 1] or scrollFrame)
			button:SetHeight(buttonHeight)
			button:SetID(i)
			scrollFrame.buttons[i] = button
		end
		scrollFrame.parent = parent
		parent:HookScript("OnShow", onParentShow)
		parent.scrollFrame = scrollFrame
		return scrollFrame
	end
end

do	-- tab interface
	local function setLabel(self, text)
		self:SetText(text)
		self:SetWidth(self:GetTextWidth() + 16)
	end
	
	local function selectTab(frame, tabIndex)
		frame.selectedTab = tabIndex
		for i, tab in ipairs(frame.tabs) do
			local active = i == tabIndex
			tab:SetEnabled(not active)
			if tab.frame then
				tab.frame:SetShown(active)
			end
		end
		if frame.OnTabSelected then
			frame:OnTabSelected(tabIndex)
		end
	end
	
	local function onClick(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		selectTab(self.container, self:GetID())
	end
	
	local function onEnable(self)
		self:SetHeight(16)
		self.bg:SetTexture(0.7, 0.7, 0.7)
	end
	
	local function onDisable(self)
		self:SetHeight(20)
		self.bg:SetTexture(0.3, 0.3, 0.3)
	end
	
	local function createTab(frame)
		local tab = CreateFrame("Button", nil, frame)
		tab:SetSize(64, 16)
		tab:SetNormalFontObject(GameFontNormalSmall)
		tab:SetHighlightFontObject(GameFontHighlightSmall)
		tab:SetDisabledFontObject(GameFontHighlightSmall)
		tab:SetScript("OnClick", onClick)
		tab:SetScript("OnEnable", onEnable)
		tab:SetScript("OnDisable", onDisable)
		tab.SetLabel = setLabel
		tab.container = frame
		local highlight = tab:CreateTexture()
		highlight:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-Tab-Highlight]])
		highlight:SetPoint("BOTTOMLEFT", -2, -6)
		highlight:SetPoint("TOPRIGHT", 2, 6)
		tab:SetHighlightTexture(highlight)

		local index = #frame.tabs + 1
		if index == 1 then
			tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 6, 1)
		else
			tab:SetPoint("BOTTOMLEFT", frame.tabs[index - 1], "BOTTOMRIGHT", 6, 0)
		end
		tab:SetID(index)
		frame.tabs[index] = tab
		
		local bg = tab:CreateTexture(nil, "BORDER")
		bg:SetTexture(0.7, 0.7, 0.7)
		bg:SetBlendMode("MOD")
		bg:SetAllPoints()
		tab.bg = bg

		local border = tab:CreateTexture(nil, "BORDER", nil, -1)
		border:SetTexture(0.5, 0.5, 0.5, 0.3)
		border:SetPoint("TOPLEFT", -1, 1)
		border:SetPoint("BOTTOMRIGHT", 1, 0)
		
		return tab
	end
	
	local function getSelectedTab(frame)
		return frame.selectedTab
	end
	
	function templates:CreateTabInterface()
		local frame = CreateFrame("Frame", nil, self)
		
		local bg = frame:CreateTexture(nil, "BORDER")
		bg:SetTexture(0.3, 0.3, 0.3)
		bg:SetBlendMode("MOD")
		bg:SetAllPoints()

		local border = frame:CreateTexture(nil, "BORDER", nil, -1)
		border:SetTexture(0.5, 0.5, 0.5, 0.3)
		border:SetPoint("TOPLEFT", bg, -1, 1)
		border:SetPoint("BOTTOMRIGHT", bg, 1, -1)

		frame.tabs = {}
		frame.CreateTab = createTab
		frame.SelectTab = selectTab
		frame.GetSelectedTab = getSelectedTab
		
		return frame
	end
end

do	-- popup
	local function onShow(self)
		self.button1:Disable()
	end
	
	local function editBoxOnEnterPressed(self, data)
		local parent = self:GetParent()
		if parent.button1:IsEnabled() then
			StaticPopupDialogs[parent.which].OnAccept(parent, data)
			parent:Hide()
		end
	end
	
	local function editBoxOnEscapePressed(self)
		self:GetParent():Hide()
	end
	
	local function editBoxOnTextChanged(self)
		local parent = self:GetParent()
		parent.button1:SetEnabled(parent.editBox:GetText():trim() ~= "")
	end
	
	function addon:CreatePopup(which, info, editBox)
		StaticPopupDialogs[which] = info
		info.hideOnEscape = true
		info.whileDead = true
		if editBox then
			info.button1 = ACCEPT
			info.button2 = CANCEL
			info.hasEditBox = true
			info.OnShow = onShow
			info.EditBoxOnEnterPressed = editBoxOnEnterPressed
			info.EditBoxOnEscapePressed = editBoxOnEscapePressed
			info.EditBoxOnTextChanged = editBoxOnTextChanged
		end
	end
end
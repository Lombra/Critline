local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local templates = {}
addon.templates = templates

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
	
	function templates:CreateConfigFrame(name, addTitle, addDesc, isParent, frame)
		frame = frame or CreateFrame("Frame")
		frame.name = name
		if not isParent then
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
end

do	-- check button
	local function onClick(self)
		local checked = self:GetChecked() ~= nil
		
		if checked then
			PlaySound("igMainMenuOptionCheckBoxOn")
		else
			PlaySound("igMainMenuOptionCheckBoxOff")
		end
		
		self.module[self.db].profile[self.setting] = checked
		
		if self.func then
			self:func(self.module)
		end
		
		addon:Debug(self.setting..(checked and " on" or " off"))
	end
	
	local function loadSetting(self)
		self:SetChecked(self.module[self.db].profile[self.setting])
		if self.func then
			self:func(self.module)
		end
	end

	function templates:CreateCheckButton(parent, data)
		local btn = CreateFrame("CheckButton", nil, parent, "OptionsBaseCheckButtonTemplate")
		btn:SetPushedTextOffset(0, 0)
		btn:SetScript("OnClick", onClick)
		
		btn.LoadSetting = loadSetting
		
		local text = btn:CreateFontString(nil, nil, "GameFontHighlight")
		text:SetPoint("LEFT", btn, "RIGHT", 0, 1)
		btn:SetFontString(text)
		
		if data then
			btn:SetText(data.text)
			data.text = nil
			data.db = data.perchar and "percharDB" or "db"
			data.perchar = nil
			for k, v in pairs(data) do
				btn[k] = v
			end
		end

		return btn
	end
end

do	-- slider template
	local backdrop = {
		bgFile = [[Interface\Buttons\UI-SliderBar-Background]],
		edgeFile = [[Interface\Buttons\UI-SliderBar-Border]],
		tile = true, tileSize = 8, edgeSize = 8,
		insets = {left = 3, right = 3, top = 6, bottom = 6}
	}
	
	local function onEnter(self)
		if self:IsEnabled() then
			if self.tooltipText then
				GameTooltip:SetOwner(self, self.tooltipOwnerPoint or "ANCHOR_RIGHT")
				GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
			end
		end
	end
	
	function templates:CreateSlider(parent, data)
		local slider = CreateFrame("Slider", nil, parent)
		slider:EnableMouse(true)
		slider:SetSize(144, 17)
		slider:SetOrientation("HORIZONTAL")
		slider:SetHitRectInsets(0, 0, -10, -10)
		slider:SetBackdrop(backdrop)
		slider:SetScript("OnEnter", onEnter)
		slider:SetScript("OnLeave", GameTooltip_Hide)
		
		local text = slider:CreateFontString(nil, nil, "GameFontNormal")
		text:SetPoint("BOTTOM", slider, "TOP")
		slider.text = text
		
		local min = slider:CreateFontString(nil, nil, "GameFontHighlightSmall")
		min:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, 3)
		slider.min = min
		
		local max = slider:CreateFontString(nil, nil, "GameFontHighlightSmall")
		max:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 4, 3)
		slider.max = max
		
		if data then
			slider:SetMinMaxValues(data.minValue, data.maxValue)
			slider:SetValueStep(data.valueStep)
			slider:SetScript("OnValueChanged", data.func)
			text:SetText(data.text)
			min:SetText(data.minText or data.minValue)
			max:SetText(data.maxText or data.maxValue)
			slider.tooltipText = data.tooltipText
		end
		
		-- font string for current value
		local value = slider:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		value:SetPoint("CENTER", 0, -15)
		slider.value = value
		
		local thumb = slider:CreateTexture()
		thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
		thumb:SetSize(32, 32)
		slider:SetThumbTexture(thumb)
		
		return slider
	end
end

do	-- swatch button template
	local ColorPickerFrame = ColorPickerFrame
	
	local function swatchFunc()
		local button = ColorPickerFrame.extraInfo
		local r, g, b = ColorPickerFrame:GetColorRGB()
		button.swatch:SetVertexColor(r, g, b)
		if button.func then button:func(r, g, b) end
		local color = button.color
		color.r = r
		color.g = g
		color.b = b
	end

	local function cancelFunc(prev)
		local button = ColorPickerFrame.extraInfo
		local r, g, b, a = prev.r, prev.g, prev.b, prev.opacity
		button.swatch:SetVertexColor(r, g, b)
		if button.func then button:func(r, g, b) end
		local color = button.color
		color.r = r
		color.g = g
		color.b = b
	end

	-- local function opacityFunc()
		-- local button = ColorPickerFrame.extraInfo
		-- local alpha = 1.0 - OpacitySliderFrame:GetValue()
		-- if button.opacityFunc then button:opacityFunc(alpha) end
	-- end
	
	local function onClick(self)
		local info = UIDropDownMenu_CreateInfo()
		local color = self.color
		info.r, info.g, info.b = color.r, color.g, color.b
		info.swatchFunc = swatchFunc
		-- info.hasOpacity = self.hasOpacity
		-- info.opacityFunc = opacityFunc
		-- info.opacity = color.a
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

	function templates:CreateColorButton(parent)
		local btn = CreateFrame("Button", nil, parent)
		btn:SetSize(16, 16)
		btn:SetPushedTextOffset(0, 0)
		
		btn:SetNormalTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
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
		
		btn:SetScript("OnClick", onClick)
		btn:SetScript("OnEnter", onEnter)
		btn:SetScript("OnLeave", onLeave)
		
		return btn
	end
end

do	-- editbox
	function templates:CreateEditBox(parent)
		local editbox = CreateFrame("EditBox", nil, parent)
		editbox:SetAutoFocus(false)
		editbox:SetHeight(20)
		editbox:SetFontObject("ChatFontNormal")
		editbox:SetTextInsets(5, 0, 0, 0)

		local left = editbox:CreateTexture("BACKGROUND")
		left:SetTexture("Interface\\Common\\Common-Input-Border")
		left:SetTexCoord(0, 0.0625, 0, 0.625)
		left:SetWidth(8)
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT")

		local right = editbox:CreateTexture("BACKGROUND")
		right:SetTexture("Interface\\Common\\Common-Input-Border")
		right:SetTexCoord(0.9375, 1, 0, 0.625)
		right:SetWidth(8)
		right:SetPoint("TOPRIGHT")
		right:SetPoint("BOTTOMRIGHT")

		local mid = editbox:CreateTexture("BACKGROUND")
		mid:SetTexture("Interface\\Common\\Common-Input-Border")
		mid:SetTexCoord(0.0625, 0.9375, 0, 0.625)
		mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
		mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
		
		return editbox
	end
end

do	-- dropdown menu frame
	local function setSelectedValue(self, value)
		UIDropDownMenu_SetSelectedValue(self, value)
		UIDropDownMenu_SetText(self, self.menu and self.menu[value] or value)
	end
	
	local function setDisabled(self, disable)
		if disable then
			self:Disable()
		else
			self:Enable()
		end
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
			UIDropDownMenu_AddButton(info)
		end
	end
	
	function templates:CreateDropDownMenu(name, parent, menu, valueLookup)
		local frame = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
		
		frame.SetFrameWidth = UIDropDownMenu_SetWidth
		frame.SetSelectedValue = setSelectedValue
		frame.GetSelectedValue = UIDropDownMenu_GetSelectedValue
		frame.Refresh = UIDropDownMenu_Refresh
		frame.SetText = UIDropDownMenu_SetText
		frame.Enable = UIDropDownMenu_EnableDropDown
		frame.Disable = UIDropDownMenu_DisableDropDown
		frame.SetDisabled = setDisabled
		frame.JustifyText = UIDropDownMenu_JustifyText
		
		if menu then
			for _, v in ipairs(menu) do
				menu[v.value] = v.text
			end
		end
		frame.menu = menu or valueLookup
		
		frame.initialize = initialize
		
		local label = frame:CreateFontString(name.."Label", "BACKGROUND", "GameFontNormalSmall")
		label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 16, 3)
		frame.label = label
		
		return frame
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
			if i == tabIndex then
				tab:Disable()
				tab:SetHeight(20)
				tab.bg:SetTexture(0.3, 0.3, 0.3)
				if tab.frame then
					tab.frame:Show()
				end
			else
				tab:Enable()
				tab:SetHeight(16)
				tab.bg:SetTexture(0.7, 0.7, 0.7)
				if tab.frame then
					tab.frame:Hide()
				end
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
	
	local function createTab(frame)
		local tab = CreateFrame("Button", nil, frame)
		tab:SetSize(64, 20)
		tab:SetNormalFontObject(GameFontNormalSmall)
		tab:SetHighlightFontObject(GameFontHighlightSmall)
		tab:SetDisabledFontObject(GameFontHighlightSmall)
		local highlight = tab:CreateTexture()
		highlight:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-Tab-Highlight]])
		highlight:SetPoint("BOTTOMLEFT", -2, -6)
		highlight:SetPoint("TOPRIGHT", 2, 6)
		tab:SetHighlightTexture(highlight)
		tab:SetScript("OnClick", onClick)
		tab.SetLabel = setLabel
		tab.container = frame

		local index = #frame.tabs + 1
		if index == 1 then
			tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 6, 1)
		else
			tab:SetPoint("BOTTOMLEFT", frame.tabs[index - 1], "BOTTOMRIGHT", 6, 0)
		end
		tab:SetID(index)
		frame.tabs[index] = tab
		
		local bg = tab:CreateTexture(nil, "BORDER")
		bg:SetTexture(0.3, 0.3, 0.3)
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
	
	function templates:CreateTabInterface(parent)
		local frame = CreateFrame("Frame", nil, parent)
		
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
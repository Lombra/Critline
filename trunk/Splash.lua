local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM = LibStub("LibSharedMedia-3.0")

local splash = CreateFrame("MessageFrame", nil, UIParent)
splash:SetMovable(true)
splash:RegisterForDrag("LeftButton")
splash:SetSize(512, 96)
splash:SetScript("OnMouseUp", function(self, button)
	if button == "RightButton" then
		if self.profile.enabled then
			addon.RegisterCallback(splash, "NewRecord")
		end
		self:SetFrameStrata("MEDIUM")
		self.hitRect:Hide()
		self:EnableMouse(false)
		self:SetFading(true)
		self:Clear()
	end
end)
splash:EnableMouse(false)
splash:SetScript("OnDragStart", splash.StartMoving)
splash:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local pos = self.profile.pos
	pos.point, pos.x, pos.y = select(3, self:GetPoint())
end)

local hitRect = splash:CreateTexture()
hitRect:SetTexture(0, 1, 0, 0.3)
hitRect:SetAllPoints()
hitRect:Hide()
splash.hitRect = hitRect

local config = addon:AddCategory(L["Splash frame"], true)

do
	local options = {
		{
			type = "CheckButton",
			label = L["Enabled"],
			tooltipText = L["Shows the new record on the middle of the screen."],
			setting = "enabled",
			func = function(self, checked)
				if checked then
					if not splash:IsMouseEnabled() then
						addon.RegisterCallback(splash, "NewRecord")
					end
				else
					addon.UnregisterCallback(splash, "NewRecord")
				end
			end,
		},
		{
			type = "CheckButton",
			label = L["Use combat text splash"],
			tooltipText = L["Enable to use scrolling combat text for \"New record\" messages instead of the default splash frame."],
			setting = "sct",
		},
		{
			type = "ColorButton",
			label = L["Spell color"],
			tooltipText = L["Sets the color for the spell text in the splash frame."],
			setting = "spellColor",
		},
		{
			type = "ColorButton",
			label = L["Amount color"],
			tooltipText = L["Sets the color for the amount text in the splash frame."],
			setting = "amountColor",
		},
		{
			type = "Slider",
			label = L["Scale"],
			tooltipText = L["Sets the scale of the splash frame."],
			setting = "scale",
			minValue = 0.5,
			maxValue = 1,
			valueStep = 0.05,
			isPercent = true,
			func = function(self, value)
				local os = splash:GetScale()
				splash:SetScale(value)
				local point, relativeTo, relativePoint, xOff, yOff = splash:GetPoint()
				splash:SetPoint(point, relativeTo, relativePoint, (xOff*os/value), (yOff*os/value))
			end,
		},
		{
			type = "Slider",
			label = L["Duration"],
			tooltipText = L["Sets the time (in seconds) the splash frame is visible before fading out."],
			setting = "duration",
			minValue = 0,
			maxValue = 5,
			valueStep = 0.5,
			func = "SetTimeVisible",
		},
		{
			type = "Slider",
			label = L["Fade duration"],
			tooltipText = L["Sets the time between the splash frame starting to fade and being fully faded out."],
			setting = "fadeDuration",
			minValue = 0,
			maxValue = 5,
			valueStep = 0.5,
			func = "SetFadeDuration",
		},
		{
			newColumn = true,
			type = "DropDownMenu",
			label = L["Font"],
			setting = "fontFace",
			width = 120,
			func = "UpdateFont",
			initialize = function(self)
				for _, v in ipairs(LSM:List("font")) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = v
					info.func = self.onClick
					info.owner = self
					UIDropDownMenu_AddButton(info)
				end
			end,
		},
		{
			type = "DropDownMenu",
			label = L["Font outline"],
			setting = "fontFlags",
			width = 120,
			func = "UpdateFont",
			menu = {
				{text = L["None"],   value = ""},
				{text = L["Normal"], value = "OUTLINE"},
				{text = L["Thick"],  value = "THICKOUTLINE"},
			}
		},
		{
			type = "Slider",
			label = L["Font size"],
			tooltipText = L["Sets the font size of the splash frame."],
			setting = "fontSize",
			minValue = 8,
			maxValue = 30,
			valueStep = 1,
			func = "UpdateFont",
		},
	}

	config:CreateOptions(options, splash)

	local moveSplash = CreateFrame("Button", nil, config, "UIPanelButtonTemplate")
	moveSplash:SetPoint("TOP", config.registry.fadeDuration, "BOTTOM", 0, -24)
	moveSplash:SetSize(96, 22)
	moveSplash:SetText(UNLOCK)
	moveSplash:SetScript("OnClick", function()
		-- don't want to be interrupted by new records
		addon.UnregisterCallback(splash, "NewRecord")
		splash:SetFrameStrata("FULLSCREEN")
		splash.hitRect:Show()
		splash:EnableMouse(true)
		splash:SetFading(false)
		splash:Clear()
		splash:AddMessage(L["Critline splash frame unlocked"], splash.profile.spellColor)
		splash:AddMessage(L["Drag to move"], splash.profile.amountColor)
		splash:AddMessage(L["Right-click to lock"], splash.profile.amountColor)
	end)
end

local defaults = {
	profile = {
		enabled = true,
		sct = false,
		scale = 1,
		duration = 2,
		fadeDuration = 3,
		fontFace = "Skurri",
		fontSize = 30,
		fontFlags = "OUTLINE",
		spellColor  = {r = 1, g = 1, b = 0},
		amountColor = {r = 1, g = 1, b = 1},
		pos = {
			point = "CENTER"
		},
	}
}

function splash:AddonLoaded()
	self.db = addon.db:RegisterNamespace("splash", defaults)
	addon.RegisterCallback(self, "SettingsLoaded", "LoadSettings")
	
	-- convert from < 4.4.0
	for k, profile in pairs(self.db.profiles) do
		local font = profile.font
		if font then
			profile.fontFace = font.name
			profile.fontSize = font.size
			profile.fontFlags = font.flags
			profile.font = nil
		end
		
		if profile.colors then
			for k, v in pairs(profile.colors) do
				profile[k.."Color"] = v
			end
			profile.colors = nil
		end
	end
end

addon.RegisterCallback(splash, "AddonLoaded")

function splash:LoadSettings()
	self.profile = self.db.profile
	
	local pos = self.profile.pos
	self:ClearAllPoints()
	self:SetPoint(pos.point, pos.x, pos.y)
	-- need to set scale separately first to ensure proper positioning
	self:SetScale(self.profile.scale)
	
	config:LoadOptions(self)
	
	LSM.RegisterCallback(self, "LibSharedMedia_Registered", "UpdateFont")
	LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", "UpdateFont")
end

local addMessage = splash.AddMessage

function splash:AddMessage(msg, color, ...)
	addMessage(self, msg, color.r, color.g, color.b, ...)
end

local red1 = {r = 1, g = 0, b = 0}
local red255 = {r = 255, g = 0, b = 0}

function splash:NewRecord(event, tree, spellID, spellName, periodic, amount, crit, prevRecord, isFiltered)
	if isFiltered then
		return
	end
	
	spell = format(L["New %s record!"], addon:GetFullSpellName(spellName, periodic, true))
	amount = addon:ShortenNumber(amount)
	if addon.db.profile.oldRecord and prevRecord.amount > 0 then
		amount = format("%s (%s)", amount, addon:ShortenNumber(prevRecord.amount))
	end
	
	local spellColor = self.profile.spellColor
	local amountColor = self.profile.amountColor
	
	if self.profile.sct then
		-- check if any custom SCT addon is loaded and use it accordingly
		if MikSBT then
			if crit then
				MikSBT.DisplayMessage(L["Critical!"], nil, true, 255, 0, 0)
			end
			MikSBT.DisplayMessage(spell, nil, true, spellColor.r * 255, spellColor.g * 255, spellColor.b * 255)
			MikSBT.DisplayMessage(amount, nil, true, amountColor.r * 255, amountColor.g * 255, amountColor.b * 255)
		elseif SCT then
			if crit then
				SCT:DisplayMessage(L["Critical!"], red255)
			end
			SCT:DisplayMessage(spell, spellColor)
			SCT:DisplayMessage(amount, amountColor)
		elseif Parrot then
			local Parrot = Parrot:GetModule("Display")
			Parrot:ShowMessage(amount, nil, true, amountColor.r, amountColor.g, amountColor.b)
			Parrot:ShowMessage(spell, nil, true, spellColor.r, spellColor.g, spellColor.b)
			if crit then
				Parrot:ShowMessage(L["Critical!"], nil, true, 1, 0, 0)
			end
		elseif SHOW_COMBAT_TEXT == "1" then
			CombatText_AddMessage(amount, CombatText_StandardScroll, amountColor.r, amountColor.g, amountColor.b)
			CombatText_AddMessage(spell, CombatText_StandardScroll, spellColor.r, spellColor.g, spellColor.b)
			if crit then
				CombatText_AddMessage(L["Critical!"], CombatText_StandardScroll, 1, 0, 0)
			end
		end
	else
		self:Clear()
		if crit then
			self:AddMessage(L["Critical!"], red1)
		end
		self:AddMessage(spell, spellColor)
		self:AddMessage(amount, amountColor)
	end
end

function splash:UpdateFont()
	self:SetFont(LSM:Fetch("font", self.profile.fontFace), self.profile.fontSize, self.profile.fontFlags)
end
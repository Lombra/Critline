local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local FRAME_WIDTH = 128
local FRAME_WIDTH_WIDE = 160
local FRAME_HEIGHT = 24
local FRAME_HEIGHT_WIDE = 16

local height = FRAME_HEIGHT

local display = CreateFrame("Frame", nil, UIParent)
addon.display = display
display:SetMovable(true)
display:SetBackdrop({
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 12,
})
display:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

Critline.SlashCmdHandlers["reset"] = function()
	display:ClearAllPoints()
	display:SetPoint("CENTER")
end

local function onDragStart(self)
	display:StartMoving()
end

local function onDragStop(self)
	display:StopMovingOrSizing()
	local pos = display.profile.pos
	pos.point, pos.x, pos.y = select(3, display:GetPoint())
end

local function onEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
	addon:ShowTooltip(self.tree)
	if not display.profile.locked then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Drag to move"], GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	end
	GameTooltip:Show()
end

local backdrop = {
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
	insets = {left = -1, right = -1, top = -1, bottom = -1},
}

local trees = {}

for k, tree in pairs(addon.trees) do
	local frame = CreateFrame("Frame", nil, display)
	frame:SetFrameStrata("LOW")
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetPoint("LEFT", 4, 0)
	frame:SetPoint("RIGHT", -4, 0)
	frame:SetBackdrop(backdrop)
	frame:SetScript("OnDragStart", onDragStart)
	frame:SetScript("OnDragStop", onDragStop)
	frame:SetScript("OnEnter", onEnter)
	frame:SetScript("OnLeave", GameTooltip_Hide)
	frame.tree = k
	
	local text = frame:CreateFontString(nil, nil, "GameFontHighlightSmall")
	text:SetPoint("CENTER", frame, "RIGHT", -48, 0)
	frame.text = text
	
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetSize(20, 20)
	icon:SetPoint("LEFT", 2, 0)
	icon:SetTexture(tree.icon)
	frame.icon = icon
	
	local label = frame:CreateFontString(nil, nil, "GameFontHighlightSmall")
	label:SetPoint("LEFT", 4, 0)
	label:SetText(tree.title..":")
	frame.label = label
	
	trees[k] = frame
end

trees.dmg:SetPoint("TOP", 0, -4)

local config = addon:AddCategory("Display", true)

do
	local function swatchFunc(self, color)
		trees[self.setting:sub(1, -3)]:SetBackdropColor(color.r, color.g, color.b, display.profile.bgAlpha)
	end

	local options = {
		{
			type = "CheckButton",
			label = L["Show"],
			tooltipText = L["Show summary frame."],
			setting = "show",
			func = "UpdateLayout",
		},
		{
			type = "CheckButton",
			label = L["Locked"],
			tooltipText = L["Lock summary frame."],
			setting = "locked",
			func = function(self, checked)
				for _, tree in pairs(trees) do
					tree:RegisterForDrag(not checked and "LeftButton")
				end
			end,
		},
		{
			type = "CheckButton",
			label = L["Show icons"],
			tooltipText = L["Enable to show icon indicators instead of text."],
			setting = "icons",
			func = function(self, checked)
				display:SetWidth(checked and FRAME_WIDTH or FRAME_WIDTH_WIDE)
				height = checked and FRAME_HEIGHT or FRAME_HEIGHT_WIDE
				for _, tree in pairs(trees) do
					if checked then
						tree.icon:Show()
						tree.label:Hide()
					else
						tree.icon:Hide()
						tree.label:Show()
					end
					tree:SetHeight(height)
				end
				display:UpdateLayout()
			end,
		},
		{
			type = "Slider",
			label = L["Scale"],
			tooltipText = L["Sets the scale of the display."],
			setting = "scale",
			minValue = 0.5,
			maxValue = 2,
			valueStep = 0.05,
			isPercent = true,
			func = function(self, value)
				local os = display:GetScale()
				display:SetScale(value)
				local point, relativeTo, relativePoint, xOffset, yOffset = display:GetPoint()
				display:SetPoint(point, relativeTo, relativePoint, (xOffset * os / value), (yOffset * os / value))
			end,
		},
		{
			type = "Slider",
			label = L["Opacity"],
			tooltipText = L["Sets the opacity of the display."],
			setting = "alpha",
			minValue = 0,
			maxValue = 1,
			valueStep = 0.05,
			isPercent = true,
			func = "SetAlpha",
		},
		{
			type = "Slider",
			label = L["Backdrop opacity"],
			tooltipText = L["Sets the opacity of the display backdrop."],
			setting = "bgAlpha",
			minValue = 0,
			maxValue = 1,
			valueStep = 0.05,
			isPercent = true,
			func = function(self, value)
				for k, v in pairs(trees) do
					local color = display.profile[k.."Bg"]
					v:SetBackdropColor(color.r, color.g, color.b, value)
				end
			end,
		},
		{
			type = "Slider",
			label = L["Border opacity"],
			tooltipText = L["Sets the opacity of the display border."],
			setting = "borderAlpha",
			minValue = 0,
			maxValue = 1,
			valueStep = 0.05,
			isPercent = true,
			func = function(self, value)
				display:SetBackdropBorderColor(0.5, 0.5, 0.5, value)
			end,
		},
	}

	-- inject these separately for now since we're using the tree iteration
	for i, v in ipairs(addon.treeIndex) do
		tinsert(options, 3 + i, {
			type = "ColorButton",
			label = addon.trees[v].title,
			setting = v.."Bg",
			func = swatchFunc,
		})
	end

	config:CreateOptions(options, display)
end

local defaults = {
	profile = {
		show = true,
		locked = false,
		icons = true,
		scale = 1,
		alpha = 1,
		bgAlpha = 1,
		borderAlpha = 1,
		dmgBg  = {r = 0, g = 0, b = 0},
		healBg = {r = 0, g = 0, b = 0},
		petBg  = {r = 0, g = 0, b = 0},
		pos = {
			point = "CENTER",
		},
	}
}

function display:AddonLoaded()
	self.db = addon.db:RegisterNamespace("display", defaults)
	addon.RegisterCallback(self, "SettingsLoaded")
	addon.RegisterCallback(self, "OnNewTopRecord", "UpdateRecords")
	addon.RegisterCallback(self, "FormatChanged", "UpdateRecords")
	addon.RegisterCallback(self, "OnTreeStateChanged", "UpdateTree")
	
	-- convert from < 4.4.0
	for k, profile in pairs(self.db.profiles) do
		if profile.colors then
			for k, v in pairs(profile.colors) do
				profile[k.."Bg"] = v
			end
			profile.colors = nil
		end
	end
end

addon.RegisterCallback(display, "AddonLoaded")

function display:SettingsLoaded()
	self.profile = self.db.profile
	
	-- restore stored position
	local pos = self.profile.pos
	self:ClearAllPoints()
	self:SetPoint(pos.point, pos.x, pos.y)
	-- need to set scale separately first to ensure proper positioning
	self:SetScale(self.profile.scale)
	
	config:LoadOptions(self)
end

function display:UpdateRecords(event, tree)
	if tree then
		local normal, crit = addon:GetHighest(tree)
		trees[tree].text:SetFormattedText("%8s / %-8s", addon:ShortenNumber(normal), addon:ShortenNumber(crit))
	else
		for k in pairs(addon.trees) do
			self:UpdateRecords(nil, k)
		end
	end
end

function display:UpdateTree(event, tree, enabled)
	if enabled then
		trees[tree]:Show()
	else
		trees[tree]:Hide()
	end
	self:UpdateLayout()
end

function display:Toggle()
	local show = not self.profile.show
	self.profile.show = show
	config.registry.show:SetChecked(show)
	self:UpdateLayout()
end

-- rearrange display buttons when any of them is shown or hidden
function display:UpdateLayout()
	local shown = {}
	for k, v in ipairs(addon.treeIndex) do
		local frame = trees[v]
		if frame:IsShown() then
			local prevShown = shown[#shown]
			if prevShown then
				frame:SetPoint("TOP", prevShown, "BOTTOM", 0, -2)
			else
				frame:SetPoint("TOP", 0, -4)
			end
			tinsert(shown, frame)
		end
	end
	
	self:SetHeight(#shown * (height + 2) + 6)
	
	-- hide the entire frame if it turns out none of the individual frames are shown
	if #shown == 0 or not self.profile.show then
		self:Hide()
	else
		self:Show()
	end
end
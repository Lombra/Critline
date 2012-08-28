local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local function onUpdate(self)
	local xpos, ypos = GetCursorPosition()
	local xmin, ymin = Minimap:GetCenter()
	
	xpos = xpos / Minimap:GetEffectiveScale() - xmin
	ypos = ypos / Minimap:GetEffectiveScale() - ymin
	
	local pos = atan2(ypos, xpos)
	self.db.profile.pos = pos
	self:Move(pos)
end

local minimap = CreateFrame("Button", "CritlineMinimapButton", Minimap)
minimap:SetToplevel(true)
minimap:SetMovable(true)
minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimap:RegisterForDrag("LeftButton")
minimap:SetSize(32, 32)
minimap:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
minimap:SetFrameLevel(8)
minimap:Hide()
minimap:SetScript("OnClick", function(self, button)
	local display = addon.display
	if button == "LeftButton" and display then
		display:Toggle()
	elseif button == "RightButton" then
		addon:OpenConfig()
	end
end)
minimap:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Critline")
	if addon.display then
		GameTooltip:AddLine(L["Left-click to toggle summary frame"], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	GameTooltip:AddLine(L["Right-click to open options"], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if not self.db.profile.locked then
		GameTooltip:AddLine(L["Drag to move"], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	GameTooltip:Show()
end)
minimap:SetScript("OnLeave", GameTooltip_Hide)
minimap:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onUpdate) end)
minimap:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
minimap:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)

local icon = minimap:CreateTexture()
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 6, -6)
icon:SetTexture(addon.trees.dmg.icon)

local border = minimap:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")
border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])

local config = addon:AddCategory(L["Minimap"], true)

local options = {
	{
		type = "CheckButton",
		label = L["Show"],
		tooltipText = L["Show minimap button."],
		setting = "show",
		func = function(self, checked)
			minimap:SetShown(checked)
		end,
	},
	{
		type = "CheckButton",
		label = L["Locked"],
		tooltipText = L["Lock minimap button."],
		setting = "locked",
		func = function(self, checked)
			minimap:RegisterForDrag(not checked and "LeftButton")
		end,
	},
}

config:CreateOptions(options, minimap)

local defaults = {
	profile = {
		show = true,
		locked = false,
		pos = 225,
	}
}

function minimap:AddonLoaded()
	self.db = addon.db:RegisterNamespace("minimap", defaults)
	addon.RegisterCallback(self, "SettingsLoaded", "LoadSettings")
end

addon.RegisterCallback(minimap, "AddonLoaded")

function minimap:LoadSettings()
	config:LoadOptions(self)
	self:Move(self.db.profile.pos)
end

function minimap:Move(angle)
	self:SetPoint("CENTER", 80 * cos(angle), 80 * sin(angle))
end
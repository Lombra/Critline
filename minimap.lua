local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local function onUpdate(self)
	local xpos, ypos = GetCursorPosition()
	local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
	
	xpos = xmin - xpos / Minimap:GetEffectiveScale() + 70
	ypos = ypos / Minimap:GetEffectiveScale() - ymin - 70
	
	local pos = atan2(ypos, xpos)
	self.db.profile.pos = pos
	self:Move(pos)
end

local minimap = CreateFrame("Button", "CritlineMinimapButton", Minimap)
minimap:SetToplevel(true)
minimap:SetMovable(true)
minimap:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimap:RegisterForDrag("LeftButton")
minimap:SetPoint("TOPLEFT", -15, 0)
minimap:SetSize(32, 32)
minimap:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
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

local icon = minimap:CreateTexture(nil, "BORDER")
icon:SetTexture(addon.trees.dmg.icon)
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 6, -6)

local border = minimap:CreateTexture(nil, "OVERLAY")
border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

local config = addon:AddCategory(L["Minimap button"], true)

local options = {
	{
		type = "CheckButton",
		label = L["Show"],
		tooltipText = L["Show minimap button."],
		setting = "show",
		func = function(self, checked)
			if checked then
				minimap:Show()
			else
				minimap:Hide()
			end
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
		pos = 0,
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
	self:SetPoint("TOPLEFT", (52 - 80 * cos(angle)), (80 * sin(angle) - 52))
end
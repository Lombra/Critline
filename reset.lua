local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

assert(addon.spellList, "Reset module requires spellList module.")

-- history for undoing recent (last fight) records
local history = {
	dmg  = {},
	heal = {},
	pet  = {},
}

local module = CreateFrame("Frame")
module:RegisterEvent("PLAYER_REGEN_DISABLED")
module:SetScript("OnEvent", function(self)
	-- previous records are wiped upon entering combat
	self:ClearHistory()
end)

-- reset/announce button
local button = CreateFrame("Button", nil, addon.spellList, "UIPanelButtonTemplate")
button:SetPoint("BOTTOMRIGHT", CritlineSpellsScrollFrame, "TOPRIGHT", 0, 8)
button:SetSize(100, 22)
button:SetText(L["Reset all"])
button:SetScript("OnClick", function(self)
	PlaySound("gsTitleOptionOK")
	local tree = addon.spellList:GetSelectedTree()
	StaticPopup_Show("CRITLINE_RESET_ALL", addon.trees[tree].label, nil, tree)
end)

-- "edit tooltip format" popup
StaticPopupDialogs["CRITLINE_RESET_ALL"] = {
	text = L["Are you sure you want to reset all %s records?"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(self, data)
		module:ResetAll(data)
	end,
	hideOnEscape = true,
	whileDead = true,
	timeout = 0,
}

local colorFormat = GREEN_FONT_COLOR_CODE.."%s"..FONT_COLOR_CODE_CLOSE

addon.spellList:SetSpellColorMod(function(data, tree, hitType)
	local prevRecord = addon:GetPreviousRecord(data, tree)
	if prevRecord and prevRecord[hitType] then
		return colorFormat
	end
end)

-- since dropdowns doesn't accept .disabled as a function, do some magics
local mt = {
	__index = function(tbl, key)
		if key == "disabled" then
			return not addon:GetPreviousRecord(tbl.value, tbl.arg1)
		end
	end
}

addon.spellList:AddSpellOption(setmetatable({
	text = L["Revert"],
	func = function(self, tree)
		local data = self.value
		local history = history[tree][data.spellID]
		local spell = addon:GetSpellInfo(tree, data.spellID, data.periodic)
		for k, v in pairs(history[data.periodic]) do
			local hitType = spell[k]
			local amount, target = hitType.amount, hitType.target
			for k, v in pairs(v) do
				hitType[k] = v
			end
			addon:Message(format("Reverted %s (%d, %s) record on %s.", data.spellName, amount, tree, target))
		end
		history[data.periodic] = nil
		addon:UpdateTopRecords(tree)
		addon:UpdateRecords(tree)
	end,
	notCheckable = true,
}, mt))

addon.spellList:AddSpellOption({
	text = L["Reset"],
	func = function(self, tree)
		local data = self.value
		addon:DeleteSpell(tree, data.spellID, data.periodic)
		local history = history[tree][data.spellID]
		if history then
			history[data.periodic] = nil
		end
		addon:UpdateSpells(tree)
	end,
	notCheckable = true,
})

function addon:GetPreviousRecord(data, tree)
	local prevRecord = history[tree][data.spellID]
	return prevRecord and prevRecord[data.periodic]
end

function module:ResetAll(tree)
	wipe(addon.percharDB.profile.spells[tree])
	wipe(addon:GetSpellArray(tree))
	addon:Message(format(L["Reset all %s records."], tree))
	addon:UpdateTopRecords(tree)
	addon:UpdateSpells(tree)
end

-- stores previous record for the undo feature
function module:NewRecord(event, tree, spellID, periodic, amount, crit, prevRecord)
	-- do not store previous record if it was 0
	if prevRecord.amount == 0 then
		return
	end
	
	history[tree][spellID] = history[tree][spellID] or {}
	local hitType = crit and "crit" or "normal"
	local spell = history[tree][spellID]
	spell[periodic] = spell[periodic] or {}
	-- do not store previous records gained in current fight
	if spell[periodic][hitType] then
		return
	else
		spell[periodic][hitType] = {}
	end
	for k, v in pairs(prevRecord) do
		spell[periodic][hitType][k] = v
	end
	addon:Debug(format("Storing previous record for %s = %d (%s, %s, %s)",
						addon:GetSpellName(spellID), prevRecord.amount, tree, periodic == 2 and "periodic" or "direct", hitType))
end

addon.RegisterCallback(module, "NewRecord")

function module:ClearHistory()
	for k, tree in pairs(history) do
		wipe(tree)
	end
	addon.callbacks:Fire("HistoryCleared")
end

addon.RegisterCallback(module, "PerCharSettingsLoaded", "ClearHistory")
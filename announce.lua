local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

assert(addon.spellList, "Announce module requires spellList module.")

local lastTarget = ""

local announceFormat = format("%%s - %s: %%s %s: %%s", L["Normal"], L["Crit"])

local function announce(data, channel, target)
	local normal = data.normal and addon:ShortenNumber(data.normal.amount)
	local crit = data.crit and addon:ShortenNumber(data.crit.amount)
	local text = format(announceFormat, addon:GetFullSpellName(data.spellID, data.periodic, true), (normal or "-"), (crit or "-"))
	SendChatMessage(text, channel, nil, target)
end

local targetChannels = {
	WHISPER = "CRITLINE_ANNOUNCE_WHISPER",
	CHANNEL = "CRITLINE_ANNOUNCE_CHANNEL",
}

local function onClick(self, tree, channel)
	local popup = targetChannels[channel]
	if popup then
		StaticPopup_Show(popup, nil, nil, self.value)
	else
		announce(self.value, channel)
	end
	CloseDropDownMenus()
end

local channels = {
	"SAY",
	"GUILD",
	"PARTY",
	"RAID",
	"WHISPER",
	"CHANNEL",
}

for i, v in ipairs(channels) do
	channels[i] = {
		text = _G[v],
		func = onClick,
		notCheckable = true,
		arg2 = v,
	}
end

addon.spellList:AddSpellOption({
	text = L["Announce"],
	hasArrow = true,
	notCheckable = true,
	menuList = channels,
})

local function onAccept(self, data)
	lastTarget = self.editBox:GetText()
	local target = lastTarget:trim()
	if target == "" then
		addon:Message(L["Invalid player name."])
		return
	else
		announce(data, "WHISPER", target)
	end
end

StaticPopupDialogs["CRITLINE_ANNOUNCE_WHISPER"] = {
	text = L["Enter whisper target"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	OnAccept = onAccept,
	EditBoxOnEnterPressed = function(self, data)
		local parent = self:GetParent()
		onAccept(parent, data)
		parent:Hide()
	end,
	OnShow = function(self, data)
		self.editBox:SetText(lastTarget)
		self.editBox:HighlightText()
	end,
	whileDead = true,
	timeout = 0,
}

local function onAccept(self, data)
	lastTarget = self.editBox:GetText()
	local target = GetChannelName(lastTarget:trim())
	target = target
	if target == 0 then
		addon:Message(L["Invalid channel. Please enter a valid channel name or ID."])
		return
	else
		announce(data, "CHANNEL", target)
	end
end

StaticPopupDialogs["CRITLINE_ANNOUNCE_CHANNEL"] = {
	text = ADD_CHANNEL,
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	OnAccept = onAccept,
	EditBoxOnEnterPressed = function(self, data)
		local parent = self:GetParent()
		onAccept(parent, data)
		parent:Hide()
	end,
	OnShow = function(self, data)
		self.editBox:SetText(lastTarget)
		self.editBox:HighlightText()
	end,
	whileDead = true,
	timeout = 0,
}
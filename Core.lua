local addonName, Critline = ...
_G.Critline = Critline

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM = LibStub("LibSharedMedia-3.0")
local _, playerClass = UnitClass("player")
local spellMappings, tooltipMappings, spellNameOverrides, spellIconOverrides
local debugging

-- debugging = true

-- auto attack spell
local AUTO_ATTACK_ID = 6603
local AUTO_ATTACK = GetSpellInfo(AUTO_ATTACK_ID)

-- local references to commonly used functions and variables for faster access
local floor, band, tonumber, format = floor, bit.band, tonumber, format
local CombatLog_Object_IsA = CombatLog_Object_IsA
local HasPetUI = HasPetUI
local GetSpellInfo = GetSpellInfo
local GetSpellLink = GetSpellLink
local IsPlayerSpell = IsPlayerSpell

local COMBATLOG_FILTER_MINE = COMBATLOG_FILTER_MINE
local COMBATLOG_FILTER_MY_PET = COMBATLOG_FILTER_MY_PET
local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER
local COMBATLOG_OBJECT_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN

local trees = {
	dmg  = {
		title = L["Damage"],
		label = L["damage"],
		icon = [[Interface\Icons\Ability_SteelMelee]],
	},
	heal = {
		title = L["Healing"],
		label = L["healing"],
		icon = [[Interface\Icons\Spell_Holy_FlashHeal]],
	},
	pet  = {
		title = L["Pet"],
		label = L["pet"],
		icon = [[Interface\Icons\Ability_Hunter_Pet_Bear]],
	},
}
Critline.trees = trees
Critline.treeIndex = {
	"dmg",
	"heal",
	"pet",
}

-- guardian type pets whose damage we may want to register
local classPets = {
	[89] = true, -- Infernal
	[11859] = true,	-- Doomguard
	[15438] = true,	-- Greater Fire Elemental
	[27829] = true, -- Ebon Gargoyle
	[29264] = true,	-- Spirit Wolf
}

local spellIDCache = {}

-- cache of spell ID -> spell name
local spellNameCache = {}

-- cache of spell textures
local spellTextureCache = {
	-- use a static icon for auto attack (otherwise uses your weapon's icon)
	[AUTO_ATTACK_ID] = [[Interface\Icons\INV_Sword_04]],
	[5019] = [[Interface\Icons\Ability_ShootWand]], -- Shoot (wand)
}

local swingDamage = function(amount, _, school, resisted, _, _, critical)
	return AUTO_ATTACK_ID, AUTO_ATTACK, amount, resisted, critical, school
end

local spellDamage = function(spellID, spellName, _, amount, _, school, resisted, _, _, critical)
	return spellID, spellName, amount, resisted, critical, school
end

local healing = function(spellID, spellName, _, amount, _, _, critical)
	return spellID, spellName, amount, 0, critical, 0
end

local absorb = function(spellID, spellName, _, _, amount)
	return spellID, spellName, amount, 0, critical, 0
end

local combatEvents = {
	SWING_DAMAGE = swingDamage,
	RANGE_DAMAGE = spellDamage,
	SPELL_DAMAGE = spellDamage,
	SPELL_PERIODIC_DAMAGE = spellDamage,
	SPELL_HEAL = healing,
	SPELL_PERIODIC_HEAL = healing,
	SPELL_AURA_APPLIED = absorb,
	SPELL_AURA_REFRESH = absorb,
}


-- alpha: sort by name
local alpha = function(a, b)
	if a == b then return end
	if a.name == b.name then
		if a.id == b.id then
			-- sort DoT entries after non DoT
			return a.periodic < b.periodic
		else
			return a.id < b.id
		end
	else
		return a.name < b.name
	end
end

-- normal: sort by normal > crit > name
local normal = function(a, b)
	if a == b then return end
	local normalA, normalB = (a.normal and a.normal.amount or 0), (b.normal and b.normal.amount or 0)
	if normalA == normalB then
		-- equal normal amounts, sort by crit amount instead
		local critA, critB = (a.crit and a.crit.amount or 0), (b.crit and b.crit.amount or 0)
		if critA == critB then
			-- equal crit amounts too, sort by name instead
			return alpha(a, b)
		else
			return critA > critB
		end
	else
		return normalA > normalB
	end
end

-- crit: sort by crit > normal > name
local crit = function(a, b)
	if a == b then return end
	local critA, critB = (a.crit and a.crit.amount or 0), (b.crit and b.crit.amount or 0)
	if critA == critB then
		return normal(a, b)
	else
		return critA > critB
	end
end

local recordSorters = {
	alpha = alpha,
	normal = normal,
	crit = crit,
}


local callbacks = LibStub("CallbackHandler-1.0"):New(Critline)
Critline.callbacks = callbacks


-- this will hold the text for the summary tooltip
local tooltips = {dmg = {}, heal = {}, pet = {}}

-- indicates whether a given tree will need to have its tooltip updated before next use
local doTooltipUpdate = {}

-- overall record for each tree
local topRecords = {
	dmg  = {normal = 0, crit = 0},
	heal = {normal = 0, crit = 0},
	pet  = {normal = 0, crit = 0},
}

-- sortable spell tables
local spellArrays = {dmg = {}, heal = {}, pet = {}}


LSM:Register("sound", "Level up", [[Sound\Interface\LevelUp.ogg]])


Critline.SlashCmdHandlers = {
	debug = function() Critline:ToggleDebug() end,
}

SlashCmdList.CRITLINE = function(msg)
	msg = msg:trim():lower()
	local slashCmdHandler = Critline.SlashCmdHandlers[msg]
	if slashCmdHandler then
		slashCmdHandler()
	else
		Critline:OpenConfig()
	end
end

SLASH_CRITLINE1 = "/critline"
SLASH_CRITLINE2 = "/cl"

-- tooltip for level scanning
local tooltip = CreateFrame("GameTooltip", "CritlineTooltip", nil, "GameTooltipTemplate")

Critline.eventFrame = CreateFrame("Frame")
function Critline:RegisterEvent(event)
	self.eventFrame:RegisterEvent(event)
end
function Critline:UnregisterEvent(event)
	self.eventFrame:UnregisterEvent(event)
end
Critline:RegisterEvent("ADDON_LOADED")
Critline:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Critline.eventFrame:SetScript("OnEvent", function(self, event, ...)
	return Critline[event] and Critline[event](Critline, ...)
end)

local config = Critline:CreateConfigFrame()

do
	local function toggleTree(self, checked)
		callbacks:Fire("OnTreeStateChanged", self.setting, checked)
	end
	
	-- summary sort dropdown
	local menu = {
		{
			text = L["Spell name"],
			value = "alpha",
		},
		{
			text = L["Normal record"],
			value = "normal",
		},
		{
			text = L["Crit record"],
			value = "crit",
		},
	}
	
	local options = {
		{
			type = "CheckButton",
			label = L["Record damage"],
			tooltipText = L["Check to enable damage events to be recorded."],
			setting = "dmg",
			perchar = true,
			func = toggleTree,
		},
		{
			type = "CheckButton",
			label = L["Record healing"],
			tooltipText = L["Check to enable healing events to be recorded."],
			setting = "heal",
			perchar = true,
			func = toggleTree,
		},
		{
			type = "CheckButton",
			label = L["Record pet damage"],
			tooltipText = L["Check to enable pet damage events to be recorded."],
			setting = "pet",
			perchar = true,
			func = toggleTree,
		},
		{
			type = "CheckButton",
			label = L["Record PvE"],
			tooltipText = L["Disable to ignore records where the target is an NPC."],
			setting = "PvE",
			gap = 8,
		},
		{
			type = "CheckButton",
			label = L["Record PvP"],
			tooltipText = L["Disable to ignore records where the target is a player."],
			setting = "PvP",
		},
		{
			type = "CheckButton",
			label = L["Ignore vulnerability"],
			tooltipText = L["Enable to ignore additional damage due to vulnerability."],
			setting = "ignoreVulnerability",
		},
		{
			newColumn = true,
			type = "CheckButton",
			label = L["Shorten records"],
			tooltipText = L["Use shorter format for record numbers."],
			setting = "shortFormat",
			func = function(self, checked)
				callbacks:Fire("FormatChanged")
				Critline:UpdateTooltips()
			end,
		},
		{
			type = "CheckButton",
			label = L["Records in spell tooltips"],
			tooltipText = L["Include (unfiltered) records in spell tooltips."],
			setting = "spellTooltips",
		},
		{
			type = "CheckButton",
			label = L["Detailed tooltip"],
			tooltipText = L["Use detailed format in the summary tooltip."],
			setting = "detailedTooltip",
			func = "UpdateTooltips",
		},
		{
			type = "DropDownMenu",
			label = L["Sort tooltips by:"],
			setting = "tooltipSort",
			width = 160,
			func = "UpdateTooltips",
			menu = menu,
		},
		{
			type = "CheckButton",
			label = L["Include old record"],
			tooltipText = L["Includes previous record along with \"New record\" messages."],
			setting = "oldRecord",
		},
		{
			type = "CheckButton",
			label = L["Chat output"],
			tooltipText = L["Prints new record notifications to the chat frame."],
			setting = "chatOutput",
		},
		{
			type = "CheckButton",
			label = L["Screenshot"],
			tooltipText = L["Saves a screenshot on a new record."],
			setting = "screenshot",
		},
		{
			type = "DropDownMenu",
			label = L["Sound effect"],
			setting = "sound",
			width = 160,
			func = function(self, value)
				-- hack not to play the sound when settings are loaded from a triggered event
				if not GetMouseButtonClicked() then return end
				PlaySoundFile(LSM:Fetch("sound", value))
			end,
			initialize = function(self)
				for _, v in ipairs(LSM:List("sound")) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = v
					info.func = self.onClick
					info.owner = self
					UIDropDownMenu_AddButton(info)
				end
			end,
		},
	}
	
	config:CreateOptions(options, Critline)
end


local defaults = {
	profile = {
		PvE = true,
		PvP = true,
		ignoreVulnerability = true,
		shortFormat = false,
		spellTooltips = true,
		detailedTooltip = false,
		tooltipSort = "normal",
		oldRecord = false,
		chatOutput = false,
		screenshot = false,
		sound = "None",
	},
	global = {
		spellMappings = {},
		tooltipMappings = {},
		spellNameOverrides = {
			-- pre-add form name to hybrid druid abilities, so the user can tell which is cat and which is bear
			[33878] = format("%s (%s)", GetSpellInfo(33878), GetSpellInfo(5487)), -- Mangle (Bear Form)
			[33876] = format("%s (%s)", GetSpellInfo(33876), GetSpellInfo(768)), -- Mangle (Cat Form)
			[779] = format("%s (%s)", GetSpellInfo(779), GetSpellInfo(5487)), -- Swipe (Bear Form)
			[62078] = format("%s (%s)", GetSpellInfo(62078), GetSpellInfo(768)), -- Swipe (Cat Form)
		},
		spellIconOverrides = {},
	},
}

-- which trees are enabled by default for a given class
-- if not specified; defaults to only damage enabled
local treeDefaults = {
	DRUID	= {heal = true},
	HUNTER	= {pet  = true},
	MONK	= {heal = true},
	PALADIN	= {heal = true},
	PRIEST	= {heal = true},
	SHAMAN	= {heal = true},
	WARLOCK	= {pet  = true},
}

function Critline:ADDON_LOADED(addon)
	if addon ~= addonName then
		return
	end
	
	local AceDB = LibStub("AceDB-3.0")
	local db = AceDB:New("CritlineDB", defaults, nil)
	self.db = db
	
	local percharDefaults = {
		profile = treeDefaults[playerClass] or {},
	}
	-- everyone wants damage!
	percharDefaults.profile.dmg = true
	-- set these to false rather than nil if disabled, for consistency
	percharDefaults.profile.heal = percharDefaults.profile.heal or false
	percharDefaults.profile.pet = percharDefaults.profile.pet or false
	percharDefaults.profile.spells = {
		dmg  = {},
		heal = {},
		pet  = {},
	}
	
	local percharDB = AceDB:New("CritlinePerCharDB", percharDefaults)
	self.percharDB = percharDB
	
	-- dual spec support
	local LibDualSpec = LibStub("LibDualSpec-1.0")
	LibDualSpec:EnhanceDatabase(self.db, addonName)
	LibDualSpec:EnhanceDatabase(self.percharDB, addonName)
	
	db.RegisterCallback(self, "OnProfileChanged", "LoadSettings")
	db.RegisterCallback(self, "OnProfileCopied", "LoadSettings")
	db.RegisterCallback(self, "OnProfileReset", "LoadSettings")
	
	percharDB.RegisterCallback(self, "OnProfileChanged", "LoadPerCharSettings")
	percharDB.RegisterCallback(self, "OnProfileCopied", "LoadPerCharSettings")
	percharDB.RegisterCallback(self, "OnProfileReset", "LoadPerCharSettings")
	
	spellMappings = db.global.spellMappings
	tooltipMappings = db.global.tooltipMappings
	spellNameOverrides = db.global.spellNameOverrides
	spellIconOverrides = db.global.spellIconOverrides
	
	-- purge invalid spell mappings
	for k, v in pairs(spellMappings) do
		if not GetSpellLink(v) then
			spellMappings[k] = nil
		end
	end
	
	self:UnregisterEvent("ADDON_LOADED")
	callbacks:Fire("AddonLoaded")
	
	-- deprecated
	self.db.profile.playSound = nil
	
	self:LoadSettings()
	self:LoadPerCharSettings()
	
	self.ADDON_LOADED = nil
end

function Critline:LoadSettings()
	callbacks:Fire("SettingsLoaded")
	config:LoadOptions(self)
end

function Critline:LoadPerCharSettings()
	self:FixSpells()
	self:BuildSpellArray()
	
	callbacks:Fire("PerCharSettingsLoaded")
	self:UpdateTopRecords()
	self:UpdateTooltips()
	
	config:LoadOptions(self, true)
end

function Critline:FixSpells()
	for k, tree in pairs(self.percharDB.profile.spells) do
		for spellID, spell in pairs(tree) do
			-- merge any spell remnants that has gotten new mappings, into their new spell ID
			local spellMapping = spellMappings[spellID]
			if spellMapping and spellMapping ~= spellID then
				local map = tree[spellMapping] or spell
				for i = 1, 2 do
					map[i] = map[i] or spell[i]
				end
				tree[spellID] = nil
			end
			
			-- remove spells that have been taken out of the game
			if not GetSpellLink(spellID) then
				tree[spellID] = nil
			end
		end
	end
end

function Critline:COMBAT_LOG_EVENT_UNFILTERED(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, ...)
	local isPet
	
	-- if sourceGUID is not us or our pet, we leave
	if not CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MINE) then
		-- only register if it's a real pet, or a guardian tree pet that's included in the filter
		if self:IsMyPet(sourceFlags, sourceGUID) then
			isPet = true
			-- self:Debug(format("This is my pet (%s)", sourceName))
		else
			-- self:Debug("This is not me, my trap or my pet; return.")
			return
		end
	else
		-- self:Debug(format("This is me or my trap (%s)", sourceName))
	end
	
	local isPeriodic
	local periodic = 1
	local isHeal = eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL" or eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REFRESH"
	-- we don't care about healing done by the pet
	if isHeal and isPet then
		self:Debug("Pet healing. Return.")
		return
	end
	if eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "SPELL_PERIODIC_HEAL" then
		isPeriodic = true
		periodic = 2
	end
	
	local combatEvent = combatEvents[eventType]
	if not combatEvent then
		return
	end
	
	-- get the relevants arguments
	local spellID, spellName, amount, resisted, critical, school = combatEvent(...)
	
	local rawID = spellID
	local cachedID = spellIDCache[spellID]
	if cachedID then
		spellID = cachedID
	elseif not IsPlayerSpell(spellID) then
		local spellLink = GetSpellLink(spellName)
		if spellLink then
			local id = tonumber(spellLink:match("spell:(%d+)"))
			if IsPlayerSpell(id) then
				spellIDCache[spellID] = id
				spellID = id
			end
		end
	else
		-- cache either way so we don't have to check with IsPlayerSpell when we know that it is
		spellIDCache[spellID] = spellID
	end
	
	-- return if the event has no amount (non-absorbing aura applied)
	if not amount then
		return
	end
	
	-- if we don't have a destName (who we hit or healed) and we don't have a sourceName (us or our pets) then we leave
	if not destName then
		self:Debug(format("No target info for %s (%d).", spellName, spellID))
		return
	end
	
	local spellMapping = spellMappings[spellID]
	if spellMapping then
		spellID = spellMapping
	end
	
	-- some absorb effects seem to have a floating point amount
	amount = floor(amount)

	if amount <= 0 then
		self:Debug(format("Amount <= 0. (%s) Return.", self:GetFullSpellName(spellName, periodic)))
		return
	end

	local tree = "dmg"
	
	if isPet then
		tree = "pet"
	elseif isHeal then
		tree = "heal"
	end
	
	-- exit if not recording tree dmg
	if not self.percharDB.profile[tree] then
		self:Debug(format("Not recording %s spells. Return.", tree))
		return
	end
	
	local targetLevel = self:GetLevelFromGUID(destGUID)
	local passed, isFiltered
	if self.filters then
		passed, isFiltered = self.filters:SpellPassesFilters(tree, spellName, spellID, isPeriodic, destGUID, destName, school, targetLevel, rawID)
		if not passed then
			return
		end
	end
	
	local isPvPTarget = band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) ~= 0
	local friendlyFire = band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0
	local hostileTarget = band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0
	
	if not (isPvPTarget or self.db.profile.PvE or isHeal) then
		self:Debug(format("%s is an NPC and PvE damage is not registered.", destName))
		return
	end
	
	if isPvPTarget and not (self.db.profile.PvP or isHeal or friendlyFire) then
		self:Debug(format("%s is a player and PvP damage is not registered.", destName))
		return
	end
	
	-- ignore damage done to friendly targets
	if friendlyFire and not isHeal then
		self:Debug(format("Skipped %s @ %s. Friendly fire.", GetSpellLink(rawID), destName))
		return
	end
	
	-- ignore healing done to hostile targets
	if hostileTarget and isHeal then
		self:Debug(format("Skipped %s @ %s. Healing hostile target", GetSpellLink(rawID), destName))
		return
	end
	
	-- ignore vulnerability damage if necessary
	if self.db.profile.ignoreVulnerability and resisted and resisted < 0 then
		amount = amount + resisted
		self:Debug(format("%d vulnerability damage ignored for a real value of %d.", abs(resisted), amount))
	end
	
	local hitType = critical and "crit" or "normal"
	local data = self:GetSpellInfo(tree, spellID, periodic)
	local arrayData
	
	spellName = self:GetSpellName(spellID)

	-- create spell database entries as required
	if not data then
		self:Debug(format("Creating data for %s (%s)", self:GetFullSpellName(spellName, periodic), tree))
		data, arrayData = self:AddSpell(tree, spellID, periodic, spellName, isFiltered)
		self:UpdateSpells(tree)
	end
	
	if not data[hitType] then
		data[hitType] = {amount = 0}
		(arrayData or self:GetSpellArrayEntry(tree, spellID, periodic))[hitType] = data[hitType]
	end
	
	data = data[hitType]

	-- if new amount is larger than the stored amount we'll want to store it
	if amount > data.amount then
		self:NewRecord(tree, spellID, spellName, periodic, amount, critical, data, isFiltered)
		
		if not isFiltered then
			-- update the highest record if needed
			local topRecords = topRecords[tree]
			if amount > topRecords[hitType] then
				topRecords[hitType] = amount
				callbacks:Fire("OnNewTopRecord", tree)
			end
		end

		data.amount = amount
		data.target = destName
		data.targetLevel = targetLevel
		data.isPvPTarget = isPvPTarget
		
		self:UpdateRecords(tree, isFiltered)
	end
end

function Critline:UNIT_LEVEL(unit)
end

function Critline:IsMyPet(flags, guid)
	local isMyPet = CombatLog_Object_IsA(flags, COMBATLOG_FILTER_MY_PET)
	local isGuardian = band(flags, COMBATLOG_OBJECT_TYPE_GUARDIAN) ~= 0
	return isMyPet and ((not isGuardian and HasPetUI()) or classPets[tonumber(guid:sub(6, 10), 16)])
end

local levelCache = {}

local levelStrings = {
	TOOLTIP_UNIT_LEVEL:format("(%d+)"),
	TOOLTIP_UNIT_LEVEL_CLASS:format("(%d+)", ".+"),
	TOOLTIP_UNIT_LEVEL_CLASS_TYPE:format("(%d+)", ".+", ".+"),
	TOOLTIP_UNIT_LEVEL_RACE_CLASS:format("(%d+)", ".+", ".+"),
	TOOLTIP_UNIT_LEVEL_RACE_CLASS_TYPE:format("(%d+)", ".+", ".+", ".+"),
	TOOLTIP_UNIT_LEVEL_TYPE:format("(%d+)", ".+"),
}

function Critline:GetLevelFromGUID(destGUID)
	if levelCache[destGUID] then
		return levelCache[destGUID]
	end
	
	tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	tooltip:SetHyperlink("unit:"..destGUID)
	
	local level = -1
	
	for i = 1, tooltip:NumLines() do
		local text = _G["CritlineTooltipTextLeft"..i]:GetText()
		for i, v in ipairs(levelStrings) do
			local level = text and text:match(v)
			if level then
				level = tonumber(level) or -1
				levelCache[destGUID] = level
				return level
			end
		end
	end
	return level
end

function Critline:Message(...)
	print("|cffffff00Critline:|r", ...)
end

function Critline:Debug(...)
	if debugging then
		print("|cff56a3ffCritlineDebug:|r", ...)
	end
end

function Critline:ToggleDebug()
	debugging = not debugging
	self:Message("Debugging "..(debugging and "enabled" or "disabled"))
end

function Critline:OpenConfig()
	InterfaceOptionsFrame_OpenToCategory(config)
end

function Critline:NewRecord(tree, spellID, spellName, periodic, amount, critical, prevRecord, isFiltered)
	callbacks:Fire("NewRecord", tree, spellID, spellName, periodic, amount, critical, prevRecord, isFiltered)
	
	if isFiltered then
		return
	end
	
	amount = self:ShortenNumber(amount)
	
	if self.db.profile.oldRecord and prevRecord.amount > 0 then
		amount = format("%s (%s)", amount, self:ShortenNumber(prevRecord.amount))
	end

	if self.db.profile.chatOutput then
		self:Message(format(L["New %s%s record - %s"], critical and "|cffff0000"..L["critical "].."|r" or "", self:GetFullSpellName(spellName, periodic, true), amount))
	end
	
	if self.db.profile.screenshot then 
		TakeScreenshot() 
	end
	
	PlaySoundFile(LSM:Fetch("sound", self.db.profile.sound))
end

local FIRST_NUMBER_CAP = FIRST_NUMBER_CAP:lower()

function Critline:ShortenNumber(amount)
	if tonumber(amount) and self.db.profile.shortFormat then
		if amount >= 1e7 then
			amount = (floor(amount / 1e5) / 10)..SECOND_NUMBER_CAP
		elseif amount >= 1e6 then
			amount = (floor(amount / 1e4) / 100)..SECOND_NUMBER_CAP
		elseif amount >= 1e4 then
			amount = (floor(amount / 100) / 10)..FIRST_NUMBER_CAP
		end
	end
	return amount
end

function Critline:BuildSpellArray(tree)
	if not tree then
		for tree in pairs(trees) do
			self:BuildSpellArray(tree)
		end
		return
	end
	
	local array = spellArrays[tree]
	wipe(array)
	for spellID, spell in pairs(self.percharDB.profile.spells[tree]) do
		for i, v in pairs(spell) do
			array[#array + 1] = {
				id = spellID,
				name = self:GetSpellName(spellID),
				filtered = v.filtered,
				periodic = i,
				normal = v.normal,
				crit = v.crit,
			}
		end
	end
end

function Critline:GetSpellArrayEntry(tree, spellID, periodic)
	for i, spell in ipairs(spellArrays[tree]) do
		if spell.id == spellID and spell.periodic == periodic then
			return spell
		end
	end
end

-- local previousTree
-- local previousSort

function Critline:GetSpellArray(tree, useProfileSort)
	local array = spellArrays[tree]
	if useProfileSort ~= false then
		local sortMethod = useProfileSort and self.db.profile.tooltipSort or "alpha"
		-- no need to sort if it's already sorted the way we want it
		-- if sortMethod ~= previousSort or tree ~= previousTree then
			sort(array, recordSorters[sortMethod])
			-- previousTree = tree
			-- previousSort = sortMethod
		-- end
	end
	return array
end

-- return spell table from database, given tree, spell name and isPeriodic value
function Critline:GetSpellInfo(tree, spellID, periodic)
	local spell = self.percharDB.profile.spells[tree][spellID]
	return spell and spell[periodic]
end

function Critline:GetSpellName(spellID, raw)
	local spellName = spellNameCache[spellID] or GetSpellInfo(spellID)
	spellNameCache[spellID] = spellName
	return (not raw and spellNameOverrides[spellID]) or spellName
end

function Critline:GetSpellTexture(spellID)
	local spellTexture = spellIconOverrides[spellID] or spellTextureCache[spellID] or GetSpellTexture(spellID)
	spellTextureCache[spellID] = spellTexture
	return spellTexture
end

function Critline:GetFullSpellName(spellName, periodic, verbose)
	if periodic == 2 then
		spellName = format("%s (%s)", spellName, verbose and L["tick"] or "*")
	end
	return spellName
end

function Critline:GetFullTargetName(spell)
	local suffix = ""
	if spell.isPvPTarget then
		suffix = format(" (%s)", PVP)
	end
	return format("%s%s", spell.target, suffix)
end

-- retrieves the top, non filtered record amounts and spell names for a given tree
function Critline:UpdateTopRecords(tree)
	if not tree then
		for tree in pairs(topRecords) do
			self:UpdateTopRecords(tree)
		end
		return
	end
	
	local normalRecord, critRecord = 0, 0
	
	for spellID, spell in pairs(self.percharDB.profile.spells[tree]) do
		for i, v in pairs(spell) do
			if not (self.filters and v.filtered) then
				local normal = v.normal
				if normal then
					normalRecord = max(normal.amount, normalRecord)
				end
				local crit = v.crit
				if crit then
					critRecord = max(crit.amount, critRecord)
				end
			end
		end
	end
	local topRecords = topRecords[tree]
	topRecords.normal = normalRecord
	topRecords.crit = critRecord
	
	callbacks:Fire("OnNewTopRecord", tree)
end

-- retrieves the top, non filtered record amounts and spell names for a given tree
function Critline:GetHighest(tree)
	local topRecords = topRecords[tree]
	return topRecords.normal, topRecords.crit
end

function Critline:AddSpell(tree, spellID, periodic, spellName, filtered)
	local spells = self.percharDB.profile.spells[tree]
	
	local spell = spells[spellID] or {}
	spells[spellID] = spell
	spell[periodic] = {filtered = filtered}
	
	local spellArray = spellArrays[tree]
	local arrayData = {
		id = spellID,
		name = spellName,
		filtered = filtered,
		periodic = periodic,
	}
	spellArray[#spellArray + 1] = arrayData
	
	return spell[periodic], arrayData
end

function Critline:DeleteSpell(tree, spellID, periodic)
	do
		local tree = self.percharDB.profile.spells[tree]
		local spell = tree[spellID]
		spell[periodic] = nil
	
		-- remove this entire spell entry if neither direct nor tick entries remain
		if not spell[3 - periodic] then
			tree[spellID] = nil
		end
	end
	
	for i, v in ipairs(spellArrays[tree]) do
		if v.id == spellID and v.periodic == periodic then
			tremove(spellArrays[tree], i)
			self:Message(format(L["Reset %s (%s) records."], self:GetFullSpellName(v.name, v.periodic), trees[tree].label))
			break
		end
	end
	
	self:UpdateTopRecords(tree)
end

-- this "fires" when spells are added to/removed from the database
function Critline:UpdateSpells(tree)
	if tree then
		doTooltipUpdate[tree] = true
		callbacks:Fire("SpellsChanged", tree)
	else
		for k in pairs(tooltips) do
			self:UpdateSpells(k)
		end
	end
end

-- this "fires" when a new record has been registered
function Critline:UpdateRecords(tree, isFiltered)
	if tree then
		doTooltipUpdate[tree] = true
		callbacks:Fire("RecordsChanged", tree, isFiltered)
	else
		for k in pairs(tooltips) do
			self:UpdateRecords(k, isFiltered)
		end
	end
end

function Critline:UpdateTooltips()
	for k in pairs(tooltips) do
		doTooltipUpdate[k] = true
	end
end

local LETHAL_LEVEL = "??"
local leftFormat = "|cffc0c0c0%s:|r %s"
local leftFormatIndent = leftFormat
local rightFormat = format("%s%%s|r (%%s)", HIGHLIGHT_FONT_COLOR_CODE)
local recordFormat = format("%s%%s|r", GREEN_FONT_COLOR_CODE)
local r, g, b = HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b

function Critline:ShowTooltip(tree)
	if doTooltipUpdate[tree] then
		self:UpdateTooltip(tree)
	end
	local r, g, b = r, g, b
	local rR, gR, bR
	GameTooltip:AddLine("Critline "..trees[tree].label, r, g, b)
	if not self.db.profile.detailedTooltip then
		-- advanced tooltip uses different text color
		rR, gR, bR = r, g, b
		r, g, b = nil
	end
	local tooltip = tooltips[tree]
	for i = 1, #tooltips[tree] do
		local v = tooltip[i]
		-- v is either an array containing the left and right tooltip strings, or a single string
		if type(v) == "table" then
			local left, right = unpack(v)
			GameTooltip:AddDoubleLine(left, right, r, g, b, rR, gR, bR)
		else
			GameTooltip:AddLine(v)
		end
	end
	GameTooltip:Show()
end

function Critline:UpdateTooltip(tree)
	local tooltip = tooltips[tree]
	wipe(tooltip)
	
	local normalRecord, critRecord = self:GetHighest(tree)
	local n = 1
	
	for _, v in ipairs(self:GetSpellArray(tree, true)) do
		if not (self.filters and self:GetSpellInfo(tree, v.id, v.periodic).filtered) then
			local spellName = self:GetFullSpellName(v.name, v.periodic)
			
			-- if this is a DoT/HoT, and a direct entry exists, add the proper suffix
			-- if v.periodic == 2 and not (self.filters and self.filters:IsFilteredSpell(tree, v.spellID, 1)) then
				-- spellName = self:GetFullSpellName(v.spellID, 2)
			-- end
			
			if self.db.profile.detailedTooltip then
				tooltip[n] = spellName
				n = n + 1
				tooltip[n] = {self:GetTooltipLine(v, "normal", tree)}
				n = n + 1
				tooltip[n] = {self:GetTooltipLine(v, "crit", tree)}
			else
				local normalAmount, critAmount = 0, 0
				
				-- color the top score amount green
				local normal = v.normal
				if normal then
					normalAmount = self:ShortenNumber(normal.amount)
					normalAmount = normal.amount == normalRecord and GREEN_FONT_COLOR_CODE..normalAmount..FONT_COLOR_CODE_CLOSE or normalAmount
				end
				
				local crit = v.crit
				if crit then
					critAmount = self:ShortenNumber(crit.amount)
					critAmount = crit.amount == critRecord and GREEN_FONT_COLOR_CODE..critAmount..FONT_COLOR_CODE_CLOSE or critAmount
				end
				
				tooltip[n] = {spellName, crit and format("%s / %s", normalAmount, critAmount) or normalAmount}
			end
			
			n = n + 1
		end
	end
	
	if #tooltip == 0 then
		tooltip[1] = L["No records"]
	end
	
	doTooltipUpdate[tree] = nil
end

local hitTypes = {
	normal = L["Normal"],
	crit = L["Crit"],
}

function Critline:GetTooltipLine(data, hitType, tree)
	local leftFormat = tree and "   "..leftFormat or leftFormat
	data = data and data[hitType]
	if data then
		local amount = self:ShortenNumber(data.amount)
		if tree and data.amount == topRecords[tree][hitType] then
			amount = format(recordFormat, amount)
		end
		local level = data.targetLevel
		level = level > 0 and level or LETHAL_LEVEL
		return format(leftFormat, hitTypes[hitType], amount), format(rightFormat, self:GetFullTargetName(data), level), r, g, b
	end
end

function Critline:AddTooltipLine(data, tree)
	GameTooltip:AddDoubleLine(self:GetTooltipLine(data, "normal", tree))
	GameTooltip:AddDoubleLine(self:GetTooltipLine(data, "crit", tree))
end

local funcset = {}

for k in pairs(trees) do
	funcset[k] = function(spellID)
		local spell = Critline.percharDB.profile.spells[k][spellID]
		if not spell then
			return
		end
		local direct = spell[1]
		local tick = spell[2]
		if Critline.filters then
			direct = direct and not direct.filtered and direct
			tick = tick and not tick.filtered and tick
		end
		return direct, tick
	end
end

local function addLine(header, nonTick, tick)
	if header then
		GameTooltip:AddLine(header)
	end
	Critline:AddTooltipLine(nonTick)
	if tick and nonTick then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Tick"])
	end
	Critline:AddTooltipLine(tick)
end

GameTooltip:HookScript("OnTooltipSetSpell", function(self)
	if self.Critline then
		return
	end
	
	self.Critline = true
	
	if debugging then
		self:AddLine(format("Spell ID: |cffffffff%d|r", select(3, self:GetSpell())))
	end
	
	if not Critline.db.profile.spellTooltips then
		return
	end
	
	local spellName, rank, spellID = self:GetSpell()
	spellID = tooltipMappings[spellID] or spellID
	
	local dmg1, dmg2 = funcset.dmg(spellID)
	local dmg = dmg1 or dmg2
	
	local heal1, heal2 = funcset.heal(spellID)
	local heal = heal1 or heal2
	
	-- ignore pet auto attack records here, since that's handled by another function
	local pet1, pet2 = spellID ~= AUTO_ATTACK_ID and funcset.pet(spellID)
	local pet = pet1 or pet2
	
	if dmg or heal or pet then
		self:AddLine(" ")
	end
	
	if dmg then
		addLine((heal or pet) and L["Damage"], dmg1, dmg2)
	end
	
	if heal then
		if dmg then
			GameTooltip:AddLine(" ")
		end
		addLine((dmg or pet) and L["Healing"], heal1, heal2)
	end
	
	if pet then
		if dmg or heal then
			GameTooltip:AddLine(" ")
		end
		addLine((dmg or heal) and L["Pet"], pet1, pet2)
	end
end)

GameTooltip:HookScript("OnTooltipCleared", function(self)
	self.Critline = nil
end)

hooksecurefunc(GameTooltip, "SetPetAction", function(self, action)
	if not Critline.db.profile.spellTooltips then
		return
	end
	
	if GetPetActionInfo(action) == "PET_ACTION_ATTACK" then
		addLine(" ", (funcset.pet(AUTO_ATTACK_ID)))
		self:Show()
	end
end)
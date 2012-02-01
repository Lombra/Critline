local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local band = bit.band
local CombatLog_Object_IsA = CombatLog_Object_IsA
local IsSpellKnown = IsSpellKnown
local UnitAura = UnitAura

local COMBATLOG_FILTER_ME = COMBATLOG_FILTER_ME

-- mobs whose received hits won't be tracked due to various vulnerabilities
local specialMobs = {
	[12460] = true,	-- Death Talon Wyrmguard
	[12461] = true,	-- Death Talon Overseer
	[14020] = true,	-- Chromaggus
	[15339] = true,	-- Ossirian the Unscarred
	[15928] = true,	-- Thaddius
	[16803] = true, -- Death Knight Understudy
	[22841] = true,	-- Shade of Akama
	[33329] = true, -- Heart of the Deconstructor
	[33670] = true, -- Aerial Command Unit
	[34496] = true, -- Eydis Darkbane
	[34497] = true, -- Fjola Lightbane
	[38567] = true, -- Phantom Hallucination
	[40484] = true, -- Erudax
	[42347] = true, -- Exposed Head of Magmaw ?
	[42803] = true, -- Drakeadon Mongrel
	[46083] = true, -- Drakeadon Mongrel
	[46273] = true, -- Debilitated Apexar
	[48270] = true, -- Exposed Head of Magmaw
	[52155] = true, -- High Priest Venoxis
	[54191] = true, -- Risen Ghoul (End Time)
}

-- auras that when gained will suppress record tracking
local specialAuras = {
	[18173] = true,	-- Burning Adrenaline (Vaelastrasz the Corrupt)
	[23768] = true, -- Sayge's Dark Fortune of Damage
	[24378] = true, -- Berserking (battlegrounds)
	[30402] = true, -- Nether Beam - Dominance (Netherspite)
	[40604] = true, -- Fel Rage (Gurtogg Bloodboil)
	[41337] = true,	-- Aura of Anger (Reliquary of Souls)
	[41350] = true,	-- Aura of Desire (Reliquary of Souls)
	[44335] = true,	-- Energy Feedback (Vexallus)
	[44406] = true,	-- Energy Infusion (Vexallus)
	[40880] = true, -- Prismatic Aura: Shadow (Mother Shahraz)
	[40882] = true, -- Prismatic Aura: Fire (Mother Shahraz)
	[40883] = true, -- Prismatic Aura: Nature (Mother Shahraz)
	[40891] = true, -- Prismatic Aura: Arcane (Mother Shahraz)
	[40896] = true, -- Prismatic Aura: Frost (Mother Shahraz)
	[40897] = true, -- Prismatic Aura: Holy (Mother Shahraz)
	[53642] = true,	-- Might of Mograine (Light's Hope Chapel)
	[55849] = true,	-- Power Spark (Malygos)
	[56330] = true,	-- Iron's Bane (Storm Peaks quest)
	[56648] = true,	-- Potent Fungus (Amanitar)
	[57524] = true, -- Metanoia (Valkyrion Aspirant)
	[58026] = true,	-- Blessing of the Crusade (Icecrown quest)
	[58361] = true,	-- Might of Mograine (Patchwerk)
	[58549] = true,	-- Tenacity (Lake Wintergrasp)
	[59641] = true,	-- Warchief's Blessing (The Battle For The Undercity)
	[60964] = true,	-- Strength of Wrynn (The Battle For The Undercity)
	[61888] = true, -- Overwhelming Power (Assembly of Iron 25)
	[62243] = true, -- Unstable Sun Beam (Elder Brightleaf)
	[62650] = true, -- Fortitude of Frost (Yogg-Saron)
	[62670] = true, -- Resilience of Nature (Yogg-Saron)
	[62671] = true, -- Speed of Invention (Yogg-Saron)
	[62702] = true, -- Fury of the Storm (Yogg-Saron)
	[63138] = true, -- Sara's Fervor (Yogg-Saron)
	[63277] = true, -- Shadow Crash (General Vezax)
	[63711] = true, -- Storm Power (Hodir 10)
	[64320] = true, -- Rune of Power (Assembly of Iron)
	[64321] = true, -- Potent Pheromones (Freya)
	[64637] = true, -- Overwhelming Power (Assembly of Iron 10)
	[65134] = true, -- Storm Power (Hodir 25)
	[70227] = true, -- Empowered Blood (Empowered Orb)
	[70867] = true, -- Essence of the Blood Queen (Blood Queen Lana'thel)
	[70879] = true, -- Essence of the Blood Queen (Blood Queen Lana'thel, bitten by a player)
	[71532] = true, -- Essence of the Blood Queen (Blood Queen Lana'thel heroic)
	[72219] = true, -- Gastric Bloat (Festergut)
	[73822] = true, -- Hellscream's Warsong (Icecrown Citadel)
	[73828] = true, -- Strength of Wrynn (Icecrown Citadel) 
	[76133] = true, -- Tidal Surge (Neptulon)
	[76155] = true, -- Tidal Surge (Neptulon)
	[76159] = true, -- Pyrogenics (Sun-Touched Spriteling)
	[76355] = true, -- Blessing of the Sun (Rajh)
	[76693] = true, -- Empowering Twilight (Crimsonborne Warlord)
	[79624] = true, -- Power Generator (Arcanotron) ?
	[79629] = true, -- Power Generator (Arcanotron 10)
	[80718] = true, -- Burden of the Crown (Spirit of Corehammer 25) ?
	[81096] = true, -- Red Mist (Red Mist)
	[82170] = true, -- Corruption: Absolute (Cho'gall)
	[86622] = true, -- Engulfing Magic (Theralion) ?
	[86872] = true, -- Frothing Rage (Thundermar Ale)
	[89879] = true, -- Blessing of the Sun (Rajh heroic)
	[90707] = true, -- Empowering Twilight 
	[90932] = true, -- Ragezone (Defias Blood Wizard)
	[90933] = true, -- Ragezone (Defias Blood Wizard heroic)
	[91871] = true, -- Lightning Charge (Siamat)
	[91555] = true, -- Power Generator (Arcanotron 25)
	[93777] = true, -- Invocation of Flame (Skullcrusher the Mountain)
	[93778] = true, -- Invocation of Flame (Elemental Bonds: Fury)
	[95639] = true, -- Engulfing Magic (Theralion) ?
	[95640] = true, -- Engulfing Magic (Theralion) ?
	[95641] = true, -- Engulfing Magic (Theralion) ?
	[96493] = true, -- Spirit's Vengeance (Bloodlord Mandokir)
	[96494] = true, -- Spirit's Vengeance (Bloodlord Mandokir)
	[96802] = true, -- Bethekk's Blessing (Lesser Priest of Bethekk)
	[98245] = true, -- Legendary Concentration (Majordomo Staghelm)
	[98252] = true, -- Epic Concentration (Majordomo Staghelm)
	[98253] = true, -- Rare Concentration (Majordomo Staghelm)
	[98254] = true, -- Uncommon Concentration (Majordomo Staghelm)
	[99389] = true, -- Imprinted (Voracious Hatchling)
	[99762] = true, -- Flames of the Firehawk (Inferno Firehawk)
	[100359] = true, -- Imprinted (Voracious Hatchling)
	[102994] = true, -- Shadow Walk (Illidan Stormrage)
	[103018] = true, -- Shadow Ambusher (Illidan Stormrage)
	[103020] = true, -- Shadow Walk (Illidan Stormrage)
	[103744] = true, -- Water Shell (Thrall)
	[103817] = true, -- Rising Fire
	[106029] = true, -- Kalecgos' Presence (no event)
	[109457] = true, -- Ysera's Presence (no event) ?
	[109606] = true, -- Kalecgos' Presence (LFR - no event)
	[109640] = true, -- Ysera's Presence (LFR - no event)
}

-- these are auras that increases the target's damage or healing received
local targetAuras = {
	[46287] = true, -- Infernal Defense (Apocalypse Guard)
	[46474] = true, -- Sacrifice of Anveena (Kil'jaeden)
	[64436] = true, -- Magnetic Core (Aerial Command Unit) ?
	[65280] = true, -- Singed (Hodir)
	[66758] = true, -- Staggered Daze (Icehowl) ?
	[75664] = true, -- Shadow Gale (Erudax) ?
	[75846] = true, -- Superheated Quicksilver Armor (Karsh Steelbender) ?
	[76015] = true, -- Superheated Quicksilver Armor (Karsh Steelbender) ?
	[76232] = true, -- Storm's Fury (Ragnaros - Mount Hyjal) ?
	[77615] = true, -- Debilitating Slime (Maloriak)
	[77717] = true, -- Vertigo (Atramedes 10)
	[80164] = true, -- Chemical Cloud (Toxitron)
	[82840] = true, -- Vulnerable (Deepstone Elemental)
	[87683] = true, -- Dragon's Vengeance (Halfus Wyrmbreaker)
	[87904] = true, -- Feedback (Al'Akir)
	-- [91086] = true, -- Shadow Gale (Erudax heroic) -- UNTRACKABLE!!!
	[91478] = true, -- Chemical Cloud (Toxitron 25) ?
	[92389] = true, -- Vertigo (Atramedes 25) ?
	[92390] = true, -- Vertigo (Atramedes) ?
	[92910] = true, -- Debilitating Slime (Maloriak) ?
	[93567] = true, -- Superheated Quicksilver Armor (Karsh Steelbender) ?
	[95723] = true, -- Storm's Fury (Ragnaros - Mount Hyjal) ?
	[96960] = true, -- Antlers of Malorne (Galenges)
	[97320] = true, -- Sunder Rift (Jin'do the Godbreaker)
	[98596] = true, -- Infernal Rage (Spark of Rhyolith)
	[99432] = true, -- Burnout (Alysrazor)
	[101458] = true, -- Feedback (Al'Akir 25) ?
	[101602] = true, -- Throw Totem (Echo of Baine)
	[104031] = true, -- Void Diffusion (Warlord Zon'ozz)
	[106588] = true, -- Expose Weakness (Deathwing)
	[106600] = true, -- Expose Weakness (Deathwing)
	[106613] = true, -- Expose Weakness (Deathwing)
	[106624] = true, -- Expose Weakness (Deathwing)
	[108934] = true, -- Feedback (Hagara the Stormbinder)
	[109582] = true, -- Expose Weakness (Deathwing, Alexstrasza - LFR)
	[109619] = true, -- Expose Weakness (Deathwing, Nozdormu - LFR)
	[109637] = true, -- Expose Weakness (Deathwing, Ysera - LFR)
	[109728] = true, -- Expose Weakness (Deathwing, Kalecgos - LFR)
}

-- used for the "player spells only" option, due to only the main spell ID being recognised
-- these will not be displayed on any tooltip, why they don't go in the main exceptions table
local playerSpells = {
	-- Warrior
	[12721] = true, -- Deep Wounds
	[44949] = true, -- Whirlwind Off-hand
	[76858] = true, -- Opportunity Strike
	[85384] = true, -- Raging Blow Off-hand
	-- Death knight
	[50536] = true, -- Unholy Blight
		-- Gargoyle
		[51963] = true, -- Gargoyle Strike
		-- Ghoul
		[91778] = true, -- Sweeping Claws
		[91797] = true, -- Monstrous Blow
	-- Paladin
	[20187] = true, -- Judgement of Righteousness
	[20424] = true, -- Seals of Command
	[31803] = true, -- Censure
	[31804] = true, -- Judgement of Truth
	[86704] = true, -- Ancient Fury
	[96172] = true, -- Hand of Light
	-- Hunter
	[83077] = true, -- Improved Serpent Sting
	-- Shaman
	[32176] = true, -- Stormstrike Off-hand
	[52752] = true, -- Ancestral Awakening
	[86958] = true, -- Cleansing Waters
	[88767] = true, -- Fulmination
	-- Rogue
	[2818] = true, -- Deadly Poison
	[8680] = true, -- Instant Poison
	[13218] = true, -- Wound Poison
	[27576] = true, -- Mutilate Off-hand
	[79136] = true, -- Venomous Wound
	-- Priest
	[77489] = true, -- Echo of Light
	[88684] = true, -- Holy Word: Serenity
	[88685] = true, -- Holy Word: Sanctuary
	-- Warlock
		-- Infernal
		[22703] = true, -- Infernal Awakening
		-- Doomguard
		[85692] = true, -- Doom Bolt
}

-- these heals are treated as periodic, but has no aura associated with them, or is associated to an aura with a different name, need to add exceptions for them to filter properly
local directHoTs = {
	[54172] = true, -- Divine Storm
	-- [63106] = "Corruption", -- Siphon Life
}

local filters = addon.filters

local ignoreEncounter
local activeAuras = filters.activeAuras or {
	player = {},
	pet = {},
}
local corruptSpells = {
	player = {},
	pet = {},
}
local corruptTargets = {}
local ignoredTargets = {}


local defaults = {
	profile = {
		filterNew = false,
		onlyKnown = false,
		ignoreMobFilter = false,
		ignoreAuraFilter = false,
		suppressMC = true,
		dontFilterMagic = false,
		levelFilter = -1,
	},
	global = {
		mobs = {},
		auras = {},
	},
}

function filters:AddonLoaded()
	self.db = addon.db:RegisterNamespace("filters", defaults)
	addon.RegisterCallback(self, "SettingsLoaded", "LoadSettings")
	addon.RegisterCallback(self.spell.scrollFrame, "PerCharSettingsLoaded", "Update")
	addon.RegisterCallback(self.spell.scrollFrame, "SpellsChanged", "Update")
	
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PLAYER_LOGIN")
	self:RegisterEvent("UNIT_NAME_UPDATE")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_CONTROL_LOST")
	self:RegisterEvent("PLAYER_CONTROL_GAINED")
end

addon.RegisterCallback(filters, "AddonLoaded")

function filters:LoadSettings()
	self.profile = self.db.profile
	
	for i, v in ipairs(self.options.checkButtons) do
		v:LoadSetting()
	end
	
	self.options.slider:SetValue(self.profile.levelFilter)
end

function filters:COMBAT_LOG_EVENT_UNFILTERED(timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2, spellID, spellName)
	if (eventType == "SPELL_AURA_REMOVED" or eventType == "SPELL_AURA_BROKEN" or eventType == "SPELL_AURA_BROKEN_SPELL" or eventType == "SPELL_AURA_STOLEN") then
		if targetAuras[spellID] then
			corruptTargets[destGUID] = corruptTargets[destGUID] or {}
			corruptTargets[destGUID][spellID] = nil
			addon:Debug(format("Filtered aura (%s) faded from %s.", spellName, destName))
		end
		
		-- self buffs
		if self:IsFilteredAura(spellID) then
			local unit = self:GetUnit(destFlags, destGUID)
			if unit then
				addon:Debug(format("Filtered aura (%s) faded from %s.", spellName, unit))
				-- if we lost a special aura we have to check if any other filtered auras remain
				activeAuras[unit][spellID] = nil
				-- if not self:IsEmpowered(unit) then
					-- addon:Debug(format("No filtered aura detected on %s. Resuming record tracking.", unit))
				-- end
			end
		end
	end
	
	if eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_APPLIED_DOSE" or eventType == "SPELL_AURA_REFRESH" then
		-- if this is one of the damage-taken-increased auras, we flag this target - along with the aura in question - as corrupt
		if targetAuras[spellID] then
			corruptTargets[destGUID] = corruptTargets[destGUID] or {}
			corruptTargets[destGUID][spellID] = true
			ignoredTargets[destGUID] = true
			addon:Debug(format("Target (%s) gained filtered aura. (%s) Ignore received damage.", destName, spellName))
		end
		
		local destUnit = self:GetUnit(destFlags, destGUID)
		if destUnit and self:IsFilteredAura(spellID) then
			-- if we gain any aura in the filter we can just stop tracking records
			if not (self:IsEmpowered(destUnit) or self.profile.ignoreAuraFilter) then
				addon:Debug(format("%s gained filtered aura. (%s) Suppressing new records for this encounter.", destUnit:gsub(".", string.upper, 1), spellName))
			end
			ignoreEncounter = true
			activeAuras[destUnit][spellID] = true
		end
		
		-- auras applied by self
		local sourceUnit = self:GetUnit(sourceFlags, sourceGUID)
		if sourceUnit then
			local corruptSpell = corruptSpells[sourceUnit][spellID] or {}
			corruptSpell[destGUID] = self:IsEmpowered(sourceUnit) or self:IsVulnerableTarget(destGUID)
			corruptSpells[sourceUnit][spellID] = corruptSpell
		end
	end
end

function filters:PLAYER_LOGIN()
	self:ScanAuras()
	self:CheckPlayerControl()
end

function filters:UNIT_NAME_UPDATE()
	self:ScanAuras()
	self:CheckPlayerControl()
	self:UnregisterEvent("UNIT_NAME_UPDATE")
end

function filters:PLAYER_REGEN_DISABLED()
	self:ScanAuras()
	ignoreEncounter = self:IsEmpowered("player")
	if ignoreEncounter then
		addon:Debug("Filtered aura(s) detected. Suppressing new records for this encounter.")
	end
	for unit, v in pairs(ignoredTargets) do
		if not self:IsVulnerableTarget(unit) then
			ignoredTargets[unit] = nil
		end
	end
end

function filters:PLAYER_CONTROL_LOST()
	self.inControl = false
	addon:Debug("Lost control. Disabling combat log tracking.")
end

function filters:PLAYER_CONTROL_GAINED()
	self.inControl = true
	addon:Debug("Regained control. Resuming combat log tracking.")
end

local auraTypes = {
	BUFF = "HELPFUL",
	DEBUFF = "HARMFUL",
}

function filters:ScanAuras()
	wipe(activeAuras["player"])
	local filterAuras = self.db.global.auras
	for auraType, filter in pairs(auraTypes) do
		for i = 1, 40 do
			local spellName, _, _, _, _, _, _, source, _, _, spellID = UnitAura("player", i, filter)
			if not spellID then break end
			self:UnregisterEvent("UNIT_NAME_UPDATE")
			if specialAuras[spellID] or filterAuras[spellID] then
				activeAuras["player"][spellID] = true
			end
		end
	end
	if next(activeAuras["player"]) then
		-- ignoreEncounter = false
		addon:Debug("Filtered aura detected. Disabling combat log tracking.")
	end
end

function filters:CheckPlayerControl()
	self.inControl = HasFullControl()
	if not self.inControl then
		addon:Debug("Lost control. Disabling combat log tracking.")
	end
end

function filters:FilterSpell(filter, tree, data)
	data.filtered = filter
	addon:GetSpellInfo(tree, data.spellID, data.periodic).filtered = filter
	addon:UpdateTopRecords(tree)
	addon:UpdateRecords(tree)
end

-- adds a mob to the mob filter
function filters:AddMob(name)
	if self:IsFilteredTarget(name) then
		addon:Message(L["%s is already in mob filter."]:format(name))
	else
		tinsert(self.db.global.mobs, name)
		self:UpdateFilter()
		addon:Message(L["%s added to mob filter."]:format(name))
	end
end

-- adds an aura to the aura filter
function filters:AddAura(spellID)
	local spellName = GetSpellInfo(spellID)
	if self:IsFilteredAura(spellID) then
		addon:Message(L["%s is already in aura filter."]:format(spellName))
	else
		tinsert(self.db.global.auras, spellID)
		-- after we add an aura to the filter; check if we have it
		for auraType, filter in pairs(auraTypes) do
			for i = 1, 40 do
				local spellID = select(11, UnitAura("player", i, filter))
				if not spellID then break end
				for i, v in ipairs(self.db.global.auras) do
					if v == spellID then
						activeAuras[v] = true
						break
					end
				end
			end
		end
		self:UpdateFilter()
		addon:Message(L["%s added to aura filter."]:format(spellName))
	end
end

-- check if a spell passes the filter settings
function filters:SpellPassesFilters(tree, spellName, spellID, isPeriodic, destGUID, destName, school, targetLevel)
	local isPet = tree == "pet"
	if spellID and not (playerSpells[spellID] or IsSpellKnown(spellID, isPet) or (isPet and spellID == 6603)) and self.profile.onlyKnown then
		addon:Debug(format("%s (%d) is not in your%s spell book. Return.", spellName, spellID, isPet and " pet's" or ""))
		return
	end
	
	local unit = isPet and "pet" or "player"
	if ((corruptSpells[unit][spellID] and corruptSpells[unit][spellID][destGUID]) or self:IsEncounterIgnored(unit)) and not self.profile.ignoreAuraFilter then
		addon:Debug(format("Spell (%s) was cast under the influence of a filtered aura. Return.", spellName))
		return
	end
	
	if self:IsIgnoredTarget(destGUID) and not self.profile.ignoreAuraFilter then
		addon:Debug("Target is vulnerable. Return.")
		return
	end
	
	local levelDiff = 0
	if (targetLevel > 0) and (targetLevel < UnitLevel("player")) then
		levelDiff = (UnitLevel("player") - targetLevel)
	end
	
	-- ignore level adjustment if magic damage and the setting is enabled
	if not isHeal and (self.profile.levelFilter >= 0) and (self.profile.levelFilter < levelDiff) and (school == 1 or not self.profile.dontFilterMagic) then
		-- target level is too low to pass level filter
		addon:Debug(format("Target (%s) level too low (%d) and damage school is filtered. Return.", destName, targetLevel))
		return
	end
	
	local filteredTarget = self:IsFilteredTarget(destName, destGUID)
	if filteredTarget then
		addon:Debug(format("Target (%s) is in %s target filter.", destName, filteredTarget))
		return
	end
	
	return true, self:IsFilteredSpell(tree, spellID, isPeriodic and 2 or 1), targetLevel
end

-- check if a spell will be filtered out
function filters:IsFilteredSpell(tree, spellID, periodic)
	local spell = addon:GetSpellInfo(tree, spellID, periodic)
	return (not spell and self.db.profile.filterNew) or (spell and spell.filtered)
end


function filters:IsEncounterIgnored()
	return ignoreEncounter
end

-- scan for filtered auras from the specialAuras table
function filters:IsEmpowered(unit)
	if next(activeAuras[unit]) or (unit == "player" and not self.inControl) then
		return true
	end
end

-- checks if a target will be ignored based on current or recent vulnerability
function filters:IsIgnoredTarget(guid)
	return ignoredTargets[guid]
end

-- checks if a target is affected by any vulnerability auras
function filters:IsVulnerableTarget(guid)
	local corruptTarget = corruptTargets[guid]
	if (corruptTarget and next(corruptTarget)) then
		return true
	end
end

function filters:IsFilteredTarget(targetName, guid)
	-- GUID is provided if the function was called from the combat event handler
	if guid and not self.profile.ignoreMobFilter and specialMobs[tonumber(guid:sub(7, 10), 16)] then
		return "default"
	end
	for _, v in ipairs(self.db.global.mobs) do
		if v:lower() == targetName:lower() then
			return "custom"
		end
	end
end

function filters:IsFilteredAura(spellID)
	if specialAuras[spellID] then
		return true
	end
	for _, v in ipairs(self.db.global.auras) do
		if v == spellID then
			return true
		end
	end
end

function filters:GetUnit(unitFlags, unitGUID)
	if CombatLog_Object_IsA(unitFlags, COMBATLOG_FILTER_ME) then
		return "player"
	elseif addon:IsMyPet(unitFlags, unitGUID) then
		return "pet"
	end
end

function filters:UpdateFilter()
	self[self.type:GetSelectedValue()].scrollFrame:Update()
end
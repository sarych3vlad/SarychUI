-- Global enabled state
LevelUpDisplayEnabled = LevelUpDisplayEnabled or true;

-- Function to check if addon is enabled
local function IsEnabled()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons and SarychUI.db.profile.addons.LevelUpDisplay then
		return SarychUI.db.profile.addons.LevelUpDisplay.enabled ~= false;
	end
	return LevelUpDisplayEnabled;
end

LEVEL_UP_TYPE_CHARACTER = "character";
LEVEL_UP_TYPE_PET = "pet";


LEVEL_UP_EVENTS = {
	[10] = {"TalentsUnlocked", "BGsUnlocked"},
	[15] = {"Glyphs", "LFDUnlocked"},
	[30] = {"GlyphSlots"},
	[40] = {"DualSpec"},
	[50] = {"GlyphSlots"},
	[70] = {"HeroicBurningCrusade", "GlyphSlots"},
	[80] = {"HeroicWrathOfTheLichKing", "GlyphSlots"},
}

SUBICON_TEXCOOR_BOOK 	= {0.64257813, 0.72070313, 0.03710938, 0.11132813};
SUBICON_TEXCOOR_LOCK	= {0.64257813, 0.70117188, 0.11523438, 0.18359375};
SUBICON_TEXCOOR_ARROW 	= {0.72460938, 0.78320313, 0.03710938, 0.10351563};

local levelUpTexCoords = {
	[LEVEL_UP_TYPE_CHARACTER] = {
		dot = { 0.64257813, 0.68359375, 0.18750000, 0.23046875 },
		goldBG = { 0.56054688, 0.99609375, 0.24218750, 0.46679688 },
		gLine = { 0.00195313, 0.81835938, 0.01953125, 0.03320313 },
		gLineDelay = 1.5,
	},
	[LEVEL_UP_TYPE_PET] = {
		dot = { 0.64257813, 0.68359375, 0.18750000, 0.23046875 },
		goldBG = { 0.56054688, 0.99609375, 0.24218750, 0.46679688 },
		gLine = { 0.00195313, 0.81835938, 0.01953125, 0.03320313 },
		tint = {1, 0.5, 0.25},
		textTint = {1, 0.7, 0.25},
		gLineDelay = 1.5,
	},
}

LEVEL_UP_TYPES = {
	["TalentPoint"] = {
		icon="Interface\\Icons\\Ability_Marksmanship",
		subIcon=SUBICON_TEXCOOR_ARROW,
		text=LEVEL_UP_TALENT_MAIN,
		subText=LEVEL_UP_TALENT_SUB,
		link=LEVEL_UP_TALENTS_LINK;
	},
	
	["PetTalentPoint"] = {
		icon="Interface\\Icons\\Ability_Marksmanship",
		subIcon=SUBICON_TEXCOOR_ARROW,
		text=PET_LEVEL_UP_TALENT_MAIN,
		subText=PET_LEVEL_UP_TALENT_SUB,
		link=PET_LEVEL_UP_TALENTS_LINK;
	},
									
	["SpecializationUnlocked"] = {
		icon="Interface\\Icons\\Ability_Marksmanship",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=SPECIALIZATION,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_SPECIALIZATION_LINK
	},
									
	["TalentsUnlocked"] = {
		icon="Interface\\Icons\\Ability_Marksmanship",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=LEVEL_UP_TALENT_MAIN,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_TALENTS_LINK
	},
									
	["BGsUnlocked"] = {
		icon="Interface\\Icons\\Ability_DualWield",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=BATTLEFIELDS,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_BG_LINK
	},

	["LFDUnlocked"] = {
		icon="Interface\\AddOns\\LevelUpDisplay\\Textures\\LEVELUPICON-LFD",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=LOOKING_FOR_DUNGEON,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_LFD_LINK
	},

	["Glyphs"] = {
		icon="Interface\\Icons\\Inv_inscription_tradeskill01",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=GLYPHS,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_GLYPHSLOT_LINK
	},

	["GlyphSlots"] = {
		icon="Interface\\Icons\\Inv_inscription_tradeskill01",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=GLYPH_SLOTS,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_GLYPHSLOT_LINK
	},

	["DualSpec"] = {
		icon="Interface\\Icons\\INV_Misc_Coin_01",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=LEVEL_UP_DUALSPEC,
		subText=LEVEL_UP_FEATURE,
		link=LEVEL_UP_DUAL_SPEC_LINK
	},

	["HeroicBurningCrusade"] = {
		entryType = "heroicdungeon",
		tier = 2,
		icon="Interface\\AddOns\\LevelUpDisplay\\Textures\\ExpansionIcon_BurningCrusade",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=EXPANSION_NAME1,
		subText=LEVEL_UP_HEROIC,
	},
									
	["HeroicWrathOfTheLichKing"] = {
		entryType = "heroicdungeon",
		tier = 3,
		icon="Interface\\AddOns\\LevelUpDisplay\\Textures\\ExpansionIcon_WrathoftheLichKing",
		subIcon=SUBICON_TEXCOOR_LOCK,
		text=EXPANSION_NAME2,
		subText=LEVEL_UP_HEROIC,
	},
	
	--Hacks
	["SealOfVengeance"] = { spellID=31801 },
	["SealofCorruption"] = {spellID=53736 },
	["Plate"] = { spellID=750, feature=true },
	["Mail"] = { spellID=8737, feature=true },
}

LEVEL_UP_CLASS_HACKS = {
	["PALADINAlliance"] = {
		[6] = {"SealOfVengeance"},
		[6] = {"Plate"},
	},	
	["PALADINHorde"] = {
		[66] = {"SealofCorruption"},
		[6] = {"Mail"},
	},	
}

function LevelUpDisplay_OnLoad(self)
	self:RegisterEvent("PLAYER_LEVEL_UP");
	self.currSpell = 0; 
end

function LevelUpDisplay_OnEvent(self, event, ...)
	if not IsEnabled() then
		return;
	end
	local arg1 = ...;
	if event == "PLAYER_LEVEL_UP" then
		local level = ...
		self.level = level;
		self.type = LEVEL_UP_TYPE_CHARACTER;
		self:Show();
		LevelUpDisplaySide:Hide();
	end
end

function LevelUpDisplay_BuildCharacterList(self)
	local nivel;	
	local nivel2;	
	nivel2 = UnitLevel("player");
	local name, icon = "","";
	self.unlockList = {};

	if LEVEL_UP_EVENTS[self.level] then
		nivel = self.level;
		for _, unlockType in pairs(LEVEL_UP_EVENTS[self.level]) do
			self.unlockList[#self.unlockList +1] = LEVEL_UP_TYPES[unlockType];
		end
	end
	
	local spellLink; 
	local HaySpells = nil; 
	local spells = getPlayerSpellsForClass(self.level);
	for _,spell in pairs(spells) do		
		name, _, icon = GetSpellInfo(spell); 
		spellLink = GetSpellLink(tonumber(spell));  
		if(spellLink)then 
			HaySpells = 1;
			self.unlockList[#self.unlockList +1] = { 
				entryType = "spell", 
				text = name, 
				subText = LEVEL_UP_ABILITY, 
				icon = icon, 
				subIcon = SUBICON_TEXCOOR_BOOK,
				link=LEVEL_UP_ABILITY2.." "..GetSpellLink(spell) 
			};
		end
	end
	
	if(HaySpells ~= nil)then 
		if (IsSpellKnown(9961451, false)) then
		else 
		end 
	end 
		
	local dungeons = (GetDungeonsForLevel and GetDungeonsForLevel(self.level)) or {};
	for _, data in ipairs(dungeons) do
    self.unlockList[#self.unlockList + 1] = { 
        entryType = "dungeon",
        text = data.name, 
        subText = LEVEL_UP_DUNGEON, 
        icon = data.icon,
        subIcon = SUBICON_TEXCOOR_LOCK,
        link = LEVEL_UP_DUNGEON .. " " .. data.name,
    };
end
	
	local raids = {};
	for _,raid in pairs(raids) do
		name, icon, link = GetDungeonInfo(raid);
		if link then
			self.unlockList[#self.unlockList +1] = { 
				entryType = "dungeon", 
				text = name, 
				subText = LEVEL_UP_RAID, 
				icon = "Interface\\LFGFrame\\LFGIcon-"..icon, 
				subIcon = SUBICON_TEXCOOR_LOCK,
				link = LEVEL_UP_RAID2.." "..link
			};
		else
			self.unlockList[#self.unlockList +1] = { 
				entryType = "dungeon", 
				text = name, 
				subText = LEVEL_UP_RAID, 
				icon = "Interface\\LFGFrame\\LFGIcon-"..icon, 
				subIcon = SUBICON_TEXCOOR_LOCK,
				link = LEVEL_UP_RAID2.." "..name
			};
		end
	end

	local race, raceFile = UnitRace("player");
	local _, class = UnitClass("player");
	local factionName = UnitFactionGroup("player");
	local hackTable = LEVEL_UP_CLASS_HACKS[class..raceFile] or LEVEL_UP_CLASS_HACKS[class..factionName] or LEVEL_UP_CLASS_HACKS[class];
	if hackTable and hackTable[self.level] then
		hackTable = hackTable[self.level];
		for _,spelltype in pairs(hackTable) do
			if LEVEL_UP_TYPES[spelltype] and LEVEL_UP_TYPES[spelltype].spellID then 
				if LEVEL_UP_TYPES[spelltype].feature then
					name, _, icon = GetSpellInfo(LEVEL_UP_TYPES[spelltype].spellID);
					self.unlockList[#self.unlockList +1] = { 
						text = name, 
						subText = LEVEL_UP_FEATURE, 
						icon = icon, 
						subIcon = SUBICON_TEXCOOR_LOCK,
						link=LEVEL_UP_FEATURE.." "..GetSpellLink(LEVEL_UP_TYPES[spelltype].spellID)
					};
				else
					name, _, icon = GetSpellInfo(LEVEL_UP_TYPES[spelltype].spellID);
					self.unlockList[#self.unlockList +1] = { 
						text = name, 
						subText = LEVEL_UP_ABILITY, 
						icon = icon, 
						subIcon = SUBICON_TEXCOOR_BOOK,
						link=LEVEL_UP_ABILITY2.." "..GetSpellLink(LEVEL_UP_TYPES[spelltype].spellID)
					};
				end
			end
		end	
	end
	
	local features = {};
	for _,feature in pairs(features) do		
		name, _, icon = GetSpellInfo(feature);
		self.unlockList[#self.unlockList +1] = { 
			entryType = "spell", 
			text = name, 
			subText = LEVEL_UP_FEATURE, 
			icon = icon, 
			subIcon = SUBICON_TEXCOOR_LOCK,
			link=LEVEL_UP_FEATURE.." "..GetSpellLink(feature)
		};
	end	
	
	self.currSpell = 1;
end

function LevelUpDisplay_BuildPetList(self)
	local name, icon = "","";
	self.unlockList = {};
	self.currSpell = 1;
end

function LevelUpDisplay_BuildEmptyList(self)
	self.unlockList = {};
	self.currSpell = 1;
end

function LevelUpDisplay_OnShow(self)
	if not IsEnabled() then
		return;
	end 
	local playAnim;
	if self.currSpell == 0 then
		LevelUpDisplay:SetPoint("TOP", 0, -190);
		playAnim = self.levelFrame.levelUp;
		self.levelFrame.reachedText:SetFont("Fonts\\MORPHEUS.ttf", 20, "OUTLINE")
		self.levelFrame.reachedText:SetText("");
		self.levelFrame.levelText:SetFont("Fonts\\MORPHEUS.ttf", 20, "OUTLINE")
		self.levelFrame.levelText:SetText("");
		self.levelFrame.singleline:SetFont("Fonts\\MORPHEUS.ttf", 20, "OUTLINE")
		self.levelFrame.singleline:SetText("");
		self.levelFrame.blockText:SetFont("Fonts\\MORPHEUS.ttf", 20, "OUTLINE")
		self.levelFrame.blockText:SetText("");
		if ( self.type == LEVEL_UP_TYPE_CHARACTER ) then
			LevelUpDisplay_BuildCharacterList(self);
			self.levelFrame.reachedText:SetText(LEVEL_UP_YOU_REACHED)
			self.levelFrame.levelText:SetFormattedText(LEVEL_GAINED,self.level);
		elseif ( self.type == LEVEL_UP_TYPE_PET ) then
			LevelUpDisplay_BuildPetList(self);
		end

		if ( playAnim ) then
			self.gLine:SetTexCoord(unpack(levelUpTexCoords[self.type].gLine));
			self.gLine2:SetTexCoord(unpack(levelUpTexCoords[self.type].gLine));
			if (levelUpTexCoords[self.type].tint) then
				self.gLine:SetVertexColor(unpack(levelUpTexCoords[self.type].tint));
				self.gLine2:SetVertexColor(unpack(levelUpTexCoords[self.type].tint));
			else
				self.gLine:SetVertexColor(1, 1, 1);
				self.gLine2:SetVertexColor(1, 1, 1);
			end
			if (levelUpTexCoords[self.type].textTint) then
				self.levelFrame.levelText:SetTextColor(unpack(levelUpTexCoords[self.type].textTint));
			else
				self.levelFrame.levelText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
			end
			self.gLine.grow.anim1:SetStartDelay(levelUpTexCoords[self.type].gLineDelay);
			self.gLine2.grow.anim1:SetStartDelay(levelUpTexCoords[self.type].gLineDelay);
			self.blackBg.grow.anim1:SetStartDelay(levelUpTexCoords[self.type].gLineDelay);
			playAnim:Play();
			if (levelUpTexCoords[self.type].subIcon) then
				self.battlePetLevelFrame.subIcon:SetTexCoord(unpack(levelUpTexCoords[self.type].subIcon));
			end
		else
			self:Hide();
		end
	end
end

function LevelUpDisplay_AnimStep(self, fast)
	if self.currSpell > #self.unlockList then
		LevelUpDisplay_AnimOut(self, fast);
	else
		local spellInfo = self.unlockList[self.currSpell];
		self.currSpell = self.currSpell+1;

		self.spellFrame.name:SetText("");
		self.spellFrame.flavorText:SetText("");
		self.spellFrame.upperwhite:SetText("");
		self.spellFrame.bottomGiant:SetFont("Fonts\\MORPHEUS.ttf", 20, "OUTLINE")
		self.spellFrame.bottomGiant:SetText("");
		self.spellFrame.subIcon:Hide();
		self.spellFrame.subIconRight:Hide();
		self.spellFrame.rarityUpperwhite:SetText("");
		self.spellFrame.rarityMiddleHuge:SetText("");
		self.spellFrame.rarityIcon:Hide();
		self.spellFrame.rarityValue:SetText("");
		self.spellFrame.rarityValue:Hide();
		
		if (not spellInfo.entryType or
			spellInfo.entryType == "spell" or
			spellInfo.entryType == "dungeon" or
			spellInfo.entryType == "heroicdungeon") then
			self.spellFrame.name:SetText(spellInfo.text);
			self.spellFrame.flavorText:SetText(spellInfo.subText);
			self.spellFrame.icon:SetTexture(spellInfo.icon);
			if (spellInfo.subIcon) then
				self.spellFrame.subIcon:Show();
				self.spellFrame.subIcon:SetTexCoord(unpack(spellInfo.subIcon));
			end
			self.spellFrame.showAnim:Play();
		end
	end
end

function LevelUpDisplay_AnimOut(self, fast)
	self = self or LevelUpDisplay;
	self.currSpell = 0;
	if (fast) then
		self.fastHideAnim:Play();
	else
		self.hideAnim:Play();
	end
end

function LevelUpDisplay_ShowSideDisplay(level, levelUpType, arg1)
	if not IsEnabled() then
		return;
	end
	if LevelUpDisplaySide.level and LevelUpDisplaySide.level == level and LevelUpDisplaySide.type == levelUpType and LevelUpDisplaySide.arg1 == arg1 then
		if LevelUpDisplaySide:IsVisible() then		
			LevelUpDisplaySide:Hide();	
		else	
			LevelUpDisplaySide:Show();
		end
	else
		LevelUpDisplaySide.level = level;
		LevelUpDisplaySide.type = levelUpType;
		LevelUpDisplaySide.arg1 = arg1;
		LevelUpDisplaySide:Hide();
		LevelUpDisplaySide:Show();
	end
end

function LevelUpDisplaySide_OnShow(self)
	if ( self.type == LEVEL_UP_TYPE_CHARACTER ) then
		LevelUpDisplay_BuildCharacterList(self);
		self.reachedText:SetText(LEVEL_UP_YOU_REACHED);
		self.levelText:SetFormattedText(LEVEL_GAINED,self.level);
	end
	self.goldBG:SetTexCoord(unpack(levelUpTexCoords[self.type].goldBG));
	self.dot:SetTexCoord(unpack(levelUpTexCoords[self.type].dot));
	
	if (levelUpTexCoords[self.type].tint) then
		self.goldBG:SetVertexColor(unpack(levelUpTexCoords[self.type].tint));
		self.dot:SetVertexColor(unpack(levelUpTexCoords[self.type].tint));
	else
		self.goldBG:SetVertexColor(1, 1, 1);
		self.dot:SetVertexColor(1, 1, 1);
	end
	
	if (levelUpTexCoords[self.type].textTint) then
		self.levelText:SetTextColor(unpack(levelUpTexCoords[self.type].textTint));
	else
		self.levelText:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
	
	local i = 1;
	local displayFrame = _G["LevelUpDisplaySideUnlockFrame1"];
	while i <=  #self.unlockList do	
		if not displayFrame then
			displayFrame = CreateFrame("FRAME", "LevelUpDisplaySideUnlockFrame"..i, LevelUpDisplaySide, "LevelUpSkillTemplate");
			displayFrame:SetPoint("TOP",  _G["LevelUpDisplaySideUnlockFrame"..(i-1)], "BOTTOM", 0, -1);
			displayFrame:SetAlpha(0.0);
		end
		i = i+1;		
		displayFrame = _G["LevelUpDisplaySideUnlockFrame"..i];
	end
	self:SetHeight(65);
	self.fadeIn:Play();
end

function LevelUpDisplaySide_OnHide(self)
	local displayFrame = _G["LevelUpDisplaySideUnlockFrame1"];
	local i = 1;
	while displayFrame do 	
		if displayFrame.sideAnimIn:IsPlaying() then
			displayFrame.sideAnimIn:Stop();
		end				
		displayFrame:SetAlpha(0.0);
		i = i+1;
		displayFrame = _G["LevelUpDisplaySideUnlockFrame"..i];
	end	
end

function LevelUpDisplaySide_AnimStep(self)
	if self.currSpell > 1 then
		_G["LevelUpDisplaySideUnlockFrame"..(self.currSpell-1)]:SetAlpha(1.0);
	end	

	if self.currSpell <= #self.unlockList then
		local spellInfo = self.unlockList[self.currSpell];
		local displayFrame = _G["LevelUpDisplaySideUnlockFrame"..self.currSpell];
		displayFrame.name:SetText(spellInfo.text);
		displayFrame.flavorText:SetText(spellInfo.subText);
		displayFrame.icon:SetTexture(spellInfo.icon);
		displayFrame.subIcon:SetTexCoord(unpack(spellInfo.subIcon));
		displayFrame.subIconRight:Hide();
		displayFrame.sideAnimIn:Play();
		self.currSpell = self.currSpell+1;
		self:SetHeight(self:GetHeight()+45);
	end
end

function LevelUpDisplaySide_Remove()
	LevelUpDisplaySide.fadeOut:Play();
end

function LevelUpDisplay_ChatPrint(self, level, levelUpType, ...)
	local info;
	local chatLevelUP = {level = level, type = levelUpType};
	local levelstring;
	if ( levelUpType == LEVEL_UP_TYPE_CHARACTER ) then
		LevelUpDisplay_BuildCharacterList(chatLevelUP);
		levelstring = format(LEVEL_UP, level);
		info = ChatTypeInfo["SYSTEM"];
	elseif ( levelUpType == LEVEL_UP_TYPE_PET ) then
		LevelUpDisplay_BuildPetList(chatLevelUP);
		local petName = UnitName("pet");
		if (petName) then
			levelstring = "";
		else
			levelstring = "";
		end
		info = ChatTypeInfo["SYSTEM"];
	end
	self:AddMessage(levelstring, info.r, info.g, info.b, info.id);
	for _,skill in pairs(chatLevelUP.unlockList) do
		if skill.entryType == "heroicdungeon" then
			self:AddMessage(LEVEL_UP_HEROIC2..skill.text, info.r, info.g, info.b, info.id);
		elseif skill.entryType ~= "spell" then
			self:AddMessage(skill.link, info.r, info.g, info.b, info.id);
		end
	end
end

function getPlayerSpellsForClass(level)
	local spells = {};
	local loc,class = UnitClass("player")
	spells = Getspellforleveltrainer(class, level)
	return spells;
end

function Getspellforleveltrainer(class, level)
	local spellList = {
		WARRIOR = {
			[1] = {{78}, {2457}, {6673}},
			[4] = {{100}, {772}},
			[6] = {{3127}, {6343, "talent", 6343}, {34428}},
			[8] = {{284}, {1715}},
			[10] = {{71}, {355}, {2687}, {6546}, {7386}},
			[12] = {{72}, {5242}, {7384}},
			[14] = {{1160}, {6572}},
			[16] = {{285}, {694, "talent", 694}, {2565}},
			[18] = {{676}, {8198}},
			[20] = {{674}, {845}, {6547}, {12678}, {20230}},
			[22] = {{5246}, {6192, "talent", 6192}},
			[25] = {{1608}, {5308}, {6190}, {6574}},
			[26] = {{1161}, {6178}},
			[28] = {{871}, {8204}},
			[30] = {{1464}, {2458}, {6548}, {7369}, {20252}},
			[32] = {{11549}, {11564}, {18499}, {20658}},
			[34] = {{7379}, {11554}},
			[36] = {{1680}},
			[38] = {{6552}, {8205}, {8820}},
			[40] = {{750}, {11565}, {11572}, {11608}, {20660}, {23922}},
			[42] = {{11550}},
			[44] = {{11555}, {11600}},
			[46] = {{11578}, {11604}},
			[48] = {{11566}, {11580}, {20661}, {23923}},
			[50] = {{1719}, {11609}, {11573}},
			[52] = {{11551}},
			[54] = {{11556}, {11601}, {11605}, {23924}},
			[56] = {{11567}, {20662}},
			[58] = {{11581}},
			[60] = {{11574}, {20569}, {23925}, {25286}, {25288}, {25289}},
			[61] = {{25241}},
			[62] = {{25202}},
			[63] = {{25269}},
			[64] = {{23920}},
			[65] = {{25234}},
			[66] = {{25258}, {29707}},
			[67] = {{25264}},
			[68] = {{469}, {25208}, {25231}},
			[69] = {{2048}, {25242}},
			[70] = {{3411}, {25203}, {25236}, {30324}, {30356}, {30357}},
			[71] = {{46845}, {64382}},
			[72] = {{47449}, {47519}},
			[73] = {{47470}, {47501}},
			[74] = {{47439}, {47474}},
			[75] = {{47487}, {55694}},
			[76] = {{47450}, {47465}},
			[77] = {{47520}},
			[78] = {{47436}, {47502}},
			[79] = {{47437}, {47475}},
			[80] = {{47440}, {47471}, {47488}, {57755}, {57823}},
		},
		PALADIN = {
			[1] = {{21084}, {465}, {635}},
			[4] = {{19740}, {20271}},
			[6] = {{498}, {639}},
			[8] = {{1152}, {853}, {3127}},
			[10] = {{1022}, {633}, {10290}},
			[12] = {{53408}, {7328}, {19834}},
			[14] = {{31789}, {19742}, {647}},
			[16] = {{7294}, {62124}, {25780}},
			[18] = {{1044}, {10290}},
			[20] = {{20217}, {19750}, {26573}, {5502}, {34769}, {879}, {643}},
			[22] = {{1026}, {19746}, {20164}, {19835}},
			[24] = {{10322}, {5588}, {5599}, {19850}, {10326}},
			[26] = {{1038}, {19939}, {10298}},
			[28] = {{53407}, {19876}, {5614}},
			[30] = {{19752}, {20165}, {1042}, {20116}, {2800}, {10291}},
			[32] = {{19888}, {19836}},
			[34] = {{19852}, {19940}, {642}},
			[36] = {{10324}, {19891}, {5615}, {10299}},
			[38] = {{10278}, {20166}, {3472}},
			[40] = {{750}, {19895}, {5589}, {20922}, {1032}},
			[42] = {{19941}, {4987}, {19853}, {19837}},
			[44] = {{24275}, {10312}},
			[46] = {{6940}, {10328}, {10300}},
			[48] = {{19899}, {20772}},
			[50] = {{19942}, {2812}, {20923}, {10310}, {10292}},
			[52] = {{19896}, {25782}, {24274}, {10313}, {19838}},
			[54] = {{10308}, {19854}, {25894}, {10329}},
			[56] = {{19898}, {10301}},
			[58] = {{19943}},
			[60] = {{25916}, {25918}, {25290}, {20924}, {25291}, {20773}, {10314}, {10293}, {10318}, {25292}, {25898}, {24239}},
			[62] = {{27135}, {32223}},
			[63] = {{27151}},
			[65] = {{27142}, {27143}},
			[66] = {{27137}, {27150}},
			[68] = {{27152}, {27138}, {27180}},
			[69] = {{27154}, {27139}},
			[70] = {{27141}, {27140}, {27173}, {27149}, {27136}, {27153}, {31884}},
			[71] = {{48935}, {48937}, {54428}},
			[72] = {{48816}, {48949}},
			[73] = {{48800}, {48931}, {48933}},
			[74] = {{48784}, {48941}, {48805}}, 
			[75] = {{48781}, {53600}, {48818}},
			[76] = {{54043}, {48943}},
			[77] = {{48936}, {48938}, {48945}},
			[78] = {{48947}, {48788}},
			[79] = {{48932}, {48934}, {48942}, {48785}, {48950}, {48801}},
			[80] = {{61411}, {48819}, {53601}, {48782}, {48806}},
		},
		MAGE = {
			[1] = {{1459}},
			[4] = {{116}, {5504}},
			[6] = {{2136}, {143}, {587}},
			[8] = {{205}, {118}, {5143}},
			[10] = {{122}, {7300}, {5505}},
			[12] = {{145}, {130}, {604}, {597}},
			[14] = {{2137}, {837}, {1449}, {1460}},
			[16] = {{2120}, {5144}},
			[18] = {{3140}, {475}, {1008}},
			[20] = {{543}, {7322}, {7301}, {10}, {12824}, {12051}, {1953}, {5506}, {3562}, {3561}, {1463}},
			[22] = {{2138}, {2948}, {6143}, {990}, {8437}},
			[24] = {{12505, "talent", 11366}, {2121}, {8400}, {2139}, {8450}, {5145}},
			[26] = {{865}, {120}, {8406}},
			[28] = {{8444}, {6141}, {759}, {1461}, {8494}},
			[30] = {{8457}, {12522, "talent", 11366}, {8412}, {8401}, {45438}, {7302}, {28272}, {6127}, {3565}, {32271}, {8455}, {8438}},
			[32] = {{8422}, {8461}, {8407}, {6129}, {8416}},
			[34] = {{8445}, {8492}, {6117}},
			[35] = {{49360}, {49359}},
			[36] = {{13018, "talent", 11113}, {12523, "talent", 11366}, {8402}, {8427}, {8451}, {8495}},
			[38] = {{8413}, {8408}, {3552}, {8439}},
			[40] = {{8458}, {8423}, {8446}, {6131}, {7320}, {11416}, {10059}, {32266}, {12825}, {10138}, {8417}},
			[42] = {{12524, "talent", 11366}, {10148}, {8462}, {10159}, {10144}, {10169}, {10156}},
			[44] = {{13019, "talent", 11113}, {10179}, {10185}, {10191}},
			[46] = {{10197}, {10205}, {13031, "talent", 11426}, {22782}, {10201}},
			[48] = {{12525, "talent", 11366}, {10215}, {10149}, {10173}, {10053}, {10211}},
			[50] = {{10223}, {10160}, {10180}, {10219}, {11419}, {10139}},
			[52] = {{13020, "talent", 11113}, {10206}, {10177}, {13032, "talent", 11426}, {10186}, {10145}, {10192}},
			[54] = {{12526, "talent", 11366}, {10199}, {10150}, {10230}, {10170}, {10202}},
			[56] = {{33041, "talent", 31661}, {10216}, {10181}, {23028}, {10212}, {10157}},
			[58] = {{10207}, {10161}, {13033, "talent", 11426}, {22783}, {10054}},
			[60] = {{13021, "talent", 11113}, {10225}, {18809, "talent", 11366}, {10151}, {25306}, {28609}, {25304}, {10220}, {10187}, {10174}, {12826}, {10140}, {28612}, {33690}, {25345}, {10193}},
			[61] = {{27078}},
			[62] = {{25306}, {30482}, {27080}},
			[63] = {{27071}, {27130}, {27075}},
			[64] = {{33042, "talent", 31661}, {27086}, {27134, "talent", 11426}, {30451}},
			[65] = {{27133, "talent", 11113}, {27073}, {27087}, {33691}, {37420}},
			[66] = {{27132, "talent", 11366}, {27070}, {30455}},
			[67] = {{27088}, {33944}},
			[68] = {{27085}, {66}, {27101}, {27131}},
			[69] = {{27128}, {27072}, {27124}, {27125}, {33946}, {38699}},
			[70] = {{33933, "talent", 11113}, {33043, "talent", 31661}, {55359, "talent", 44457}, {33938, "talent", 11366}, {27079}, {38692}, {27074}, {32796}, {33405, "talent", 11426}, {38697}, {43987}, {27090}, {33717}, {27127}, {38704}, {27082}, {27126}, {44780, "talent", 44425}, {30449}},
			[71] = {{43045}, {43023}, {53140}, {42894}},
			[72] = {{42925}, {42930}, {42913}},
			[73] = {{42890, "talent", 11366}, {42858}, {43019}},
			[74] = {{42872}, {42832}, {42939}, {53142}},
			[75] = {{42944, "talent", 11113}, {42949, "talent", 31661}, {44614}, {42917}, {43038, "talent", 11426}, {42841}, {42955}, {42843}},
			[76] = {{43015}, {42896}, {42920}},
			[77] = {{42891, "talent", 11366}, {42985}, {43017}},
			[78] = {{43010}, {42833}, {42859}, {42914}},
			[79] = {{42926}, {43046}, {43012}, {42931}, {42842}, {43008}, {43024}, {42846}, {43020}},
			[80] = {{42945, "talent", 11113}, {42950, "talent", 31661}, {55360, "talent", 44457}, {42873}, {47610}, {43039, "talent", 11426}, {42940}, {55342}, {58659}, {61025}, {61780}, {61721}, {28271}, {61305}, {42956}, {42897}, {43002}, {42921}, {42995}, {44781, "talent", 44425}},
		},
		HUNTER = {
			[1] = {{1494}},
			[4] = {{13163}, {1978}},
			[6] = {{1130}, {3044}},
			[8] = {{14260}, {3127}, {5116}},
			[10] = {{19883}, {982}, {13165}, {6991}, {883}, {1515}, {2641}, {13549}},
			[12] = {{2974}, {136}, {20736}, {14281}},
			[14] = {{1002}, {6197}, {1513}},
			[16] = {{13795}, {14261}, {1495}, {5118}},
			[18] = {{19884}, {14318}, {2643}, {13550}},
			[20] = {{674}, {1499}, {781}, {34074}, {3111}, {14282}},
			[22] = {{14323}, {3043}},
			[24] = {{19885}, {14262}, {1462}},
			[26] = {{19880}, {14302}, {3045}, {13551}},
			[28] = {{13809}, {14319}, {3661}, {20900, "talent", 19434}, {14283}},
			[30] = {{5384}, {14269}, {13161}, {14326}, {14288}},
			[32] = {{19878}, {14263}, {1543}},
			[34] = {{13813}, {13552}},
			[36] = {{14303}, {3662}, {20901, "talent", 19434}, {3034}, {14284}},
			[38] = {{14320}},
			[40] = {{19882}, {14310}, {14264}, {8737}, {13159}, {1510}, {14324}},
			[42] = {{20909, "talent", 19306}, {14289}, {13553}},
			[44] = {{14316}, {14270}, {13542}, {20902, "talent", 19434}, {14285}},
			[46] = {{14304}, {20043}, {14327}},
			[48] = {{14265}, {14321}},
			[50] = {{19879}, {24132, "talent", 19386}, {56641}, {14294}, {13554}},
			[52] = {{13543}, {20903, "talent", 19434}, {14286}},
			[54] = {{14317}, {20910, "talent", 19306}, {14290}},
			[56] = {{14305}, {14266}, {20190}},
			[57] = {{63668, "talent", 3674}},
			[58] = {{14271}, {14322}, {14295}, {14325}, {13555}},
			[60] = {{14311}, {19263}, {24133, "talent", 19386}, {25296}, {13544}, {62757}, {25294}, {20904, "talent", 19434}, {25295}, {19801}, {14287}},
			[61] = {{27025}},
			[62] = {{34120}},
			[63] = {{27014}, {63669, "talent", 3674}},
			[65] = {{27023}},
			[66] = {{27067, "talent", 19306}, {34026}},
			[67] = {{27022}, {27021}, {27016}},
			[68] = {{34600}, {27045}, {27044}, {27046}},
			[69] = {{63670, "talent", 3674}, {27019}},
			[70] = {{34477}, {60051, "talent", 53301}, {27068, "talent", 19386}, {36916}, {27065, "talent", 19434}},
			[71] = {{49066}, {48995}, {49051}, {53351}},
			[72] = {{48998, "talent", 19306}, {49055}},
			[73] = {{49000}, {49044}},
			[74] = {{61846}, {48989}, {58431}, {49047}},
			[75] = {{60052, "talent", 53301}, {49011, "talent", 19386}, {63671, "talent", 3674}, {53271}, {49049, "talent", 19434}, {61005}},
			[76] = {{49071}, {53338}},
			[77] = {{49067}, {48996}, {49052}},
			[78] = {{48999, "talent", 19306}, {49056}},
			[79] = {{49001}, {49045}},
			[80] = {{60192}, {60053, "talent", 53301}, {49012, "talent", 19386}, {53339}, {63672, "talent", 3674}, {61847}, {48990}, {58434}, {49048}, {49050, "talent", 19434}, {61006}},
		},		
	}
	
	local filteredSpells = {}
	if spellList[class] and spellList[class][level] then
		for _, spellData in ipairs(spellList[class][level]) do
			local spellID = spellData[1]
			local checkType = spellData[2]
			if checkType == "talent" then
				local talentID = spellData[3]
				local minRank = spellData[4] or 1
				
				-- Показываем способность ТОЛЬКО если талант изучен
				if IsSpellKnown(talentID) then
					table.insert(filteredSpells, spellID)
				end
			else
				table.insert(filteredSpells, spellID)
			end
		end
	end
	return filteredSpells
end
-- Transfer: detect /equip item names in macros and remap them to owned gear.

local strlower, strmatch, strtrim, strgsub = string.lower, string.match, strtrim, string.gsub
local tinsert, tsort = table.insert, table.sort

local Transfer = SarychUI.Transfer
if not Transfer then
	return
end

local EQUIP_LOC_GROUPS = {
	INVTYPE_WEAPON = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND" },
	INVTYPE_WEAPONMAINHAND = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND" },
	INVTYPE_WEAPONOFFHAND = { "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_HOLDABLE" },
	INVTYPE_HOLDABLE = { "INVTYPE_HOLDABLE", "INVTYPE_WEAPONOFFHAND" },
	INVTYPE_SHIELD = { "INVTYPE_SHIELD" },
	INVTYPE_2HWEAPON = { "INVTYPE_2HWEAPON" },
	INVTYPE_RANGED = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN" },
	INVTYPE_RANGEDRIGHT = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN" },
	INVTYPE_THROWN = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN" },
	INVTYPE_HEAD = { "INVTYPE_HEAD" },
	INVTYPE_NECK = { "INVTYPE_NECK" },
	INVTYPE_SHOULDER = { "INVTYPE_SHOULDER" },
	INVTYPE_BODY = { "INVTYPE_BODY" },
	INVTYPE_CHEST = { "INVTYPE_CHEST", "INVTYPE_ROBE" },
	INVTYPE_ROBE = { "INVTYPE_CHEST", "INVTYPE_ROBE" },
	INVTYPE_WAIST = { "INVTYPE_WAIST" },
	INVTYPE_LEGS = { "INVTYPE_LEGS" },
	INVTYPE_FEET = { "INVTYPE_FEET" },
	INVTYPE_WRIST = { "INVTYPE_WRIST" },
	INVTYPE_HAND = { "INVTYPE_HAND" },
	INVTYPE_FINGER = { "INVTYPE_FINGER" },
	INVTYPE_TRINKET = { "INVTYPE_TRINKET" },
	INVTYPE_CLOAK = { "INVTYPE_CLOAK" },
	INVTYPE_TABARD = { "INVTYPE_TABARD" },
	INVTYPE_RELIC = { "INVTYPE_RELIC" },
}

local slashCache

local function buildSlashCache()
	if slashCache then
		return slashCache
	end
	slashCache = { equip = {}, equipslot = {} }
	local function add(bucket, value)
		if type(value) == "string" and value ~= "" then
			local key = strlower(value)
			if key:sub(1, 1) == "/" then
				key = key:sub(2)
			end
			bucket[key] = true
		end
	end
	for i = 1, 20 do
		add(slashCache.equip, _G["SLASH_EQUIP" .. i])
		add(slashCache.equipslot, _G["SLASH_EQUIP_TO_SLOT" .. i])
	end
	-- Fallbacks if globals are missing on a private build.
	add(slashCache.equip, "equip")
	add(slashCache.equip, "eq")
	add(slashCache.equip, "экип")
	add(slashCache.equipslot, "equipslot")
	add(slashCache.equipslot, "надеть")
	return slashCache
end

local function stripConditions(rest)
	rest = strtrim(rest or "")
	-- Options may appear before and/or after the slot number:
	-- /equipslot [combat] 16 Item
	-- /equipslot 16 [combat] Item
	while true do
		local changed = false
		while rest:sub(1, 1) == "[" do
			local close = rest:find("%]", 1, true)
			if not close then
				break
			end
			rest = strtrim(rest:sub(close + 1))
			changed = true
		end
		-- Drop trailing "; ..." reset / chained commands.
		local semi = rest:find(";", 1, true)
		if semi then
			rest = strtrim(rest:sub(1, semi - 1))
			changed = true
		end
		if not changed then
			break
		end
	end
	return rest
end

-- /equipslot 16 Item  OR  /equipslot [opt] 16 [opt] Item  → item name only (no slot).
local function parseEquipSlotItem(rest)
	rest = strtrim(rest or "")
	-- Peel leading option blocks.
	while rest:sub(1, 1) == "[" do
		local close = rest:find("%]", 1, true)
		if not close then
			break
		end
		rest = strtrim(rest:sub(close + 1))
	end
	local slot, after = strmatch(rest, "^(%d+)%s+(.-)%s*$")
	if not slot then
		return
	end
	after = strtrim(after or "")
	-- Peel option blocks between slot and item name.
	while after:sub(1, 1) == "[" do
		local close = after:find("%]", 1, true)
		if not close then
			break
		end
		after = strtrim(after:sub(close + 1))
	end
	local semi = after:find(";", 1, true)
	if semi then
		after = strtrim(after:sub(1, semi - 1))
	end
	if after == "" or strmatch(after, "^%d+$") then
		return
	end
	return after
end

local function parseEquipLine(line)
	line = strtrim(line or "")
	if line == "" or line:sub(1, 1) ~= "/" then
		return
	end
	local cmd, rest = strmatch(line, "^/(%S+)%s+(.-)%s*$")
	if not cmd or not rest then
		return
	end
	local slashes = buildSlashCache()
	local key = strlower(cmd)
	if slashes.equipslot[key] then
		return parseEquipSlotItem(rest)
	end
	if slashes.equip[key] then
		local item = stripConditions(rest)
		-- Guard: never treat a bare "/equip 16" style leftover as an item.
		if item and item ~= "" and not strmatch(item, "^%d+$") then
			return item
		end
	end
end

local DEFAULT_ICONS = {
	INVTYPE_SHIELD = "Interface\\Icons\\INV_Shield_06",
	INVTYPE_WEAPON = "Interface\\Icons\\INV_Axe_09",
	INVTYPE_WEAPONMAINHAND = "Interface\\Icons\\INV_Sword_04",
	INVTYPE_WEAPONOFFHAND = "Interface\\Icons\\INV_Misc_Bone_ElfSkull_01",
	INVTYPE_HOLDABLE = "Interface\\Icons\\INV_Offhand_OutlandRaid_03blue",
	INVTYPE_2HWEAPON = "Interface\\Icons\\INV_Axe_68",
	INVTYPE_RANGED = "Interface\\Icons\\INV_Weapon_Bow_02",
	INVTYPE_RANGEDRIGHT = "Interface\\Icons\\INV_Weapon_Rifle_01",
	INVTYPE_THROWN = "Interface\\Icons\\INV_ThrowingKnife_02",
	INVTYPE_HEAD = "Interface\\Icons\\INV_Helmet_03",
	INVTYPE_NECK = "Interface\\Icons\\INV_Jewelry_Necklace_01",
	INVTYPE_SHOULDER = "Interface\\Icons\\INV_Shoulder_02",
	INVTYPE_CHEST = "Interface\\Icons\\INV_Chest_Chain",
	INVTYPE_ROBE = "Interface\\Icons\\INV_Chest_Cloth_17",
	INVTYPE_WAIST = "Interface\\Icons\\INV_Belt_02",
	INVTYPE_LEGS = "Interface\\Icons\\INV_Pants_01",
	INVTYPE_FEET = "Interface\\Icons\\INV_Boots_01",
	INVTYPE_WRIST = "Interface\\Icons\\INV_Bracer_07",
	INVTYPE_HAND = "Interface\\Icons\\INV_Gauntlets_05",
	INVTYPE_FINGER = "Interface\\Icons\\INV_Jewelry_Ring_01",
	INVTYPE_TRINKET = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01",
	INVTYPE_CLOAK = "Interface\\Icons\\INV_Misc_Cape_02",
	INVTYPE_TABARD = "Interface\\Icons\\INV_Shirt_GuildTabard_01",
	INVTYPE_RELIC = "Interface\\Icons\\INV_Relics_LibramofGrace",
}

-- Guess slot from the item name when GetItemInfo has not cached it yet.
local function guessEquipLoc(name)
	local n = strlower(name or "")
	if n == "" then
		return
	end
	if n:find("щит", 1, true) or n:find("shield", 1, true) then
		return "INVTYPE_SHIELD"
	end
	if n:find("двуруч", 1, true) or n:find("2h", 1, true) or n:find("two%-hand") or n:find("посох", 1, true) or n:find("staff", 1, true) or n:find("алебарда", 1, true) or n:find("кирка", 1, true) then
		return "INVTYPE_2HWEAPON"
	end
	if n:find("лук", 1, true) or n:find("bow", 1, true) or n:find("арбалет", 1, true) or n:find("crossbow", 1, true) then
		return "INVTYPE_RANGED"
	end
	if n:find("ружье", 1, true) or n:find("gun", 1, true) or n:find("жезл", 1, true) or n:find("wand", 1, true) then
		return "INVTYPE_RANGEDRIGHT"
	end
	if n:find("метател", 1, true) or n:find("thrown", 1, true) then
		return "INVTYPE_THROWN"
	end
	if n:find("ожерел", 1, true) or n:find("амулет", 1, true) or n:find("neck", 1, true) or n:find("necklace", 1, true) then
		return "INVTYPE_NECK"
	end
	if n:find("кольц", 1, true) or n:find("ring", 1, true) then
		return "INVTYPE_FINGER"
	end
	if n:find("тринкет", 1, true) or n:find("trinket", 1, true) or n:find("аксессуар", 1, true) then
		return "INVTYPE_TRINKET"
	end
	if n:find("плащ", 1, true) or n:find("cloak", 1, true) or n:find("cape", 1, true) then
		return "INVTYPE_CLOAK"
	end
	if n:find("шлем", 1, true) or n:find("капюшон", 1, true) or n:find("helmet", 1, true) or n:find("head", 1, true) then
		return "INVTYPE_HEAD"
	end
	if n:find("наплеч", 1, true) or n:find("shoulder", 1, true) then
		return "INVTYPE_SHOULDER"
	end
	if n:find("нагрудник", 1, true) or n:find("кираса", 1, true) or n:find("chest", 1, true) or n:find("robe", 1, true) or n:find("одеяние", 1, true) then
		return "INVTYPE_CHEST"
	end
	if n:find("пояс", 1, true) or n:find("belt", 1, true) or n:find("waist", 1, true) then
		return "INVTYPE_WAIST"
	end
	if n:find("поножи", 1, true) or n:find("штаны", 1, true) or n:find("legs", 1, true) or n:find("pants", 1, true) then
		return "INVTYPE_LEGS"
	end
	if n:find("сапог", 1, true) or n:find("boots", 1, true) or n:find("feet", 1, true) then
		return "INVTYPE_FEET"
	end
	if n:find("наруч", 1, true) or n:find("bracer", 1, true) or n:find("wrist", 1, true) then
		return "INVTYPE_WRIST"
	end
	if n:find("перчат", 1, true) or n:find("gloves", 1, true) or n:find("gauntlet", 1, true) or n:find("hand", 1, true) then
		return "INVTYPE_HAND"
	end
	if n:find("реликви", 1, true) or n:find("relic", 1, true) or n:find("идол", 1, true) or n:find("тотем", 1, true) or n:find("либрам", 1, true) or n:find("печать", 1, true) then
		return "INVTYPE_RELIC"
	end
	if n:find("одноруч", 1, true) or n:find("1h", 1, true) or n:find("топор", 1, true) or n:find("меч", 1, true) or n:find("кинжал", 1, true) or n:find("булава", 1, true) or n:find("молот", 1, true) or n:find("axe", 1, true) or n:find("sword", 1, true) or n:find("dagger", 1, true) or n:find("mace", 1, true) then
		return "INVTYPE_WEAPON"
	end
	if n:find("offhand", 1, true) or n:find("левой руки", 1, true) or n:find("off%-hand") then
		return "INVTYPE_HOLDABLE"
	end
end

local function linkFromRef(ref)
	if type(ref) ~= "string" or ref == "" then
		return
	end
	if ref:find("item:", 1, true) then
		return ref
	end
	if strmatch(ref, "^%-?%d+$") then
		return "item:" .. ref
	end
	return ref
end

local function iconFromRef(ref)
	local link = linkFromRef(ref)
	if not link then
		return
	end
	if type(GetItemIcon) == "function" then
		local icon = GetItemIcon(link)
		if icon then
			return icon
		end
		local id = tonumber(strmatch(link, "item:(%-?%d+)")) or tonumber(link)
		if id then
			return GetItemIcon(id)
		end
	end
end

local nameCache -- [lowerName] = { name, link, quality, equipLoc, texture }

local function rememberName(name, link, quality, equipLoc, texture)
	if type(name) ~= "string" or name == "" then
		return
	end
	nameCache = nameCache or {}
	local key = strlower(name)
	local prev = nameCache[key]
	if prev and prev.texture and prev.equipLoc then
		return
	end
	nameCache[key] = {
		name = name,
		link = link,
		quality = tonumber(quality) or (prev and prev.quality) or 1,
		equipLoc = equipLoc or (prev and prev.equipLoc),
		texture = texture or (prev and prev.texture) or iconFromRef(link),
	}
end

local function ingestLink(link)
	link = linkFromRef(link)
	if not link or type(GetItemInfo) ~= "function" then
		return
	end
	local name, fullLink, quality, _, _, _, _, _, equipLoc, texture = GetItemInfo(link)
	if name then
		rememberName(name, fullLink or link, quality, equipLoc, texture or iconFromRef(link))
		return
	end
	-- Warm client cache for next pass / next open.
	pcall(GetItemInfo, link)
end

local function scanBagnonForeverNames()
	local db = rawget(_G, "BagnonForeverDB")
	if type(db) ~= "table" then
		return
	end
	for realm, players in pairs(db) do
		if type(players) == "table" and realm ~= "version" then
			for _, bags in pairs(players) do
				if type(bags) == "table" then
						for key, value in pairs(bags) do
						if type(value) == "string" and key ~= "g" and key ~= "numBankSlots" then
							local ref = strmatch(value, "^([^,]+)")
							if ref then
								ingestLink(ref)
							end
						end
					end
				end
			end
		end
	end
end

local function scanAuctionatorCache()
	if type(Atr_GetItemLink) == "function" then
		-- Atr_GetItemLink only helps for names already asked; warm nothing here.
	end
	local hist = rawget(_G, "AUCTIONATOR_PRICING_HISTORY")
	if type(hist) == "table" then
		for name, _ in pairs(hist) do
			if type(name) == "string" and name ~= "" and name:sub(1, 1) ~= "_" then
				if type(Atr_GetItemLink) == "function" then
					local link = Atr_GetItemLink(name)
					if link then
						ingestLink(link)
					end
				end
				-- Price DB keys are item names; pull into GetItemInfo cache if known.
				if type(GetItemInfo) == "function" then
					local n, link, quality, _, _, _, _, _, equipLoc, texture = GetItemInfo(name)
					if n then
						rememberName(n, link, quality, equipLoc, texture)
					end
				end
			end
		end
	end
end

local function resolveItem(name)
	if type(name) ~= "string" or name == "" then
		return
	end
	local key = strlower(name)
	if nameCache and nameCache[key] then
		local c = nameCache[key]
		return c.name, c.link, c.quality, c.equipLoc, c.texture
	end
	if type(GetItemInfo) == "function" then
		local itemName, link, quality, _, _, _, _, _, equipLoc, texture = GetItemInfo(name)
		if itemName then
			rememberName(itemName, link, quality, equipLoc, texture)
			return itemName, link, quality, equipLoc, texture
		end
	end
	if type(Atr_GetItemLink) == "function" then
		local link = Atr_GetItemLink(name)
		if link then
			ingestLink(link)
			if nameCache and nameCache[key] then
				local c = nameCache[key]
				return c.name, c.link, c.quality, c.equipLoc, c.texture
			end
			local texture = iconFromRef(link)
			local equipLoc = guessEquipLoc(name)
			rememberName(name, link, 4, equipLoc, texture)
			return name, link, 4, equipLoc, texture
		end
	end
end

local function addOwnedItem(byLoc, byName, link)
	if type(link) ~= "string" then
		return
	end
	local name, _, quality, _, _, _, _, _, equipLoc, texture = GetItemInfo(link)
	if not name or type(equipLoc) ~= "string" or equipLoc == "" then
		return
	end
	rememberName(name, link, quality, equipLoc, texture)
	local key = strlower(name)
	if byName[key] then
		return
	end
	local entry = {
		name = name,
		link = link,
		quality = tonumber(quality) or 1,
		equipLoc = equipLoc,
		icon = texture or iconFromRef(link),
	}
	byName[key] = entry
	byLoc[equipLoc] = byLoc[equipLoc] or {}
	tinsert(byLoc[equipLoc], entry)
end

function Transfer.ScanOwnedGear()
	local byLoc, byName = {}, {}
	for slot = 1, 19 do
		addOwnedItem(byLoc, byName, GetInventoryItemLink("player", slot))
	end
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local slots = GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			addOwnedItem(byLoc, byName, GetContainerItemLink(bag, slot))
		end
	end
	for _, list in pairs(byLoc) do
		tsort(list, function(a, b)
			if a.quality ~= b.quality then
				return a.quality > b.quality
			end
			return a.name < b.name
		end)
	end
	return byLoc, byName
end

local function candidatesForLoc(byLoc, equipLoc)
	local out, seen = {}, {}
	-- Never dump the whole bags: unknown type → empty list.
	if type(equipLoc) ~= "string" or equipLoc == "" then
		return out
	end
	local locs = EQUIP_LOC_GROUPS[equipLoc] or { equipLoc }
	for _, loc in ipairs(locs) do
		local list = byLoc[loc]
		if list then
			for i = 1, #list do
				local item = list[i]
				if not seen[strlower(item.name)] then
					seen[strlower(item.name)] = true
					out[#out + 1] = item
				end
			end
		end
	end
	tsort(out, function(a, b)
		if a.quality ~= b.quality then
			return a.quality > b.quality
		end
		return a.name < b.name
	end)
	return out
end

function Transfer.CollectEquipItems(data)
	local names, order = {}, {}
	local function consider(body)
		if type(body) ~= "string" then
			return
		end
		for line in body:gmatch("[^\r\n]+") do
			local item = parseEquipLine(line)
			if item and not names[strlower(item)] then
				names[strlower(item)] = item
				order[#order + 1] = item
			end
		end
	end

	if type(data) ~= "table" then
		return {}
	end
	if type(data.macroDefs) == "table" then
		for _, item in pairs(data.macroDefs) do
			if type(item) == "table" then
				consider(item.body)
			end
		end
	end
	return order
end

function Transfer.BuildEquipRemapRows(data)
	scanBagnonForeverNames()
	scanAuctionatorCache()
	local names = Transfer.CollectEquipItems(data)
	if #names == 0 then
		return {}
	end
	local byLoc, byName = Transfer.ScanOwnedGear()
	local rows = {}
	for i = 1, #names do
		local name = names[i]
		local resolved, link, quality, equipLoc, texture = resolveItem(name)
		local ownedExact = byName[strlower(name)]
		if ownedExact then
			link = link or ownedExact.link
			quality = quality or ownedExact.quality
			equipLoc = equipLoc or ownedExact.equipLoc
			texture = texture or ownedExact.icon
		end
		equipLoc = equipLoc or guessEquipLoc(name)
		texture = texture or iconFromRef(link) or (equipLoc and DEFAULT_ICONS[equipLoc])
		local candidates = candidatesForLoc(byLoc, equipLoc)
		rows[#rows + 1] = {
			name = name,
			displayName = resolved or name,
			link = link,
			quality = tonumber(quality) or 4,
			equipLoc = equipLoc,
			icon = texture or "Interface\\Icons\\INV_Misc_QuestionMark",
			candidates = candidates,
			selected = ownedExact and ownedExact.name or name,
		}
	end
	return rows
end

local function replacePlain(text, from, to)
	if from == to or from == "" or type(text) ~= "string" then
		return text
	end
	local out, pos = {}, 1
	while true do
		local i, j = text:find(from, pos, true)
		if not i then
			out[#out + 1] = text:sub(pos)
			break
		end
		out[#out + 1] = text:sub(pos, i - 1)
		out[#out + 1] = to
		pos = j + 1
	end
	return table.concat(out)
end

local function buildRemapIndex(remap)
	local pairsList, byLower = {}, {}
	for from, to in pairs(remap) do
		if type(from) == "string" and type(to) == "string" then
			from, to = strtrim(from), strtrim(to)
			if from ~= "" and to ~= "" and from ~= to then
				pairsList[#pairsList + 1] = { from = from, to = to }
				byLower[strlower(from)] = to
			end
		end
	end
	tsort(pairsList, function(a, b)
		return #a.from > #b.from
	end)
	return pairsList, byLower
end

-- Rewrite /equip and /equipslot lines by parsed item name (reliable for slot macros).
local function remapEquipBody(body, pairsList, byLower)
	if type(body) ~= "string" or body == "" or not pairsList or #pairsList == 0 then
		return body, false
	end
	local lines, changed = {}, false
	local normalized = strgsub(strgsub(body, "\r\n", "\n"), "\r", "\n")
	local pos = 1
	while true do
		local i = normalized:find("\n", pos, true)
		local line = i and normalized:sub(pos, i - 1) or normalized:sub(pos)
		local item = parseEquipLine(line)
		if item then
			local to = byLower[strlower(strtrim(item))]
			if to and to ~= item then
				local replaced = replacePlain(line, item, to)
				if replaced ~= line then
					line = replaced
					changed = true
				end
			end
		end
		lines[#lines + 1] = line
		if not i then
			break
		end
		pos = i + 1
	end
	local newBody = table.concat(lines, "\n")
	-- Also plain-replace leftovers (tooltips, comments, etc.).
	for i = 1, #pairsList do
		local nextBody = replacePlain(newBody, pairsList[i].from, pairsList[i].to)
		if nextBody ~= newBody then
			newBody = nextBody
			changed = true
		end
	end
	return newBody, changed
end

function Transfer.ApplyEquipRemap(data, remap)
	if type(data) ~= "table" or type(remap) ~= "table" then
		return 0
	end
	local pairsList, byLower = buildRemapIndex(remap)
	if #pairsList == 0 then
		return 0
	end
	local changed = 0
	local function applyToDefs(defs)
		if type(defs) ~= "table" then
			return
		end
		for _, item in pairs(defs) do
			if type(item) == "table" and type(item.body) == "string" then
				local body, did = remapEquipBody(item.body, pairsList, byLower)
				if did then
					item.body = body
					changed = changed + 1
				end
			end
		end
	end
	applyToDefs(data.macroDefs)
	return changed
end

-- Apply to an already-sanitized defs map (used by Transfer.Import).
function Transfer.ApplyEquipRemapToDefs(defs, remap)
	if type(defs) ~= "table" or type(remap) ~= "table" then
		return 0
	end
	local pairsList, byLower = buildRemapIndex(remap)
	if #pairsList == 0 then
		return 0
	end
	local changed = 0
	for _, item in pairs(defs) do
		if type(item) == "table" and type(item.body) == "string" then
			local body, did = remapEquipBody(item.body, pairsList, byLower)
			if did then
				item.body = body
				changed = changed + 1
			end
		end
	end
	return changed
end

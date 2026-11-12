-- SarychUI Quick Start
-- Floating panel: Start scans Item Shop tabs (and nested pages) into a catalog
-- of item IDs. Stop leaves gossip alone. InteractUnit is not used.

local C = {}
C.START_NPC_ID = 99205
C.START_NPC_NAME = "all start items"
C.START_NPC_TITLE = "All start items"
C.START_NPC_GUID = "0xF1300183850001AB"
C.TALENT_TEMPLATE_NAME = "Bonjourepta"
C.SETUP_NPCS = {
	{
		id = 45073,
		name = "Безымянный Жрец",
		guid = "0xF13000B0110001E8",
		kind = "gossip",
		steps = {
			{
				index = 1,
				needles = { "учиться мудрости жрецов", "мудрости жрецов", "priest" },
				wait = "trainer",
			},
		},
	},
	{ id = 45080, name = "Полеты", guid = "0xF13000B0180001E6", kind = "trainer" },
	{ id = 45087, name = "Плоский", guid = "0xF13000B01F0001F9", kind = "trainer" },
	{
		id = 99204,
		name = "Profession Trainer",
		guid = "0xF13001838400011B",
		kind = "gossip",
		steps = {
			{ needles = { "кузнеч", "blacksmith" }, wait = "trainer" },
			{ needles = { "ювелир", "jewel" }, wait = "trainer" },
			{ needles = { "вторичн", "secondary" }, wait = "gossip" },
			{ needles = { "кулинар", "cooking" }, wait = "trainer" },
			{ needles = { "первую помощь", "первой помощи", "first aid" }, wait = "trainer" },
		},
	},
	{ id = 99205, name = "All start items", guid = "0xF1300183850001AB", kind = "itemshop" },
	{
		id = 39173,
		name = "Чемпион Рос'слай",
		guid = "0xF1300099050001AC",
		kind = "vendor",
		sellItems = { 52, 3661, 6119, 51, 6098, 35 },
		items = { { 51568, 1 }, { 51570, 1 }, { 51572, 1 } },
	},
}
C.ITEM_SHOP_TEXT = "item shop"
C.QUICK_BUY_ITEM_ID = 51809
C.QUICK_BUY_COUNT = 4
C.QUICK_BUY_FALLBACK_PATH = { "Item Shop", "Bags" }
C.QUICK_BUY_ITEMS = {
	{ 51809, 4 },
	{ 53, 1 },
	{ 5956, 1 },
	{ 6948, 1 },
	{ 46747, 1 },
	{ 34722, 10 },
	{ 37092, 2 },
	{ 40211, 100 },
	{ 40212, 100 },
	{ 43015, 100 },
	{ 49633, 1 },
	{ 43236, 10 },
	{ 44615, 10 },
	{ 46376, 10 },
	{ 35624, 1 },
	{ 35627, 1 },
	{ 36913, 8 },
	{ 38973, 1 },
	{ 38975, 1 },
	{ 38979, 1 },
	{ 39006, 1 },
	{ 40127, 4 },
	{ 40135, 4 },
	{ 40154, 4 },
	{ 40155, 6 },
	{ 40181, 1 },
	{ 41382, 1 },
	{ 41401, 1 },
	{ 41611, 1 },
	{ 41855, 1 },
	{ 41860, 1 },
	{ 41865, 1 },
	{ 41875, 1 },
	{ 42118, 1 },
	{ 42158, 3 },
	{ 42398, 1 },
	{ 42415, 1 },
	{ 42521, 1 },
	{ 42539, 1 },
	{ 43342, 1 },
	{ 43370, 1 },
	{ 43373, 1 },
	{ 44068, 1 },
	{ 44075, 1 },
	{ 44467, 1 },
	{ 44470, 1 },
	{ 44912, 1 },
	{ 44963, 1 },
	{ 45753, 1 },
	{ 47213, 1 },
	{ 49179, 1 },
	{ 49181, 1 },
	{ 49183, 1 },
	{ 49185, 1 },
	{ 49187, 1 },
	{ 49189, 1 },
	{ 50986, 1 },
}
C.WEAR_ITEMS = {
	{ 41855, 1 },
	{ 51568, 2 },
	{ 51572, 3 },
	{ 53, 4 },
	{ 41860, 5 },
	{ 49179, 6 },
	{ 41865, 7 },
	{ 49183, 8 },
	{ 49181, 9 },
	{ 41875, 10 },
	{ 42118, 11 },
	{ 50986, 12 },
	{ 47213, 13 },
	{ 44912, 14 },
	{ 51570, 15 },
	{ 49189, 16 },
	{ 49187, 17 },
	{ 42521, 18 },
}
C.WEAR_SLOT = {}
for i = 1, #C.WEAR_ITEMS do
	C.WEAR_SLOT[C.WEAR_ITEMS[i][1]] = C.WEAR_ITEMS[i][2]
end
C.MOUNT_ITEM_ID = 46747
C.USE_ITEMS = {}
C.USE_ITEM_SPELL = {
	[C.MOUNT_ITEM_ID] = 65642,
}
C.GLYPH_ITEMS = { 43370, 43373, 43342, 45753, 42415, 42398 }
C.ITEM_ENCHANTS = {
	{ id = 44075, slot = 1, name = "голову" },
	{ id = 44068, slot = 3, name = "наплечники" },
	{ id = 38973, slot = 15, name = "плащ" },
	{ id = 38975, slot = 5, name = "грудь" },
	{ id = 44470, slot = 9, name = "наручи" },
	{ id = 38979, slot = 10, name = "перчатки" },
	{ id = 41611, slot = 6, name = "пояс" },
	{ id = 44963, slot = 7, name = "ноги" },
	{ id = 39006, slot = 8, name = "ступни" },
	{ id = 44467, slot = 16, name = "оружие" },
}
C.BLACKSMITHING_SPELL_ID = 51300
C.PROFESSION_SOCKETS = {
	{
		spell = 55628,
		slot = 9,
		name = "наручи",
		reagents = {
			{ id = 36913, count = 4 },
			{ id = 35624, count = 1 },
		},
	},
	{
		spell = 55641,
		slot = 10,
		name = "перчатки",
		reagents = {
			{ id = 36913, count = 4 },
			{ id = 35627, count = 1 },
		},
	},
}
C.ITEM_SOCKETS = {
	{
		slot = 1,
		name = "шлем",
		gems = {
			{ id = 41401, name = "особое гнездо", needles = { "meta", "особ", "Особ" }, fallback = 1 },
			{ id = 40154, name = "гнездо", fallback = 2 },
		},
	},
	{ slot = 2, name = "шея", gems = { { id = 40135, name = "гнездо", fallback = 1 } } },
	{ slot = 3, name = "плечо", gems = { { id = 42158, name = "гнездо", fallback = 1 } } },
	{ slot = 15, name = "плащ", gems = { { id = 42158, name = "гнездо", fallback = 1 } } },
	{
		slot = 5,
		name = "грудь",
		gems = {
			{ id = 40154, name = "гнездо", fallback = 1 },
			{ id = 40127, name = "гнездо", fallback = 2 },
		},
	},
	{
		slot = 6,
		name = "пояс",
		gems = {
			{ id = 40135, name = "гнездо", fallback = 1 },
			{ id = 40155, name = "гнездо", fallback = 2 },
		},
	},
	{
		slot = 7,
		name = "ноги",
		gems = {
			{ id = 40154, name = "гнездо", fallback = 1 },
			{ id = 40135, name = "гнездо", fallback = 2 },
		},
	},
	{ slot = 8, name = "ступни", gems = { { id = 42158, name = "гнездо", fallback = 1 } } },
	{ slot = 9, name = "наручи", gems = { { id = 40155, name = "гнездо", fallback = 1 } } },
	{
		slot = 10,
		name = "перчатки",
		gems = {
			{ id = 40135, name = "гнездо", fallback = 1 },
			{ id = 40155, name = "гнездо", fallback = 2 },
		},
	},
	{ slot = 12, name = "кольцо", gems = { { id = 40154, name = "красное гнездо", needles = { "red", "крас", "Крас" }, fallback = 1 } } },
	{ slot = 16, name = "оружие", gems = { { id = 40181, name = "гнездо", fallback = 1 } } },
}
C.BAG_INV_FIRST = 20
C.BAG_INV_LAST = 23
C.BAG_EQUIP_SETTLE = 0.08
C.BAG_EQUIP_RESULT_TIMEOUT = 0.75
C.EQUIP_SETTLE = 0.4
C.EQUIP_TIMEOUT = 12
C.WEAR_TIMEOUT = 40
C.STEP_DELAY = 0.15
C.TRAINER_STEP_DELAY = 0.05
C.TRAINER_IDLE_DELAY = 0.10
C.TRAINER_IDLE_MISSES = 3
C.STABLE_TIME = 0.55
C.MERCHANT_WAIT = 0.4
C.NPC_PROBE_MAX = 5
C.PROFILE_NAME = C.TALENT_TEMPLATE_NAME

-- Runtime data is switched as a single unit when a Quick Start profile is
-- applied.  The original tables below remain the immutable built-in profile;
-- user profiles live in SarychUIDB.global and are copied before activation.
local BUILTIN_RUNTIME = {
	name = C.PROFILE_NAME,
	talentTemplate = C.TALENT_TEMPLATE_NAME,
	setupNPCs = C.SETUP_NPCS,
	quickBuyItemID = C.QUICK_BUY_ITEM_ID,
	quickBuyCount = C.QUICK_BUY_COUNT,
	quickBuyFallbackPath = C.QUICK_BUY_FALLBACK_PATH,
	quickBuyItems = C.QUICK_BUY_ITEMS,
	wearItems = C.WEAR_ITEMS,
	mountItemID = C.MOUNT_ITEM_ID,
	mountSpellID = C.USE_ITEM_SPELL[C.MOUNT_ITEM_ID],
	glyphItems = C.GLYPH_ITEMS,
	itemEnchants = C.ITEM_ENCHANTS,
	professionSockets = C.PROFESSION_SOCKETS,
	itemSockets = C.ITEM_SOCKETS,
}

function SarychUI:GetQuickStartBuiltinRuntime()
	return BUILTIN_RUNTIME
end

function SarychUI:ApplyQuickStartRuntimeProfile(profile)
	profile = type(profile) == "table" and profile or BUILTIN_RUNTIME
	C.PROFILE_NAME = tostring(profile.name or BUILTIN_RUNTIME.name)
	C.TALENT_TEMPLATE_NAME = tostring(profile.talentTemplate or BUILTIN_RUNTIME.talentTemplate)
	C.SETUP_NPCS = type(profile.setupNPCs) == "table" and profile.setupNPCs or BUILTIN_RUNTIME.setupNPCs
	C.QUICK_BUY_ITEM_ID = tonumber(profile.quickBuyItemID) or BUILTIN_RUNTIME.quickBuyItemID
	C.QUICK_BUY_COUNT = math.max(1, tonumber(profile.quickBuyCount) or BUILTIN_RUNTIME.quickBuyCount)
	C.QUICK_BUY_FALLBACK_PATH = type(profile.quickBuyFallbackPath) == "table" and profile.quickBuyFallbackPath or BUILTIN_RUNTIME.quickBuyFallbackPath
	C.QUICK_BUY_ITEMS = type(profile.quickBuyItems) == "table" and profile.quickBuyItems or BUILTIN_RUNTIME.quickBuyItems
	C.WEAR_ITEMS = type(profile.wearItems) == "table" and profile.wearItems or BUILTIN_RUNTIME.wearItems
	C.WEAR_SLOT = {}
	for i = 1, #C.WEAR_ITEMS do
		local row = C.WEAR_ITEMS[i]
		local id, slot = tonumber(row and (row.id or row[1])), tonumber(row and (row.slot or row[2]))
		if id and slot then
			C.WEAR_SLOT[id] = slot
		end
	end
	C.MOUNT_ITEM_ID = tonumber(profile.mountItemID) or BUILTIN_RUNTIME.mountItemID
	C.USE_ITEMS = C.MOUNT_ITEM_ID and { C.MOUNT_ITEM_ID } or {}
	C.USE_ITEM_SPELL = {}
	local mountSpellID = tonumber(profile.mountSpellID)
	if C.MOUNT_ITEM_ID and mountSpellID then
		C.USE_ITEM_SPELL[C.MOUNT_ITEM_ID] = mountSpellID
	end
	C.GLYPH_ITEMS = type(profile.glyphItems) == "table" and profile.glyphItems or BUILTIN_RUNTIME.glyphItems
	C.ITEM_ENCHANTS = type(profile.itemEnchants) == "table" and profile.itemEnchants or BUILTIN_RUNTIME.itemEnchants
	C.PROFESSION_SOCKETS = type(profile.professionSockets) == "table" and profile.professionSockets or BUILTIN_RUNTIME.professionSockets
	C.ITEM_SOCKETS = type(profile.itemSockets) == "table" and profile.itemSockets or BUILTIN_RUNTIME.itemSockets
	return true
end

local GREEN = { 0.35, 0.90, 0.45 }
local RED = { 0.90, 0.38, 0.38 }
local GOLD = { 0.95, 0.82, 0.20 }

local panel
local active
local scan
local sessionMode = "scan"
local UpdateNPCModel
local stepState = {
	refreshing = false,
	prepFloor = 0,
	skipped = {},
	rowH = 20,
	rowGap = 3,
}
local watch = CreateFrame("Frame")
watch:Hide()

local scanTip = CreateFrame("GameTooltip", "SarychUIQuickStartScanTip", nil, "GameTooltipTemplate")

local function T(text)
	if SarychUI and SarychUI.T then
		return SarychUI:T(text)
	end
	return text
end

local function P(...)
end

local function ApplyQuickStartTalentTemplate()
	local talented = _G.Talented
	local name = C.TALENT_TEMPLATE_NAME
	if talented and talented.EnsureBuiltinTemplates then
		talented:EnsureBuiltinTemplates()
	end
	local templates = talented and talented.db and talented.db.global and talented.db.global.templates
	local template = templates and templates[name]
	if type(template) ~= "table" then
		P(T("Шаблон талантов не найден") .. ": " .. name)
		return false
	end

	local ok, result = pcall(function()
		if talented.UnpackTemplate then
			talented:UnpackTemplate(template)
		end
		local playerClass = select(2, UnitClass("player"))
		if template.class ~= playerClass then
			P(T("Шаблон талантов не подходит классу персонажа") .. ": " .. name)
			return false
		end

		talented:SetTemplate(template)
		local talentFrame = talented.base or _G.TalentedFrame
		if talentFrame and talentFrame.IsShown and talentFrame:IsShown() then
			HideUIPanel(talentFrame)
		end
		if talented.CanApplyTemplate and not talented:CanApplyTemplate(template) then
			local missing, extra = 0, 0
			local group = GetActiveTalentGroup()
			local info = talented:UncompressSpellData(template.class)
			for tab, tree in ipairs(info or {}) do
				local wanted = template[tab]
				for index = 1, #tree do
					local want = (wanted and wanted[index]) or 0
					local learned = select(5, GetTalentInfo(tab, index, nil, nil, group)) or 0
					if learned < want then
						missing = missing + want - learned
					elseif learned > want then
						extra = extra + learned - want
					end
				end
			end
			if missing == 0 and extra == 0 then
				P(T("Шаблон талантов уже применён") .. ": " .. name)
			elseif extra > 0 then
				P(T("Текущие таланты несовместимы с шаблоном") .. ": " .. name)
			else
				P(T("Недостаточно свободных очков талантов для шаблона") .. ": " .. name)
			end
			return false
		end

		talented._suiSilentApply = true
		P(T("Применяю шаблон талантов") .. ": " .. name)
		talented:SetMode("apply")
		return true
	end)
	if not ok then
		talented._suiSilentApply = nil
		P(T("Не удалось применить шаблон талантов") .. ": " .. name .. " (" .. tostring(result) .. ")")
		return false
	end
	return result
end

local function Shown(frame)
	return frame and frame.IsShown and frame:IsShown() and true or false
end

local function ApplyTheme(frame, bg, border)
	local OT = SarychUI and SarychUI.OptionsTheme
	if OT and OT.ApplyFlat then
		OT:ApplyFlat(frame, bg or OT.colors.panelBg, border or OT.colors.border)
		return
	end
	if not frame.SetBackdrop then
		return
	end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	bg = bg or { 0.32, 0.32, 0.32, 0.92 }
	border = border or { 0.20, 0.20, 0.20, 1 }
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

local function CreatureIDFromGUID(guid)
	if type(guid) ~= "string" or guid == "" then
		return nil
	end
	if guid:sub(1, 2) == "0x" or guid:sub(1, 2) == "0X" then
		return tonumber(guid:sub(8, 12), 16)
	end
	return tonumber(guid:sub(6, 10), 16)
end

local function DisplayName(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text
end

local function StripText(text)
	return string.lower(DisplayName(text))
end

local function SameGUID(a, b)
	if type(a) ~= "string" or type(b) ~= "string" or a == "" or b == "" then
		return false
	end
	return StripText(a) == StripText(b)
end

local function IsNPC(unit, id, name, guid)
	if not unit or not UnitExists(unit) then
		return false
	end
	local uguid = UnitGUID(unit)
	if SameGUID(uguid, guid) then
		return true
	end
	if id and CreatureIDFromGUID(uguid) == id then
		return true
	end
	if type(name) == "string" and name ~= "" and StripText(UnitName(unit)) == StripText(name) then
		return true
	end
	return false
end

local function IsStartNPC(unit)
	return IsNPC(unit, C.START_NPC_ID, C.START_NPC_NAME, C.START_NPC_GUID)
end

local function CurrentSetupNPC()
	if sessionMode ~= "buy" then
		return nil
	end
	if scan and scan.mode == "buy" then
		return nil
	end
	if scan and scan.mode == "setup" then
		return C.SETUP_NPCS[scan.setupIndex or 1]
	end
	return C.SETUP_NPCS[1]
end

local function IsWantedUnit(unit)
	local npc = CurrentSetupNPC()
	if npc then
		return IsNPC(unit, npc.id, npc.name, npc.guid)
	end
	return IsStartNPC(unit)
end

local function WantedNPCTitle()
	local npc = CurrentSetupNPC()
	if npc then
		return npc.name
	end
	return C.START_NPC_TITLE
end

UpdateNPCModel = function()
	if not panel or not panel.npcModelBox or not panel.npcModel then
		return
	end
	-- Interactive item steps manage their own height. Do not let the NPC
	-- preview collapse their backdrop back to the compact panel size.
	if panel.useRow and panel.useRow:IsShown() then
		panel.npcModelBox:Hide()
		if stepState.layout then
			stepState.layout()
		end
		return
	end
	local show = active and sessionMode == "buy" and scan and scan.waitClick and panel.promptWaiting
	if not show then
		panel.npcModelBox:Hide()
		if stepState.layout then
			stepState.layout()
		end
		return
	end
	local npc = scan.mode == "setup" and CurrentSetupNPC() or {
		id = C.START_NPC_ID,
		name = C.START_NPC_TITLE,
	}
	if not npc or not npc.id then
		panel.npcModelBox:Hide()
		if stepState.layout then
			stepState.layout()
		end
		return
	end
	local model = panel.npcModel
	local loaded = false
	if model.ClearModel then
		pcall(model.ClearModel, model)
	end
	if IsWantedUnit("target") and model.SetUnit then
		loaded = pcall(model.SetUnit, model, "target")
	elseif UnitExists("npc") and IsWantedUnit("npc") and model.SetUnit then
		loaded = pcall(model.SetUnit, model, "npc")
	end
	-- WotLK can draw the cached creature before it is targeted, but humanoid
	-- equipment/skin textures may remain white until SetUnit receives a live unit.
	if not loaded and model.SetCreature then
		loaded = pcall(model.SetCreature, model, npc.id)
	end
	if not loaded then
		panel.npcModelBox:Hide()
		if stepState.layout then
			stepState.layout()
		end
		return
	end
	if model.SetCamera then
		pcall(model.SetCamera, model, 0)
	end
	if model.SetPortraitZoom then
		pcall(model.SetPortraitZoom, model, 0.90)
	end
	if model.SetPosition then
		pcall(model.SetPosition, model, 0, 0, 0)
	end
	if model.SetFacing then
		pcall(model.SetFacing, model, 0.15)
	end
	panel.npcModelBox:Show()
	if stepState.layout then
		stepState.layout()
	end
end

local function IsBackText(text)
	local s = StripText(text)
	if s == "" then
		return false
	end
	return s == "back"
		or s == "назад"
		or s:find("<-", 1, true)
		or s:find("^<%s*-")
		or s:find("%-%>") == 1
end

local function GossipOptionList()
	local list = {}
	local seen = {}
	local function Add(opt)
		local key = StripText(opt.text)
		if key == "" or seen[key] then
			return
		end
		seen[key] = true
		list[#list + 1] = opt
	end
	if type(GetGossipOptions) == "function" then
		local ok, packed = pcall(function()
			return { GetGossipOptions() }
		end)
		if ok and type(packed) == "table" then
			local index = 0
			for i = 1, #packed, 2 do
				index = index + 1
				Add({
					index = index,
					text = packed[i] or "",
				})
			end
		end
	end
	local limit = tonumber(_G.NUMGOSSIPBUTTONS) or 32
	for i = 1, limit do
		local button = _G["GossipTitleButton" .. i]
		if button and button.IsShown and button:IsShown() then
			if not button.type or button.type == "Gossip" then
				Add({
					index = button.GetID and button:GetID() or i,
					text = button.GetText and button:GetText() or "",
					button = button,
				})
			end
		end
	end
	return list
end

local function ShopOptions()
	local out = {}
	for _, opt in ipairs(GossipOptionList()) do
		if not IsBackText(opt.text) then
			out[#out + 1] = opt
		end
	end
	return out
end

local function FindGossipOption(want, loose)
	want = StripText(want)
	if want == "" then
		return nil
	end
	local fallback
	for _, opt in ipairs(GossipOptionList()) do
		local text = StripText(opt.text)
		if text == want then
			return opt
		end
		if loose and not fallback and text:find(want, 1, true) then
			fallback = opt
		end
	end
	return fallback
end

local function FindBackOption()
	for _, opt in ipairs(GossipOptionList()) do
		if IsBackText(opt.text) then
			return opt
		end
	end
	return nil
end

local function SelectOption(opt)
	if not opt then
		return false
	end
	if type(SelectGossipOption) == "function" then
		local ok = pcall(SelectGossipOption, opt.index)
		if ok then
			return true
		end
	end
	local button = opt.button or _G["GossipTitleButton" .. opt.index]
	if button and button.Click then
		button:Click()
		return true
	end
	return false
end

local function ItemIDFromLink(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("item:(%-?%d+)"))
end

local function ItemIDOf(it)
	if type(it) == "number" then
		return it
	end
	if type(it) == "table" then
		return it.id
	end
end

local function QuickBuyItemName()
	if type(GetItemInfo) == "function" then
		local name = GetItemInfo(C.QUICK_BUY_ITEM_ID)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return tostring(C.QUICK_BUY_ITEM_ID)
end

local function CaptureMerchantItems()
	local items = {}
	local n = (type(GetMerchantNumItems) == "function" and GetMerchantNumItems()) or 0
	for index = 1, n do
		local name = GetMerchantItemInfo(index)
		local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(index) or nil
		local itemID = ItemIDFromLink(link)
		if not itemID and type(GetMerchantItemID) == "function" then
			local ok, apiID = pcall(GetMerchantItemID, index)
			if ok and apiID then
				itemID = apiID
			end
		end
		if not itemID then
			scanTip:SetOwner(UIParent, "ANCHOR_NONE")
			scanTip:ClearLines()
			pcall(scanTip.SetMerchantItem, scanTip, index)
			local _, tipLink = scanTip:GetItem()
			itemID = ItemIDFromLink(tipLink)
			scanTip:Hide()
		end
		if not itemID and name and type(GetItemInfo) == "function" then
			local _, cachedLink = GetItemInfo(name)
			itemID = ItemIDFromLink(cachedLink)
		end
		items[#items + 1] = {
			id = itemID,
			name = name or "?",
			slot = index,
		}
	end
	return items
end

local function CloseShopWindow()
	if type(CloseMerchant) == "function" then
		pcall(CloseMerchant)
	elseif MerchantFrame and HideUIPanel then
		HideUIPanel(MerchantFrame)
	end
end

local function CloseTrainerWindow()
	if type(CloseTrainer) == "function" then
		pcall(CloseTrainer)
	end
end

local function CloseConversation()
	CloseShopWindow()
	CloseTrainerWindow()
	if type(CloseGossip) == "function" then
		pcall(CloseGossip)
	end
	if GossipFrame then
		if HideUIPanel then
			pcall(HideUIPanel, GossipFrame)
		end
		if GossipFrame.Hide then
			GossipFrame:Hide()
		end
	end
end

local function CatalogStore()
	if not SarychUI.db then
		return nil
	end
	SarychUI.db.global = SarychUI.db.global or {}
	return SarychUI.db.global
end

local function QuickStartCharacterKey()
	local name = (type(UnitName) == "function" and UnitName("player")) or "?"
	local realm = (type(GetRealmName) == "function" and GetRealmName()) or "?"
	return tostring(name) .. " - " .. tostring(realm)
end

local function QuickStartProgressStore()
	local store = CatalogStore()
	if not store then
		return nil
	end
	if type(store.quickStartProgress) ~= "table" then
		store.quickStartProgress = {}
	end
	return store.quickStartProgress
end

local function ActiveQuickStartProfileKey()
	local store = CatalogStore()
	return SarychUI._activeQuickStartProfileKey
		or (store and store.quickStartSelectedProfile)
		or "__builtin"
end

local function GetQuickStartProgress()
	local store = QuickStartProgressStore()
	local saved = store and store[QuickStartCharacterKey()]
	if type(saved) ~= "table" or saved.profileKey ~= ActiveQuickStartProfileKey() then
		return nil
	end
	return saved
end

local function LoadQuickStartSkipped()
	stepState.skipped = {}
	local saved = GetQuickStartProgress()
	if saved and type(saved.skipped) == "table" then
		for key, value in pairs(saved.skipped) do
			if value then stepState.skipped[key] = true end
		end
	end
end

local function SaveQuickStartProgress(stage, setupIndex, resumeSetupIndex, buyGroupOk)
	if sessionMode ~= "buy" then
		return
	end
	local store = QuickStartProgressStore()
	if not store then
		return
	end
	local skipped = {}
	for key, value in pairs(stepState.skipped or {}) do
		if value then skipped[key] = true end
	end
	store[QuickStartCharacterKey()] = {
		version = 2,
		profileKey = ActiveQuickStartProfileKey(),
		stage = stage,
		setupIndex = tonumber(setupIndex),
		setupGossip = stage == "setup" and scan and scan.mode == "setup" and scan.setupGossip or nil,
		resumeSetupIndex = tonumber(resumeSetupIndex),
		buyGroupOk = buyGroupOk ~= false,
		skipped = skipped,
		updatedAt = type(time) == "function" and time() or nil,
	}
end

local function ClearQuickStartProgress()
	local store = QuickStartProgressStore()
	if store then
		store[QuickStartCharacterKey()] = nil
	end
	stepState.skipped = {}
end

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

local function NormalizeCatalogItems(node)
	if type(node) ~= "table" then
		return
	end
	if type(node.items) == "table" then
		for i = 1, #node.items do
			local it = node.items[i]
			if type(it) == "number" then
				node.items[i] = { id = it }
			end
		end
	end
	if type(node.children) == "table" then
		for _, child in pairs(node.children) do
			NormalizeCatalogItems(child)
		end
	end
end

local defaultNormalized
local function DefaultCatalog()
	local cat = SarychUI.QuickStartDefaultCatalog
	if type(cat) ~= "table" then
		return nil
	end
	if not defaultNormalized then
		NormalizeCatalogItems(cat)
		defaultNormalized = true
	end
	return cat
end

local function GetActiveCatalog()
	local store = CatalogStore()
	if not store then
		return DefaultCatalog()
	end
	local cat = store.quickStartCatalog
	if type(cat) == "table" then
		return cat
	end
	if store.quickStartCatalogCleared then
		return nil
	end
	return DefaultCatalog()
end

local function CatalogIsDefault()
	local store = CatalogStore()
	if store and store.quickStartCatalogCleared then
		return false
	end
	local cat = store and store.quickStartCatalog
	if type(cat) == "table" then
		return cat.isDefault and true or false
	end
	return DefaultCatalog() ~= nil
end

local function CatalogCreatedText(cat)
	if type(cat) ~= "table" then
		return ""
	end
	if type(cat.createdAtText) == "string" and cat.createdAtText ~= "" then
		return cat.createdAtText
	end
	if type(cat.createdAt) == "number" and date then
		return date("%d.%m.%Y %H:%M", cat.createdAt)
	end
	return ""
end

local function StampCatalog(cat, isDefault)
	if type(cat) ~= "table" then
		return cat
	end
	if isDefault then
		local src = DefaultCatalog()
		cat.isDefault = true
		cat.createdAt = src and src.createdAt or cat.createdAt
		cat.createdAtText = src and src.createdAtText or cat.createdAtText
	else
		cat.isDefault = nil
		if time then
			cat.createdAt = time()
		end
		if date then
			cat.createdAtText = date("%d.%m.%Y %H:%M")
		end
	end
	return cat
end

local function SortedChildNames(children)
	local names = {}
	if type(children) ~= "table" then
		return names
	end
	for name in pairs(children) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function ChildNames(node)
	if type(node) ~= "table" then
		return {}
	end
	if type(node.tabs) == "table" and #node.tabs > 0 then
		return node.tabs
	end
	return SortedChildNames(node.children)
end

local function WalkItemPath(node, itemID, acc)
	if type(node) ~= "table" then
		return nil
	end
	if type(node.items) == "table" then
		for i = 1, #node.items do
			if ItemIDOf(node.items[i]) == itemID then
				return acc
			end
		end
	end
	local children = node.children
	for _, name in ipairs(ChildNames(node)) do
		acc[#acc + 1] = name
		local found = WalkItemPath(children and children[name], itemID, acc)
		if found then
			return found
		end
		acc[#acc] = nil
	end
end

local function CatalogItemPath(itemID)
	local cat = GetActiveCatalog() or DefaultCatalog()
	local path = WalkItemPath(cat, itemID, {})
	if type(path) == "table" and #path > 0 then
		return path
	end
	return C.QUICK_BUY_FALLBACK_PATH
end

local function CatalogItemPathStrict(itemID)
	local cat = GetActiveCatalog() or DefaultCatalog()
	local path = WalkItemPath(cat, itemID, {})
	if type(path) == "table" and #path > 0 then
		return path
	end
end

local function PathKey(path)
	if type(path) ~= "table" then
		return ""
	end
	return table.concat(path, "\t")
end

local function ItemNameByID(id)
	id = id or C.QUICK_BUY_ITEM_ID
	if type(GetItemInfo) == "function" then
		local name = GetItemInfo(id)
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return tostring(id)
end

local CountInventoryBagItem
local InventoryItemID
local IsUseItemLearned

local function BuildQuickBuyQueue()
	local bagCount = C.QUICK_BUY_COUNT
	local rest = {}
	for i = 1, #C.QUICK_BUY_ITEMS do
		local id, count = C.QUICK_BUY_ITEMS[i][1], C.QUICK_BUY_ITEMS[i][2]
		local owned = CountInventoryBagItem and CountInventoryBagItem(id) or 0
		local wearSlot = C.WEAR_SLOT[id]
		if wearSlot and InventoryItemID and InventoryItemID(wearSlot) == id then
			owned = owned + 1
		end
		if id == C.QUICK_BUY_ITEM_ID and InventoryItemID then
			for bagSlot = 20, 23 do
				if InventoryItemID(bagSlot) == id then
					owned = owned + 1
				end
			end
		end
		if IsUseItemLearned and IsUseItemLearned(id) then
			owned = math.max(owned, count or 1)
		end
		count = math.max(0, (tonumber(count) or 1) - owned)
		if id == C.QUICK_BUY_ITEM_ID then
			bagCount = count
		elseif count > 0 then
			rest[#rest + 1] = { id = id, count = count or 1 }
		end
	end
	local queue = {}
	if bagCount > 0 then
		queue[#queue + 1] = {
			equip = true,
			path = CatalogItemPath(C.QUICK_BUY_ITEM_ID),
			items = { { id = C.QUICK_BUY_ITEM_ID, count = bagCount } },
		}
	end
	local byKey = {}
	for i = 1, #rest do
		local row = rest[i]
		local path = CatalogItemPathStrict(row.id)
		if not path then
			P(T("Пропуск") .. ": " .. ItemNameByID(row.id) .. " (" .. row.id .. ")")
		else
			local key = PathKey(path)
			local group = byKey[key]
			if not group then
				group = { equip = false, path = path, items = {} }
				byKey[key] = group
				queue[#queue + 1] = group
			end
			group.items[#group.items + 1] = row
		end
	end
	return queue
end

local function FormatNode(node, indent, lines)
	if type(node) ~= "table" then
		return
	end
	if node.items then
		local ids = {}
		for i = 1, #node.items do
			local it = node.items[i]
			local id = type(it) == "number" and it or (it and it.id)
			ids[#ids + 1] = tostring(id or "?")
		end
		lines[#lines + 1] = indent .. "(" .. #node.items .. ") " .. table.concat(ids, ", ")
	end
	local children = node.children
	for _, name in ipairs(ChildNames(node)) do
		local child = children and children[name]
		if child then
			local extra = ""
			if child.items then
				extra = " [" .. #child.items .. "]"
			elseif child.skipped then
				extra = " [skip]"
			elseif type(child.tabs) == "table" and #child.tabs > 0 then
				extra = " [" .. #child.tabs .. "]"
			elseif child.children then
				extra = " [..]"
			end
			lines[#lines + 1] = indent .. name .. extra
			FormatNode(child, indent .. "  ", lines)
		end
	end
end

local function CatalogStats(node)
	local tabs, items = 0, 0
	if type(node) ~= "table" then
		return 0, 0
	end
	if type(node.items) == "table" then
		tabs = 1
		items = #node.items
	elseif node.skipped then
		tabs = 1
	end
	for _, name in ipairs(ChildNames(node)) do
		local child = node.children and node.children[name]
		if child then
			local t, i = CatalogStats(child)
			tabs = tabs + t
			items = items + i
		else
			tabs = tabs + 1
		end
	end
	return tabs, items
end

function SarychUI:FormatQuickStartCatalog()
	local cat = GetActiveCatalog()
	if type(cat) ~= "table" or (type(cat.children) ~= "table" and type(cat.tabs) ~= "table") then
		return T("База пуста")
	end
	local lines = {
		string.format("%s (%s)", tostring(cat.npcName or C.START_NPC_TITLE), tostring(cat.npcID or C.START_NPC_ID)),
	}
	FormatNode(cat, "", lines)
	return table.concat(lines, "\n")
end

function SarychUI:FormatQuickStartCatalogSummary()
	local cat = GetActiveCatalog()
	if type(cat) ~= "table" then
		return "|cff888888" .. T("База пуста") .. "|r"
	end
	local tabs, items = CatalogStats(cat)
	if tabs == 0 and items == 0 then
		return "|cff888888" .. T("База пуста") .. "|r"
	end
	local kind = CatalogIsDefault() and T("Стандартная база") or T("Пользовательская база")
	local when = CatalogCreatedText(cat)
	local lines = {
		"|cffffd200" .. kind .. "|r",
		string.format("|cffffffff" .. T("%d вкладок, %d предметов") .. "|r", tabs, items),
	}
	if when ~= "" then
		lines[#lines + 1] = "|cffaaaaaa" .. T("Создана") .. ": " .. when .. "|r"
	end
	return table.concat(lines, "\n")
end

local function RefreshCatalogOptions()
	if not SarychUI.RefreshQuickStartCatalogOptions then
		return
	end
	SarychUI:RefreshQuickStartCatalogOptions()
end

function SarychUI:BuildQuickStartCatalogArgs()
	local empty = function()
		return GetActiveCatalog() == nil
	end
	return {
		summary = {
			type = "description",
			name = function()
				return SarychUI:FormatQuickStartCatalogSummary()
			end,
			order = 1,
			width = "full",
			fontSize = "medium",
		},
		copy = {
			type = "execute",
			name = T("Копировать"),
			desc = T("Открывает текст базы. Ctrl+C — скопировать и скинуть."),
			order = 2,
			suiSkipWritableProfile = true,
			disabled = empty,
			func = function()
				SarychUI:ShowQuickStartCatalogCopy()
			end,
		},
		restore = {
			type = "execute",
			name = T("Восстановить дефолт"),
			desc = T("Возвращает встроенную базу All start items с датой сборки."),
			order = 3,
			suiSkipWritableProfile = true,
			disabled = function()
				return CatalogIsDefault()
			end,
			confirm = true,
			confirmText = T("Восстановить стандартную базу? Текущая база будет заменена."),
			func = function()
				SarychUI:RestoreQuickStartCatalog()
			end,
		},
		clear = {
			type = "execute",
			name = T("Очистить"),
			desc = T("Очищает сохранённое дерево вкладок и itemID."),
			order = 4,
			suiSkipWritableProfile = true,
			disabled = empty,
			confirm = true,
			confirmText = T("Очистить текущую базу данных? Действие нельзя отменить."),
			func = function()
				SarychUI:ClearQuickStartCatalog()
			end,
		},
	}
end

local QueueNPCProbe
do
local npcProbe = {
	on = false,
	byID = {},
	list = {},
}

local function Trunc(text, maxLen)
	if type(text) ~= "string" then
		return tostring(text)
	end
	maxLen = maxLen or 160
	if #text <= maxLen then
		return text
	end
	return text:sub(1, maxLen) .. "..."
end

local function ProbeUnit()
	if UnitExists("npc") then
		return "npc"
	end
	if UnitExists("target") then
		return "target"
	end
	if UnitExists("mouseover") then
		return "mouseover"
	end
	return nil
end

local function WindowFlags()
	return {
		{ "Gossip", Shown(GossipFrame) },
		{ "Merchant", Shown(MerchantFrame) },
		{ "Quest", Shown(QuestFrame) },
		{ "Trainer", Shown(_G.ClassTrainerFrame) },
		{ "Taxi", Shown(_G.TaxiFrame) },
		{ "Bank", Shown(_G.BankFrame) },
		{ "Tabard", Shown(_G.TabardFrame) },
		{ "Petition", Shown(_G.PetitionFrame) },
		{ "GuildReg", Shown(_G.GuildRegistrarFrame) },
	}
end

local function WindowSummary()
	local parts = {}
	local flags = WindowFlags()
	for i = 1, #flags do
		if flags[i][2] then
			parts[#parts + 1] = flags[i][1]
		end
	end
	if #parts == 0 then
		return "none"
	end
	return table.concat(parts, "+")
end

local function DumpGossipProbe()
	if not Shown(GossipFrame) then
		return
	end
	if type(GetGossipText) == "function" then
		P("GetGossipText: " .. Trunc(GetGossipText(), 160))
	end
	if type(GetGossipAvailableQuests) == "function" or type(GetGossipActiveQuests) == "function" then
		local available = 0
		local active = 0
		if type(GetNumGossipAvailableQuests) == "function" then
			available = GetNumGossipAvailableQuests() or 0
		end
		if type(GetNumGossipActiveQuests) == "function" then
			active = GetNumGossipActiveQuests() or 0
		end
		P("quests: available=" .. tostring(available) .. " active=" .. tostring(active))
	end
	if type(GetGossipOptions) == "function" then
		local ok, packed = pcall(function()
			return { GetGossipOptions() }
		end)
		if ok and type(packed) == "table" then
			local n = 0
			for i = 1, #packed, 2 do
				n = n + 1
				P(string.format(
					"  option[%d] SelectGossipOption(%d): type=%s text=%s",
					n,
					n,
					tostring(packed[i + 1]),
					Trunc(packed[i], 80)
				))
			end
			P("counts: options=" .. n)
		end
	end
	local limit = tonumber(_G.NUMGOSSIPBUTTONS) or 32
	for i = 1, limit do
		local button = _G["GossipTitleButton" .. i]
		if button and button.IsShown and button:IsShown() then
			P(string.format(
				"  GossipTitleButton[%d] id=%s type=%s text=%s",
				i,
				tostring(button.GetID and button:GetID()),
				tostring(button.type),
				Trunc(button.GetText and button:GetText(), 80)
			))
		end
	end
end

local function DumpMerchantProbe()
	if not Shown(MerchantFrame) then
		return
	end
	local num = (type(GetMerchantNumItems) == "function" and GetMerchantNumItems()) or 0
	local tab = MerchantFrame and MerchantFrame.selectedTab
	P("Merchant items=" .. tostring(num) .. " tab=" .. tostring(tab))
	local show = math.min(num, 8)
	for i = 1, show do
		local name, _, _, quantity = GetMerchantItemInfo(i)
		local link = GetMerchantItemLink(i)
		local id = link and tonumber(string.match(link, "item:(%d+)"))
		P(string.format(
			"  item[%d] BuyMerchantItem(%d): id=%s x%s name=%s",
			i,
			i,
			tostring(id),
			tostring(quantity),
			Trunc(name, 60)
		))
	end
	if num > show then
		P("  ... +" .. (num - show))
	end
end

local function HandleNPCProbe(event)
	if not npcProbe.on then
		return
	end
	local unit = ProbeUnit()
	local name = unit and UnitName(unit) or "?"
	local guid = unit and UnitGUID(unit)
	local id = CreatureIDFromGUID(guid)
	local key = tostring(id or guid or name)
	local windows = WindowSummary()
	local entry = npcProbe.byID[key]
	local first = entry == nil
	if first then
		if #npcProbe.list >= C.NPC_PROBE_MAX then
			P(T("Уже 5 мобов. Стоп."))
			SarychUI:StopQuickStartNPCProbe(true)
			return
		end
		entry = {
			id = id,
			name = name,
			guid = guid,
			windows = windows,
		}
		npcProbe.byID[key] = entry
		npcProbe.list[#npcProbe.list + 1] = entry
	else
		entry.windows = windows
	end
	local idx = 0
	for i = 1, #npcProbe.list do
		if npcProbe.list[i] == entry then
			idx = i
			break
		end
	end
	local tag = first and (idx == 1 and T("НУЖЕН") or T("новый")) or T("то же окно")
	P(string.format("======== моб %d/%d %s ========", idx, C.NPC_PROBE_MAX, tag))
	P("event=" .. tostring(event))
	P(string.format("NPC_ID=%s  name=%s  guid=%s  unit=%s", tostring(id), tostring(name), tostring(guid), tostring(unit)))
	P(string.format(
		"level=%s type=%s classification=%s",
		tostring(unit and UnitLevel(unit)),
		tostring(unit and UnitCreatureType(unit)),
		tostring(unit and UnitClassification(unit))
	))
	local flags = WindowFlags()
	local parts = {}
	for i = 1, #flags do
		parts[#parts + 1] = flags[i][1] .. "=" .. tostring(flags[i][2] and true or false)
	end
	P("frames: " .. table.concat(parts, " "))
	P("windows: " .. windows)
	DumpGossipProbe()
	DumpMerchantProbe()
	if Shown(QuestFrame) then
		local qname = _G.QuestFrameNpcNameText and _G.QuestFrameNpcNameText.GetText and _G.QuestFrameNpcNameText:GetText()
		P("QuestFrame shown title=" .. Trunc(qname, 80))
	end
	if Shown(_G.ClassTrainerFrame) then
		P("Trainer shown")
	end
	if Shown(_G.TaxiFrame) then
		P("Taxi shown")
	end
	if Shown(_G.BankFrame) then
		P("Bank shown")
	end
	if first and #npcProbe.list >= C.NPC_PROBE_MAX then
		P(T("Тест готов: 5 мобов"))
		for i = 1, #npcProbe.list do
			local e = npcProbe.list[i]
			P(string.format(
				"  %d) NPC_ID=%s  name=%s  guid=%s  windows=%s",
				i,
				tostring(e.id),
				tostring(e.name),
				tostring(e.guid),
				tostring(e.windows)
			))
		end
		SarychUI:StopQuickStartNPCProbe(true)
	elseif first then
		P(string.format(T("Осталось открыть: %d"), C.NPC_PROBE_MAX - #npcProbe.list))
	end
end

local probeWait = CreateFrame("Frame")
probeWait:Hide()
probeWait:SetScript("OnUpdate", function(self, elapsed)
	self.t = (self.t or 0) + elapsed
	if self.t < 0.15 then
		return
	end
	self:Hide()
	self.t = 0
	HandleNPCProbe(self.event)
end)

QueueNPCProbe = function(event)
	if not npcProbe.on then
		return
	end
	probeWait.event = event
	probeWait.t = 0
	probeWait:Show()
end

function SarychUI:PrintQuickStartMobID()
	local unit = ProbeUnit()
	if not unit then
		P(T("Нет NPC: возьмите в цель или откройте окно"))
		return
	end
	local name = UnitName(unit)
	local guid = UnitGUID(unit)
	local id = CreatureIDFromGUID(guid)
	P(string.format("NPC_ID=%s  name=%s  guid=%s  unit=%s", tostring(id), tostring(name), tostring(guid), tostring(unit)))
end

function SarychUI:StartQuickStartNPCProbe()
	npcProbe.on = true
	for k in pairs(npcProbe.byID) do
		npcProbe.byID[k] = nil
	end
	for i = #npcProbe.list, 1, -1 do
		npcProbe.list[i] = nil
	end
	P(T("Тест: откройте 5 NPC по очереди. В чат уйдёт NPC_ID."))
end

function SarychUI:StopQuickStartNPCProbe(silent)
	npcProbe.on = false
	probeWait:Hide()
	if not silent then
		P(T("Тест остановлен"))
	end
end

function SarychUI:IsQuickStartNPCProbeOn()
	return npcProbe.on
end

function SarychUI:GetQuickStartNPCProbeCount()
	return #npcProbe.list, C.NPC_PROBE_MAX
end
end

function SarychUI:BuildQuickStartGeneralArgs()
	return {
		builtinProfile = {
			type = "group",
			name = "",
			order = 1,
			inline = true,
			suiThreeCol = true,
			args = {
				summary = {
					type = "description",
					name = "|cffffffffBonjourepta|r  |cff68b5ff" .. T("Встроенный") .. "|r\n|cff9a9aa2" .. T("Быстрый старт на WoWCircle FUN") .. "|r",
					order = 1,
					width = "full",
					fontSize = "small",
					suiFullRow = true,
				},
				buy = {
					type = "execute",
					name = T("Применить"),
					desc = T("Открывает панель закупки и запускает выбранный шаблон."),
					order = 2,
					suiSkipWritableProfile = true,
					func = function()
						SarychUI:BeginQuickStartBuy()
					end,
				},
				clone = {
					type = "execute",
					name = T("Клонировать"),
					order = 3,
					suiSkipWritableProfile = true,
					func = function()
						if SarychUI.CloneQuickStartProfile then
							SarychUI:CloneQuickStartProfile("__builtin", false)
						end
					end,
				},
				edit = {
					type = "execute",
					name = T("Редактировать"),
					order = 4,
					suiSkipWritableProfile = true,
					func = function()
						if SarychUI.ShowQuickStartProfileEditor then
							SarychUI:ShowQuickStartProfileEditor("__builtin")
						end
					end,
				},
			},
		},
	}
end

function SarychUI:IsQuickStartMiscEnabled()
	local store = CatalogStore()
	return store and store.quickStartMiscEnabled and true or false
end

function SarychUI:SetQuickStartMiscEnabled(value)
	local store = CatalogStore()
	if store then
		store.quickStartMiscEnabled = value and true or false
	end
	if self.NotifySarychUIOptionsChange then
		self:NotifySarychUIOptionsChange()
	end
end

function SarychUI:BuildQuickStartMiscArgs()
	local function miscOff()
		return not SarychUI:IsQuickStartMiscEnabled()
	end
	return {
		hint = {
			type = "description",
			name = T("Вкладка для тестов разработки. Включите, чтобы показать служебные инструменты."),
			order = 1,
			width = "full",
			fontSize = "medium",
		},
		showExtras = {
			type = "toggle",
			name = T("Показать дополнительные функции"),
			desc = T("Показать служебные блоки для тестов разработки."),
			order = 2,
			width = "full",
			suiSkipWritableProfile = true,
			get = function()
				return SarychUI:IsQuickStartMiscEnabled()
			end,
			set = function(_, value)
				SarychUI:SetQuickStartMiscEnabled(value)
			end,
		},
		scanItemsBox = {
			type = "group",
			name = T("Предметы персонажа"),
			order = 3,
			inline = true,
			hidden = miscOff,
			args = {
				hint = {
					type = "description",
					name = T("Сканирует экипировку и сумки: предметы, слоты, установленные камни и наложенные чары. Результат содержит данные для профиля быстрого старта."),
					order = 1,
					width = "full",
					fontSize = "small",
				},
				scan = {
					type = "execute",
					name = T("Сканировать ID"),
					desc = T("Собирает полный список экипировки и сумок, включая камни и чары, и открывает окно для копирования."),
					order = 2,
					width = "full",
					suiSkipWritableProfile = true,
					func = function()
						SarychUI:ShowPlayerItemScanCopy()
					end,
				},
			},
		},
		testBox = {
			type = "group",
			name = T("Тестовое"),
			order = 4,
			inline = true,
			hidden = miscOff,
			args = {
				hint = {
					type = "description",
					name = function()
						if SarychUI.IsQuickStartNPCProbeOn and SarychUI:IsQuickStartNPCProbeOn() then
							local n, maxN = SarychUI:GetQuickStartNPCProbeCount()
							return string.format(T("Слушаю мобов: %d/%d. Откройте NPC — в чат уйдёт кто это и какие окна."), n, maxN)
						end
						return T("Цель или откройте NPC — кнопка «ID моба» печатает NPC_ID. Либо Начать тест: 5 мобов подряд.")
					end,
					order = 1,
					width = "full",
					fontSize = "small",
				},
				idNow = {
					type = "execute",
					name = T("ID моба"),
					desc = T("Печатает NPC_ID, GUID и имя текущей цели / открытого NPC."),
					order = 2,
					width = "full",
					suiSkipWritableProfile = true,
					func = function()
						SarychUI:PrintQuickStartMobID()
					end,
				},
				start = {
					type = "execute",
					name = T("Начать тест"),
					desc = T("Слушает открытие NPC. Всего 5, в чат NPC_ID."),
					order = 3,
					width = "full",
					suiSkipWritableProfile = true,
					disabled = function()
						return SarychUI.IsQuickStartNPCProbeOn and SarychUI:IsQuickStartNPCProbeOn()
					end,
					func = function()
						SarychUI:StartQuickStartNPCProbe()
					end,
				},
				stop = {
					type = "execute",
					name = T("Стоп"),
					desc = T("Остановить прослушивание NPC."),
					order = 4,
					width = "full",
					suiSkipWritableProfile = true,
					disabled = function()
						return not (SarychUI.IsQuickStartNPCProbeOn and SarychUI:IsQuickStartNPCProbeOn())
					end,
					func = function()
						SarychUI:StopQuickStartNPCProbe()
					end,
				},
			},
		},
	}
end

function SarychUI:BuildQuickStartMiscGroup()
	return {
		type = "group",
		name = T("Иное"),
		order = 3,
		args = self:BuildQuickStartMiscArgs(),
	}
end

function SarychUI:BuildQuickStartOptionsGroup()
	return {
		type = "group",
		name = "Быстрый старт",
		order = 2,
		childGroups = "tab",
		args = {
			general = {
				type = "group",
				name = "Основное",
				order = 1,
				args = (self.BuildQuickStartGeneralArgs and self:BuildQuickStartGeneralArgs()) or {},
			},
			database = {
				type = "group",
				name = "База данных",
				order = 2,
				args = (self.BuildQuickStartDatabaseArgs and self:BuildQuickStartDatabaseArgs()) or {},
			},
			misc = (self.BuildQuickStartMiscGroup and self:BuildQuickStartMiscGroup()) or {
				type = "group",
				name = "Иное",
				order = 3,
				args = {},
			},
		},
	}
end

function SarychUI:GetQuickStartOptionsGroup()
	local root = self._customOptionsRoot
	local automation = root and root.args and root.args.modules and root.args.modules.args
		and root.args.modules.args.automation
	return automation and automation.args and automation.args.quickstart
end

function SarychUI:BuildQuickStartDatabaseArgs()
	return {
		catalogBox = {
			type = "group",
			name = T("Текущая база"),
			order = 1,
			inline = true,
			suiThreeCol = true,
			args = self:BuildQuickStartCatalogArgs(),
		},
		scanBox = {
			type = "group",
			name = T("Своя база"),
			order = 2,
			inline = true,
			args = {
				hint = {
					type = "description",
					name = T("Пересобрать базу с NPC All start items: откройте панель и пройдите скан."),
					order = 1,
					width = "full",
					fontSize = "small",
				},
				quickBuy = {
					type = "execute",
					name = T("Сформировать"),
					desc = T("Очищает текущую базу и открывает панель скана, чтобы заполнить свою."),
					order = 2,
					width = "full",
					suiSkipWritableProfile = true,
					confirm = true,
					confirmText = T("Текущая база будет очищена. Начать заполнение своей?"),
					func = function()
						SarychUI:BeginQuickStartCustomScan()
					end,
				},
			},
		},
	}
end

function SarychUI:RefreshQuickStartCatalogOptions()
	local qs = self.GetQuickStartOptionsGroup and self:GetQuickStartOptionsGroup()
	local db = qs and qs.args and qs.args.database
	if not db then
		return
	end
	db.args = self:BuildQuickStartDatabaseArgs()
	if self.OptionsCore and self.OptionsCore.InvalidateStructure then
		self.OptionsCore:InvalidateStructure()
	end
	if self.NotifySarychUIOptionsChange then
		self:NotifySarychUIOptionsChange()
	end
end

function SarychUI:PrintQuickStartCatalog()
	local text = self:FormatQuickStartCatalog()
	if text == T("База пуста") then
		P(text)
		return
	end
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		if line ~= "" then
			P(line)
		end
	end
end

function SarychUI:ClearQuickStartCatalog(silent)
	local store = CatalogStore()
	if store then
		store.quickStartCatalog = false
		store.quickStartCatalogCleared = true
	end
	RefreshCatalogOptions()
	if not silent then
		P(T("База пуста"))
	end
end

function SarychUI:RestoreQuickStartCatalog()
	local store = CatalogStore()
	local src = DefaultCatalog()
	if not store or not src then
		return
	end
	store.quickStartCatalog = StampCatalog(DeepCopy(src), true)
	store.quickStartCatalogCleared = false
	RefreshCatalogOptions()
	P(T("Восстановлена стандартная база"))
end

do
local copyFrame
local function EnsureCopyFrame()
	if copyFrame then
		return copyFrame
	end
	local f = CreateFrame("Frame", "SarychUI_QuickStartCopy", UIParent)
	f:SetSize(480, 400)
	f:SetPoint("CENTER")
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(600)
	f:SetToplevel(true)
	f:EnableMouse(false)
	f:SetMovable(true)
	f:Hide()
	ApplyTheme(f)
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "SarychUI_QuickStartCopy")
	end

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -36, -1)
	header:SetHeight(36)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
	end)

	local close = CreateFrame("Button", nil, f)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -8, -8)
	close:EnableMouse(true)
	close:RegisterForClicks("LeftButtonUp")
	close:SetFrameLevel((f:GetFrameLevel() or 600) + 20)
	ApplyTheme(close, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
	local closeFs = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	closeFs:SetPoint("CENTER", 1, 0)
	closeFs:SetText("X")
	local function HideCopy()
		if f.edit then
			f.edit:ClearFocus()
		end
		f:Hide()
	end
	close:SetScript("OnEnter", function(self)
		ApplyTheme(self, { 0.22, 0.22, 0.25, 1 }, { 0.95, 0.78, 0.15, 1 })
	end)
	close:SetScript("OnLeave", function(self)
		ApplyTheme(self, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
	end)
	close:SetScript("OnMouseDown", HideCopy)
	close:SetScript("OnClick", HideCopy)
	f.close = close

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetPoint("RIGHT", close, "LEFT", -6, 0)
	title:SetJustifyH("LEFT")
	title:SetText(T("Копировать базу"))
	title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.title = title

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 12, -30)
	hint:SetText(T("Ctrl+C чтобы скопировать"))

	local scroll = CreateFrame("ScrollFrame", "SarychUI_QuickStartCopyScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -48)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)

	local edit = CreateFrame("EditBox", "SarychUI_QuickStartCopyEdit", scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(true)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(420)
	edit:SetMaxLetters(500000)
	edit:SetScript("OnEscapePressed", function()
		edit:ClearFocus()
		f:Hide()
	end)
	f:SetScript("OnHide", function()
		if f.edit then
			f.edit:ClearFocus()
		end
	end)
	scroll:SetScrollChild(edit)
	f.edit = edit
	copyFrame = f
	return f
end

function SarychUI:ShowQuickStartCopy(text, title)
	local f = EnsureCopyFrame()
	if f.title then
		f.title:SetText(title or T("Копировать базу"))
	end
	f:Show()
	f:Raise()
	if f.close then
		f.close:Raise()
	end
	f.edit:SetText(text or "")
	f.edit:HighlightText()
	f.edit:SetFocus()
end

function SarychUI:ShowQuickStartCatalogCopy()
	self:ShowQuickStartCopy(self:FormatQuickStartCatalog(), T("Копировать базу"))
end

C.PAPER_SLOTS = {
	{ 0, "Боеприпасы" },
	{ 1, "Голова" },
	{ 2, "Шея" },
	{ 3, "Плечи" },
	{ 4, "Рубашка" },
	{ 5, "Грудь" },
	{ 6, "Пояс" },
	{ 7, "Ноги" },
	{ 8, "Ступни" },
	{ 9, "Запястья" },
	{ 10, "Кисти" },
	{ 11, "Палец 1" },
	{ 12, "Палец 2" },
	{ 13, "Аксессуар 1" },
	{ 14, "Аксессуар 2" },
	{ 15, "Спина" },
	{ 16, "Правая рука" },
	{ 17, "Левая рука" },
	{ 18, "Дальний бой" },
	{ 19, "Гербовая накидка" },
}

local function AddItemCount(map, id, count)
	id = tonumber(id)
	count = tonumber(count) or 1
	if not id or count < 1 then
		return
	end
	map[id] = (map[id] or 0) + count
end

local function SlotItemID(slot)
	if type(GetInventoryItemID) == "function" then
		local id = GetInventoryItemID("player", slot)
		if id then
			return tonumber(id)
		end
	end
	if type(GetInventoryItemLink) == "function" then
		return ItemIDFromLink(GetInventoryItemLink("player", slot))
	end
end

local function ItemEquipLoc(id)
	if type(GetItemInfo) ~= "function" then
		return "", nil
	end
	local name, _, _, _, _, _, _, _, loc = GetItemInfo(id)
	return loc or "", name
end

-- Item links on the 3.3.5 client keep the permanent enchant and up to four
-- gem item IDs in fixed fields. Parsing the link also works before item data
-- has been fully cached by the client.
local function ParseScannedItemLink(link)
	if type(link) ~= "string" or link == "" then
		return nil
	end
	local itemString = link:match("|H(item:[^|]+)|h") or link:match("^(item:[^|]+)")
	if not itemString then
		return nil
	end
	local fields = {}
	local start = 1
	while true do
		local at = itemString:find(":", start, true)
		if not at then
			fields[#fields + 1] = itemString:sub(start)
			break
		end
		fields[#fields + 1] = itemString:sub(start, at - 1)
		start = at + 1
	end
	if fields[1] ~= "item" then
		return nil
	end
	local gemEffects = {}
	for index = 1, 4 do
		local id = tonumber(fields[index + 3])
		if id and id > 0 then
			gemEffects[#gemEffects + 1] = { effectID = id, index = index }
		end
	end
	return {
		itemID = tonumber(fields[2]),
		enchantEffectID = tonumber(fields[3]) or 0,
		gemEffects = gemEffects,
	}
end

local socketTip = CreateFrame("GameTooltip", "SarychUIQuickStartSocketTip", nil, "GameTooltipTemplate")
local socketTypes = {
	{ "EMPTY_SOCKET_META", "META" },
	{ "EMPTY_SOCKET_RED", "RED" },
	{ "EMPTY_SOCKET_BLUE", "BLUE" },
	{ "EMPTY_SOCKET_YELLOW", "YELLOW" },
	{ "EMPTY_SOCKET_PRISMATIC", "PRISMATIC" },
	{ "EMPTY_SOCKET_NO_COLOR", "PRISMATIC" },
}
local socketLayoutCache = {}

local function ProbeQuickstartSocketLayout(itemID)
	itemID = tonumber(itemID)
	if not itemID then return nil end
	if socketLayoutCache[itemID] then return socketLayoutCache[itemID] end
	local link = type(GetItemInfo) == "function" and select(2, GetItemInfo(itemID))
	if not link then return nil end
	socketTip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok = pcall(socketTip.SetHyperlink, socketTip, link)
	if not ok then socketTip:Hide(); return nil end
	local layout = {}
	for index = 2, socketTip:NumLines() do
		local line = _G["SarychUIQuickStartSocketTipTextLeft" .. index]
		local text = line and line:GetText()
		if text then
			text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			for _, entry in ipairs(socketTypes) do
				local label = _G[entry[1]]
				if label and text == label then
					layout[#layout + 1] = { socketType = entry[2] }
					break
				end
			end
		end
	end
	socketTip:Hide()
	socketLayoutCache[itemID] = layout
	return layout
end

SarychUI.ProbeQuickstartSocketLayout = ProbeQuickstartSocketLayout

local function ResolveScannedEnchant(slot, link, effectID)
	if not effectID or effectID <= 0 then
		return nil
	end
	return { effectID = effectID }
end

local function ResolveSocketLayout(slot, link)
	local itemID = type(link) == "string" and tonumber(link:match("item:(%d+)"))
	return ProbeQuickstartSocketLayout(itemID)
end

local function EnrichScannedItem(row, inventorySlot)
	local parsed = ParseScannedItemLink(row.link)
	if not parsed then
		return row
	end
	row.id = row.id or parsed.itemID
	row.gems = {}
	row.unresolvedGemEffects = {}
	for i = 1, #parsed.gemEffects do
		local effect = parsed.gemEffects[i]
		local gemLink
		if type(GetItemGem) == "function" then
			local ok, _, resolvedLink = pcall(GetItemGem, row.link, effect.index)
			if ok then gemLink = resolvedLink end
		end
		local gemID = ItemIDFromLink(gemLink)
		if gemID then
			row.gems[#row.gems + 1] = { id = gemID, index = effect.index, effectID = effect.effectID }
		else
			row.unresolvedGemEffects[#row.unresolvedGemEffects + 1] = effect
		end
	end
	local layout = ResolveSocketLayout(inventorySlot, row.link)
	row.socketCount = type(layout) == "table" and #layout or 0
	for i = 1, #row.gems do
		local gem = row.gems[i]
		local socket = layout and layout[gem.index]
		gem.socketType = socket and socket.socketType or nil
		gem.name = ItemNameByID(gem.id)
		if gem.index > row.socketCount then
			row.socketCount = gem.index
		end
	end
	row.enchant = ResolveScannedEnchant(inventorySlot, row.link, parsed.enchantEffectID)
	return row
end

local function CollectEquippedSlots()
	local rows = {}
	for i = 1, #C.PAPER_SLOTS do
		local slot, label = C.PAPER_SLOTS[i][1], C.PAPER_SLOTS[i][2]
		local id = SlotItemID(slot)
		local link = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slot) or nil
		local loc, name = "", nil
		if id then
			loc, name = ItemEquipLoc(id)
			if type(loc) ~= "string" then
				loc = ""
			end
		end
		rows[#rows + 1] = EnrichScannedItem({
			slot = slot,
			label = T(label),
			id = id,
			link = link,
			loc = loc,
			name = name or (id and ItemNameByID(id) or ""),
		}, slot)
	end
	return rows
end

local function CollectWornBags()
	local rows = {}
	for slot = 20, 23 do
		local id = SlotItemID(slot)
		local link = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slot) or nil
		rows[#rows + 1] = EnrichScannedItem({
			slot = slot,
			label = T("Сумка") .. " " .. (slot - 19),
			id = id,
			link = link,
			name = id and ItemNameByID(id) or "",
		}, slot)
	end
	return rows
end

local function CollectBagItems()
	local rows = {}
	local bags = { 0, 1, 2, 3, 4 }
	if KEYRING_CONTAINER then
		bags[#bags + 1] = KEYRING_CONTAINER
	end
	for i = 1, #bags do
		local bag = bags[i]
		local n = (type(GetContainerNumSlots) == "function" and GetContainerNumSlots(bag)) or 0
		for slot = 1, n do
			local id, link
			if type(GetContainerItemID) == "function" then
				id = GetContainerItemID(bag, slot)
			end
			if type(GetContainerItemLink) == "function" then
				link = GetContainerItemLink(bag, slot)
				id = id or ItemIDFromLink(link)
			end
			local count = 1
			if type(GetContainerItemInfo) == "function" then
				local _, itemCount = GetContainerItemInfo(bag, slot)
				if itemCount then
					count = itemCount
				end
			end
			if id then
				rows[#rows + 1] = EnrichScannedItem({
					bag = bag,
					slot = slot,
					id = tonumber(id),
					count = count,
					link = link,
					name = ItemNameByID(id),
				}, nil)
			end
		end
	end
	return rows
end

local function CountBagItems(rows)
	local counts = {}
	for i = 1, #rows do
		AddItemCount(counts, rows[i].id, rows[i].count)
	end
	return counts
end

local function AppendCountLines(lines, counts)
	local ids = {}
	for id in pairs(counts) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	if #ids == 0 then
		lines[#lines + 1] = T("Предметов нет")
		return
	end
	local total = 0
	for i = 1, #ids do
		total = total + counts[ids[i]]
	end
	lines[#lines + 1] = string.format(T("%d id, %d шт."), #ids, total)
	for i = 1, #ids do
		local id = ids[i]
		lines[#lines + 1] = string.format("%d  x%d  %s", id, counts[id], ItemNameByID(id))
	end
end

local function FormatEquippedRows(rows, includeEmpty)
	local lines = {}
	local worn = 0
	for i = 1, #rows do
		if rows[i].id then
			worn = worn + 1
		end
	end
	lines[#lines + 1] = string.format(T("Надето: %d / %d"), worn, #rows)
	for i = 1, #rows do
		local row = rows[i]
		if row.id then
			lines[#lines + 1] = string.format(
				"%d  %s  %d  %s  %s",
				row.slot,
				row.label,
				row.id,
				type(row.loc) == "string" and row.loc ~= "" and row.loc or "-",
				row.name ~= "" and row.name or ItemNameByID(row.id)
			)
			if row.enchant then
				local enchant = row.enchant
				local source = enchant.itemID and ("itemID " .. enchant.itemID) or T("предмет чар не найден")
				local text = enchant.text and (" — " .. enchant.text) or ""
				lines[#lines + 1] = string.format("    %s: effectID %d, %s%s", T("Чары"), enchant.effectID, source, text)
			end
			for gemIndex = 1, #(row.gems or {}) do
				local gem = row.gems[gemIndex]
				lines[#lines + 1] = string.format(
					"    %s %d%s: %d  %s",
					T("Камень"),
					gem.index,
					gem.socketType and (" [" .. gem.socketType .. "]") or "",
					gem.id,
					gem.name or ItemNameByID(gem.id)
				)
			end
			for gemIndex = 1, #(row.unresolvedGemEffects or {}) do
				local gem = row.unresolvedGemEffects[gemIndex]
				lines[#lines + 1] = string.format(
					"    %s %d: effectID %d (%s)",
					T("Камень"), gem.index, gem.effectID, T("itemID камня не определён")
				)
			end
		elseif includeEmpty then
			lines[#lines + 1] = string.format("%d  %s  —", row.slot, row.label)
		end
	end
	return lines
end

local function LuaString(text)
	return string.format("%q", tostring(text or ""))
end

local function FormatProfileGear(rows)
	local lines = { T("Данные экипировки для профиля"), "gear = {" }
	for i = 1, #rows do
		local row = rows[i]
		if row.id and row.slot > 0 and row.slot < 20 then
			local fields = { "itemID = " .. row.id }
			if row.enchant and row.enchant.itemID then
				fields[#fields + 1] = "enchantID = " .. row.enchant.itemID
				fields[#fields + 1] = "enchantName = " .. LuaString(row.label)
			end
			if row.socketCount and row.socketCount > 0 then
				fields[#fields + 1] = "socketCount = " .. row.socketCount
			end
			local gems = {}
			for gemIndex = 1, #(row.gems or {}) do
				local gem = row.gems[gemIndex]
				gems[#gems + 1] = string.format(
					"{ id = %d, fallback = %d, name = %s }",
					gem.id,
					gem.index,
					LuaString(gem.socketType or T("гнездо"))
				)
			end
			fields[#fields + 1] = "gems = { " .. table.concat(gems, ", ") .. " }"
			local comment = row.label .. " — " .. (row.name or ItemNameByID(row.id))
			if row.enchant and not row.enchant.itemID then
				comment = comment .. string.format("; enchant effectID %d (%s)", row.enchant.effectID, T("нужен itemID предмета чар"))
			end
			lines[#lines + 1] = string.format("\t[%d] = { %s }, -- %s", row.slot, table.concat(fields, ", "), comment)
		end
	end
	lines[#lines + 1] = "}"
	return lines
end

local function FormatBagRows(lines, rows)
	if #rows == 0 then
		lines[#lines + 1] = T("Предметов нет")
		return
	end
	for i = 1, #rows do
		local row = rows[i]
		lines[#lines + 1] = string.format("bag %d, slot %d  %d  x%d  %s", row.bag, row.slot, row.id, row.count, row.name)
		if row.enchant then
			local source = row.enchant.itemID and ("itemID " .. row.enchant.itemID) or T("предмет чар не найден")
			lines[#lines + 1] = string.format("    %s: effectID %d, %s", T("Чары"), row.enchant.effectID, source)
		end
		for gemIndex = 1, #(row.gems or {}) do
			local gem = row.gems[gemIndex]
			lines[#lines + 1] = string.format("    %s %d: %d  %s", T("Камень"), gem.index, gem.id, gem.name)
		end
		for gemIndex = 1, #(row.unresolvedGemEffects or {}) do
			local gem = row.unresolvedGemEffects[gemIndex]
			lines[#lines + 1] = string.format("    %s %d: effectID %d (%s)", T("Камень"), gem.index, gem.effectID, T("itemID камня не определён"))
		end
	end
end

local function BuildCompleteItemCounts(equipped, wornBags, bagRows)
	local counts = CountBagItems(bagRows)
	for i = 1, #equipped do
		local row = equipped[i]
		AddItemCount(counts, row.id, 1)
		if row.enchant then AddItemCount(counts, row.enchant.itemID, 1) end
		for gemIndex = 1, #(row.gems or {}) do
			AddItemCount(counts, row.gems[gemIndex].id, 1)
		end
	end
	for i = 1, #wornBags do
		AddItemCount(counts, wornBags[i].id, 1)
	end
	for i = 1, #bagRows do
		local row = bagRows[i]
		if row.enchant then AddItemCount(counts, row.enchant.itemID, 1) end
		for gemIndex = 1, #(row.gems or {}) do
			AddItemCount(counts, row.gems[gemIndex].id, 1)
		end
	end
	return counts
end

local function FormatProfileBag(lines, wornBags)
	local ids, counts = {}, {}
	for i = 1, #wornBags do
		local id = wornBags[i].id
		if id then
			if not counts[id] then ids[#ids + 1] = id end
			counts[id] = (counts[id] or 0) + 1
		end
	end
	if #ids == 1 then
		lines[#lines + 1] = string.format("bag = { itemID = %d, count = %d }", ids[1], counts[ids[1]])
	elseif #ids > 1 then
		lines[#lines + 1] = T("Надеты разные сумки; для поля «Сумки экипировки» выберите один itemID:")
		for i = 1, #ids do
			lines[#lines + 1] = string.format("  %d x%d  %s", ids[i], counts[ids[i]], ItemNameByID(ids[i]))
		end
	end
end

local function FormatEquippedLua(rows)
	local lines = { "", T("Для закупки (надеть после покупки)"), "{" }
	for i = 1, #rows do
		local row = rows[i]
		if row.id then
			lines[#lines + 1] = string.format("\t{ %d, 1 }, -- %s", row.id, row.label)
		end
	end
	lines[#lines + 1] = "}"
	return lines
end

function SarychUI:FormatPlayerEquippedScan()
	local rows = CollectEquippedSlots()
	local wornBags = CollectWornBags()
	local lines = { T("Экипировка") }
	local equipped = FormatEquippedRows(rows, true)
	for i = 1, #equipped do
		lines[#lines + 1] = equipped[i]
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = T("Надетые сумки")
	local bags = FormatEquippedRows(wornBags, true)
	for i = 1, #bags do
		lines[#lines + 1] = bags[i]
	end
	local luaLines = FormatEquippedLua(rows)
	for i = 1, #luaLines do
		lines[#lines + 1] = luaLines[i]
	end
	return table.concat(lines, "\n")
end

function SarychUI:FormatPlayerItemScan()
	local rows = CollectEquippedSlots()
	local wornBags = CollectWornBags()
	local bagRows = CollectBagItems()
	local bagCounts = CountBagItems(bagRows)
	local playerName = type(UnitName) == "function" and UnitName("player") or ""
	local realmName = type(GetRealmName) == "function" and GetRealmName() or ""
	local lines = {
		T("Полный скан персонажа"),
		string.format("%s: %s%s", T("Персонаж"), playerName or "", realmName ~= "" and (" - " .. realmName) or ""),
		"",
		T("Экипировка"),
	}
	local equipped = FormatEquippedRows(rows, false)
	for i = 1, #equipped do
		lines[#lines + 1] = equipped[i]
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = T("Надетые сумки")
	local bags = FormatEquippedRows(wornBags, false)
	for i = 1, #bags do
		lines[#lines + 1] = bags[i]
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = T("Содержимое сумок по ячейкам")
	FormatBagRows(lines, bagRows)
	lines[#lines + 1] = ""
	lines[#lines + 1] = T("Содержимое сумок, итог")
	AppendCountLines(lines, bagCounts)
	lines[#lines + 1] = ""
	lines[#lines + 1] = T("Данные сумок для раздела «Основное»")
	FormatProfileBag(lines, wornBags)
	lines[#lines + 1] = ""
	local profile = FormatProfileGear(rows)
	for i = 1, #profile do
		lines[#lines + 1] = profile[i]
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = T("Полный список для закупки (экипировка + камни + предметы чар + надетые сумки + содержимое сумок)")
	AppendCountLines(lines, BuildCompleteItemCounts(rows, wornBags, bagRows))
	return table.concat(lines, "\n")
end

function SarychUI:ShowPlayerItemScanCopy()
	self:ShowQuickStartCopy(self:FormatPlayerItemScan(), T("Копировать ID"))
end

function SarychUI:ShowPlayerEquippedScanCopy()
	self:ShowQuickStartCopy(self:FormatPlayerEquippedScan(), T("Что надето"))
end
end

local function SetStatus(text)
	if panel and panel.status then
		panel.status:SetText(text or "")
	end
	if stepState.refreshing or sessionMode ~= "buy" or not stepState.refresh then
		return
	end
	stepState.refreshing = true
	stepState.refresh()
	stepState.refreshing = false
end

local function SetNested(text)
	if panel and panel.nested then
		panel.nested:SetText(text or "")
	end
end

local function SetPrompt(text, waiting)
	if not panel or not panel.prompt then
		return
	end
	panel.prompt:SetText(text or "")
	panel.promptWaiting = waiting and text and text ~= "" and true or false
	if waiting then
		panel.prompt:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	else
		panel.prompt:SetTextColor(0.65, 0.65, 0.68)
	end
	if UpdateNPCModel then
		UpdateNPCModel()
	end
end

local bagEquip = {
	on = false,
	busy = false,
	want = 0,
	attempts = 0,
	fails = 0,
	filledAtStart = 0,
	startedAt = 0,
	settleAt = 0,
	waitingResult = false,
}
local bagEquipWatch = CreateFrame("Frame")
bagEquipWatch:Hide()

local function PlayerInCombat()
	if type(InCombatLockdown) == "function" and InCombatLockdown() then
		return true
	end
	return UnitAffectingCombat("player") and true or false
end

InventoryItemID = function(slot)
	if type(GetInventoryItemID) == "function" then
		local id = GetInventoryItemID("player", slot)
		if id then
			return id
		end
	end
	if type(GetInventoryItemLink) == "function" then
		return ItemIDFromLink(GetInventoryItemLink("player", slot))
	end
end

local function CountEmptyBagInvSlots()
	local n = 0
	for slot = C.BAG_INV_FIRST, C.BAG_INV_LAST do
		if not InventoryItemID(slot) then
			n = n + 1
		end
	end
	return n
end

local function FirstEmptyBagInvSlot()
	for slot = C.BAG_INV_FIRST, C.BAG_INV_LAST do
		if not InventoryItemID(slot) then
			return slot
		end
	end
end

local function FindInventoryBagItem(itemID)
	for bag = 0, 4 do
		local n = (type(GetContainerNumSlots) == "function" and GetContainerNumSlots(bag)) or 0
		for slot = 1, n do
			local id
			if type(GetContainerItemID) == "function" then
				id = GetContainerItemID(bag, slot)
			end
			if not id and type(GetContainerItemLink) == "function" then
				id = ItemIDFromLink(GetContainerItemLink(bag, slot))
			end
			if id == itemID then
				local link = type(GetContainerItemLink) == "function" and GetContainerItemLink(bag, slot) or nil
				return bag, slot, link
			end
		end
	end
end

CountInventoryBagItem = function(itemID)
	local total = 0
	for bag = 0, 4 do
		local n = (type(GetContainerNumSlots) == "function" and GetContainerNumSlots(bag)) or 0
		for slot = 1, n do
			local id
			if type(GetContainerItemID) == "function" then
				id = GetContainerItemID(bag, slot)
			end
			if not id and type(GetContainerItemLink) == "function" then
				id = ItemIDFromLink(GetContainerItemLink(bag, slot))
			end
			if id == itemID then
				local count = 1
				if type(GetContainerItemInfo) == "function" then
					count = select(2, GetContainerItemInfo(bag, slot)) or 1
				end
				total = total + count
			end
		end
	end
	return total
end

local function FilledBagInvSlots()
	return (C.BAG_INV_LAST - C.BAG_INV_FIRST + 1) - CountEmptyBagInvSlots()
end

local function StopBagEquipWatch(msg)
	bagEquip.on = false
	bagEquip.busy = false
	bagEquip.waitingResult = false
	bagEquip.resultUntil = nil
	bagEquip.want = 0
	bagEquipWatch:Hide()
	bagEquipWatch:UnregisterAllEvents()
	SetPrompt("")
	if msg then
		SetStatus(msg)
		P(msg)
	end
end

local function BagEquipFinished()
	if CountEmptyBagInvSlots() <= 0 then
		return true
	end
	return FilledBagInvSlots() >= (bagEquip.filledAtStart or 0) + (bagEquip.want or 0)
end

local function NotifyBagsEquipped()
	local engine = _G.SarychUI_Bags and _G.SarychUI_Bags[1]
	local bags = engine and engine.GetModule and engine:GetModule("Bags")
	if bags and bags.ScheduleEquippedBagSync then
		bags:ScheduleEquippedBagSync("quickstart")
	end
end

local function FinishBagEquip(ok)
	local onDone = bagEquip.onDone
	bagEquip.onDone = nil
	if ok then
		StopBagEquipWatch(T("Сумки надеты"))
	else
		StopBagEquipWatch(T("Не удалось надеть сумку"))
	end
	NotifyBagsEquipped()
	if type(onDone) == "function" then
		onDone(ok)
	end
end

C.BIND_POPUPS = {
	EQUIP_BIND = true,
	AUTOEQUIP_BIND = true,
}

local function EachBindPopup(fn)
	local n = tonumber(STATICPOPUP_NUMDIALOGS) or 4
	for i = 1, n do
		local popup = _G["StaticPopup" .. i]
		if popup and popup.IsShown and popup:IsShown() and popup.which and C.BIND_POPUPS[popup.which] then
			fn(popup)
		end
	end
end

local function BindPopupVisible()
	local found = false
	EachBindPopup(function()
		found = true
	end)
	return found
end

local function ConfirmEquipBind(invSlot)
	local confirmed = false
	EachBindPopup(function(popup)
		confirmed = true
		popup:SetFrameStrata("TOOLTIP")
		popup:SetFrameLevel(800)
		if popup.Raise then
			popup:Raise()
		end
		P(T("Подтверждаю персональность"))
		if type(EquipPendingItem) == "function" then
			pcall(EquipPendingItem, invSlot or popup.data)
		end
		if popup.IsShown and popup:IsShown() then
			if type(StaticPopup_OnClick) == "function" then
				pcall(StaticPopup_OnClick, popup, 1)
			else
				local btn = _G[popup:GetName() .. "Button1"]
				if btn and btn.Click then
					btn:Click()
				end
			end
		end
	end)
	return confirmed
end

local function PlaceItemOnSlot(bag, bagSlot, invSlot, itemID)
	if type(ClearCursor) == "function" then
		ClearCursor()
	end
	if type(PickupContainerItem) == "function" then
		PickupContainerItem(bag, bagSlot)
	end
	if type(CursorHasItem) == "function" and CursorHasItem() and type(PickupInventoryItem) == "function" then
		PickupInventoryItem(invSlot)
		return true
	end
	if type(EquipItemByName) == "function" then
		local name = itemID and type(GetItemInfo) == "function" and GetItemInfo(itemID) or nil
		if name then
			pcall(EquipItemByName, name, invSlot)
		elseif itemID then
			pcall(EquipItemByName, itemID, invSlot)
		end
		return true
	end
	return false
end

local function PlaceBagOnSlot(bag, bagSlot, invSlot)
	return PlaceItemOnSlot(bag, bagSlot, invSlot, C.QUICK_BUY_ITEM_ID)
end

local function TryEquipBoughtBag()
	if bagEquip.busy or not bagEquip.on then
		return
	end
	if bagEquip.waitingResult then
		if BindPopupVisible() then
			ConfirmEquipBind(bagEquip.pendingSlot)
			bagEquip.bindTried = true
			bagEquip.waitingResult = true
			bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
			return
		end
		if not bagEquip.bindTried and type(EquipPendingItem) == "function" and bagEquip.pendingSlot then
			P(T("Подтверждаю персональность"))
			pcall(EquipPendingItem, bagEquip.pendingSlot)
			bagEquip.bindTried = true
			bagEquip.waitingResult = true
			bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
			return
		end
		local filled = FilledBagInvSlots()
		if filled <= (bagEquip.lastFilled or 0) and GetTime() < (bagEquip.resultUntil or 0) then
			bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
			return
		end
		bagEquip.waitingResult = false
		if BagEquipFinished() then
			FinishBagEquip(true)
			return
		end
		if filled > (bagEquip.lastFilled or 0) then
			bagEquip.fails = 0
			P(T("Сумка надета"))
		else
			bagEquip.fails = (bagEquip.fails or 0) + 1
			P(T("Не удалось надеть сумку"))
		end
		if BagEquipFinished() then
			FinishBagEquip(true)
			return
		end
		if (bagEquip.attempts or 0) >= ((bagEquip.want or 1) + 3) or (bagEquip.fails or 0) >= 3 then
			FinishBagEquip(false)
			return
		end
	end
	if BagEquipFinished() then
		FinishBagEquip(true)
		return
	end
	if (bagEquip.attempts or 0) >= ((bagEquip.want or 1) + 3) then
		FinishBagEquip(false)
		return
	end
	if PlayerInCombat() then
		SetPrompt(T("Выйдите из боя, чтобы надеть сумку"), true)
		if not bagEquip.printedCombat then
			bagEquip.printedCombat = true
			P(T("Выйдите из боя, чтобы надеть сумку"))
		end
		bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
		return
	end
	if type(CursorHasItem) == "function" and CursorHasItem() then
		if type(ClearCursor) == "function" then
			ClearCursor()
		end
	end
	local invSlot = FirstEmptyBagInvSlot()
	local bag, bagSlot = FindInventoryBagItem(C.QUICK_BUY_ITEM_ID)
	if not invSlot then
		FinishBagEquip(true)
		return
	end
	if not bag then
		bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
		return
	end
	bagEquip.busy = true
	bagEquip.attempts = (bagEquip.attempts or 0) + 1
	bagEquip.lastFilled = FilledBagInvSlots()
	bagEquip.pendingSlot = invSlot
	bagEquip.bindTried = false
	bagEquip.resultUntil = GetTime() + C.BAG_EQUIP_RESULT_TIMEOUT
	P(string.format(T("Надеваю сумку в слот %d") .. " (%d/%d)", invSlot, bagEquip.attempts, bagEquip.want or 1))
	PlaceBagOnSlot(bag, bagSlot, invSlot)
	if BindPopupVisible() then
		ConfirmEquipBind(invSlot)
		bagEquip.bindTried = true
	end
	bagEquip.busy = false
	bagEquip.waitingResult = true
	bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
end

local function StartBagEquipWatch(count, onDone)
	count = tonumber(count) or 0
	local empty = CountEmptyBagInvSlots()
	if count < 1 or empty < 1 then
		P(T("Нет свободного слота сумки"))
		if type(onDone) == "function" then
			onDone(false)
		end
		return
	end
	if bagEquip.on then
		if type(onDone) == "function" then
			bagEquip.onDone = onDone
		end
		return
	end
	bagEquip.on = true
	bagEquip.onDone = onDone
	bagEquip.busy = false
	bagEquip.waitingResult = false
	bagEquip.printedCombat = false
	bagEquip.attempts = 0
	bagEquip.fails = 0
	bagEquip.bindTried = false
	bagEquip.pendingSlot = nil
	bagEquip.resultUntil = nil
	bagEquip.want = math.min(count, empty)
	bagEquip.filledAtStart = FilledBagInvSlots()
	bagEquip.lastFilled = bagEquip.filledAtStart
	bagEquip.startedAt = GetTime()
	bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
	bagEquipWatch:UnregisterAllEvents()
	bagEquipWatch:RegisterEvent("BAG_UPDATE")
	bagEquipWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	bagEquipWatch:Show()
	SetStatus(T("Надеваю сумки"))
	P(T("Надеваю сумки") .. ": " .. bagEquip.want)
end

local wearEquip = {
	on = false,
	busy = false,
	waitingResult = false,
	queue = {},
	index = 1,
	attempts = 0,
	startedAt = 0,
	settleAt = 0,
}
local wearEquipWatch = CreateFrame("Frame")
wearEquipWatch:Hide()

local function SortWearQueue(queue)
	table.sort(queue, function(a, b)
		return (a.slot or 0) < (b.slot or 0)
	end)
	return queue
end

local function WearListFromItems(items)
	local list = {}
	if type(items) ~= "table" then
		return list
	end
	local seen = {}
	for i = 1, #items do
		local it = items[i]
		local id = it and (it.id or it[1])
		id = tonumber(id)
		local slot = id and C.WEAR_SLOT[id]
		if slot and not seen[id] then
			seen[id] = true
			list[#list + 1] = { id = id, slot = slot }
		end
	end
	return SortWearQueue(list)
end

local function RemainingWearList()
	local list = {}
	for i = 1, #C.WEAR_ITEMS do
		local id, slot = C.WEAR_ITEMS[i][1], C.WEAR_ITEMS[i][2]
		if InventoryItemID(slot) ~= id then
			list[#list + 1] = { id = id, slot = slot }
		end
	end
	return SortWearQueue(list)
end

local function IsUseItem(id)
	id = tonumber(id)
	if not id then
		return false
	end
	for i = 1, #C.USE_ITEMS do
		if C.USE_ITEMS[i] == id then
			return true
		end
	end
	return false
end

IsUseItemLearned = function(id)
	id = tonumber(id)
	local spell = id and C.USE_ITEM_SPELL[id]
	if not spell or type(GetNumCompanions) ~= "function" or type(GetCompanionInfo) ~= "function" then
		return false
	end
	local n = GetNumCompanions("MOUNT") or 0
	for i = 1, n do
		local _, _, sid = GetCompanionInfo("MOUNT", i)
		if sid == spell then
			return true
		end
	end
	return false
end

local function UseListFromItems(items)
	local list = {}
	if type(items) ~= "table" then
		return list
	end
	local seen = {}
	for i = 1, #items do
		local it = items[i]
		local id = tonumber(it and (it.id or it[1]))
		if IsUseItem(id) and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	return list
end

local function RemainingUseList()
	local list = {}
	for i = 1, #C.USE_ITEMS do
		local id = C.USE_ITEMS[i]
		if FindInventoryBagItem(id) and not IsUseItemLearned(id) then
			list[#list + 1] = id
		end
	end
	return list
end

local function PruneWornBuyItems(queue)
	if type(queue) ~= "table" then
		return
	end
	for i = #queue, 1, -1 do
		local group = queue[i]
		if group and not group.equip and type(group.items) == "table" then
			for j = #group.items, 1, -1 do
				local id = group.items[j].id
				local slot = C.WEAR_SLOT[id]
				if slot and InventoryItemID(slot) == id then
					table.remove(group.items, j)
				end
			end
			if #group.items == 0 then
				table.remove(queue, i)
			end
		end
	end
end

local function StopWearEquipWatch()
	wearEquip.on = false
	wearEquip.busy = false
	wearEquip.waitingResult = false
	wearEquip.queue = {}
	wearEquipWatch:Hide()
	wearEquipWatch:UnregisterAllEvents()
end

local function FinishWearEquip(ok)
	local onDone = wearEquip.onDone
	wearEquip.onDone = nil
	StopWearEquipWatch()
	SetPrompt("")
	if type(onDone) == "function" then
		onDone(ok)
	end
end

local function WearSlotHasItem(it)
	return it and InventoryItemID(it.slot) == it.id
end

local function PendingWearCount()
	local n = 0
	for i = 1, #(wearEquip.queue or {}) do
		if not WearSlotHasItem(wearEquip.queue[i]) then
			n = n + 1
		end
	end
	return n
end

local function EquipWearItemNow(it)
	if not it or WearSlotHasItem(it) then
		return
	end
	if it.slot == 17 and not InventoryItemID(16) then
		return
	end
	if type(CursorHasItem) == "function" and CursorHasItem() and type(ClearCursor) == "function" then
		ClearCursor()
	end
	if type(EquipItemByName) == "function" then
		local name = type(GetItemInfo) == "function" and GetItemInfo(it.id) or nil
		if name then
			pcall(EquipItemByName, name, it.slot)
		else
			pcall(EquipItemByName, it.id, it.slot)
		end
	else
		local bag, bagSlot = FindInventoryBagItem(it.id)
		if bag then
			PlaceItemOnSlot(bag, bagSlot, it.slot, it.id)
		end
	end
	if type(CursorHasItem) == "function" and CursorHasItem() and type(ClearCursor) == "function" then
		ClearCursor()
	end
end

local function TryEquipWearItem()
	if not wearEquip.on then
		return
	end
	if BindPopupVisible() then
		ConfirmEquipBind()
		wearEquip.waitingResult = true
		wearEquip.settleAt = GetTime() + C.EQUIP_SETTLE
		return
	end
	if wearEquip.waitingResult then
		wearEquip.waitingResult = false
		if PendingWearCount() < 1 then
			FinishWearEquip(true)
			return
		end
		wearEquip.attempts = (wearEquip.attempts or 0) + 1
		if (wearEquip.attempts or 0) >= 5 then
			FinishWearEquip(false)
			return
		end
	end
	if PlayerInCombat() then
		SetPrompt(T("Выйдите из боя, чтобы надеть экипировку"), true)
		wearEquip.settleAt = GetTime() + C.EQUIP_SETTLE
		return
	end
	SetStatus(T("Надеваю экипировку"))
	for i = 1, #wearEquip.queue do
		local it = wearEquip.queue[i]
		if not WearSlotHasItem(it) then
			EquipWearItemNow(it)
			if BindPopupVisible() then
				ConfirmEquipBind(it.slot)
				wearEquip.waitingResult = true
				wearEquip.settleAt = GetTime() + C.EQUIP_SETTLE
				return
			end
		end
	end
	if PendingWearCount() < 1 then
		FinishWearEquip(true)
		return
	end
	wearEquip.waitingResult = true
	wearEquip.settleAt = GetTime() + C.EQUIP_SETTLE
end

local function StartWearEquip(list, onDone)
	local queue = {}
	for i = 1, #(list or {}) do
		local it = list[i]
		local id, slot = it.id or it[1], it.slot or it[2]
		if id and slot and InventoryItemID(slot) ~= id then
			queue[#queue + 1] = { id = id, slot = slot }
		end
	end
	SortWearQueue(queue)
	if #queue < 1 then
		if type(onDone) == "function" then
			onDone(true)
		end
		return
	end
	if wearEquip.on then
		wearEquip.onDone = onDone
		return
	end
	wearEquip.on = true
	wearEquip.onDone = onDone
	wearEquip.busy = false
	wearEquip.waitingResult = false
	wearEquip.printedCombat = false
	wearEquip.attempts = 0
	wearEquip.bindTried = false
	wearEquip.queue = queue
	wearEquip.index = 1
	wearEquip.startedAt = GetTime()
	wearEquip.settleAt = GetTime()
	wearEquipWatch:UnregisterAllEvents()
	wearEquipWatch:RegisterEvent("BAG_UPDATE")
	wearEquipWatch:RegisterEvent("UNIT_INVENTORY_CHANGED")
	wearEquipWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	wearEquipWatch:Show()
	SetStatus(T("Надеваю экипировку"))
end

wearEquipWatch:SetScript("OnEvent", function(_, event)
	if not wearEquip.on then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		wearEquip.settleAt = GetTime() + C.EQUIP_SETTLE
		SetPrompt("")
		return
	end
	if wearEquip.waitingResult then
		return
	end
	wearEquip.settleAt = GetTime() + C.EQUIP_SETTLE
end)

wearEquipWatch:SetScript("OnUpdate", function()
	if not wearEquip.on then
		wearEquipWatch:Hide()
		return
	end
	if GetTime() - (wearEquip.startedAt or 0) > C.WEAR_TIMEOUT then
		FinishWearEquip(false)
		return
	end
	if GetTime() < (wearEquip.settleAt or 0) then
		return
	end
	TryEquipWearItem()
end)

local useWatch = CreateFrame("Frame")
useWatch:Hide()
local useState = {
	on = false,
	queue = {},
	index = 1,
	itemID = nil,
	itemCount = nil,
	phase = nil,
}

local function HideUseItemUI()
	if not panel then
		return
	end
	if panel.useRow then
		panel.useRow:Hide()
	end
	local btn = panel.learnBtn
	if btn and btn.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
		btn:SetAttribute("type", nil)
		btn:SetAttribute("item", nil)
		btn:SetAttribute("macrotext", nil)
		btn:SetAttribute("spell", nil)
	end
	if panel.useTargetIconTex then
		panel.useTargetIconTex:Hide()
	end
	if panel.useSecondIconTex then
		panel.useSecondIconTex:Hide()
	end
	panel.chromeTall = false
	if stepState.layout then
		stepState.layout()
	end
end

local function ShowUseItemUI(id, mountReady)
	if not panel or not panel.useRow then
		return
	end
	panel.useItemID = id
	local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
	if type(GetItemIcon) == "function" then
		icon = GetItemIcon(id) or icon
	elseif type(GetItemInfo) == "function" then
		local tex = select(10, GetItemInfo(id))
		if type(tex) == "string" and tex ~= "" then
			icon = tex
		end
	end
	if panel.useIconTex then
		panel.useIconTex:SetTexture(icon)
	end
	if panel.learnBtn and panel.learnBtn.label then
		local label = panel.learnBtn.label
		label:ClearAllPoints()
		label:SetPoint("LEFT", panel.useIconTex, "RIGHT", 8, 0)
		label:SetPoint("RIGHT", -8, 0)
		label:SetJustifyH("LEFT")
		label:SetText(mountReady and T("Сесть на маунта") or T("Изучить"))
	end
	if panel.useTargetIconTex then
		panel.useTargetIconTex:Hide()
	end
	if panel.useSecondIconTex then
		panel.useSecondIconTex:Hide()
	end
	local btn = panel.learnBtn
	if btn and btn.SetAttribute and not (InCombatLockdown and InCombatLockdown()) then
		if mountReady then
			btn:SetAttribute("type", nil)
			btn:SetAttribute("item", nil)
			btn:SetAttribute("macrotext", nil)
			btn:SetAttribute("spell", nil)
		else
			local bag, slot = FindInventoryBagItem(id)
			local item
			if bag then
				item = tostring(bag) .. " " .. tostring(slot)
			else
				local name = ItemNameByID(id)
				if type(name) == "string" and name ~= "" and name ~= tostring(id) then
					item = name
				else
					item = "item:" .. tostring(id)
				end
			end
			btn:SetAttribute("type", "item")
			btn:SetAttribute("item", item)
			btn:SetAttribute("macrotext", nil)
			btn:SetAttribute("spell", nil)
		end
	end
	panel.chromeTall = false
	panel.useRow:Show()
	if stepState.layout then
		stepState.layout()
	end
end

local function FinishUseItems()
	local onDone = useState.onDone
	useState.onDone = nil
	useState.on = false
	useState.queue = {}
	useState.itemID = nil
	useState.itemCount = nil
	useState.phase = nil
	useWatch:Hide()
	useWatch:UnregisterAllEvents()
	HideUseItemUI()
	SetPrompt("")
	if type(onDone) == "function" then
		onDone(true)
	end
end

local function TryUseNextItem()
	if not useState.on then
		return
	end
	local id = useState.queue[useState.index]
	if not id then
		FinishUseItems()
		return
	end
	local count = CountInventoryBagItem(id)
	if useState.itemID ~= id then
		useState.itemID = id
		useState.itemCount = count
	end
	if IsUseItemLearned(id) then
		if id == C.MOUNT_ITEM_ID then
			if useState.phase ~= "mount" then
				P(T("Изучено") .. ": " .. ItemNameByID(id))
			end
			useState.phase = "mount"
			SetStatus(T("Маунт изучен"))
			SetPrompt(PlayerInCombat() and T("Выйдите из боя, чтобы сесть на маунта") or T("Нажмите, чтобы сесть на маунта"), true)
			ShowUseItemUI(id, true)
			return
		end
		HideUseItemUI()
		P(T("Изучено") .. ": " .. ItemNameByID(id))
		useState.index = useState.index + 1
		useState.itemID = nil
		useState.itemCount = nil
		useState.phase = nil
		useState.printed = nil
		useState.startedAt = GetTime()
		return
	end
	if count < (useState.itemCount or count) or count < 1 then
		if id == C.MOUNT_ITEM_ID and useState.phase ~= "waitingMount" then
			useState.phase = "waitingMount"
			useState.startedAt = GetTime()
			HideUseItemUI()
			SetStatus(T("Ожидание изучения маунта"))
			return
		end
		if id == C.MOUNT_ITEM_ID and useState.phase == "waitingMount" and GetTime() - (useState.startedAt or 0) <= 5 then
			return
		end
		HideUseItemUI()
		P(T("Использовано") .. ": " .. ItemNameByID(id))
		useState.index = useState.index + 1
		useState.itemID = nil
		useState.itemCount = nil
		useState.phase = nil
		useState.printed = nil
		useState.startedAt = GetTime()
		return
	end
	if GetTime() - (useState.startedAt or 0) > 60 then
		HideUseItemUI()
		P(T("Пропуск") .. ": " .. ItemNameByID(id))
		useState.index = useState.index + 1
		useState.itemID = nil
		useState.itemCount = nil
		useState.phase = nil
		useState.printed = nil
		useState.startedAt = GetTime()
		return
	end
	if not useState.printed then
		useState.printed = true
		P(T("Используйте") .. ": " .. ItemNameByID(id))
	end
	SetStatus(T("Используйте") .. ": " .. ItemNameByID(id))
	SetPrompt(T("Нажмите Изучить"), true)
	ShowUseItemUI(id)
end

local function StartUseItems(list, onDone)
	local queue = {}
	for i = 1, #(list or {}) do
		local id = tonumber(list[i])
		if id and FindInventoryBagItem(id) and not IsUseItemLearned(id) then
			queue[#queue + 1] = id
		end
	end
	if #queue < 1 then
		if type(onDone) == "function" then
			onDone(true)
		end
		return
	end
	useState.on = true
	useState.onDone = onDone
	useState.queue = queue
	useState.index = 1
	useState.itemID = nil
	useState.itemCount = nil
	useState.phase = nil
	useState.printed = nil
	useState.startedAt = GetTime()
	useWatch:UnregisterAllEvents()
	useWatch:RegisterEvent("BAG_UPDATE")
	useWatch:RegisterEvent("COMPANION_LEARNED")
	useWatch:RegisterEvent("COMPANION_UPDATE")
	useWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	useWatch:Show()
	TryUseNextItem()
end

local function HandleUseItemClick()
	if not useState.on or useState.phase ~= "mount" then
		return false
	end
	if PlayerInCombat() then
		SetPrompt(T("Выйдите из боя, чтобы сесть на маунта"), true)
		return true
	end
	local spellID = C.USE_ITEM_SPELL[C.MOUNT_ITEM_ID]
	local companionIndex
	if type(GetNumCompanions) == "function" and type(GetCompanionInfo) == "function" then
		for i = 1, (GetNumCompanions("MOUNT") or 0) do
			local _, _, knownSpellID = GetCompanionInfo("MOUNT", i)
			if knownSpellID == spellID then
				companionIndex = i
				break
			end
		end
	end
	if not companionIndex or type(CallCompanion) ~= "function" then
		SetPrompt(T("Маунт не найден в списке изученных"), true)
		return true
	end
	local ok = pcall(CallCompanion, "MOUNT", companionIndex)
	if not ok then
		SetPrompt(T("Не удалось сесть на маунта"), true)
		return true
	end
	P(T("Призываю маунта") .. ": " .. ItemNameByID(C.MOUNT_ITEM_ID))
	useState.index = useState.index + 1
	useState.itemID = nil
	useState.itemCount = nil
	useState.phase = nil
	useState.printed = nil
	useState.startedAt = GetTime()
	HideUseItemUI()
	TryUseNextItem()
	return true
end

useWatch:SetScript("OnEvent", function(_, event)
	if not useState.on then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		local id = useState.queue[useState.index]
		if id then
			ShowUseItemUI(id)
		end
	end
	TryUseNextItem()
end)

useWatch:SetScript("OnUpdate", function(_, elapsed)
	if not useState.on then
		useWatch:Hide()
		return
	end
	useState.tick = (useState.tick or 0) + elapsed
	if useState.tick < 0.25 then
		return
	end
	useState.tick = 0
	TryUseNextItem()
end)

local itemEnchantWatch = CreateFrame("Frame")
itemEnchantWatch:Hide()
local itemEnchantState = {
	on = false,
	queue = {},
	index = 0,
	itemCount = 0,
	startedAt = 0,
}

local function CurrentItemEnchant()
	return itemEnchantState.queue[itemEnchantState.index]
end

local function StopItemEnchants()
	itemEnchantState.on = false
	itemEnchantState.onDone = nil
	itemEnchantState.queue = {}
	itemEnchantState.index = 0
	itemEnchantState.itemCount = 0
	itemEnchantState.startedAt = 0
	itemEnchantState.tick = 0
	itemEnchantWatch:Hide()
	itemEnchantWatch:UnregisterAllEvents()
	HideUseItemUI()
end

local function FinishItemEnchants(ok)
	local onDone = itemEnchantState.onDone
	itemEnchantState.onDone = nil
	itemEnchantState.on = false
	itemEnchantState.queue = {}
	itemEnchantState.index = 0
	itemEnchantWatch:Hide()
	itemEnchantWatch:UnregisterAllEvents()
	HideUseItemUI()
	SetPrompt("")
	if type(onDone) == "function" then
		onDone(ok)
	end
end

local function ShowItemEnchantUI()
	if not panel or not panel.useRow then
		return
	end
	local enchant = CurrentItemEnchant()
	if not enchant then
		return
	end
	local enchantID = enchant.id
	panel.useItemID = enchantID
	local enchantIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
	if type(GetItemIcon) == "function" then
		enchantIcon = GetItemIcon(enchantID) or enchantIcon
	end
	if panel.useIconTex then
		panel.useIconTex:SetTexture(enchantIcon)
	end
	if panel.useTargetIconTex then
		local targetIcon = type(GetInventoryItemTexture) == "function" and GetInventoryItemTexture("player", enchant.slot)
		panel.useTargetIconTex:SetTexture(targetIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
		panel.useTargetIconTex:Show()
	end
	if panel.useSecondIconTex then
		panel.useSecondIconTex:Hide()
	end
	if panel.learnBtn and panel.learnBtn.label then
		local label = panel.learnBtn.label
		label:ClearAllPoints()
		label:SetPoint("LEFT", panel.useIconTex, "RIGHT", 8, 0)
		label:SetPoint("RIGHT", panel.useTargetIconTex, "LEFT", -8, 0)
		label:SetJustifyH("CENTER")
		label:SetText(T("Наложить на") .. ": " .. T(enchant.name))
	end
	local btn = panel.learnBtn
	if btn and btn.SetAttribute and not PlayerInCombat() then
		btn:SetAttribute("item", nil)
		btn:SetAttribute("spell", nil)
		btn:SetAttribute("macrotext", "/use item:" .. enchantID .. "\n/use " .. enchant.slot)
		btn:SetAttribute("type", "macro")
	end
	panel.chromeTall = false
	panel.useRow:Show()
	if stepState.layout then
		stepState.layout()
	end
	SetStatus(T("Чарка") .. ": " .. ItemNameByID(enchantID) .. " → " .. T(enchant.name))
	if PlayerInCombat() then
		SetPrompt(T("Выйдите из боя, чтобы наложить чарку"), true)
	else
		SetPrompt(T("Нажмите, чтобы наложить чарку на показанный предмет"), true)
	end
end

local function AdvanceItemEnchant(message)
	if message then
		P(message)
	end
	while itemEnchantState.on do
		itemEnchantState.index = itemEnchantState.index + 1
		local enchant = CurrentItemEnchant()
		if not enchant then
			FinishItemEnchants(true)
			return
		end
		if not FindInventoryBagItem(enchant.id) then
			-- The item can disappear while another enchant is being cast.
		elseif not InventoryItemID(enchant.slot) then
			P(string.format(T("Не надет предмет для слота %s — чарка %d пропущена"), T(enchant.name), enchant.id))
		else
			itemEnchantState.itemCount = CountInventoryBagItem(enchant.id)
			itemEnchantState.startedAt = GetTime()
			itemEnchantState.tick = 0
			ShowItemEnchantUI()
			P(string.format(T("Чарка %d готова: нажмите кнопку с предметом %s"), enchant.id, T(enchant.name)))
			return
		end
	end
end

local function StartItemEnchants(onDone)
	local queue = {}
	for i = 1, #C.ITEM_ENCHANTS do
		local enchant = C.ITEM_ENCHANTS[i]
		if FindInventoryBagItem(enchant.id) then
			queue[#queue + 1] = enchant
		end
	end
	if #queue < 1 then
		if type(onDone) == "function" then
			onDone(true)
		end
		return
	end

	itemEnchantState.on = true
	itemEnchantState.onDone = onDone
	itemEnchantState.queue = queue
	itemEnchantState.index = 0
	itemEnchantWatch:UnregisterAllEvents()
	itemEnchantWatch:RegisterEvent("BAG_UPDATE")
	itemEnchantWatch:RegisterEvent("UNIT_INVENTORY_CHANGED")
	itemEnchantWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	itemEnchantWatch:Show()
	AdvanceItemEnchant()
end

itemEnchantWatch:SetScript("OnEvent", function(_, event, unit)
	if not itemEnchantState.on then
		return
	end
	if event == "UNIT_INVENTORY_CHANGED" and unit and unit ~= "player" then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" or event == "UNIT_INVENTORY_CHANGED" then
		ShowItemEnchantUI()
	end
end)

itemEnchantWatch:SetScript("OnUpdate", function(_, elapsed)
	if not itemEnchantState.on then
		itemEnchantWatch:Hide()
		return
	end
	itemEnchantState.tick = (itemEnchantState.tick or 0) + elapsed
	if itemEnchantState.tick < 0.25 then
		return
	end
	itemEnchantState.tick = 0
	local enchant = CurrentItemEnchant()
	if not enchant then
		FinishItemEnchants(true)
		return
	end
	local count = CountInventoryBagItem(enchant.id)
	if count < (itemEnchantState.itemCount or count) or count < 1 then
		AdvanceItemEnchant(T("Чарка наложена") .. ": " .. T(enchant.name))
		return
	end
	if GetTime() - (itemEnchantState.startedAt or 0) > 60 then
		AdvanceItemEnchant(T("Чарка не была использована") .. ": " .. T(enchant.name))
	end
end)

local ProfessionSocketFlow = {
	watch = CreateFrame("Frame"),
	state = {
		on = false,
		queue = {},
		index = 0,
		phase = nil,
		startedAt = 0,
		castSeen = false,
		attempt = 0,
		lastGameError = nil,
		lastGameErrorAt = 0,
		lastSpellEvent = nil,
		recipeIndex = nil,
		recipeLink = nil,
		professionOpen = false,
		clickPhase = nil,
		clickIndex = nil,
		recipeCallOK = nil,
		recipeCallError = nil,
	},
}
ProfessionSocketFlow.watch:Hide()

local function DebugBool(value)
	if value == nil then
		return "неизвестно"
	end
	return value and "да" or "нет"
end

local function DebugValue(value)
	if value == nil or value == "" then
		return "nil"
	end
	return tostring(value)
end

local function SpellbookKnowsSpell(spellID, spellName)
	if type(IsSpellKnown) == "function" then
		local ok, known = pcall(IsSpellKnown, spellID)
		if ok then
			return known and true or false, "IsSpellKnown"
		end
	end
	if type(GetNumSpellTabs) ~= "function" or type(GetSpellName) ~= "function" then
		return nil, "API недоступно"
	end
	local bookType = BOOKTYPE_SPELL or "spell"
	local lastSlot = 0
	local tabs = GetNumSpellTabs() or 0
	for tab = 1, tabs do
		local _, _, offset, numSlots = GetSpellTabInfo(tab)
		lastSlot = math.max(lastSlot, (tonumber(offset) or 0) + (tonumber(numSlots) or 0))
	end
	for slot = 1, lastSlot do
		local name = GetSpellName(slot, bookType)
		if name and spellName and name == spellName then
			return true, "книга заклинаний"
		end
		if type(GetSpellLink) == "function" then
			local link = GetSpellLink(slot, bookType)
			local linkedID = type(link) == "string" and tonumber(link:match("spell:(%d+)"))
			if linkedID == spellID then
				return true, "книга заклинаний"
			end
		end
	end
	return false, "книга заклинаний"
end

function ProfessionSocketFlow:PrintProfessions()
	if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
		P("[ковка] GetProfessions недоступно — это нормально для данного клиента; проверяю профессию через 51300 и TradeSkill API")
		return
	end
	local p1, p2, archaeology, fishing, cooking, firstAid = GetProfessions()
	local indexes = { p1, p2, archaeology, fishing, cooking, firstAid }
	local found = false
	for i = 1, 6 do
		local index = indexes[i]
		if index then
			local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
			P(string.format("[ковка] Профессия: %s, навык=%s/%s, skillLine=%s",
				DebugValue(name), DebugValue(rank), DebugValue(maxRank), DebugValue(skillLine)))
			found = true
		end
	end
	if not found then
		P("[ковка] Профессии: клиент не вернул ни одной профессии")
	end
end

function ProfessionSocketFlow:FindCurrentRecipe()
	local current = self:Current()
	if not current then
		return nil, "нет текущего рецепта"
	end
	if type(GetNumTradeSkills) ~= "function" or type(GetTradeSkillInfo) ~= "function" then
		return nil, "API профессий GetNumTradeSkills/GetTradeSkillInfo недоступно"
	end
	local tradeName, tradeRank, tradeMax
	if type(GetTradeSkillLine) == "function" then
		tradeName, tradeRank, tradeMax = GetTradeSkillLine()
	end
	local count = tonumber(GetNumTradeSkills()) or 0
	if count < 1 then
		return nil, "список рецептов пуст; сначала нужно открыть Кузнечное дело (51300)", tradeName, tradeRank, tradeMax, count
	end

	-- A collapsed category can hide recipes on 3.3.5 clients.
	if type(ExpandTradeSkillSubClass) == "function" then
		for index = count, 1, -1 do
			local _, skillType, _, isExpanded = GetTradeSkillInfo(index)
			if skillType == "header" and not isExpanded then
				pcall(ExpandTradeSkillSubClass, index)
			end
		end
		count = tonumber(GetNumTradeSkills()) or count
	end

	local wantedName = GetSpellInfo(current.spell)
	for index = 1, count do
		local name, skillType = GetTradeSkillInfo(index)
		if skillType ~= "header" then
			local link
			if type(GetTradeSkillRecipeLink) == "function" then
				link = GetTradeSkillRecipeLink(index)
			end
			local linkedID
			if type(link) == "string" then
				linkedID = tonumber(link:match("enchant:(%d+)")) or tonumber(link:match("spell:(%d+)"))
			end
			if linkedID == current.spell or (wantedName and name == wantedName) then
				return index, nil, tradeName, tradeRank, tradeMax, count, name, link, linkedID
			end
		end
	end
	return nil, string.format("рецепт %d (%s) не найден среди %d строк профессии",
		current.spell, DebugValue(wantedName), count), tradeName, tradeRank, tradeMax, count
end

function ProfessionSocketFlow:PrepareCurrentRecipe(stage, quiet)
	local state = self.state
	local index, reason, tradeName, tradeRank, tradeMax, count, recipeName, recipeLink, linkedID = self:FindCurrentRecipe()
	state.tradeName = tradeName
	state.tradeRank = tradeRank
	state.tradeMax = tradeMax
	state.tradeCount = count
	if not index then
		state.recipeIndex = nil
		state.recipeLink = nil
		state.recipeFindError = reason
		if not quiet then
			P("[ковка] Рецепт пока недоступен: " .. DebugValue(reason))
		end
		return false
	end
	state.recipeIndex = index
	state.recipeLink = recipeLink
	state.recipeFindError = nil
	state.professionOpen = true
	state.phase = "ready"
	if not quiet then
		P(string.format("[ковка] Рецепт найден: index=%d name=%s linkID=%s link=%s; профессия=%s %s/%s",
			index, DebugValue(recipeName), DebugValue(linkedID), DebugValue(recipeLink),
			DebugValue(tradeName), DebugValue(tradeRank), DebugValue(tradeMax)))
		if stage then
			P("[ковка] Этап: " .. stage)
		end
	end
	return true
end

function ProfessionSocketFlow:PrintDiagnostics(stage)
	local current = self:Current()
	if not current then
		P("[ковка] Диагностика: нет текущего задания")
		return
	end
	local spellName, spellRank, spellIcon = GetSpellInfo(current.spell)
	local known, knownSource = SpellbookKnowsSpell(current.spell, spellName)
	local usable, noMana
	if type(IsUsableSpell) == "function" and spellName then
		usable, noMana = IsUsableSpell(spellName)
		usable = usable and true or false
		noMana = noMana and true or false
	end
	local cooldownStart, cooldownDuration, cooldownEnabled
	if type(GetSpellCooldown) == "function" and spellName then
		cooldownStart, cooldownDuration, cooldownEnabled = GetSpellCooldown(spellName)
	end
	local professionName, professionRank = GetSpellInfo(C.BLACKSMITHING_SPELL_ID)
	local professionKnown, professionKnownSource = SpellbookKnowsSpell(C.BLACKSMITHING_SPELL_ID, professionName)
	local professionUsable, professionNoMana
	if type(IsUsableSpell) == "function" and professionName then
		professionUsable, professionNoMana = IsUsableSpell(professionName)
		professionUsable = professionUsable and true or false
		professionNoMana = professionNoMana and true or false
	end
	local itemID = InventoryItemID(current.slot)
	local itemLink = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", current.slot)
	local targeting
	if type(SpellIsTargeting) == "function" then
		targeting = SpellIsTargeting() and true or false
	end
	local cursorType, cursorID, cursorExtra
	if type(GetCursorInfo) == "function" then
		cursorType, cursorID, cursorExtra = GetCursorInfo()
	end
	local castName, _, _, _, castStart, castEnd, isTradeSkill
	if type(UnitCastingInfo) == "function" then
		castName, _, _, _, castStart, castEnd, isTradeSkill = UnitCastingInfo("player")
	end

	P(string.format("[ковка] ===== %s; попытка=%d; этап=%s =====",
		DebugValue(stage), tonumber(self.state.attempt) or 0, DebugValue(self.state.phase)))
	P(string.format("[ковка] Открытие профессии: id=%d name=%s rank=%s известно=%s (%s) usable=%s noMana=%s",
		C.BLACKSMITHING_SPELL_ID, DebugValue(professionName), DebugValue(professionRank),
		DebugBool(professionKnown), DebugValue(professionKnownSource), DebugBool(professionUsable), DebugBool(professionNoMana)))
	P(string.format("[ковка] Рецепт: id=%d name=%s rank=%s icon=%s обычнаяКнига=%s (%s) usableКакSpell=%s",
		current.spell, DebugValue(spellName), DebugValue(spellRank), DebugValue(spellIcon),
		DebugBool(known), DebugValue(knownSource), DebugBool(usable)))
	P(string.format("[ковка] TradeSkill: open=%s line=%s skill=%s/%s rows=%s recipeIndex=%s recipeLink=%s findError=%s callOK=%s callError=%s",
		DebugBool(self.state.professionOpen), DebugValue(self.state.tradeName), DebugValue(self.state.tradeRank),
		DebugValue(self.state.tradeMax), DebugValue(self.state.tradeCount), DebugValue(self.state.recipeIndex),
		DebugValue(self.state.recipeLink), DebugValue(self.state.recipeFindError), DebugBool(self.state.recipeCallOK),
		DebugValue(self.state.recipeCallError)))
	P(string.format("[ковка] Состояние: cooldownStart=%s duration=%s enabled=%s combat=%s",
		DebugValue(cooldownStart), DebugValue(cooldownDuration), DebugValue(cooldownEnabled), DebugBool(PlayerInCombat())))
	P(string.format("[ковка] Цель: slot=%d itemID=%s item=%s", current.slot, DebugValue(itemID), DebugValue(itemLink)))
	local blockers = {}
	if not spellName then
		blockers[#blockers + 1] = "клиент не знает spellID " .. current.spell .. " (GetSpellInfo вернул nil)"
	end
	if self.state.phase == "profession" or self.state.phase == "waitingProfession" then
		if not professionName then
			blockers[#blockers + 1] = "клиент не знает навык Кузнечного дела 51300"
		end
		if professionKnown == false then
			blockers[#blockers + 1] = "навык Кузнечного дела 51300 не изучен"
		end
		if professionUsable == false then
			blockers[#blockers + 1] = "Кузнечное дело 51300 сейчас нельзя открыть"
		end
		if professionNoMana == true then
			blockers[#blockers + 1] = "для открытия Кузнечного дела не хватает ресурса"
		end
	elseif not self.state.recipeIndex then
		blockers[#blockers + 1] = "не найден индекс рецепта в открытом окне Кузнечного дела"
	end
	if PlayerInCombat() then
		blockers[#blockers + 1] = "персонаж находится в бою"
	end
	if not itemID then
		blockers[#blockers + 1] = "в целевом слоте нет надетого предмета"
	end
	for i = 1, #(current.reagents or {}) do
		local reagent = current.reagents[i]
		local have = CountInventoryBagItem(reagent.id)
		P(string.format("[ковка] Реагент: id=%d name=%s есть=%d нужно=%d результат=%s",
			reagent.id, ItemNameByID(reagent.id), have, reagent.count, have >= reagent.count and "OK" or "НЕ ХВАТАЕТ"))
		if have < reagent.count then
			blockers[#blockers + 1] = string.format("не хватает реагента %d: есть %d, нужно %d", reagent.id, have, reagent.count)
		end
	end
	P(string.format("[ковка] Курсор/каст: SpellIsTargeting=%s cursor=%s/%s/%s cast=%s start=%s end=%s tradeSkill=%s",
		DebugBool(targeting), DebugValue(cursorType), DebugValue(cursorID), DebugValue(cursorExtra),
		DebugValue(castName), DebugValue(castStart), DebugValue(castEnd), DebugBool(isTradeSkill)))
	if #blockers > 0 then
		for i = 1, #blockers do
			P("[ковка] ПРОБЛЕМА: " .. blockers[i])
		end
	else
		P("[ковка] Предварительная проверка: явных проблем нет; точную причину ждём от клиента после нажатия")
	end
	if self.state.lastGameError then
		P(string.format("[ковка] Последняя ошибка клиента: %s", self.state.lastGameError))
	end
end

function ProfessionSocketFlow:PrintFailure(reason)
	local state = self.state
	P("[ковка] НЕУДАЧА: " .. DebugValue(reason))
	if state.lastGameError and GetTime() - (state.lastGameErrorAt or 0) < 10 then
		P("[ковка] Причина от клиента: " .. state.lastGameError)
	else
		P("[ковка] Клиент не прислал UI_ERROR_MESSAGE или CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
	end
	P("[ковка] Последнее событие каста: " .. DebugValue(state.lastSpellEvent))
	self:PrintDiagnostics("состояние после ошибки")
end

function ProfessionSocketFlow:Current()
	return self.state.queue[self.state.index]
end

function ProfessionSocketFlow:CloseWindow()
	if type(CloseTradeSkill) == "function" then
		pcall(CloseTradeSkill)
	end
	local frame = _G.TradeSkillFrame
	if not frame then
		return
	end
	if type(HideUIPanel) == "function" then
		pcall(HideUIPanel, frame)
	end
	if frame.Hide then
		frame:Hide()
	end
end

function ProfessionSocketFlow:Stop()
	self:CloseWindow()
	local state = self.state
	state.on = false
	state.onDone = nil
	state.queue = {}
	state.index = 0
	state.phase = nil
	state.startedAt = 0
	state.castSeen = false
	state.attempt = 0
	state.lastGameError = nil
	state.lastGameErrorAt = 0
	state.lastSpellEvent = nil
	state.recipeIndex = nil
	state.recipeLink = nil
	state.recipeFindError = nil
	state.professionOpen = false
	state.clickPhase = nil
	state.clickIndex = nil
	state.recipeCallOK = nil
	state.recipeCallError = nil
	state.tick = 0
	self.watch:Hide()
	self.watch:UnregisterAllEvents()
	HideUseItemUI()
end

function ProfessionSocketFlow:Finish(ok)
	self:CloseWindow()
	local state = self.state
	local onDone = state.onDone
	state.onDone = nil
	state.on = false
	state.queue = {}
	state.index = 0
	state.phase = nil
	state.castSeen = false
	state.lastGameError = nil
	state.lastGameErrorAt = 0
	state.lastSpellEvent = nil
	state.recipeIndex = nil
	state.recipeLink = nil
	state.recipeFindError = nil
	state.professionOpen = false
	state.clickPhase = nil
	state.clickIndex = nil
	state.recipeCallOK = nil
	state.recipeCallError = nil
	self.watch:Hide()
	self.watch:UnregisterAllEvents()
	HideUseItemUI()
	SetPrompt("")
	if type(onDone) == "function" then
		onDone(ok)
	end
end

function ProfessionSocketFlow:ShowUI()
	local state = self.state
	local current = self:Current()
	if not panel or not panel.useRow or not state.on or not current then
		return
	end
	local spellName, _, spellIcon = GetSpellInfo(current.spell)
	local professionName, _, professionIcon = GetSpellInfo(C.BLACKSMITHING_SPELL_ID)
	panel.useItemID = nil
	if panel.useIconTex then
		local icon = (state.phase == "profession" or state.phase == "waitingProfession") and professionIcon or spellIcon
		panel.useIconTex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	end
	if panel.useSecondIconTex then
		panel.useSecondIconTex:Hide()
	end
	if panel.useTargetIconTex then
		local targetIcon = type(GetInventoryItemTexture) == "function" and GetInventoryItemTexture("player", current.slot)
		panel.useTargetIconTex:SetTexture(targetIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
		panel.useTargetIconTex:Show()
	end
	if panel.learnBtn and panel.learnBtn.label then
		local label = panel.learnBtn.label
		label:ClearAllPoints()
		label:SetPoint("LEFT", panel.useIconTex, "RIGHT", 8, 0)
		label:SetPoint("RIGHT", panel.useTargetIconTex, "LEFT", -8, 0)
		label:SetJustifyH("CENTER")
		if state.phase == "profession" then
			label:SetText("Открыть Кузнечное дело")
		elseif state.phase == "waitingProfession" then
			label:SetText("Открываю Кузнечное дело...")
		elseif state.phase == "ready" then
			label:SetText("Начать ковку: " .. T(current.name))
		elseif state.phase == "target" then
			label:SetText(T("Выбрать предмет") .. ": " .. T(current.name))
		elseif state.phase == "casting" then
			label:SetText(T("Создаю гнездо") .. ": " .. T(current.name))
		else
			label:SetText(T("Добавить гнездо") .. ": " .. T(current.name))
		end
	end
	local btn = panel.learnBtn
	if btn and btn.SetAttribute and not PlayerInCombat() then
		btn:SetAttribute("type", nil)
		btn:SetAttribute("item", nil)
		btn:SetAttribute("macrotext", nil)
		btn:SetAttribute("spell", nil)
		if state.phase == "profession" and professionName then
			btn:SetAttribute("spell", professionName)
			btn:SetAttribute("type", "spell")
		elseif state.phase == "target" then
			btn:SetAttribute("macrotext", "/use " .. current.slot)
			btn:SetAttribute("type", "macro")
		end
	end
	panel.chromeTall = false
	panel.useRow:Show()
	if stepState.layout then
		stepState.layout()
	end
	SetStatus(T("Профессиональное гнездо") .. ": " .. T(current.name))
	if PlayerInCombat() then
		SetPrompt(T("Выйдите из боя и подойдите к наковальне"), true)
	elseif state.phase == "profession" then
		SetPrompt("Сначала откройте навык Кузнечного дела (51300)", true)
	elseif state.phase == "waitingProfession" then
		SetPrompt("Жду открытия списка рецептов Кузнечного дела", true)
	elseif state.phase == "ready" then
		SetPrompt("Нажмите, чтобы запустить рецепт " .. current.spell, true)
	elseif state.phase == "target" then
		SetPrompt(T("Нажмите ещё раз, чтобы выбрать показанный предмет"), true)
	elseif state.phase == "casting" then
		SetPrompt(T("Дождитесь завершения каста"), true)
	else
		SetPrompt(T("Подойдите к наковальне и нажмите кнопку"), true)
	end
end

function ProfessionSocketFlow:Advance(message)
	local state = self.state
	if message then
		P(message)
	end
	while state.on do
		state.index = state.index + 1
		local current = self:Current()
		if not current then
			self:Finish(true)
			return
		end
		if not InventoryItemID(current.slot) then
			P(string.format(T("Не надет предмет %s — профессиональное гнездо пропущено"), T(current.name)))
		else
			state.phase = "profession"
			state.startedAt = GetTime()
			state.castSeen = false
			state.lastGameError = nil
			state.lastGameErrorAt = 0
			state.lastSpellEvent = nil
			state.recipeIndex = nil
			state.recipeLink = nil
			state.recipeFindError = nil
			state.clickPhase = nil
			state.clickIndex = nil
			state.recipeCallOK = nil
			state.recipeCallError = nil
			state.tick = 0
			if self:PrepareCurrentRecipe("профессия уже открыта", true) then
				state.professionOpen = true
			else
				state.phase = "profession"
				state.professionOpen = false
			end
			self:ShowUI()
			self:PrintDiagnostics("подготовка " .. T(current.name))
			return
		end
	end
end

function ProfessionSocketFlow:Start(onDone)
	local state = self.state
	state.on = true
	state.onDone = onDone
	state.queue = C.PROFESSION_SOCKETS
	state.index = 0
	state.phase = nil
	state.startedAt = GetTime()
	state.castSeen = false
	state.attempt = 0
	state.lastGameError = nil
	state.lastGameErrorAt = 0
	state.lastSpellEvent = nil
	state.recipeIndex = nil
	state.recipeLink = nil
	state.recipeFindError = nil
	state.professionOpen = false
	state.clickPhase = nil
	state.clickIndex = nil
	state.recipeCallOK = nil
	state.recipeCallError = nil
	state.tick = 0
	self.watch:UnregisterAllEvents()
	pcall(self.watch.RegisterEvent, self.watch, "UNIT_SPELLCAST_SUCCEEDED")
	pcall(self.watch.RegisterEvent, self.watch, "UNIT_SPELLCAST_START")
	pcall(self.watch.RegisterEvent, self.watch, "UNIT_SPELLCAST_FAILED")
	pcall(self.watch.RegisterEvent, self.watch, "UNIT_SPELLCAST_INTERRUPTED")
	pcall(self.watch.RegisterEvent, self.watch, "UNIT_SPELLCAST_SENT")
	pcall(self.watch.RegisterEvent, self.watch, "UNIT_SPELLCAST_STOP")
	pcall(self.watch.RegisterEvent, self.watch, "UI_ERROR_MESSAGE")
	pcall(self.watch.RegisterEvent, self.watch, "CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
	pcall(self.watch.RegisterEvent, self.watch, "TRADE_SKILL_SHOW")
	pcall(self.watch.RegisterEvent, self.watch, "TRADE_SKILL_UPDATE")
	pcall(self.watch.RegisterEvent, self.watch, "TRADE_SKILL_CLOSE")
	pcall(self.watch.RegisterEvent, self.watch, "ADDON_ACTION_BLOCKED")
	pcall(self.watch.RegisterEvent, self.watch, "ADDON_ACTION_FORBIDDEN")
	self.watch:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.watch:Show()
	self:PrintProfessions()
	self:Advance()
end

function ProfessionSocketFlow:BeforeClick()
	local state = self.state
	if not state.on then
		return
	end
	state.clickPhase = state.phase
	state.clickIndex = state.index
	state.attempt = (state.attempt or 0) + 1
	state.lastGameError = nil
	state.lastGameErrorAt = 0
	state.lastSpellEvent = nil
	self:PrintDiagnostics("перед нажатием")
	local btn = panel and panel.learnBtn
	if btn and btn.GetAttribute then
		P(string.format("[ковка] Secure-кнопка: type=%s spell=%s macro=%s",
			DebugValue(btn:GetAttribute("type")), DebugValue(btn:GetAttribute("spell")),
			DebugValue(btn:GetAttribute("macrotext"))))
	end
	if state.clickPhase == "ready" then
		state.recipeCallOK = false
		state.recipeCallError = nil
		if not self:PrepareCurrentRecipe("проверка перед запуском", true) then
			state.recipeCallError = state.recipeFindError or "рецепт не найден"
			P("[ковка] DoTradeSkill НЕ вызван: " .. state.recipeCallError)
		elseif type(DoTradeSkill) ~= "function" then
			state.recipeCallError = "API DoTradeSkill недоступно"
			P("[ковка] DoTradeSkill НЕ вызван: API недоступно")
		else
			P(string.format("[ковка] Вызываю DoTradeSkill(index=%d, count=1) для spellID=%d",
				state.recipeIndex, (self:Current() and self:Current().spell) or 0))
			local ok, err = pcall(DoTradeSkill, state.recipeIndex, 1)
			state.recipeCallOK = ok
			state.recipeCallError = not ok and DebugValue(err) or nil
			P(string.format("[ковка] Результат вызова DoTradeSkill: pcall=%s error=%s",
				DebugBool(ok), DebugValue(err)))
		end
	end
end

function ProfessionSocketFlow:HandleClick()
	local state = self.state
	if not state.on or PlayerInCombat() then
		return
	end
	local clickedPhase = state.clickPhase or state.phase
	local clickedIndex = state.clickIndex
	state.clickPhase = nil
	state.clickIndex = nil
	if clickedIndex and clickedIndex ~= state.index then
		return
	end
	if clickedPhase == "profession" then
		state.phase = "waitingProfession"
		state.startedAt = GetTime()
		if self:PrepareCurrentRecipe("после открытия Кузнечного дела", true) then
			P("[ковка] Кузнечное дело открыто, рецепт найден")
		end
		self:ShowUI()
		self:PrintDiagnostics("после нажатия 51300")
	elseif clickedPhase == "ready" then
		if not state.recipeCallOK then
			state.phase = "ready"
			self:PrintFailure("DoTradeSkill не был выполнен: " .. DebugValue(state.recipeCallError))
			self:ShowUI()
			return
		end
		state.phase = "target"
		state.startedAt = GetTime()
		self:ShowUI()
		self:PrintDiagnostics("после запуска рецепта через DoTradeSkill")
	elseif clickedPhase == "target" then
		state.phase = "casting"
		state.startedAt = GetTime()
		state.castSeen = false
		self:ShowUI()
		self:PrintDiagnostics("после выбора предмета")
	end
end

function ProfessionSocketFlow:EventMatches(...)
	local current = self:Current()
	if not current then
		return false
	end
	local spellName = GetSpellInfo(current.spell)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if tonumber(value) == current.spell or (spellName and value == spellName) then
			return true
		end
	end
	return false
end

ProfessionSocketFlow.watch:SetScript("OnEvent", function(_, event, unit, ...)
	local state = ProfessionSocketFlow.state
	if not state.on then
		return
	end
	if event == "UI_ERROR_MESSAGE" or event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" then
		local first, second = unit, select(1, ...)
		local message = type(second) == "string" and second or (type(first) == "string" and first or nil)
		state.lastGameError = message or (DebugValue(first) .. " / " .. DebugValue(second))
		state.lastGameErrorAt = GetTime()
		P(string.format("[ковка] Ошибка клиента (%s): %s", event, state.lastGameError))
		return
	end
	if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		state.lastGameError = event .. ": addon=" .. DebugValue(unit) .. " function=" .. DebugValue(select(1, ...))
		state.lastGameErrorAt = GetTime()
		P("[ковка] Блокировка защищённого действия: " .. state.lastGameError)
		return
	end
	if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
		state.professionOpen = true
		local shouldPrepare = state.phase == "profession" or state.phase == "waitingProfession"
		local prepared = shouldPrepare and ProfessionSocketFlow:PrepareCurrentRecipe(event, event == "TRADE_SKILL_UPDATE")
		if event == "TRADE_SKILL_SHOW" then
			P("[ковка] Событие TRADE_SKILL_SHOW: окно профессии открылось")
		end
		if prepared then
			ProfessionSocketFlow:ShowUI()
			ProfessionSocketFlow:PrintDiagnostics("рецепт готов после " .. event)
		end
		return
	elseif event == "TRADE_SKILL_CLOSE" then
		state.professionOpen = false
		P("[ковка] Событие TRADE_SKILL_CLOSE: окно профессии закрылось")
		if state.phase == "profession" or state.phase == "waitingProfession" or state.phase == "ready" then
			state.phase = "profession"
			state.recipeIndex = nil
			state.recipeLink = nil
			ProfessionSocketFlow:ShowUI()
		end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		ProfessionSocketFlow:ShowUI()
		return
	end
	if unit and unit ~= "player" then
		return
	end
	local matched = ProfessionSocketFlow:EventMatches(...)
	local eventArgs = {}
	for i = 1, select("#", ...) do
		eventArgs[#eventArgs + 1] = DebugValue(select(i, ...))
	end
	state.lastSpellEvent = event .. " unit=" .. DebugValue(unit) .. " args=" .. table.concat(eventArgs, " | ")
	P("[ковка] Событие: " .. state.lastSpellEvent .. " match=" .. DebugBool(matched))
	if not matched then
		return
	end
	local current = ProfessionSocketFlow:Current()
	if event == "UNIT_SPELLCAST_SENT" then
		return
	elseif event == "UNIT_SPELLCAST_START" then
		state.phase = "casting"
		state.castSeen = true
		state.startedAt = GetTime()
		ProfessionSocketFlow:ShowUI()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		ProfessionSocketFlow:Advance(T("Гнездо добавлено") .. ": " .. T(current and current.name or ""))
	elseif event == "UNIT_SPELLCAST_STOP" then
		return
	else
		state.phase = "ready"
		state.castSeen = false
		state.startedAt = GetTime()
		ProfessionSocketFlow:PrintFailure("получено событие " .. event)
		ProfessionSocketFlow:ShowUI()
	end
end)

ProfessionSocketFlow.watch:SetScript("OnUpdate", function(_, elapsed)
	local state = ProfessionSocketFlow.state
	if not state.on then
		ProfessionSocketFlow.watch:Hide()
		return
	end
	state.tick = (state.tick or 0) + elapsed
	if state.tick < 0.25 then
		return
	end
	state.tick = 0
	local elapsedSinceClick = GetTime() - (state.startedAt or 0)
	if state.phase == "waitingProfession" then
		if ProfessionSocketFlow:PrepareCurrentRecipe("ожидание списка рецептов", true) then
			P("[ковка] Кузнечное дело открыто, рецепт найден")
			ProfessionSocketFlow:ShowUI()
			ProfessionSocketFlow:PrintDiagnostics("Кузнечное дело готово")
			return
		end
		if elapsedSinceClick > 5 then
			state.phase = "profession"
			ProfessionSocketFlow:PrintFailure("после нажатия 51300 окно Кузнечного дела не открылось или рецепт не найден")
			ProfessionSocketFlow:ShowUI()
		end
		return
	end
	if state.phase == "target" then
		if type(SpellIsTargeting) == "function" and SpellIsTargeting() then
			return
		end
		if elapsedSinceClick > 3 then
			state.phase = "ready"
			ProfessionSocketFlow:PrintFailure("после DoTradeSkill не появился курсор выбора предмета")
			ProfessionSocketFlow:ShowUI()
		end
		return
	end
	if state.phase == "casting" then
		local current = ProfessionSocketFlow:Current()
		local expectedName = current and GetSpellInfo(current.spell)
		local castingName = type(UnitCastingInfo) == "function" and UnitCastingInfo("player")
		if castingName and expectedName and castingName == expectedName then
			state.castSeen = true
			return
		end
		if state.castSeen and elapsedSinceClick > 0.5 then
			ProfessionSocketFlow:Advance(T("Гнездо добавлено") .. ": " .. T(current and current.name or ""))
			return
		end
		if not state.castSeen and elapsedSinceClick > 2 then
			state.phase = "ready"
			ProfessionSocketFlow:PrintFailure("после выбора предмета каст не начался")
			ProfessionSocketFlow:ShowUI()
			return
		end
		if elapsedSinceClick > 12 then
			state.phase = "ready"
			ProfessionSocketFlow:PrintFailure("каст начался, но не завершился за 12 секунд")
			ProfessionSocketFlow:ShowUI()
		end
	end
end)

local SocketFlow = {
	watch = CreateFrame("Frame"),
	state = {
		on = false,
		phase = nil,
		queue = {},
		index = 0,
		gems = {},
		counts = {},
		startedAt = 0,
		success = false,
	},
}
SocketFlow.watch:Hide()

function SocketFlow:Stop(closeSocketing)
	local state = self.state
	local wasOn = state.on
	state.on = false
	state.onDone = nil
	state.phase = nil
	state.queue = {}
	state.index = 0
	state.gems = {}
	state.counts = {}
	state.startedAt = 0
	state.success = false
	state.tick = 0
	self.watch:Hide()
	self.watch:UnregisterAllEvents()
	HideUseItemUI()
	if closeSocketing and wasOn and type(CloseSocketInfo) == "function" then
		pcall(CloseSocketInfo)
	end
end

function SocketFlow:Finish(ok, message)
	local state = self.state
	local onDone = state.onDone
	state.onDone = nil
	state.on = false
	state.phase = nil
	state.queue = {}
	state.index = 0
	state.gems = {}
	state.counts = {}
	self.watch:Hide()
	self.watch:UnregisterAllEvents()
	HideUseItemUI()
	SetPrompt("")
	if type(CloseSocketInfo) == "function" then
		pcall(CloseSocketInfo)
	end
	if message then
		SetStatus(message)
		P(message)
	end
	if type(onDone) == "function" then
		onDone(ok)
	end
end

function SocketFlow:Current()
	return self.state.queue[self.state.index]
end

function SocketFlow:ShowUI()
	local state = self.state
	local target = self:Current()
	if not panel or not panel.useRow or not state.on or not target then
		return
	end
	local first, second = state.gems[1], state.gems[2]
	panel.useItemID = first and first.id or nil
	if panel.useIconTex then
		panel.useIconTex:SetTexture((first and type(GetItemIcon) == "function" and GetItemIcon(first.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
	end
	if panel.useSecondIconTex then
		panel.useSecondIconTex:SetTexture((second and type(GetItemIcon) == "function" and GetItemIcon(second.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
		if second then
			panel.useSecondIconTex:Show()
		else
			panel.useSecondIconTex:Hide()
		end
	end
	if panel.useTargetIconTex then
		local targetIcon = type(GetInventoryItemTexture) == "function" and GetInventoryItemTexture("player", target.slot)
		panel.useTargetIconTex:SetTexture(targetIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
		panel.useTargetIconTex:Show()
	end
	if panel.learnBtn and panel.learnBtn.label then
		local label = panel.learnBtn.label
		label:ClearAllPoints()
		label:SetPoint("LEFT", second and panel.useSecondIconTex or panel.useIconTex, "RIGHT", 6, 0)
		label:SetPoint("RIGHT", panel.useTargetIconTex, "LEFT", -6, 0)
		label:SetJustifyH("CENTER")
		if state.phase == "open" then
			label:SetText(T("Открыть гнёзда") .. ": " .. T(target.name))
		elseif state.phase == "waiting" then
			label:SetText(T("Открываю гнёзда") .. ": " .. T(target.name))
		elseif state.phase == "fill" then
			label:SetText(T("Вставить самоцветы") .. ": " .. T(target.name))
		else
			label:SetText(T("Устанавливаю самоцветы") .. ": " .. T(target.name))
		end
	end
	local btn = panel.learnBtn
	if btn and btn.SetAttribute and not PlayerInCombat() then
		btn:SetAttribute("type", nil)
		btn:SetAttribute("item", nil)
		btn:SetAttribute("macrotext", nil)
		btn:SetAttribute("spell", nil)
	end
	-- The socket instruction can wrap to two lines; keep it inside the backdrop.
	panel.chromeTall = true
	panel.useRow:Show()
	if stepState.layout then
		stepState.layout()
	end
	SetStatus(T("Сокеты") .. ": " .. T(target.name))
	if PlayerInCombat() then
		SetPrompt(T("Выйдите из боя, чтобы вставить самоцветы"), true)
	elseif state.phase == "open" then
		SetPrompt(T("Нажмите, чтобы открыть гнёзда показанного предмета"), true)
	elseif state.phase == "fill" then
		SetPrompt(T("Нажмите ещё раз, чтобы вставить и подтвердить самоцветы"), true)
	else
		SetPrompt(T("Ожидание окна гнёзд"), true)
	end
end

function SocketFlow:SocketTypeText(index)
	if type(GetSocketTypes) ~= "function" then
		return ""
	end
	local values = { GetSocketTypes(index) }
	local text = ""
	for i = 1, #values do
		text = text .. " " .. tostring(values[i] or "")
	end
	return string.lower(text)
end

function SocketFlow:FindSocketIndex(gem, used)
	local count = type(GetNumSockets) == "function" and (GetNumSockets() or 0) or 0
	for index = 1, count do
		if not used[index] then
			local text = self:SocketTypeText(index)
			for i = 1, #(gem.needles or {}) do
				if text:find(gem.needles[i], 1, true) then
					return index
				end
			end
		end
	end
	if gem.fallback and gem.fallback <= count and not used[gem.fallback] then
		return gem.fallback
	end
end

function SocketFlow:PlaceGem(gem, socketIndex)
	local bag, slot = FindInventoryBagItem(gem.id)
	if not bag or not socketIndex or type(PickupContainerItem) ~= "function" or type(ClickSocketButton) ~= "function" then
		return false
	end
	if type(CursorHasItem) == "function" and CursorHasItem() and type(ClearCursor) == "function" then
		ClearCursor()
	end
	local picked = pcall(PickupContainerItem, bag, slot)
	if not picked then
		return false
	end
	local placed = pcall(ClickSocketButton, socketIndex)
	if type(CursorHasItem) == "function" and CursorHasItem() and type(ClearCursor) == "function" then
		ClearCursor()
	end
	return placed
end

function SocketFlow:HandleClick()
	local state = self.state
	local target = self:Current()
	if not state.on or not target or PlayerInCombat() then
		return
	end
	if state.phase == "open" then
		if type(SocketInventoryItem) ~= "function" then
			self:Finish(false, T("Клиент не поддерживает открытие гнёзд предмета"))
			return
		end
		local ok = pcall(SocketInventoryItem, target.slot)
		if not ok then
			self:Advance(T("Не удалось открыть гнёзда") .. ": " .. T(target.name))
			return
		end
		state.phase = "waiting"
		state.startedAt = GetTime()
		self:ShowUI()
		return
	end
	if state.phase ~= "fill" then
		return
	end

	local used, placed = {}, 0
	for i = 1, #state.gems do
		local gem = state.gems[i]
		local socketIndex = self:FindSocketIndex(gem, used)
		if socketIndex and self:PlaceGem(gem, socketIndex) then
			used[socketIndex] = true
			placed = placed + 1
		else
			P(string.format(T("Не удалось поместить самоцвет %d в %s"), gem.id, T(gem.name)))
		end
	end
	if placed < #state.gems or type(AcceptSockets) ~= "function" then
		return
	end
	local ok = pcall(AcceptSockets)
	if not ok then
		P(T("Не удалось подтвердить установку самоцветов"))
		return
	end
	state.phase = "applying"
	state.startedAt = GetTime()
	self:ShowUI()
end

function SocketFlow:Advance(message)
	local state = self.state
	if message then
		P(message)
	end
	if type(CloseSocketInfo) == "function" then
		pcall(CloseSocketInfo)
	end
	while state.on do
		state.index = state.index + 1
		local target = self:Current()
		if not target then
			self:Finish(true)
			return
		end
		state.gems = {}
		for i = 1, #(target.gems or {}) do
			local gem = target.gems[i]
			if FindInventoryBagItem(gem.id) then
				state.gems[#state.gems + 1] = gem
			end
		end
		if not InventoryItemID(target.slot) then
			P(string.format(T("Не надет предмет %s — сокеты пропущены"), T(target.name)))
		elseif #state.gems > 0 then
			state.counts = {}
			for i = 1, #state.gems do
				state.counts[state.gems[i].id] = CountInventoryBagItem(state.gems[i].id)
			end
			state.phase = "open"
			state.startedAt = GetTime()
			state.success = false
			state.tick = 0
			self:ShowUI()
			P(T("Самоцветы готовы") .. ": " .. T(target.name))
			return
		end
	end
end

function SocketFlow:Start(onDone)
	local state = self.state
	local queue = {}
	for i = 1, #C.ITEM_SOCKETS do
		local target = C.ITEM_SOCKETS[i]
		for j = 1, #(target.gems or {}) do
			if FindInventoryBagItem(target.gems[j].id) then
				queue[#queue + 1] = target
				break
			end
		end
	end
	if #queue < 1 then
		if type(onDone) == "function" then
			onDone(true)
		end
		return
	end

	state.on = true
	state.onDone = onDone
	state.phase = nil
	state.queue = queue
	state.index = 0
	state.gems = {}
	state.counts = {}
	state.startedAt = GetTime()
	state.success = false
	state.tick = 0
	self.watch:UnregisterAllEvents()
	pcall(self.watch.RegisterEvent, self.watch, "SOCKET_INFO_UPDATE")
	pcall(self.watch.RegisterEvent, self.watch, "SOCKET_INFO_SUCCESS")
	pcall(self.watch.RegisterEvent, self.watch, "SOCKET_INFO_CLOSE")
	self.watch:RegisterEvent("BAG_UPDATE")
	self.watch:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.watch:Show()
	self:Advance()
end

local function CloseGlyphFrames()
	local talented = _G.Talented
	local host = talented and (talented.base or _G.TalentedFrame) or _G.TalentedFrame
	local frames = {}
	if _G.TalentedGlyphs then
		frames[#frames + 1] = _G.TalentedGlyphs
	end
	if _G.GlyphFrame then
		frames[#frames + 1] = _G.GlyphFrame
	end
	if host then
		frames[#frames + 1] = host
	end
	for i = 1, #frames do
		local frame = frames[i]
		if frame and frame.IsShown and frame:IsShown() then
			if type(HideUIPanel) == "function" then
				pcall(HideUIPanel, frame)
			end
			if frame.Hide then
				frame:Hide()
			end
		end
	end
end

local function StartItemPrep(onDone)
	local glyphItems, glyphCount = {}, 0
	for i = 1, #C.GLYPH_ITEMS do
		local id = C.GLYPH_ITEMS[i]
		if FindInventoryBagItem(id) then
			glyphItems[#glyphItems + 1] = id
			glyphCount = glyphCount + 1
		end
	end
	local mountItems = {}
	if FindInventoryBagItem(C.MOUNT_ITEM_ID) and not IsUseItemLearned(C.MOUNT_ITEM_ID) then
		mountItems[1] = C.MOUNT_ITEM_ID
	end
	SetStatus(T("Подготовка предметов"))
	if panel then
		if panel.nextLine then
			panel.nextLine:SetText("")
		end
		if panel.openLabel then
			panel.openLabel:SetText("")
		end
		if panel.targetName then
			panel.targetName:SetText("")
		end
	end
	SetPrompt("")
	StartUseItems(glyphItems, function()
		if glyphCount > 0 then
			CloseGlyphFrames()
		end
		stepState.prepFloor = #C.GLYPH_ITEMS
		StartUseItems(mountItems, function()
			ProfessionSocketFlow:Start(function()
				stepState.prepFloor = #C.GLYPH_ITEMS + #C.PROFESSION_SOCKETS
				StartItemEnchants(function()
					stepState.prepFloor = #C.GLYPH_ITEMS + #C.PROFESSION_SOCKETS + #C.ITEM_ENCHANTS
					SocketFlow:Start(function()
						SetStatus(T("Подготовка предметов завершена"))
						if type(onDone) == "function" then
							onDone()
						end
					end)
				end)
			end)
		end)
	end)
end

SocketFlow.watch:SetScript("OnEvent", function(_, event)
	local state = SocketFlow.state
	if not state.on then
		return
	end
	if event == "SOCKET_INFO_SUCCESS" then
		state.success = true
	elseif event == "SOCKET_INFO_UPDATE" and state.phase ~= "applying" then
		state.phase = "fill"
		state.startedAt = GetTime()
		SocketFlow:ShowUI()
	elseif event == "PLAYER_REGEN_ENABLED" then
		SocketFlow:ShowUI()
	end
end)

SocketFlow.watch:SetScript("OnUpdate", function(_, elapsed)
	local state = SocketFlow.state
	if not state.on then
		SocketFlow.watch:Hide()
		return
	end
	state.tick = (state.tick or 0) + elapsed
	if state.tick < 0.25 then
		return
	end
	state.tick = 0
	if state.phase == "waiting" and type(GetNumSockets) == "function" and (GetNumSockets() or 0) > 0 then
		state.phase = "fill"
		state.startedAt = GetTime()
		SocketFlow:ShowUI()
		return
	end
	if state.phase == "applying" then
		local consumed = true
		for i = 1, #state.gems do
			local gem = state.gems[i]
			if CountInventoryBagItem(gem.id) >= (state.counts[gem.id] or 0) then
				consumed = false
				break
			end
		end
		if state.success or consumed then
			local target = SocketFlow:Current()
			SocketFlow:Advance(T("Самоцветы вставлены") .. ": " .. T(target and target.name or ""))
			return
		end
	end
	if GetTime() - (state.startedAt or 0) > 60 then
		local target = SocketFlow:Current()
		SocketFlow:Advance(T("Установка самоцветов не завершена") .. ": " .. T(target and target.name or ""))
	end
end)

local function ContinueAfterBoughtItems(items, cont)
	local wear = WearListFromItems(items)
	local use = UseListFromItems(items)
	local function afterWear()
		if #use > 0 then
			StartUseItems(use, cont)
		elseif type(cont) == "function" then
			cont()
		end
	end
	if #wear > 0 then
		StartWearEquip(wear, afterWear)
	else
		afterWear()
	end
end

local function FinishBuyGearThen(cont)
	local rest = RemainingWearList()
	local function afterWear()
		StartItemPrep(cont)
	end
	if #rest > 0 then
		StartWearEquip(rest, afterWear)
	else
		afterWear()
	end
end

bagEquipWatch:SetScript("OnEvent", function(_, event)
	if not bagEquip.on then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
		SetPrompt("")
		return
	end
	if bagEquip.waitingResult then
		if FilledBagInvSlots() > (bagEquip.lastFilled or 0) then
			bagEquip.settleAt = GetTime()
		end
		return
	end
	bagEquip.settleAt = GetTime() + C.BAG_EQUIP_SETTLE
end)

bagEquipWatch:SetScript("OnUpdate", function()
	if not bagEquip.on then
		bagEquipWatch:Hide()
		return
	end
	if GetTime() - (bagEquip.startedAt or 0) > C.EQUIP_TIMEOUT then
		FinishBagEquip(BagEquipFinished())
		return
	end
	if GetTime() < (bagEquip.settleAt or 0) then
		return
	end
	TryEquipBoughtBag()
end)

local function TabIsDone(frame, name)
	if not frame or not name then
		return false
	end
	local child = frame.node and frame.node.children and frame.node.children[name]
	if not child then
		return false
	end
	if child.skipped or child.complete then
		return true
	end
	if type(child.items) == "table" then
		return true
	end
	if type(child.tabs) == "table" and #child.tabs > 0 then
		for i = 1, #child.tabs do
			if not TabIsDone({ node = child, tabs = child.tabs }, child.tabs[i]) then
				return false
			end
		end
		return true
	end
	return false
end

local function SkipPastDone(frame)
	if not frame or type(frame.tabs) ~= "table" then
		return
	end
	if (frame.index or 0) < 1 then
		frame.index = 1
	end
	while frame.index <= #frame.tabs and TabIsDone(frame, frame.tabs[frame.index]) do
		frame.index = frame.index + 1
	end
end

local function MarkTabSkipped(frame, name)
	if not frame or not frame.node or not name then
		return
	end
	frame.node.children = frame.node.children or {}
	local child = frame.node.children[name] or {}
	child.skipped = true
	frame.node.children[name] = child
end

local function FrameDoneCount(frame)
	local n = #(frame.tabs or {})
	local saved = 0
	for i = 1, n do
		if TabIsDone(frame, frame.tabs[i]) then
			saved = saved + 1
		end
	end
	local idx = frame.index or 0
	local passed = 0
	if idx > n then
		passed = n
	elseif idx >= 1 then
		passed = idx - 1
	end
	return math.max(saved, passed), n
end

local function NextOpenName()
	if not scan then
		return ""
	end
	local frame = scan.stack and scan.stack[#scan.stack]
	if not frame or type(frame.tabs) ~= "table" then
		return ""
	end
	local idx = frame.index or 0
	if idx < 1 then
		idx = 1
	end
	while idx <= #frame.tabs and TabIsDone(frame, frame.tabs[idx]) do
		idx = idx + 1
	end
	return frame.tabs[idx] or ""
end

local function LastSavedName(frame)
	if not frame or type(frame.tabs) ~= "table" then
		return ""
	end
	local done = FrameDoneCount(frame)
	if done >= 1 and done <= #frame.tabs then
		return frame.tabs[done] or ""
	end
	return ""
end

local function FormatSavedLine(frame)
	if not frame then
		return ""
	end
	local done, n = FrameDoneCount(frame)
	local name = LastSavedName(frame)
	if name ~= "" then
		return string.format("%d/%d  %s", done, n, name)
	end
	return string.format("%d/%d", done, n)
end

local function FormatUpcomingLine(frame)
	if not frame or type(frame.tabs) ~= "table" then
		return ""
	end
	local n = #frame.tabs
	local idx = frame.index or 0
	if idx < 1 then
		idx = 1
	end
	while idx <= n and TabIsDone(frame, frame.tabs[idx]) do
		idx = idx + 1
	end
	if idx > n then
		return ""
	end
	return string.format("%d/%d  %s", idx, n, frame.tabs[idx] or "")
end

local function CountNodeProgress(node)
	if type(node) ~= "table" then
		return 0, 0
	end
	if node.items then
		return 1, 1
	end
	local names = node.tabs
	if type(names) ~= "table" or #names == 0 then
		return 0, 1
	end
	local done, total = 0, 0
	for i = 1, #names do
		local child = node.children and node.children[names[i]]
		if child and child.items then
			done = done + 1
			total = total + 1
		elseif child and child.skipped then
			done = done + 1
			total = total + 1
		elseif child and type(child.tabs) == "table" and #child.tabs > 0 then
			local d, t = CountNodeProgress(child)
			done = done + d
			total = total + t
		else
			total = total + 1
		end
	end
	return done, total
end

do
local function RealStepCount(npc)
	local steps = npc and npc.steps
	if npc and (npc.kind == "trainer" or npc.kind == "vendor" or npc.kind == "itemshop") then
		return 1
	end
	if type(steps) ~= "table" or #steps == 0 then
		return 1
	end
	local n = 0
	for i = 1, #steps do
		if steps[i].wait ~= "gossip" then
			n = n + 1
		end
	end
	if n < 1 then
		n = #steps
	end
	return n
end

local function RealStepsDone(npc, gossipIndex)
	local steps = npc and npc.steps or {}
	local done = 0
	gossipIndex = gossipIndex or 1
	for i = 1, #steps do
		if i < gossipIndex and steps[i].wait ~= "gossip" then
			done = done + 1
		end
	end
	return done
end

local function ShoppingSpan()
	local first, last, vendors
	for i = 1, #C.SETUP_NPCS do
		local kind = C.SETUP_NPCS[i].kind
		if not first then
			if kind == "itemshop" then
				first, last = i, i
			end
		elseif kind == "itemshop" or kind == "vendor" then
			last = i
			if kind == "vendor" then
				vendors = (vendors or 0) + 1
			end
		else
			break
		end
	end
	return first, last, vendors or 0
end

local function SetupCursor()
	if scan and scan.mode == "setup" then
		return scan.setupIndex or 1
	end
	if scan and scan.mode == "buy" then
		return select(1, ShoppingSpan()) or (#C.SETUP_NPCS + 1)
	end
	if not active then
		local saved = GetQuickStartProgress()
		if not saved then
			return 0
		end
		if saved.stage == "finalize" then
			return #C.SETUP_NPCS + 1
		end
		if saved.stage == "buy" then
			return select(1, ShoppingSpan()) or 1
		end
		if saved.stage == "setup" then
			return tonumber(saved.setupIndex) or 1
		end
	end
	return 0
end

local function BuyGroupCount()
	if scan and scan.mode == "buy" and type(scan.buyQueue) == "table" then
		return #scan.buyQueue
	end
	local first = select(1, ShoppingSpan())
	if stepState.shopGroupTotal and first and SetupCursor() > first then
		return stepState.shopGroupTotal
	end
	if active and stepState.cachedBuyGroups then
		return stepState.cachedBuyGroups
	end
	local queue = BuildQuickBuyQueue()
	stepState.cachedBuyGroups = type(queue) == "table" and #queue or 0
	return stepState.cachedBuyGroups
end

local function BuyProgress(first)
	local groups = BuyGroupCount()
	local total = groups
	if total < 1 then
		total = 1
	end
	local cursor = SetupCursor()
	local done = 0
	if scan and scan.mode == "buy" then
		done = math.max(0, (scan.buyIndex or 1) - 1)
		if scan.buyDone then
			done = groups
		end
	elseif cursor > first then
		done = total
	end
	if done > total then
		done = total
	end
	return done, total
end

local function GlyphIdSet()
	local set = {}
	for i = 1, #C.GLYPH_ITEMS do
		local id = tonumber(C.GLYPH_ITEMS[i]) or C.GLYPH_ITEMS[i]
		if id then
			set[id] = true
		end
	end
	return set
end

local function PrepProgress()
	local gN = #C.GLYPH_ITEMS
	local pN = #C.PROFESSION_SOCKETS
	local eN = #C.ITEM_ENCHANTS
	local sN = #C.ITEM_SOCKETS
	local total = gN + pN + eN + sN
	if total < 1 then
		total = 1
	end
	if SetupCursor() <= #C.SETUP_NPCS then
		return 0, total
	end
	local done = stepState.prepFloor or 0
	if useState.on then
		local glyph = false
		local set = GlyphIdSet()
		for i = 1, #(useState.queue or {}) do
			if set[useState.queue[i]] then
				glyph = true
				break
			end
		end
		if glyph then
			done = math.max(0, (useState.index or 1) - 1)
			if done > gN then
				done = gN
			end
		else
			done = math.max(done, gN)
		end
	elseif ProfessionSocketFlow.state.on then
		local step = math.max(0, (ProfessionSocketFlow.state.index or 1) - 1)
		if step > pN then
			step = pN
		end
		done = math.max(done, gN + step)
	elseif itemEnchantState.on then
		local step = math.max(0, (itemEnchantState.index or 1) - 1)
		if step > eN then
			step = eN
		end
		done = math.max(done, gN + pN + step)
	elseif SocketFlow.state.on then
		local step = math.max(0, (SocketFlow.state.index or 1) - 1)
		if step > sN then
			step = sN
		end
		done = math.max(done, gN + pN + eN + step)
	end
	if done > total then
		done = total
	end
	return done, total
end

local function LabelForNPC(npc, trainerSeen, gossipSeen)
	local steps = RealStepCount(npc)
	if npc.kind == "gossip" and steps >= 2 then
		return T("Изучить профессии"), trainerSeen, gossipSeen
	end
	if npc.kind == "trainer" then
		trainerSeen = trainerSeen + 1
		if trainerSeen == 1 then
			return T("Изучить транспорт"), trainerSeen, gossipSeen
		end
		if trainerSeen == 2 then
			return T("Изучить владение оружием"), trainerSeen, gossipSeen
		end
		return npc.name or T("Изучить"), trainerSeen, gossipSeen
	end
	if npc.kind == "gossip" then
		gossipSeen = gossipSeen + 1
		if gossipSeen == 1 then
			return T("Изучить способности"), trainerSeen, gossipSeen
		end
	end
	return npc.name or "?", trainerSeen, gossipSeen
end

local function CollectQuickStartSteps()
	local stages = {}
	local first = ShoppingSpan()
	local trainerSeen, gossipSeen = 0, 0
	local cursor = SetupCursor()
	local saved = not active and GetQuickStartProgress() or nil
	local i = 1
	while i <= #C.SETUP_NPCS do
		if first and i == first then
			local done, total = BuyProgress(first)
			stages[#stages + 1] = { key = "buy", label = T("Купить предметы"), done = done, total = total }
			i = first + 1
		else
			local npc = C.SETUP_NPCS[i]
			local label
			label, trainerSeen, gossipSeen = LabelForNPC(npc, trainerSeen, gossipSeen)
			local total = RealStepCount(npc)
			local done = 0
			if cursor > i then
				done = total
			elseif cursor == i and npc.kind == "gossip" then
				local gossipIndex = scan and scan.mode == "setup" and scan.setupGossip
					or saved and saved.stage == "setup" and saved.setupGossip
				done = math.min(total, RealStepsDone(npc, gossipIndex or 1))
			end
			stages[#stages + 1] = { key = i, label = label, done = done, total = total }
			i = i + 1
		end
	end
	local prepDone, prepTotal = PrepProgress()
	stages[#stages + 1] = { key = "prep", label = T("Символы, чарки, сокеты"), done = prepDone, total = prepTotal }
	local started = active or cursor > 0
	local marked = false
	for n = 1, #stages do
		local stage = stages[n]
		if stepState.skipped[stage.key] then
			stage.state = "skipped"
		elseif stage.total > 0 and stage.done >= stage.total then
			stage.state = "done"
		elseif started and not marked then
			stage.state = "current"
			marked = true
		else
			stage.state = "pending"
		end
	end
	return stages
end

local function ApplyStepRow(row, stage, barWidth)
	row.text:SetText(stage.label)
	row.count:SetText(stage.state == "skipped" and T("Пропущено")
		or stage.state == "done" and T("Готово")
		or string.format("%d/%d", stage.done or 0, stage.total or 0))
	local frac = 0
	if (stage.total or 0) > 0 then
		frac = (stage.done or 0) / stage.total
	end
	if frac < 0 then
		frac = 0
	elseif frac > 1 then
		frac = 1
	end
	if stage.state == "skipped" then
		row.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		row.count:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		row.bg:SetVertexColor(0.25, 0.20, 0.10, 1)
		row.fill:Hide()
	elseif stage.state == "done" then
		row.text:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
		row.count:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
		row.bg:SetVertexColor(0.10, 0.28, 0.14, 1)
		row.fill:Show()
		row.fill:SetWidth(math.max(1, barWidth - 2))
		row.fill:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 0.55)
	elseif stage.state == "current" then
		row.text:SetTextColor(0.96, 0.96, 0.96)
		row.count:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		row.bg:SetVertexColor(0.16, 0.16, 0.18, 1)
		if frac > 0 then
			row.fill:Show()
			row.fill:SetWidth(math.max(1, (barWidth - 2) * frac))
			if scan and scan.waitClick then
				row.fill:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
			else
				row.fill:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 0.9)
			end
		else
			row.fill:Hide()
		end
	else
		row.text:SetTextColor(0.55, 0.55, 0.58)
		row.count:SetTextColor(0.55, 0.55, 0.58)
		row.bg:SetVertexColor(0.11, 0.11, 0.13, 1)
		row.fill:Hide()
	end
end

local function PlaceChrome(y, height)
	if panel.prompt then
		panel.prompt:ClearAllPoints()
		panel.prompt:SetPoint("TOPLEFT", 8, y)
		panel.prompt:SetPoint("TOPRIGHT", -8, y)
	end
	panel:SetHeight(height)
end

stepState.layout = function()
	if not panel then
		return
	end
	if sessionMode ~= "buy" then
		if panel.savedBox then
			panel.savedBox:Show()
		end
		if panel.bar then
			panel.bar:Show()
		end
		if panel.openLabel then
			panel.openLabel:Show()
		end
		if panel.nextLine then
			panel.nextLine:Show()
		end
		if panel.stepRows then
			for i = 1, #panel.stepRows do
				panel.stepRows[i]:Hide()
			end
		end
		if panel.startBtn then
			panel.startBtn:ClearAllPoints()
			panel.startBtn:SetSize(126, 24)
			panel.startBtn:SetPoint("TOPLEFT", 12, -150)
		end
		if panel.skipBtn then
			panel.skipBtn:ClearAllPoints()
			panel.skipBtn:SetSize(126, 24)
			panel.skipBtn:SetPoint("TOPRIGHT", -12, -150)
		end
		if panel.useRow then
			panel.useRow:ClearAllPoints()
			panel.useRow:SetPoint("TOPLEFT", 12, -176)
			panel.useRow:SetPoint("TOPRIGHT", -12, -176)
		end
		if panel.npcModelBox then
			panel.npcModelBox:ClearAllPoints()
			panel.npcModelBox:SetPoint("TOPLEFT", 8, -198)
			panel.npcModelBox:SetPoint("TOPRIGHT", -8, -198)
			panel.npcModelBox:SetHeight(92)
		end
		local height = 196
		local promptY = -178
		if panel.npcModelBox and panel.npcModelBox:IsShown() then
			height = 298
		elseif panel.useRow and panel.useRow:IsShown() then
			promptY = -218
			height = panel.chromeTall and 258 or 236
		end
		panel:SetWidth(300)
		PlaceChrome(promptY, height)
		return
	end

	if panel.savedBox then
		panel.savedBox:Hide()
	end
	if panel.bar then
		panel.bar:Hide()
	end
	if panel.openLabel then
		panel.openLabel:Hide()
	end
	if panel.nextLine then
		panel.nextLine:Hide()
	end

	local rows = panel.stepRows or {}
	local shown = math.min(panel.stepCount or 0, #rows)
	local top = 46
	for i = 1, #rows do
		local row = rows[i]
		if i <= shown then
			local y = top + (i - 1) * (stepState.rowH + stepState.rowGap)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 12, -y)
			row:SetPoint("TOPRIGHT", -12, -y)
			row:SetHeight(stepState.rowH)
			row:Show()
		else
			row:Hide()
		end
	end
	local stepsH = 0
	if shown > 0 then
		stepsH = shown * stepState.rowH + (shown - 1) * stepState.rowGap
	end
	local buttonsY = -(top + stepsH + 8)
	if panel.startBtn then
		panel.startBtn:ClearAllPoints()
		panel.startBtn:SetPoint("TOPLEFT", 12, buttonsY)
		panel.startBtn:SetPoint("TOPRIGHT", -204, buttonsY)
		panel.startBtn:SetHeight(24)
	end
	if panel.skipBtn then
		panel.skipBtn:ClearAllPoints()
		panel.skipBtn:SetPoint("TOPRIGHT", -108, buttonsY)
		panel.skipBtn:SetSize(92, 24)
	end
	if panel.resetBtn then
		panel.resetBtn:ClearAllPoints()
		panel.resetBtn:SetPoint("TOPRIGHT", -12, buttonsY)
		panel.resetBtn:SetSize(92, 24)
	end
	local cursor = top + stepsH + 8 + 24
	local extra = 8
	if panel.useRow and panel.useRow:IsShown() then
		panel.useRow:ClearAllPoints()
		panel.useRow:SetPoint("TOPLEFT", 12, -(cursor + 6))
		panel.useRow:SetPoint("TOPRIGHT", -12, -(cursor + 6))
		extra = 6 + 36 + 6
		if panel.chromeTall then
			extra = extra + 22
		end
	end
	local promptY = cursor + extra
	local promptText = panel.prompt and panel.prompt:GetText() or ""
	local promptBlock = promptText ~= "" and 22 or 8
	local height = promptY + promptBlock
	if panel.npcModelBox and panel.npcModelBox:IsShown() then
		panel.npcModelBox:ClearAllPoints()
		panel.npcModelBox:SetPoint("TOPLEFT", 8, -(height + 2))
		panel.npcModelBox:SetPoint("TOPRIGHT", -8, -(height + 2))
		panel.npcModelBox:SetHeight(92)
		height = height + 98
	end
	panel:SetWidth(340)
	PlaceChrome(-promptY, height)
end

stepState.refresh = function()
	if sessionMode ~= "buy" or not panel or not panel.stepRows then
		if stepState.layout then
			stepState.layout()
		end
		return
	end
	local stages = CollectQuickStartSteps()
	panel.stepCount = #stages
	local barWidth = 340 - 24
	for i = 1, #panel.stepRows do
		if stages[i] then
			ApplyStepRow(panel.stepRows[i], stages[i], barWidth)
		end
	end
	stepState.layout()
end
end

local function UpdateProgressBar()
	if not panel or not panel.barFill then
		return
	end
	local done, total = 0, 1
	if scan and scan.mode == "setup" then
		total = #C.SETUP_NPCS
		done = math.max(0, (scan.setupIndex or 1) - 1)
	elseif scan and scan.mode == "buy" then
		total = #(scan.buyQueue or {})
		if total < 1 then
			total = 1
		end
		done = math.max(0, (scan.buyIndex or 1) - 1)
		if scan.buyDone then
			done = total
		end
	elseif scan and scan.root then
		local node = scan.root.children and scan.root.children["Item Shop"]
		done, total = CountNodeProgress(node or scan.root)
	end
	if total < 1 then
		total = 1
	end
	local width = (panel.bar:GetWidth() or 250) - 2
	if width < 1 then
		width = 1
	end
	panel.barFill:SetWidth(math.max(1, width * (done / total)))
	if panel.barText then
		panel.barText:SetText(string.format("%d / %d", done, total))
	end
	local waiting = scan and scan.waitClick
	if waiting then
		panel.barFill:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.95)
	else
		panel.barFill:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 0.9)
	end
end

local function ShowProgress()
	if panel and panel.status then
		panel.status:SetTextColor(0.95, 0.95, 0.95)
	end
	if scan and scan.mode == "setup" then
		if scan.waitingEquip or (scan.setupIndex or 1) > #C.SETUP_NPCS then
			if panel and panel.openLabel then
				panel.openLabel:SetText("")
			end
			if panel and panel.nextLine then
				panel.nextLine:SetText("")
			end
			SetPrompt("")
			UpdateProgressBar()
			if sessionMode == "buy" and stepState.refresh and not stepState.refreshing then
				stepState.refreshing = true
				stepState.refresh()
				stepState.refreshing = false
			end
			return
		end
		local npc = CurrentSetupNPC()
		local n = scan.setupIndex or 1
		local total = #C.SETUP_NPCS
		SetStatus(string.format("%d/%d  %s", n, total, npc and npc.name or ""))
		if panel and panel.openLabel then
			panel.openLabel:SetText(scan.opening and T("Открываю") or "")
		end
		if panel and panel.nextLine then
			if scan.opening then
				panel.nextLine:SetText(T("Далее") .. ": " .. scan.opening)
			elseif npc then
				panel.nextLine:SetText(T("Далее") .. ": " .. npc.name)
			else
				panel.nextLine:SetText("")
			end
		end
		if scan.waitClick then
			SetPrompt(T("Кликните NPC") .. ": " .. (npc and npc.name or ""), true)
		else
			SetPrompt("")
		end
		UpdateProgressBar()
		return
	end
	if scan and scan.mode == "buy" then
		if scan.waitingEquip then
			UpdateProgressBar()
			if stepState.refresh and not stepState.refreshing then
				stepState.refreshing = true
				stepState.refresh()
				stepState.refreshing = false
			end
			return
		end
		local qi = scan.buyIndex or 1
		local qn = #(scan.buyQueue or {})
		if qn < 1 then
			qn = 1
		end
		SetStatus(string.format("%d/%d  %s", qi, qn, scan.buyName or QuickBuyItemName()))
		local path = scan.buyPath or {}
		local shown = {}
		for i = 1, #path do
			shown[i] = path[i]
		end
		SetNested(table.concat(shown, "  |  "))
		local step = path[scan.buyStep or 1]
		if panel and panel.openLabel then
			panel.openLabel:SetText(step and T("Открываю") or "")
		end
		if panel and panel.nextLine then
			if step then
				panel.nextLine:SetText(T("Далее") .. ": " .. step)
			elseif not scan.buyDone then
				panel.nextLine:SetText(T("Далее") .. ": " .. T("покупка"))
			else
				panel.nextLine:SetText("")
			end
		end
		local waiting = scan.waitClick
		if waiting then
			SetPrompt(T("Кликните NPC, чтобы продолжить"), true)
		else
			SetPrompt("")
		end
		UpdateProgressBar()
		return
	end
	local root = scan and scan.stack and scan.stack[1]
	SetStatus(root and FormatSavedLine(root) or "")
	local subs = {}
	if scan then
		for i = 2, #(scan.stack or {}) do
			local line = FormatUpcomingLine(scan.stack[i])
			if line ~= "" then
				subs[#subs + 1] = line
			end
		end
	end
	SetNested(table.concat(subs, "\n"))
	local nxt = NextOpenName()
	if panel and panel.openLabel then
		panel.openLabel:SetText(nxt ~= "" and T("Открываю") or "")
	end
	if panel and panel.nextLine then
		if nxt ~= "" then
			panel.nextLine:SetText(T("Далее") .. ": " .. nxt)
		else
			panel.nextLine:SetText("")
		end
	end
	local waiting = scan and scan.waitClick
	if waiting then
		SetPrompt(T("Кликните NPC, чтобы продолжить"), true)
	else
		SetPrompt("")
	end
	UpdateProgressBar()
end

local function UpdateTargetLine()
	if not panel or not panel.targetName then
		return
	end
	if scan and (scan.waitingEquip or (scan.mode == "setup" and (scan.setupIndex or 1) > #C.SETUP_NPCS)) then
		panel.targetName:SetText("")
		return
	end
	if IsWantedUnit("target") then
		panel.targetName:SetText(T("Цель выбрана") .. "  " .. WantedNPCTitle())
		panel.targetName:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
		return
	end
	panel.targetName:SetText(T("Выберите в цель") .. "  " .. WantedNPCTitle())
	if UnitExists("target") then
		panel.targetName:SetTextColor(RED[1], RED[2], RED[3])
	else
		local dim = (SarychUI.OptionsTheme and SarychUI.OptionsTheme.colors and SarychUI.OptionsTheme.colors.textDim) or { 0.65, 0.65, 0.68 }
		panel.targetName:SetTextColor(dim[1], dim[2], dim[3])
	end
	if UpdateNPCModel then
		UpdateNPCModel()
	end
end

local function SavedProgressLabel(saved)
	if not saved then
		return nil
	end
	if saved.stage == "setup" then
		local index = math.max(1, math.min(#C.SETUP_NPCS, tonumber(saved.setupIndex) or 1))
		local npc = C.SETUP_NPCS[index]
		return string.format("%s: %d/%d  %s", T("Сохранено"), index, #C.SETUP_NPCS, npc and npc.name or "")
	elseif saved.stage == "buy" then
		return T("Сохранено") .. ": " .. T("Закупка предметов")
	elseif saved.stage == "finalize" then
		return T("Сохранено") .. ": " .. T("Экипировка, чары и камни")
	end
end

local function UpdateStartButton()
	if not panel or not panel.startBtn then
		return
	end
	local fs = panel.startBtn.label
	if panel.title then
		if sessionMode == "buy" then
			panel.title:SetText((C.PROFILE_NAME or C.TALENT_TEMPLATE_NAME) .. ": " .. T("Быстрый старт"))
		else
			panel.title:SetText(T("Формирование базы данных"))
		end
	end
	if panel.savedCap then
		if sessionMode == "buy" then
			panel.savedCap:SetText(T("Покупка"))
		else
			panel.savedCap:SetText(T("Внесено в базу данных"))
		end
	end
	if panel.skipBtn then
		if sessionMode == "buy" then
			if active then panel.skipBtn:Show() else panel.skipBtn:Hide() end
		else
			panel.skipBtn:Show()
		end
	end
	if panel.resetBtn then
		if sessionMode == "buy" then
			panel.resetBtn:Show()
		else
			panel.resetBtn:Hide()
		end
	end
	if panel.startBtn then
		panel.startBtn:ClearAllPoints()
		if sessionMode == "buy" then
			panel.startBtn:SetPoint("TOPLEFT", 12, -150)
			panel.startBtn:SetPoint("TOPRIGHT", -204, -150)
			panel.startBtn:SetHeight(24)
		else
			panel.startBtn:SetSize(126, 24)
			panel.startBtn:SetPoint("TOPLEFT", 12, -150)
		end
	end
	if active then
		fs:SetText(T("Стоп"))
		fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		ApplyTheme(panel.startBtn, { 0.22, 0.22, 0.25, 1 }, GOLD)
		if panel.startBtn.bg then
			panel.startBtn.bg:SetVertexColor(0.22, 0.22, 0.25, 1)
		end
	else
		fs:SetText(sessionMode == "buy" and GetQuickStartProgress() and T("Продолжить") or T("Старт"))
		fs:SetTextColor(0.95, 0.95, 0.95)
		ApplyTheme(panel.startBtn, { 0.22, 0.22, 0.25, 1 }, GOLD)
		if panel.startBtn.bg then
			panel.startBtn.bg:SetVertexColor(0.22, 0.22, 0.25, 1)
		end
	end
	if panel.resetBtn then
		local resetFs = panel.resetBtn.label
		resetFs:SetTextColor(0.95, 0.95, 0.95)
		ApplyTheme(panel.resetBtn, { 0.22, 0.22, 0.25, 1 }, { 0.55, 0.30, 0.30, 1 })
		if panel.resetBtn.bg then
			panel.resetBtn.bg:SetVertexColor(0.22, 0.22, 0.25, 1)
		end
	end
	if panel.skipBtn then
		local skipFs = panel.skipBtn.label
		if active then
			skipFs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
			ApplyTheme(panel.skipBtn, { 0.22, 0.22, 0.25, 1 }, GOLD)
			if panel.skipBtn.bg then
				panel.skipBtn.bg:SetVertexColor(0.22, 0.22, 0.25, 1)
			end
		else
			skipFs:SetTextColor(0.55, 0.55, 0.55)
			ApplyTheme(panel.skipBtn, { 0.18, 0.18, 0.20, 1 }, { 0.24, 0.24, 0.26, 1 })
			if panel.skipBtn.bg then
				panel.skipBtn.bg:SetVertexColor(0.18, 0.18, 0.20, 1)
			end
		end
	end
	if not active and sessionMode == "buy" then
		local savedLabel = SavedProgressLabel(GetQuickStartProgress())
		if savedLabel then
			SetStatus(savedLabel)
		end
	end
	if sessionMode == "buy" and stepState.refresh and not stepState.refreshing then
		stepState.refreshing = true
		stepState.refresh()
		stepState.refreshing = false
	elseif stepState.layout then
		stepState.layout()
	end
end

local function SaveCatalog()
	local store = CatalogStore()
	if not store or not scan then
		return
	end
	if not scan.root.createdAt then
		StampCatalog(scan.root, false)
	end
	store.quickStartCatalog = scan.root
	store.quickStartCatalogCleared = false
	RefreshCatalogOptions()
end

local function StopScan()
	scan = nil
	watch:Hide()
	SetNested("")
	SetPrompt("")
end

local Advance
local SkipCurrentStep

local function FinishScan()
	SaveCatalog()
	active = false
	StopScan()
	UpdateStartButton()
	SetStatus(T("Скан завершён"))
	SetNested("")
	SetPrompt("")
	if panel and panel.openLabel then
		panel.openLabel:SetText("")
	end
	if panel and panel.nextLine then
		panel.nextLine:SetText("")
	end
	P(T("Скан завершён"))
end

local function FindMerchantSlot(itemID)
	local n = (type(GetMerchantNumItems) == "function" and GetMerchantNumItems()) or 0
	for index = 1, n do
		local link = type(GetMerchantItemLink) == "function" and GetMerchantItemLink(index) or nil
		local id = ItemIDFromLink(link)
		if not id and type(GetMerchantItemID) == "function" then
			local ok, apiID = pcall(GetMerchantItemID, index)
			if ok then
				id = apiID
			end
		end
		if not id then
			scanTip:SetOwner(UIParent, "ANCHOR_NONE")
			scanTip:ClearLines()
			pcall(scanTip.SetMerchantItem, scanTip, index)
			local _, tipLink = scanTip:GetItem()
			id = ItemIDFromLink(tipLink)
			scanTip:Hide()
		end
		if id == itemID then
			return index
		end
	end
end

local NextBuyGroup
local HasWork
local StartBuy
local StartSetup
local NextSetupNPC
local AdvanceSetup

local function FinishBuy(ok)
	if scan then
		scan.buyDone = true
		scan.waitingEquip = false
	end
	active = false
	ClearQuickStartProgress()
	StopScan()
	UpdateStartButton()
	local msg = ok and T("Закупка завершена") or T("Покупка не удалась")
	SetStatus(msg)
	SetNested("")
	SetPrompt("")
	if panel and panel.openLabel then
		panel.openLabel:SetText("")
	end
	if panel and panel.nextLine then
		panel.nextLine:SetText("")
	end
	P(msg)
	UpdateProgressBar()
	if panel then
		panel:Hide()
	end
	sessionMode = "scan"
end

local function CurrentBuyGroup()
	if not scan or type(scan.buyQueue) ~= "table" then
		return nil
	end
	return scan.buyQueue[scan.buyIndex]
end

local function GroupItemLabel(group)
	if not group or type(group.items) ~= "table" then
		return ""
	end
	local parts = {}
	for i = 1, #group.items do
		local it = group.items[i]
		parts[#parts + 1] = (it.count or 1) .. "x " .. ItemNameByID(it.id)
	end
	return table.concat(parts, ", ")
end

local function ApplyBuyGroup(group)
	if not scan or not group then
		return
	end
	local first = group.items and group.items[1]
	scan.buyID = first and first.id or C.QUICK_BUY_ITEM_ID
	scan.buyCount = first and first.count or C.QUICK_BUY_COUNT
	scan.buyName = GroupItemLabel(group)
	scan.buyPath = group.path or C.QUICK_BUY_FALLBACK_PATH
	scan.buyStep = 1
	scan.buyEquip = group.equip and true or false
	scan.waitingEquip = false
	scan.opening = nil
	scan.pendingCapture = false
	scan.buySpent = false
end

local function PrefetchBuyNames(queue)
	if type(GetItemInfo) ~= "function" or type(queue) ~= "table" then
		return
	end
	for i = 1, #queue do
		local items = queue[i] and queue[i].items
		if type(items) == "table" then
			for j = 1, #items do
				pcall(GetItemInfo, items[j].id)
			end
		end
	end
end

NextBuyGroup = function(forceWait)
	if not scan then
		return
	end
	scan.waitingEquip = false
	scan.buyIndex = (scan.buyIndex or 1) + 1
	local group = CurrentBuyGroup()
	if not group then
		local resumeSetupIndex = scan.resumeSetupIndex
		local buyGroupOk = scan.buyGroupOk ~= false
		if resumeSetupIndex then
			CloseConversation()
			StartSetup(resumeSetupIndex, buyGroupOk)
			if scan then
				scan.waitClick = true
			end
			ShowProgress()
			UpdateTargetLine()
			return
		end
		SaveQuickStartProgress("finalize", #C.SETUP_NPCS + 1, nil, scan.buyGroupOk)
		scan.waitingEquip = true
		scan.waitClick = false
		ShowProgress()
		FinishBuyGearThen(function()
			if not scan or scan.mode ~= "buy" then
				return
			end
			FinishBuy(scan.buyGroupOk ~= false)
		end)
		return
	end
	ApplyBuyGroup(group)
	scan.closedAt = nil
	P(T("Далее") .. ": " .. (scan.buyName or ""))
	if not forceWait and Shown(GossipFrame) and (IsStartNPC("npc") or IsStartNPC("target")) then
		scan.waitClick = false
		scan.waitUntil = GetTime() + C.STEP_DELAY
		watch.elapsed = C.STEP_DELAY
		watch:Show()
		ShowProgress()
		return
	end
	scan.waitClick = true
	ShowProgress()
end

local function AdvanceBuy()
	if not scan or not active then
		return
	end
	if scan.pendingCapture or scan.waitingEquip then
		return
	end
	if Shown(MerchantFrame) then
		return
	end
	if not Shown(GossipFrame) then
		if not HasWork() then
			FinishBuy(false)
		end
		return
	end
	if UnitExists("npc") and not IsStartNPC("npc") then
		return
	end
	local path = scan.buyPath or C.QUICK_BUY_FALLBACK_PATH
	local step = scan.buyStep or 1
	if step > #path then
		ShowProgress()
		return
	end
	local name = path[step]
	local opt = FindGossipOption(name, StripText(name) == C.ITEM_SHOP_TEXT)
	if not opt and step == 1 then
		opt = FindGossipOption(C.ITEM_SHOP_TEXT, true)
	end
	if not opt then
		ShowProgress()
		return
	end
	scan.opening = name
	scan.buyStep = step + 1
	scan.waitUntil = GetTime() + 1.2
	ShowProgress()
	SelectOption(opt)
end

local function BuyMerchantCount(slot, want)
	local bought = 0
	if not slot or type(BuyMerchantItem) ~= "function" then
		return 0
	end
	want = tonumber(want) or 1
	if want < 1 then
		return 0
	end
	local maxStack = 1
	if type(GetMerchantItemMaxStack) == "function" then
		maxStack = tonumber(GetMerchantItemMaxStack(slot)) or 1
		if maxStack < 1 then
			maxStack = 1
		end
	end
	local left = want
	while left > 0 and bought < 500 do
		local n = left
		if n > maxStack then
			n = maxStack
		end
		local ok
		if n <= 1 then
			ok = pcall(BuyMerchantItem, slot)
			if ok then
				bought = bought + 1
				left = left - 1
			else
				break
			end
		else
			ok = pcall(BuyMerchantItem, slot, n)
			if ok then
				bought = bought + n
				left = left - n
			else
				ok = pcall(BuyMerchantItem, slot)
				if ok then
					bought = bought + 1
					left = left - 1
				else
					break
				end
			end
		end
	end
	return bought
end

local function OnMerchantBuy()
	if not scan or not active then
		return
	end
	scan.pendingCapture = false
	if scan.waitingEquip or scan.buySpent then
		return
	end
	local group = CurrentBuyGroup()
	if not group or type(group.items) ~= "table" then
		CloseConversation()
		FinishBuy(true)
		return
	end
	if group.spent then
		return
	end
	if group.equip then
		local empty = CountEmptyBagInvSlots()
		if empty < 1 then
			group.spent = true
			scan.buySpent = true
			CloseConversation()
			NextBuyGroup(true)
			return
		end
		for i = 1, #group.items do
			local it = group.items[i]
			if it.id == C.QUICK_BUY_ITEM_ID then
				it.count = math.min(tonumber(it.count) or C.QUICK_BUY_COUNT, empty)
			end
		end
	end
	group.spent = true
	scan.buySpent = true
	local allOk = true
	local bagBought = 0
	for i = 1, #group.items do
		local it = group.items[i]
		local slot = FindMerchantSlot(it.id)
		local bought = BuyMerchantCount(slot, it.count)
		if bought < (it.count or 1) then
			allOk = false
			P(T("Покупка не удалась") .. ": " .. ItemNameByID(it.id) .. " (" .. bought .. "/" .. (it.count or 1) .. ")")
		end
		if it.id == C.QUICK_BUY_ITEM_ID then
			bagBought = bagBought + bought
		end
	end
	if not allOk then
		scan.buyGroupOk = false
	end
	CloseConversation()
	if group.equip then
		scan.waitingEquip = true
		scan.waitClick = false
		StartBagEquipWatch(bagBought, function()
			if not scan or scan.mode ~= "buy" then
				return
			end
			NextBuyGroup()
		end)
		return
	end
	scan.waitingEquip = true
	scan.waitClick = false
	ContinueAfterBoughtItems(group.items, function()
		if not scan or scan.mode ~= "buy" then
			return
		end
		NextBuyGroup(true)
	end)
end

local function CapBagGroup(queue)
	if type(queue) ~= "table" or not queue[1] or not queue[1].equip then
		return
	end
	local empty = CountEmptyBagInvSlots()
	if empty < 1 then
		table.remove(queue, 1)
		return
	end
	local it = queue[1].items and queue[1].items[1]
	if it then
		it.count = math.min(tonumber(it.count) or C.QUICK_BUY_COUNT, empty)
	end
end

local function FindGossipNeedles(needles)
	if type(needles) ~= "table" then
		return nil
	end
	local list = GossipOptionList()
	for i = 1, #list do
		local text = StripText(list[i].text)
		for j = 1, #needles do
			local needle = StripText(needles[j])
			if needle ~= "" and text:find(needle, 1, true) then
				return list[i]
			end
		end
	end
end

local function FindGossipIndex(index)
	index = tonumber(index)
	if not index then
		return nil
	end
	local list = GossipOptionList()
	for i = 1, #list do
		if tonumber(list[i].index) == index then
			return list[i]
		end
	end
end

local function TrainerServiceType(index)
	local name, sub, stype = GetTrainerServiceInfo(index)
	if stype == "available" or stype == "used" or stype == "unavailable" or stype == "header" then
		return stype, name
	end
	if sub == "available" or sub == "used" or sub == "unavailable" or sub == "header" then
		return sub, name
	end
	return stype or sub, name
end

local function TrainAvailableBatch()
	if not Shown(_G.ClassTrainerFrame) then
		return 0
	end
	local automation = SarychUI and SarychUI.modules and SarychUI.modules.automation
	if automation and automation.TrainAllAvailableSkillsNow then
		local ok, trained, lastName = pcall(automation.TrainAllAvailableSkillsNow, automation)
		if ok then
			return tonumber(trained) or 0, lastName
		end
	end

	local trained, lastName = 0, nil
	local n = (type(GetNumTrainerServices) == "function" and GetNumTrainerServices()) or 0
	for i = 1, n do
		local stype, name = TrainerServiceType(i)
		if stype == "available" then
			local ok = pcall(BuyTrainerService, i)
			if ok then
				trained = trained + 1
				lastName = name
			end
		end
	end
	return trained, lastName
end

local function FinishSetup()
	P(T("Подготовка завершена"))
	local buyGroupOk = not scan or scan.buyGroupOk ~= false
	SaveQuickStartProgress("finalize", #C.SETUP_NPCS + 1, nil, buyGroupOk)
	if scan then
		scan.waitingEquip = true
		scan.waitClick = false
		scan.opening = nil
	end
	if panel then
		if panel.nextLine then
			panel.nextLine:SetText("")
		end
		if panel.openLabel then
			panel.openLabel:SetText("")
		end
		if panel.targetName then
			panel.targetName:SetText("")
		end
	end
	SetPrompt("")
	ShowProgress()
	FinishBuyGearThen(function()
		if not scan or scan.mode ~= "setup" then
			return
		end
		FinishBuy(buyGroupOk)
	end)
end

NextSetupNPC = function()
	if not scan then
		return
	end
	scan.setupIndex = (scan.setupIndex or 1) + 1
	scan.setupGossip = 1
	scan.trainIdle = 0
	scan.trainMisses = 0
	scan.trainStarted = nil
	scan.trainerOpen = nil
	scan.sameTrain = 0
	scan.lastTrainName = nil
	scan.waitingTrainer = nil
	scan.setupPicked = nil
	scan.gossipSettle = nil
	scan.gossipStepUntil = nil
	scan.pendingCapture = false
	scan.opening = nil
	SaveQuickStartProgress("setup", scan.setupIndex, nil, scan.buyGroupOk)
	if scan.setupIndex > #C.SETUP_NPCS then
		FinishSetup()
		return
	end
	local npc = CurrentSetupNPC()
	if npc and npc.kind == "itemshop" then
		local nextSetupIndex = (scan.setupIndex or 1) + 1
		local buyGroupOk = scan.buyGroupOk ~= false
		P(T("Далее") .. ": " .. npc.name)
		StartBuy(nextSetupIndex, buyGroupOk)
		if scan then
			scan.waitClick = true
		end
		ShowProgress()
		UpdateTargetLine()
		return
	end
	P(T("Далее") .. ": " .. (npc and npc.name or "?"))
	scan.waitClick = true
	ShowProgress()
	UpdateTargetLine()
end

local function CompleteSetupGossipStep()
	if not scan or not scan.waitingTrainer then
		return
	end
	scan.waitingTrainer = nil
	scan.setupPicked = nil
	scan.gossipSettle = nil
	scan.gossipStepUntil = nil
	scan.opening = nil
	local npc = CurrentSetupNPC()
	scan.setupGossip = (scan.setupGossip or 1) + 1
	SaveQuickStartProgress("setup", scan.setupIndex, nil, scan.buyGroupOk)
	if not npc or not npc.steps or scan.setupGossip > #npc.steps then
		CloseConversation()
		NextSetupNPC()
		return
	end
	if Shown(GossipFrame) and IsWantedUnit("npc") then
		scan.waitClick = false
		scan.waitUntil = GetTime() + C.STEP_DELAY
		watch.elapsed = 0
		watch:Show()
		ShowProgress()
		return
	end
	scan.waitClick = true
	ShowProgress()
end

local function OnSetupTrainerIdle()
	if not scan or scan.mode ~= "setup" or scan.setupFinishing then
		return
	end
	scan.setupFinishing = true
	scan.trainerOpen = nil
	scan.trainStarted = nil
	local npc = CurrentSetupNPC()
	if npc and npc.kind == "gossip" then
		CloseTrainerWindow()
		scan.setupFinishing = nil
		scan.waitingTrainer = true
		CompleteSetupGossipStep()
		return
	end
	CloseTrainerWindow()
	scan.setupFinishing = nil
	NextSetupNPC()
end

local function OnSetupVendor()
	if not scan or not active then
		return
	end
	scan.pendingCapture = false
	local npc = CurrentSetupNPC()
	local sellItems = npc and npc.sellItems
	if type(sellItems) == "table" and type(UseContainerItem) == "function" then
		local wanted = {}
		for i = 1, #sellItems do
			wanted[sellItems[i]] = true
		end
		for bag = 0, 4 do
			local slots = (type(GetContainerNumSlots) == "function" and GetContainerNumSlots(bag)) or 0
			for slot = slots, 1, -1 do
				local link = type(GetContainerItemLink) == "function" and GetContainerItemLink(bag, slot) or nil
				local id = type(GetContainerItemID) == "function" and GetContainerItemID(bag, slot) or ItemIDFromLink(link)
				if id and wanted[id] then
					local count = 1
					if type(GetContainerItemInfo) == "function" then
						count = select(2, GetContainerItemInfo(bag, slot)) or 1
					end
					local ok = pcall(UseContainerItem, bag, slot)
					if ok then
						P(T("Продано") .. ": " .. ItemNameByID(id) .. " x" .. count)
					end
				end
			end
		end
	end
	local items = npc and npc.items or {}
	for i = 1, #items do
		local id, count = items[i][1], items[i][2] or 1
		local owned = CountInventoryBagItem(id)
		local wearSlot = C.WEAR_SLOT[id]
		if wearSlot and InventoryItemID(wearSlot) == id then
			owned = owned + 1
		end
		local missing = math.max(0, count - owned)
		local slot = missing > 0 and FindMerchantSlot(id) or nil
		local bought = missing > 0 and BuyMerchantCount(slot, missing) or 0
		if bought < missing then
			scan.buyGroupOk = false
			P(T("Покупка не удалась") .. ": " .. ItemNameByID(id) .. " (" .. bought .. "/" .. missing .. ")")
		elseif missing > 0 then
			P(T("Куплено") .. ": " .. ItemNameByID(id))
		end
	end
	CloseConversation()
	local wear = WearListFromItems(items)
	if #wear > 0 then
		scan.waitingEquip = true
		scan.waitClick = false
		StartWearEquip(wear, function()
			if not scan or scan.mode ~= "setup" then
				return
			end
			scan.waitingEquip = false
			NextSetupNPC()
		end)
		return
	end
	NextSetupNPC()
end

AdvanceSetup = function()
	if not scan or not active or scan.mode ~= "setup" then
		return
	end
	local npc = CurrentSetupNPC()
	if not npc then
		FinishSetup()
		return
	end
	if Shown(_G.ClassTrainerFrame) then
		return
	end
	if Shown(MerchantFrame) then
		return
	end
	if npc.kind == "trainer" then
		return
	end
	if npc.kind == "vendor" then
		return
	end
	if scan.waitingTrainer then
		local now = GetTime()
		if scan.gossipSettle and now >= scan.gossipSettle then
			CompleteSetupGossipStep()
			return
		end
		if scan.gossipStepUntil and now >= scan.gossipStepUntil then
			CompleteSetupGossipStep()
			return
		end
		return
	end
	if not Shown(GossipFrame) then
		return
	end
	if UnitExists("npc") and not IsWantedUnit("npc") then
		return
	end
	local step = npc.steps and npc.steps[scan.setupGossip or 1]
	if not step then
		NextSetupNPC()
		return
	end
	if scan.setupPicked == (scan.setupGossip or 1) then
		return
	end
	local opt = FindGossipIndex(step.index) or FindGossipNeedles(step.needles)
	if not opt then
		ShowProgress()
		return
	end
	scan.opening = DisplayName(opt.text)
	scan.setupPicked = scan.setupGossip or 1
	scan.waitUntil = GetTime() + 1.2
	if step.wait == "trainer" then
		scan.waitingTrainer = true
		scan.gossipStepUntil = GetTime() + 30
	end
	P(T("Открываю") .. ": " .. scan.opening)
	ShowProgress()
	SelectOption(opt)
	if step.wait == "gossip" then
		scan.setupGossip = (scan.setupGossip or 1) + 1
		SaveQuickStartProgress("setup", scan.setupIndex, nil, scan.buyGroupOk)
		scan.setupPicked = nil
		scan.opening = nil
	end
end

StartSetup = function(setupIndex, buyGroupOk, setupGossip)
	stepState.prepFloor = 0
	if (setupIndex or 1) <= 1 then
		stepState.cachedBuyGroups = nil
		stepState.shopGroupTotal = nil
	end
	scan = {
		mode = "setup",
		setupIndex = setupIndex or 1,
		buyGroupOk = buyGroupOk ~= false,
		setupGossip = setupGossip or 1,
		trainIdle = 0,
		trainMisses = 0,
		trainerOpen = nil,
		waitingTrainer = nil,
		setupPicked = nil,
		stack = {},
		opening = nil,
		pendingCapture = false,
		waitClick = false,
		waitUntil = 0,
	}
	SaveQuickStartProgress("setup", scan.setupIndex, nil, scan.buyGroupOk)
	watch.elapsed = 0
	watch:Show()
	local npc = CurrentSetupNPC()
	P(T("Далее") .. ": " .. (npc and npc.name or "?"))
end

StartBuy = function(resumeSetupIndex, buyGroupOk)
	stepState.prepFloor = 0
	stepState.cachedBuyGroups = nil
	local queue = BuildQuickBuyQueue()
	CapBagGroup(queue)
	PruneWornBuyItems(queue)
	PrefetchBuyNames(queue)
	stepState.shopGroupTotal = #queue
	scan = {
		mode = "buy",
		buyQueue = queue,
		buyIndex = 1,
		buyGroupOk = buyGroupOk ~= false,
		resumeSetupIndex = resumeSetupIndex,
		buyDone = false,
		waitingEquip = false,
		stack = {},
		opening = nil,
		pendingCapture = false,
		waitClick = false,
		waitUntil = 0,
	}
	SaveQuickStartProgress("buy", nil, resumeSetupIndex, scan.buyGroupOk)
	if #queue < 1 then
		if resumeSetupIndex then
			StartSetup(resumeSetupIndex, buyGroupOk)
			if scan then
				scan.waitClick = true
			end
			ShowProgress()
			UpdateTargetLine()
			return
		end
		FinishBuy(false)
		return
	end
	ApplyBuyGroup(queue[1])
	watch.elapsed = 0
	watch:Show()
end

local function CurrentFrame()
	return scan and scan.stack[#scan.stack]
end

local function FolderDone(frame)
	return frame and frame.discovered and (frame.index or 0) > #(frame.tabs or {})
end

HasWork = function()
	if not scan then
		return false
	end
	if scan.mode == "setup" then
		return (scan.setupIndex or 1) <= #C.SETUP_NPCS
	end
	if scan.mode == "buy" then
		return not scan.buyDone
	end
	if scan.opening or scan.pendingCapture then
		return true
	end
	if #scan.stack == 0 then
		return true
	end
	for i = 1, #scan.stack do
		if not FolderDone(scan.stack[i]) then
			return true
		end
	end
	return false
end

local function OnFolderPage(frame)
	if not frame or type(frame.tabs) ~= "table" then
		return false
	end
	for i = 1, #frame.tabs do
		if FindGossipOption(frame.tabs[i]) then
			return true
		end
	end
	return false
end

local function SameTabNames(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
		return false
	end
	for i = 1, #a do
		if StripText(a[i]) ~= StripText(b[i]) then
			return false
		end
	end
	return true
end

local function CurrentShopNames()
	local shops = ShopOptions()
	local names = {}
	for i = 1, #shops do
		names[i] = DisplayName(shops[i].text)
	end
	return names
end

local function IsNestedPage(parent)
	if not parent or type(parent.tabs) ~= "table" or #parent.tabs == 0 then
		return false
	end
	local names = CurrentShopNames()
	if #names == 0 then
		return false
	end
	return not SameTabNames(parent.tabs, names)
end

local function GossipSignature()
	local shops = ShopOptions()
	local parts = {}
	for i = 1, #shops do
		parts[i] = DisplayName(shops[i].text)
	end
	return table.concat(parts, "\t"), shops
end

local function ApplyTabs(frame, names)
	frame.tabs = names
	frame.discovered = true
	if (frame.index or 0) < 1 then
		frame.index = 0
	end
	frame.node.tabs = names
	frame.node.children = frame.node.children or {}
	for i = 1, #names do
		local name = names[i]
		frame.node.children[name] = frame.node.children[name] or {}
	end
	SaveCatalog()
end

local function DiscoverIfStable(frame)
	local sig, shops = GossipSignature()
	if scan.stableSig ~= sig then
		scan.stableSig = sig
		scan.stableAt = GetTime()
		frame.tabs = {}
		for i = 1, #shops do
			frame.tabs[i] = DisplayName(shops[i].text)
		end
		ShowProgress()
		return false
	end
	if (GetTime() - (scan.stableAt or 0)) < C.STABLE_TIME then
		return false
	end
	local names = {}
	for i = 1, #shops do
		names[i] = DisplayName(shops[i].text)
	end
	ApplyTabs(frame, names)
	if #names == 0 then
		frame.index = 1
	end
	scan.stableSig = nil
	ShowProgress()
	return true
end

local function EnsureRootFrame()
	local frame = CurrentFrame()
	if frame then
		return frame
	end
	local root = scan.root
	root.npcID = CreatureIDFromGUID(UnitGUID("npc")) or C.START_NPC_ID
	root.npcName = UnitName("npc") or C.START_NPC_TITLE
	root.children = root.children or {}
	local node = root.children["Item Shop"] or {}
	node.children = node.children or {}
	root.children["Item Shop"] = node
	frame = {
		name = "Item Shop",
		node = node,
		tabs = {},
		index = 0,
		discovered = false,
	}
	scan.stack[1] = frame
	return frame
end

local function PushNested(name)
	local parent = CurrentFrame()
	if not parent then
		return
	end
	parent.node.children = parent.node.children or {}
	local node = parent.node.children[name] or {}
	parent.node.children[name] = node
	node.children = node.children or {}
	scan.stack[#scan.stack + 1] = {
		name = name,
		node = node,
		tabs = {},
		index = 0,
		discovered = false,
	}
	scan.opening = nil
	scan.needReselect = false
	scan.stableSig = nil
	scan.waitClick = false
	scan.waitUntil = GetTime() + C.STEP_DELAY
	SaveCatalog()
	ShowProgress()
end

local function CompleteCurrentTab()
	local frame = CurrentFrame()
	if not frame then
		return
	end
	frame.index = (frame.index or 1) + 1
	scan.opening = nil
	scan.needReselect = false
	SkipPastDone(frame)
	ShowProgress()
	SaveCatalog()
end

Advance = function()
	if not scan or not active then
		return
	end
	if scan.mode == "setup" then
		AdvanceSetup()
		return
	end
	if scan.mode == "buy" then
		AdvanceBuy()
		return
	end
	if scan.pendingCapture then
		return
	end
	if Shown(MerchantFrame) then
		return
	end
	if not Shown(GossipFrame) then
		if not HasWork() then
			FinishScan()
		end
		return
	end
	if UnitExists("npc") and not IsStartNPC("npc") then
		return
	end

	if FindGossipOption(C.ITEM_SHOP_TEXT, true) then
		scan.waitUntil = GetTime() + 1.2
		SelectOption(FindGossipOption(C.ITEM_SHOP_TEXT, true))
		ShowProgress()
		return
	end

	local frame = EnsureRootFrame()

	if scan.opening then
		if IsNestedPage(frame) then
			scan.waitClick = false
			PushNested(scan.opening)
			return
		end
		if scan.needReselect then
			local opt = FindGossipOption(scan.opening)
			if opt then
				scan.needReselect = false
				scan.waitUntil = GetTime() + 1.8
				SelectOption(opt)
				ShowProgress()
				return
			end
		end
		if FindGossipOption(scan.opening) then
			return
		end
		local shops = ShopOptions()
		if #shops > 0 then
			scan.waitClick = false
			PushNested(scan.opening)
			return
		end
		CompleteCurrentTab()
		frame = CurrentFrame()
	end

	if frame.discovered and not OnFolderPage(frame) then
		for i = 1, #scan.stack do
			local fr = scan.stack[i]
			if not OnFolderPage(fr) then
				local opt = FindGossipOption(fr.name)
				if opt then
					scan.waitUntil = GetTime() + 1.2
					SelectOption(opt)
					ShowProgress()
					return
				end
				if #ShopOptions() > 0 then
					return
				end
				return
			end
		end
	end

	if not frame.discovered then
		if not DiscoverIfStable(frame) then
			return
		end
		frame = CurrentFrame()
	end

	SkipPastDone(frame)

	if FolderDone(frame) then
		if #scan.stack > 1 then
			local parent = scan.stack[#scan.stack - 1]
			if parent and parent.node and frame.name then
				parent.node.children = parent.node.children or {}
				local child = parent.node.children[frame.name] or {}
				child.complete = true
				parent.node.children[frame.name] = child
			end
			local back = FindBackOption()
			table.remove(scan.stack)
			CompleteCurrentTab()
			scan.waitUntil = GetTime() + 1.2
			if back then
				SelectOption(back)
			end
			ShowProgress(T("назад"))
			return
		end
		local back = FindBackOption()
		if back then
			SelectOption(back)
		end
		FinishScan()
		return
	end

	if (frame.index or 0) < 1 then
		frame.index = 1
		ShowProgress()
	end

	local name = frame.tabs[frame.index]
	local opt = FindGossipOption(name)
	if not opt then
		ShowProgress(T("нет вкладки"))
		return
	end
	scan.opening = name
	scan.needReselect = false
	scan.waitUntil = GetTime() + 1.8
	ShowProgress()
	SelectOption(opt)
end

SkipCurrentStep = function()
	if not scan or not active then
		return
	end
	if scan.mode == "buy" then
		FinishBuy(false)
		return
	end
	scan.pendingCapture = false
	scan.needReselect = false
	scan.stableSig = nil
	scan.closedAt = nil
	scan.waitUntil = 0
	scan.opening = nil
	scan.waitClick = true
	CloseConversation()

	local frame = CurrentFrame()
	if not frame then
		ShowProgress()
		return
	end

	local parent = scan.stack[#scan.stack - 1]
	if #scan.stack > 1 and not frame.discovered then
		MarkTabSkipped(parent, frame.name)
		table.remove(scan.stack)
		parent.index = (parent.index or 1) + 1
		SkipPastDone(parent)
	else
		local name = frame.tabs and frame.tabs[frame.index]
		MarkTabSkipped(frame, name)
		frame.index = (frame.index or 1) + 1
		SkipPastDone(frame)
		frame = CurrentFrame()
		if frame and FolderDone(frame) and #scan.stack > 1 then
			parent = scan.stack[#scan.stack - 1]
			MarkTabSkipped(parent, frame.name)
			table.remove(scan.stack)
			parent.index = (parent.index or 1) + 1
			SkipPastDone(parent)
		end
	end
	SaveCatalog()

	if not HasWork() then
		scan.waitClick = false
		FinishScan()
		return
	end
	watch:Show()
	ShowProgress()
end

local function OnMerchantCaptured()
	if not scan or not active then
		return
	end
	if scan.mode == "buy" then
		OnMerchantBuy()
		return
	end
	scan.pendingCapture = false
	local items = CaptureMerchantItems()
	local frame = CurrentFrame()
	local name = scan.opening
	if frame and name then
		frame.node.children = frame.node.children or {}
		local child = frame.node.children[name] or {}
		child.items = items
		child.children = nil
		child.tabs = nil
		frame.node.children[name] = child
	end
	CompleteCurrentTab()
	CloseShopWindow()
	if Shown(GossipFrame) then
		scan.waitClick = false
		watch.elapsed = C.STEP_DELAY
		watch:Show()
		ShowProgress(T("сохранено"))
	else
		scan.waitClick = HasWork()
		if scan.waitClick then
			ShowProgress(T("Кликните NPC"))
		else
			FinishScan()
		end
	end
end

local function StartScan()
	scan = {
		root = {
			npcID = C.START_NPC_ID,
			npcName = C.START_NPC_TITLE,
			children = {},
		},
		stack = {},
		opening = nil,
		needReselect = false,
		pendingCapture = false,
		waitClick = false,
		waitUntil = 0,
		stableSig = nil,
		stableAt = 0,
	}
	watch.elapsed = 0
	watch:Show()
end

watch:SetScript("OnUpdate", function(self, elapsed)
	if not scan or not active then
		self:Hide()
		return
	end
	if panel and scan.waitClick then
		panel.pulse = (panel.pulse or 0) + elapsed
		local a = 0.4 + 0.55 * math.abs(math.sin(panel.pulse * 3.2))
		if panel.barFill then
			panel.barFill:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], a)
		end
		if panel.prompt then
			panel.prompt:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 0.55 + 0.45 * math.abs(math.sin(panel.pulse * 3.2)))
		end
	end
	if scan.waitClick then
		return
	end
	if scan.waitingEquip then
		return
	end
	if scan.pendingCapture then
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed < C.STEP_DELAY then
			return
		end
		self.elapsed = 0
		if Shown(MerchantFrame) and GetTime() >= (scan.waitUntil or 0) then
			if scan.mode == "buy" then
				OnMerchantBuy()
			elseif scan.mode == "setup" then
				OnSetupVendor()
			else
				OnMerchantCaptured()
			end
		end
		return
	end
	if scan.mode == "setup" and Shown(_G.ClassTrainerFrame) then
		scan.trainerOpen = true
		if scan.waitUntil and GetTime() < scan.waitUntil then
			return
		end
		local n, name = TrainAvailableBatch()
		if n > 0 then
			if not scan.trainStarted then
				scan.trainStarted = true
				local npc = CurrentSetupNPC()
				P(T("Изучаю все способности") .. ": " .. (npc and npc.name or "?"))
			end
			if name and name == scan.lastTrainName then
				scan.sameTrain = (scan.sameTrain or 0) + 1
			else
				scan.sameTrain = 0
				scan.lastTrainName = name
			end
			scan.trainMisses = 0
			if (scan.sameTrain or 0) >= 6 then
				OnSetupTrainerIdle()
				return
			end
			scan.waitUntil = GetTime() + C.TRAINER_STEP_DELAY
			return
		end
		scan.trainMisses = (scan.trainMisses or 0) + 1
		if scan.trainMisses >= C.TRAINER_IDLE_MISSES then
			OnSetupTrainerIdle()
			return
		end
		scan.waitUntil = GetTime() + C.TRAINER_IDLE_DELAY
		return
	end
	if not Shown(GossipFrame) and not Shown(MerchantFrame) and not Shown(_G.ClassTrainerFrame) then
		if scan.mode == "setup" and scan.waitingTrainer then
			local now = GetTime()
			if (scan.gossipSettle and now >= scan.gossipSettle) or (scan.gossipStepUntil and now >= scan.gossipStepUntil) then
				CompleteSetupGossipStep()
			end
			return
		end
		if scan.mode == "setup" and scan.trainerOpen and not scan.waitClick then
			OnSetupTrainerIdle()
			return
		end
		if scan.mode == "setup" and scan.waitUntil and GetTime() < ((scan.waitUntil or 0) + 0.8) then
			return
		end
		if scan.closedAt and HasWork() then
			if GetTime() - scan.closedAt < 0.5 then
				return
			end
			scan.waitClick = true
			scan.closedAt = nil
			ShowProgress(T("Кликните NPC"))
		end
		if scan.waitClick then
			return
		end
		return
	end
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < C.STEP_DELAY then
		return
	end
	self.elapsed = 0
	if scan.waitUntil and GetTime() < scan.waitUntil then
		return
	end
	Advance()
end)

local function StartSavedQuickStart()
	local saved = GetQuickStartProgress()
	if not saved then
		StartSetup()
		return false
	end
	if saved.stage == "buy" then
		StartBuy(saved.resumeSetupIndex or math.min(#C.SETUP_NPCS, 1), saved.buyGroupOk)
		return false
	elseif saved.stage == "finalize" then
		StartSetup(#C.SETUP_NPCS + 1, saved.buyGroupOk)
		FinishSetup()
		return true
	end
	local index = math.max(1, math.min(#C.SETUP_NPCS, tonumber(saved.setupIndex) or 1))
	StartSetup(index, saved.buyGroupOk, saved.setupGossip)
	return false
end

local function SetActive(on)
	active = on and true or false
	if not active then
		StopScan()
		ProfessionSocketFlow:Stop()
		StopItemEnchants()
		SocketFlow:Stop(true)
		HideUseItemUI()
		local savedLabel = sessionMode == "buy" and SavedProgressLabel(GetQuickStartProgress())
		SetStatus(savedLabel or T("По умолчанию"))
		SetNested("")
		SetPrompt("")
	else
		local finalizing = false
		if sessionMode == "buy" then
			LoadQuickStartSkipped()
			ApplyQuickStartTalentTemplate()
			finalizing = StartSavedQuickStart()
		else
			StartScan()
		end
		if not finalizing then
			local openNow = Shown(GossipFrame) or Shown(MerchantFrame) or Shown(_G.ClassTrainerFrame)
			if openNow and (IsWantedUnit("npc") or IsWantedUnit("target")) then
				scan.waitClick = false
				ShowProgress()
				watch.elapsed = C.STEP_DELAY
				Advance()
			else
				scan.waitClick = true
				ShowProgress()
			end
		end
	end
	UpdateStartButton()
	UpdateTargetLine()
end

function SarychUI:SkipQuickStartStage()
	if sessionMode ~= "buy" or not active or not scan then return end
	if scan.mode == "buy" then
		stepState.skipped.buy = true
		local resumeIndex, buyGroupOk = scan.resumeSetupIndex, scan.buyGroupOk
		CloseConversation()
		if resumeIndex then
			StartSetup(resumeIndex, buyGroupOk)
			if resumeIndex > #C.SETUP_NPCS then
				FinishSetup()
			else
				scan.waitClick = true
				ShowProgress()
				UpdateTargetLine()
			end
		else
			FinishBuy(true)
		end
		return
	end
	if scan.mode ~= "setup" then return end
	local index = scan.setupIndex or 1
	if scan.waitingEquip and index <= #C.SETUP_NPCS then return end
	if index > #C.SETUP_NPCS then
		stepState.skipped.prep = true
		SetActive(false)
		ClearQuickStartProgress()
		SetStatus(T("Подготовка завершена"))
		if panel then panel:Hide() end
		sessionMode = "scan"
		return
	end
	local npc = C.SETUP_NPCS[index]
	stepState.skipped[npc.kind == "itemshop" and "buy" or index] = true
	scan.trainerOpen = nil
	scan.waitingTrainer = nil
	scan.pendingCapture = false
	CloseConversation()
	NextSetupNPC()
	UpdateTargetLine()
end

local function RaisePanel(f)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(500)
	f:SetToplevel(true)
	if f.Raise then
		f:Raise()
	end
end

local function EnsurePanel()
	if panel then
		return panel
	end

	local f = CreateFrame("Frame", "SarychUI_QuickStartPanel", UIParent)
	f:SetSize(300, 196)
	f:SetPoint("TOP", UIParent, "TOP", 0, -120)
	RaisePanel(f)
	f:EnableMouse(false)
	f:SetMovable(true)
	f:SetScript("OnShow", function(self)
		RaisePanel(self)
		UpdateTargetLine()
		UpdateStartButton()
	end)
	f:Hide()
	ApplyTheme(f)

	local header = CreateFrame("Frame", nil, f)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(32)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
	end)

	local close = CreateFrame("Button", nil, f)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -8, -8)
	close:EnableMouse(true)
	close:RegisterForClicks("LeftButtonUp")
	close:SetFrameLevel((f:GetFrameLevel() or 500) + 12)
	ApplyTheme(close, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
	local closeFs = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	closeFs:SetPoint("CENTER", 1, 0)
	closeFs:SetText("X")
	close:SetScript("OnEnter", function(self)
		ApplyTheme(self, { 0.22, 0.22, 0.25, 1 }, { 0.95, 0.78, 0.15, 1 })
	end)
	close:SetScript("OnLeave", function(self)
		ApplyTheme(self, { 0.16, 0.16, 0.18, 1 }, { 0.24, 0.24, 0.26, 1 })
	end)
	close:SetScript("OnClick", function()
		SarychUI:HideQuickStartPanel()
	end)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -12)
	title:SetPoint("RIGHT", close, "LEFT", -6, 0)
	title:SetJustifyH("LEFT")
	title:SetText(T("Формирование базы данных"))
	title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.title = title

	local targetName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	targetName:SetPoint("TOPLEFT", 10, -30)
	targetName:SetPoint("RIGHT", -10, 0)
	targetName:SetJustifyH("LEFT")
	f.targetName = targetName
	f.hint = targetName

	local savedBox = CreateFrame("Frame", nil, f)
	savedBox:SetPoint("TOPLEFT", 8, -44)
	savedBox:SetPoint("TOPRIGHT", -8, -44)
	savedBox:SetHeight(54)
	ApplyTheme(savedBox, { 0.16, 0.16, 0.18, 1 }, { 0.28, 0.28, 0.30, 1 })
	f.savedBox = savedBox

	local savedCap = savedBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	savedCap:SetPoint("TOPLEFT", 8, -5)
	savedCap:SetPoint("RIGHT", -8, 0)
	savedCap:SetJustifyH("LEFT")
	savedCap:SetText(T("Внесено в базу данных"))
	savedCap:SetTextColor(0.72, 0.72, 0.75)
	f.savedCap = savedCap

	local status = savedBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", 8, -18)
	status:SetPoint("RIGHT", -8, 0)
	status:SetJustifyH("LEFT")
	status:SetWordWrap(false)
	status:SetTextColor(0.95, 0.95, 0.95)
	f.status = status

	local nested = savedBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nested:SetPoint("TOPLEFT", 16, -32)
	nested:SetPoint("BOTTOMRIGHT", -8, 4)
	nested:SetJustifyH("LEFT")
	nested:SetJustifyV("TOP")
	nested:SetWordWrap(true)
	nested:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.nested = nested

	local openLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	openLabel:SetPoint("TOPLEFT", 12, -104)
	openLabel:SetPoint("RIGHT", -12, 0)
	openLabel:SetJustifyH("LEFT")
	openLabel:SetTextColor(0.75, 0.75, 0.78)
	f.openLabel = openLabel

	local nextLine = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nextLine:SetPoint("TOPLEFT", 12, -117)
	nextLine:SetPoint("RIGHT", -12, 0)
	nextLine:SetJustifyH("LEFT")
	nextLine:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.nextLine = nextLine

	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 12, -132)
	bar:SetPoint("TOPRIGHT", -12, -132)
	bar:SetHeight(12)
	ApplyTheme(bar, { 0.12, 0.12, 0.14, 1 }, { 0.24, 0.24, 0.26, 1 })
	local fill = bar:CreateTexture(nil, "ARTWORK")
	fill:SetTexture("Interface\\Buttons\\WHITE8X8")
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", 1, 1)
	fill:SetWidth(1)
	fill:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 0.9)
	bar.fill = fill
	local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	barText:SetPoint("CENTER", 0, 0)
	barText:SetText("0 / 0")
	f.bar = bar
	f.barFill = fill
	f.barText = barText

	f.stepRows = {}
	for i = 1, 8 do
		local row = CreateFrame("Frame", nil, f)
		row:SetHeight(stepState.rowH)
		row:Hide()
		local rowBg = row:CreateTexture(nil, "BACKGROUND")
		rowBg:SetAllPoints()
		rowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
		rowBg:SetVertexColor(0.11, 0.11, 0.13, 1)
		local rowFill = row:CreateTexture(nil, "ARTWORK")
		rowFill:SetTexture("Interface\\Buttons\\WHITE8X8")
		rowFill:SetPoint("TOPLEFT", 1, -1)
		rowFill:SetPoint("BOTTOMLEFT", 1, 1)
		rowFill:SetWidth(1)
		rowFill:Hide()
		local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		rowText:SetPoint("LEFT", 6, 0)
		rowText:SetPoint("RIGHT", -94, 0)
		rowText:SetJustifyH("LEFT")
		rowText:SetWordWrap(false)
		local rowCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		rowCount:SetPoint("RIGHT", -5, 0)
		rowCount:SetJustifyH("RIGHT")
		row.bg = rowBg
		row.fill = rowFill
		row.text = rowText
		row.count = rowCount
		f.stepRows[i] = row
	end

	local startBtn = CreateFrame("Button", nil, f)
	startBtn:SetSize(126, 24)
	startBtn:SetPoint("TOPLEFT", 12, -150)
	startBtn:EnableMouse(true)
	startBtn:RegisterForClicks("LeftButtonUp")
	startBtn:SetFrameLevel((f:GetFrameLevel() or 500) + 20)
	local startBg = startBtn:CreateTexture(nil, "BACKGROUND")
	startBg:SetAllPoints()
	startBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	startBtn.bg = startBg
	local startFs = startBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	startFs:SetPoint("CENTER")
	startBtn.label = startFs
	startBtn:SetScript("OnEnter", function(self)
		if not active then
			ApplyTheme(self, { 0.28, 0.28, 0.30, 1 }, GOLD)
			if self.bg then
				self.bg:SetVertexColor(0.28, 0.28, 0.30, 1)
			end
		end
	end)
	startBtn:SetScript("OnLeave", function()
		UpdateStartButton()
	end)
	startBtn:SetScript("OnClick", function()
		SetActive(not active)
	end)
	f.startBtn = startBtn

	local skipBtn = CreateFrame("Button", nil, f)
	skipBtn:SetSize(126, 24)
	skipBtn:SetPoint("TOPRIGHT", -12, -150)
	skipBtn:EnableMouse(true)
	skipBtn:RegisterForClicks("LeftButtonUp")
	skipBtn:SetFrameLevel((f:GetFrameLevel() or 500) + 20)
	local skipBg = skipBtn:CreateTexture(nil, "BACKGROUND")
	skipBg:SetAllPoints()
	skipBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	skipBtn.bg = skipBg
	local skipFs = skipBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	skipFs:SetPoint("CENTER")
	skipFs:SetText(T("Пропустить"))
	skipBtn.label = skipFs
	skipBtn:SetScript("OnEnter", function(self)
		if active then
			ApplyTheme(self, { 0.28, 0.28, 0.30, 1 }, GOLD)
			if self.bg then
				self.bg:SetVertexColor(0.28, 0.28, 0.30, 1)
			end
		end
	end)
	skipBtn:SetScript("OnLeave", function()
		UpdateStartButton()
	end)
	skipBtn:SetScript("OnClick", function()
		if sessionMode == "buy" then
			if SarychUI.SkipQuickStartStage then SarychUI:SkipQuickStartStage() end
		else
			SkipCurrentStep()
		end
	end)
	f.skipBtn = skipBtn

	local resetBtn = CreateFrame("Button", nil, f)
	resetBtn:SetSize(92, 24)
	resetBtn:SetPoint("TOPRIGHT", -12, -150)
	resetBtn:EnableMouse(true)
	resetBtn:RegisterForClicks("LeftButtonUp")
	resetBtn:SetFrameLevel((f:GetFrameLevel() or 500) + 20)
	local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
	resetBg:SetAllPoints()
	resetBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	resetBtn.bg = resetBg
	local resetFs = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	resetFs:SetPoint("CENTER")
	resetFs:SetText(T("С начала"))
	resetBtn.label = resetFs
	resetBtn:SetScript("OnEnter", function(self)
		ApplyTheme(self, { 0.30, 0.20, 0.20, 1 }, { 0.85, 0.35, 0.35, 1 })
		if self.bg then
			self.bg:SetVertexColor(0.30, 0.20, 0.20, 1)
		end
	end)
	resetBtn:SetScript("OnLeave", function()
		UpdateStartButton()
	end)
	resetBtn:SetScript("OnClick", function()
		if sessionMode ~= "buy" then
			return
		end
		SetActive(false)
		ClearQuickStartProgress()
		SetStatus(T("Прогресс сброшен. Нажмите Старт."))
		SetNested("")
		SetPrompt("")
		UpdateProgressBar()
		UpdateStartButton()
	end)
	resetBtn:Hide()
	f.resetBtn = resetBtn

	local useRow = CreateFrame("Frame", nil, f)
	useRow:SetPoint("TOPLEFT", 12, -176)
	useRow:SetPoint("TOPRIGHT", -12, -176)
	useRow:SetHeight(36)
	useRow:Hide()
	local learnBtn = CreateFrame("Button", "SarychUI_QuickStartLearn", useRow, "SecureActionButtonTemplate")
	learnBtn:SetAllPoints()
	learnBtn:EnableMouse(true)
	learnBtn:RegisterForClicks("LeftButtonUp")
	learnBtn:SetFrameLevel((f:GetFrameLevel() or 500) + 22)
	local learnBg = learnBtn:CreateTexture(nil, "BACKGROUND")
	learnBg:SetAllPoints()
	learnBg:SetTexture("Interface\\Buttons\\WHITE8X8")
	learnBtn.bg = learnBg
	local useIconTex = learnBtn:CreateTexture(nil, "ARTWORK")
	useIconTex:SetSize(32, 32)
	useIconTex:SetPoint("LEFT", 2, 0)
	useIconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	f.useIconTex = useIconTex
	local useSecondIconTex = learnBtn:CreateTexture(nil, "ARTWORK")
	useSecondIconTex:SetSize(32, 32)
	useSecondIconTex:SetPoint("LEFT", useIconTex, "RIGHT", 4, 0)
	useSecondIconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	useSecondIconTex:Hide()
	f.useSecondIconTex = useSecondIconTex
	local useTargetIconTex = learnBtn:CreateTexture(nil, "ARTWORK")
	useTargetIconTex:SetSize(32, 32)
	useTargetIconTex:SetPoint("RIGHT", -2, 0)
	useTargetIconTex:SetTexture("Interface\\Icons\\INV_Helmet_01")
	useTargetIconTex:Hide()
	f.useTargetIconTex = useTargetIconTex
	local learnFs = learnBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	learnFs:SetPoint("LEFT", useIconTex, "RIGHT", 8, 0)
	learnFs:SetPoint("RIGHT", -8, 0)
	learnFs:SetJustifyH("LEFT")
	learnFs:SetText(T("Изучить"))
	learnFs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	learnBtn.label = learnFs
	ApplyTheme(learnBtn, { 0.22, 0.22, 0.25, 1 }, GOLD)
	if learnBg.SetVertexColor then
		learnBg:SetVertexColor(0.22, 0.22, 0.25, 1)
	end
	learnBtn:SetScript("OnEnter", function(self)
		ApplyTheme(self, { 0.28, 0.28, 0.30, 1 }, GOLD)
		if self.bg then
			self.bg:SetVertexColor(0.28, 0.28, 0.30, 1)
		end
		local id = panel and panel.useItemID
		if not id or not GameTooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if GameTooltip.SetHyperlink then
			GameTooltip:SetHyperlink("item:" .. id)
		end
		GameTooltip:Show()
	end)
	learnBtn:SetScript("OnLeave", function(self)
		ApplyTheme(self, { 0.22, 0.22, 0.25, 1 }, GOLD)
		if self.bg then
			self.bg:SetVertexColor(0.22, 0.22, 0.25, 1)
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	learnBtn:SetScript("PreClick", function()
		ProfessionSocketFlow:BeforeClick()
	end)
	learnBtn:SetScript("PostClick", function()
		if HandleUseItemClick() then
			return
		end
		ProfessionSocketFlow:HandleClick()
		SocketFlow:HandleClick()
	end)
	f.learnBtn = learnBtn
	f.useRow = useRow

	local prompt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	prompt:SetPoint("TOPLEFT", 8, -178)
	prompt:SetPoint("TOPRIGHT", -8, -178)
	prompt:SetJustifyH("CENTER")
	prompt:SetText("")
	prompt:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.prompt = prompt

	local modelBox = CreateFrame("Frame", nil, f)
	modelBox:SetPoint("TOPLEFT", 8, -198)
	modelBox:SetPoint("TOPRIGHT", -8, -198)
	modelBox:SetHeight(92)
	local modelBack = modelBox:CreateTexture(nil, "BACKGROUND")
	modelBack:SetAllPoints()
	modelBack:SetTexture(0.08, 0.08, 0.10, 0.96)
	modelBox.back = modelBack
	modelBox:Hide()
	f.npcModelBox = modelBox
	local ok, model = pcall(CreateFrame, "PlayerModel", "SarychUI_QuickStartNPCModel", modelBox)
	if ok and model then
		model:SetPoint("TOPLEFT", 2, -6)
		model:SetPoint("BOTTOMRIGHT", -2, 2)
		model:SetFrameLevel((f:GetFrameLevel() or 500) + 5)
		model:EnableMouse(false)
		model:SetScript("OnShow", function(self)
			if self.SetCamera then
				self:SetCamera(0)
			end
			if self.SetPortraitZoom then
				self:SetPortraitZoom(0.90)
			end
		end)
		f.npcModel = model
	end

	panel = f
	UpdateTargetLine()
	UpdateStartButton()
	SetStatus(T("По умолчанию"))
	return f
end

function SarychUI:ShowQuickStartPanel()
	EnsurePanel()
	panel:Show()
	UpdateTargetLine()
	UpdateStartButton()
end

function SarychUI:HideQuickStartPanel()
	SetActive(false)
	sessionMode = "scan"
	if panel then
		panel:Hide()
	end
	UpdateStartButton()
end

function SarychUI:ToggleQuickStartPanel()
	EnsurePanel()
	if panel:IsShown() then
		self:HideQuickStartPanel()
	else
		self:ShowQuickStartPanel()
	end
end

function SarychUI:BeginQuickStartCustomScan()
	sessionMode = "scan"
	self:ClearQuickStartCatalog(true)
	self:ShowQuickStartPanel()
	SetActive(true)
end

function SarychUI:BeginQuickStartBuy(profileKey)
	if self.ActivateQuickStartProfile then
		self:ActivateQuickStartProfile(profileKey)
	else
		self:ApplyQuickStartRuntimeProfile(BUILTIN_RUNTIME)
	end
	sessionMode = "buy"
	SetActive(false)
	LoadQuickStartSkipped()
	self:ShowQuickStartPanel()
	UpdateStartButton()
end

function SarychUI:BeginQuickStartItemSetup()
	if self.ActivateQuickStartProfile then
		self:ActivateQuickStartProfile()
	end
	sessionMode = "buy"
	SetActive(false)
	LoadQuickStartSkipped()
	self:ShowQuickStartPanel()
	UpdateStartButton()
	StartItemPrep()
end

SarychUI.BeginQuickStartGlyphLearning = SarychUI.BeginQuickStartItemSetup

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("GOSSIP_CLOSED")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("QUEST_GREETING")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("CLASS_TRAINER_SHOW")
events:RegisterEvent("TRAINER_UPDATE")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("BANKFRAME_OPENED")
local function ProfessionLearnFinished(msg)
	if type(msg) ~= "string" then
		return false
	end
	msg = string.lower(msg)
	return msg:find("выучили все умения", 1, true)
		or msg:find("приобрели навык", 1, true)
		or msg:find("learned all the skills", 1, true)
		or msg:find("learned all skills", 1, true)
		or msg:find("you have gained the", 1, true)
end

events:SetScript("OnEvent", function(_, event, ...)
	if event == "GOSSIP_SHOW"
		or event == "MERCHANT_SHOW"
		or event == "QUEST_GREETING"
		or event == "QUEST_DETAIL"
		or event == "TRAINER_SHOW"
		or event == "TAXIMAP_OPENED"
		or event == "BANKFRAME_OPENED"
	then
		QueueNPCProbe(event)
	end

	if event == "PLAYER_TARGET_CHANGED" then
		if panel and panel:IsShown() then
			UpdateTargetLine()
			if UpdateNPCModel then
				UpdateNPCModel()
			end
		end
		return
	end

	if event == "CHAT_MSG_SYSTEM" then
		if active and scan and scan.mode == "setup" and scan.waitingTrainer and ProfessionLearnFinished(...) then
			scan.gossipSettle = GetTime() + 0.4
			scan.gossipStepUntil = GetTime() + 0.4
			watch.elapsed = 0
			watch:Show()
		end
		return
	end

	if event == "GOSSIP_SHOW" then
		if not active or not scan then
			return
		end
		local fresh = scan.waitClick
		scan.waitClick = false
		scan.closedAt = nil
		if fresh and scan.opening then
			scan.needReselect = FindGossipOption(scan.opening) and true or false
		end
		local frame = CurrentFrame()
		if not frame or not frame.discovered then
			scan.stableSig = nil
		end
		if not (scan.mode == "setup" and (scan.waitingTrainer or (scan.waitUntil and scan.waitUntil > GetTime()))) then
			scan.waitUntil = GetTime() + C.STEP_DELAY
		end
		watch.elapsed = 0
		watch:Show()
		return
	end

	if event == "MERCHANT_SHOW" then
		if active and scan then
			scan.waitClick = false
			scan.pendingCapture = true
			scan.waitUntil = GetTime() + C.MERCHANT_WAIT
			watch.elapsed = 0
			watch:Show()
			ShowProgress()
		end
		return
	end

	if event == "TRAINER_SHOW" or event == "CLASS_TRAINER_SHOW" then
		if active and scan and scan.mode == "setup" and (IsWantedUnit("npc") or IsWantedUnit("target")) then
			scan.waitClick = false
			scan.closedAt = nil
			scan.trainerOpen = true
			scan.trainMisses = 0
			scan.sameTrain = 0
			scan.waitUntil = GetTime() + C.TRAINER_STEP_DELAY
			watch.elapsed = 0
			watch:Show()
			ShowProgress()
		end
		return
	end

	if event == "TRAINER_UPDATE" then
		if active and scan and scan.mode == "setup" then
			watch.elapsed = 0
			watch:Show()
		end
		return
	end

	if event == "GOSSIP_CLOSED" and scan and active and not Shown(MerchantFrame) and not Shown(_G.ClassTrainerFrame) then
		if scan.mode == "setup" and scan.waitingTrainer then
			return
		end
		scan.closedAt = GetTime()
	end
end)

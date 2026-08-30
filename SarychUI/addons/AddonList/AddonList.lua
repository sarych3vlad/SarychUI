local _, ns = ...
local Private = ns.AddonListLocale or {}

local RawGetAddOnInfo = _G.GetAddOnInfo
local RawIsAddOnLoaded = _G.IsAddOnLoaded
local RawIsAddOnLoadOnDemand = _G.IsAddOnLoadOnDemand

local function GetCompatAddOnInfo(index)
	if C_AddOns and C_AddOns.GetAddOnInfo then
		return C_AddOns.GetAddOnInfo(index)
	end
	if C_GetAddOnInfo then
		return C_GetAddOnInfo(index)
	end

	local name, title, notes, enabled, loadable, reason, security = RawGetAddOnInfo(index)
	if loadable and RawIsAddOnLoaded and RawIsAddOnLoadOnDemand
		and not RawIsAddOnLoaded(index) and RawIsAddOnLoadOnDemand(index) then
		reason = "DEMAND_LOADED"
		loadable = false
	else
		loadable = loadable and true or false
	end

	return name, title, notes, loadable, reason, security, nil
end

local GetAddOnInfo = GetCompatAddOnInfo

local ADDON_BUTTON_HEIGHT = 16;
local MAX_ADDONS_DISPLAYED = 19;

-- Must stay enabled so SarychUI / ClassicAPI cannot be turned off from this list.
local PROTECTED_ADDONS = {
	["SarychUI"] = true,
	["!!!ClassicAPI"] = true,
}

local LIBRARIES_KEY = "__LIBRARIES__"

-- ACP-style Group By Name: nested categories + flat visible rows.
local masterAddonList = {}
local sortedAddonList = {}

local MEMORY_QUERY_THROTTLE;

local UIDropDownMenu_Initialize = C_UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = C_UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = C_UIDropDownMenu_CreateInfo
local UIDropDownMenu_GetSelectedValue = C_UIDropDownMenu_GetSelectedValue
local UIDropDownMenu_SetSelectedValue = C_UIDropDownMenu_SetSelectedValue
local GameTooltip = GameTooltip

local function IsAddonListFeatureEnabled()
	if _G.AddonListEnabled == false then
		return false
	end
	return true
end

local function IsProtectedAddOn(index)
	local name = GetAddOnInfo(index)
	return name and PROTECTED_ADDONS[name] or false
end

local function ProtectCoreAddOns(character)
	for i = 1, GetNumAddOns() do
		if IsProtectedAddOn(i) then
			EnableAddOn(i, character)
		end
	end
end

local function GetCollapsedTable()
	if SarychUI and SarychUI.db and SarychUI.db.profile and SarychUI.db.profile.addons then
		local db = SarychUI.db.profile.addons.AddonList
		if not db then
			db = { enabled = true, collapsed = {} }
			SarychUI.db.profile.addons.AddonList = db
		end
		if not db.collapsed then
			db.collapsed = {}
		end
		return db.collapsed
	end
	return {}
end

local function SpecialCaseName(name)
	if not name then
		return ""
	end
	local partof = GetAddOnMetadata(name, "X-Part-Of") or GetAddOnMetadata(name, "X-Child-Of")
	if partof then
		return partof .. "_" .. name
	end
	if name == "DBM-Core" then
		return "DBM"
	elseif name:match("DBM%-") then
		return name:gsub("DBM%-", "DBM_")
	elseif name:sub(1, 1) == "+" or name:sub(1, 1) == "!" or name:sub(1, 1) == "_" then
		return name:sub(2)
	elseif name == "ShadowedUF_Options" then
		return "ShadowedUnitFrames_Options"
	elseif name:match("^WeakAuras") then
		return name:gsub("WeakAuras(%w+)", "WeakAuras_%1")
	end
	return name
end

local function SplitFirst(name, sep)
	local pos = name:find(sep, 1, true)
	if pos then
		return name:sub(1, pos - 1), name:sub(pos + 1)
	end
	return name, nil
end

local function IsCategoryCollapsed(category)
	local collapsed = GetCollapsedTable()
	-- Default: groups start collapsed until the user expands them.
	if collapsed[category] == nil then
		return true
	end
	return collapsed[category] and true or false
end

local function RebuildSortedAddonList()
	wipe(sortedAddonList)
	for _, addon in ipairs(masterAddonList) do
		if type(addon) == "table" then
			local category = addon.category
			if category then
				tinsert(sortedAddonList, category)
			end
			if not category or not IsCategoryCollapsed(category) then
				for _, subAddon in ipairs(addon) do
					tinsert(sortedAddonList, subAddon)
				end
			end
		else
			tinsert(sortedAddonList, addon)
		end
	end
end

local function FindAddonIndexByCategoryName(categoryName)
	if not categoryName or categoryName == LIBRARIES_KEY then
		return nil
	end
	local exact
	for i = 1, GetNumAddOns() do
		local name = GetAddOnInfo(i)
		if name == categoryName then
			return i
		end
		if not exact and SpecialCaseName(name) == categoryName then
			exact = i
		end
	end
	return exact
end

local function GetCategoryGroup(category)
	for _, addon in ipairs(masterAddonList) do
		if type(addon) == "table" and addon.category == category then
			return addon
		end
	end
end

local function IsChildAddon(addonIndex)
	for _, addon in ipairs(masterAddonList) do
		if type(addon) == "table" then
			for _, sub in ipairs(addon) do
				if sub == addonIndex then
					return true
				end
			end
		end
	end
	return false
end

local function GetAddonCategoryKey(addonIndex)
	for _, addon in ipairs(masterAddonList) do
		if type(addon) == "table" then
			if addon.main == addonIndex then
				return addon.category
			end
			for _, sub in ipairs(addon) do
				if sub == addonIndex then
					return addon.category
				end
			end
		end
	end
end

local function BuildMasterAddonList()
	wipe(masterAddonList)

	local numAddons = GetNumAddOns()
	local indices = {}
	for i = 1, numAddons do
		tinsert(indices, i)
	end

	table.sort(indices, function(a, b)
		local nameA = SpecialCaseName(GetAddOnInfo(a)):lower()
		local nameB = SpecialCaseName(GetAddOnInfo(b)):lower()
		local catA, restA = SplitFirst(nameA, "_")
		local catB, restB = SplitFirst(nameB, "_")
		restA = restA or ""
		restB = restB or ""
		if catA == catB then
			return restA < restB
		end
		return catA < catB
	end)

	local groups = {}
	local groupOrder = {}
	local ungrouped = {}
	local libraries = { category = LIBRARIES_KEY }

	for _, addonIndex in ipairs(indices) do
		local name = GetAddOnInfo(addonIndex)
		local special = SpecialCaseName(name)
		local aceCategory = GetAddOnMetadata(addonIndex, "X-Category")

		if aceCategory and aceCategory:find("Library") and not PROTECTED_ADDONS[name] then
			tinsert(libraries, addonIndex)
		else
			local category, content = SplitFirst(special, "_")
			if not content then
				tinsert(ungrouped, addonIndex)
			else
				if not groups[category] then
					groups[category] = { category = category }
					tinsert(groupOrder, category)
				end
				tinsert(groups[category], addonIndex)
			end
		end
	end

	-- ACP: main addon named like the category becomes the header row (not a child).
	local ungroupedKept = {}
	for _, index in ipairs(ungrouped) do
		local name = GetAddOnInfo(index)
		local special = SpecialCaseName(name)
		local matchedGroup = groups[name] or groups[special]
		if matchedGroup then
			matchedGroup.main = index
		else
			tinsert(ungroupedKept, index)
		end
	end
	ungrouped = ungroupedKept

	table.sort(ungrouped, function(a, b)
		return SpecialCaseName(GetAddOnInfo(a)):lower() < SpecialCaseName(GetAddOnInfo(b)):lower()
	end)
	table.sort(groupOrder, function(a, b)
		return a:lower() < b:lower()
	end)

	for _, index in ipairs(ungrouped) do
		tinsert(masterAddonList, index)
	end

	for _, key in ipairs(groupOrder) do
		local group = groups[key]
		local childCount = #group
		-- Show as category if there is a main addon + children, or 2+ children alone.
		if (group.main and childCount >= 1) or childCount >= 2 then
			tinsert(masterAddonList, group)
		else
			if group.main then
				tinsert(masterAddonList, group.main)
			end
			for _, child in ipairs(group) do
				tinsert(masterAddonList, child)
			end
		end
	end

	if #libraries > 0 then
		tinsert(masterAddonList, libraries)
	end

	-- Pin SarychUI (and its group, if any) to the top of the list.
	local pinned
	for i = #masterAddonList, 1, -1 do
		local entry = masterAddonList[i]
		local isSarych = false
		if type(entry) == "table" then
			isSarych = entry.category == "SarychUI"
				or (entry.main and GetAddOnInfo(entry.main) == "SarychUI")
		elseif type(entry) == "number" then
			isSarych = GetAddOnInfo(entry) == "SarychUI"
		end
		if isSarych then
			pinned = entry
			table.remove(masterAddonList, i)
			break
		end
	end
	if pinned then
		table.insert(masterAddonList, 1, pinned)
	end

	RebuildSortedAddonList()
end

function AddonList_Collapse_OnClick(entry)
	local category = entry and entry.category
	if not category then
		return
	end
	local collapsed = GetCollapsedTable()
	collapsed[category] = not IsCategoryCollapsed(category)
	PlaySound("UChatScrollButton")
	RebuildSortedAddonList()
	AddonList_Update()
end

function AddonList_EntryOnEnter(entry)
	-- Pure text headers have no addon id; main-addon group rows still show tooltip.
	local id = entry:GetID()
	if entry.category and (not id or id < 1) then
		return
	end
	GameTooltip:SetOwner(entry, "ANCHOR_RIGHT", -270, 0)
	AddonTooltip_Update(entry)
	GameTooltip:Show()
end

local function ResetAddOns()
	if ( not AddonList.save ) then
		local character = UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown);
		local startStatus = AddonList.startStatus;
		for i=1, #startStatus do
			local previousState = startStatus[i]
			local currentState = (GetAddOnEnableState(character, i) > 0);

			if ( currentState ~= previousState ) then
				if ( previousState ) then
					EnableAddOn(i, character);
				else
					DisableAddOn(i, character);
				end
			end
		end
	end
end

local function SaveAddOns()
	-- TODO
end

function AddonList_HasAnyChanged()
	if (AddonList.outOfDate and not IsAddonVersionCheckEnabled() or (not AddonList.outOfDate and IsAddonVersionCheckEnabled() and AddonList_HasOutOfDate())) then
		return true;
	end
	local character = UnitName("player");
	for i=1,GetNumAddOns() do
		local enabled = (GetAddOnEnableState(character, i) > 0);
		local reason = select(5,GetAddOnInfo(i))
		if ( enabled ~= AddonList.startStatus[i] and reason ~= "DEP_DISABLED" ) then
			return true
		end
	end
	return false
end

function AddonList_HasNewVersion()
	local hasNewVersion = false;
	for i=1, GetNumAddOns() do
		local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(i);
		if ( newVersion ) then
			hasNewVersion = true;
			break;
		end
	end
	return hasNewVersion;
end

local function AddonList_Show()
	if not IsAddonListFeatureEnabled() then
		return
	end
	ShowUIPanel(AddonList);
end

local function AddonList_Hide(save)
	AddonList.save = save
	HideUIPanel(AddonList);
end

function AddonList_OnLoad(self)
	-- ESC closes the frame (same as Cancel: discard unsaved enable/disable changes).
	tinsert(UISpecialFrames, self:GetName())

	if ( GetNumAddOns() > 0 ) then
		-- Game Menu button.
		local GameMenuFrame = GameMenuFrame;
		local GameMenuButtonRatings = GameMenuButtonRatings;
		local GameMenuButtonLogout = GameMenuButtonLogout;
		local GameMenuButtonMacros = GameMenuButtonMacros;
		if not GameMenuFrame or not GameMenuButtonMacros or not GameMenuButtonLogout then
			return
		end
		-- Avoid creating a duplicate if we somehow load twice.
		if _G.GameMenuButtonAddons then
			return
		end

		local GameMenuButtonAdded = (GameMenuButtonRatings and GameMenuButtonRatings:IsShown()) and 2 or 1;

		local GameMenuButtonAddons = CreateFrame("Button", "GameMenuButtonAddons", GameMenuFrame, "GameMenuButtonTemplate");
		GameMenuButtonAddons:SetPoint("TOP", GameMenuButtonMacros, "BOTTOM", 0, -1);
		GameMenuButtonAddons:SetText(ADDONS or Private.ADDON_LIST or "AddOns");
		GameMenuButtonAddons:SetScript("OnClick", function()
			if not IsAddonListFeatureEnabled() then
				return
			end
			PlaySound("igMainMenuOption");
			HideUIPanel(GameMenuFrame);
			AddonList_Show();
		end);

		GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + (GameMenuButtonAddons:GetHeight() * GameMenuButtonAdded) + 16);
		GameMenuButtonAddons._sarychMenuHeight = (GameMenuButtonAddons:GetHeight() * GameMenuButtonAdded) + 16;

		if ( GameMenuButtonAdded == 2 ) then
			GameMenuButtonRatings:SetPoint("TOP", GameMenuButtonAddons, "BOTTOM", 0, -1);
			GameMenuFrame:HookScript("OnShow", function()
				if GameMenuButtonAddons:IsShown() then
					GameMenuButtonLogout:SetPoint("TOP", GameMenuButtonRatings, "BOTTOM", 0, -16);
				end
			end);
		else
			GameMenuButtonLogout:SetPoint("TOP", GameMenuButtonAddons, "BOTTOM", 0, -16);
		end

		if not IsAddonListFeatureEnabled() then
			GameMenuButtonAddons:Hide()
			GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() - GameMenuButtonAddons._sarychMenuHeight)
		end
	end
end

function AddonList_Setup(self)
	-- Init OnShow
	local characterName = UnitName("player");

	-- Adjust scroll parent.
	AddonListScrollFrameScrollChildFrame:SetParent(AddonListScrollFrame);

	-- Set default text.
	self.TitleText:SetText(Private.ADDON_LIST);
	AddonListForceLoad.Text:SetText(Private.ADDON_FORCE_LOAD);
	self.EnableAllButton:SetText(Private.ENABLE_ALL_ADDONS);
	self.DisableAllButton:SetText(Private.DISABLE_ALL_ADDONS);

	ButtonFrameTemplate_HidePortrait(self);

	self.offset = 0;

	--self:SetParent(UIParent);
	--self:SetFrameStrata("HIGH");
	self.startStatus = {};
	self.shouldReload = false;
	self.outOfDate = IsAddonVersionCheckEnabled() and AddonList_HasOutOfDate();
	self.outOfDateIndexes = {};
	for i=1,GetNumAddOns() do
		self.startStatus[i] = (GetAddOnEnableState(characterName, i) > 0);
		if (select(5, GetAddOnInfo(i)) == "INTERFACE_VERSION") then
			tinsert(self.outOfDateIndexes, i);
		end
	end

	BuildMasterAddonList()

	local drop = CreateFrame("Frame", "AddonListCharacterDropDown", self, "C_UIDropDownMenuTemplate")
	drop:SetPoint("TOPLEFT", 0, -30)
	UIDropDownMenu_Initialize(drop, AddonListCharacterDropDown_Initialize);
	UIDropDownMenu_SetSelectedValue(drop, characterName);
end

function AddonList_SetStatus(self,lod,status,reload)
	local button = self.LoadAddonButton
	local string = self.Status
	local relstr = self.Reload

	if ( lod ) then
		button:Show()
	else
		button:Hide()
	end

	if ( status ) then
		string:Show()
	else
		string:Hide()
	end

	if ( reload ) then
		relstr:Show()
	else
		relstr:Hide()
	end
end

local function TriStateCheckbox_SetState(checked, checkButton)
	local checkedTexture = _G[checkButton:GetName().."CheckedTexture"];
	if ( not checkedTexture ) then
		message("Can't find checked texture");
	end
	if ( not checked or checked == 0 ) then
		-- nil or 0 means not checked
		checkButton:SetChecked(false);
		checkButton.state = 0;
	elseif ( checked == 2 ) then
		-- 2 is a normal
		checkButton:SetChecked(true);
		checkedTexture:SetVertexColor(1, 1, 1);
		checkedTexture:SetDesaturated(false);
		checkButton.state = 2;
	else
		-- 1 is a gray check
		checkButton:SetChecked(true);
		checkedTexture:SetDesaturated(true);
		checkButton.state = 1;
	end
end

local function RenderAddonRow(entry, addonIndex, category, isChild)
	local characterName = UnitName("player")

	entry.Header:Hide()
	entry.Enabled:Show()
	entry.Title:Show()

	if category then
		entry.category = category
		entry.Collapse:Show()
		-- Collapse left, checkbox to its right.
		entry.Collapse:ClearAllPoints()
		entry.Collapse:SetPoint("LEFT", entry, "LEFT", 4, 0)
		entry.Enabled:ClearAllPoints()
		entry.Enabled:SetPoint("LEFT", entry.Collapse, "RIGHT", 2, 0)
		entry.Title:ClearAllPoints()
		entry.Title:SetPoint("LEFT", entry.Enabled, "RIGHT", 2, 0)
		if IsCategoryCollapsed(category) then
			entry.Collapse.Icon:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
		else
			entry.Collapse.Icon:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")
		end
	else
		entry.category = nil
		entry.Collapse:Hide()
		entry.Enabled:ClearAllPoints()
		entry.Enabled:SetPoint("LEFT", entry, "LEFT", 5, 0)
		entry.Title:ClearAllPoints()
		entry.Title:SetPoint("LEFT", entry, "LEFT", 32, 0)
	end

	local name, title, notes, loadable, reason, security = GetAddOnInfo(addonIndex)

	local character = UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown)
	if character == true then
		character = nil
	end

	local obj = entry.Enabled
	local checkboxState = GetAddOnEnableState(character, addonIndex)
	local enabled = (GetAddOnEnableState(characterName, addonIndex) > 0)
	TriStateCheckbox_SetState(checkboxState, obj)
	if IsProtectedAddOn(addonIndex) then
		obj:Disable()
		obj.tooltip = nil
	else
		obj:Enable()
		if checkboxState == 1 then
			obj.tooltip = Private.ENABLED_FOR_SOME
		else
			obj.tooltip = nil
		end
	end

	obj = entry.Title
	if loadable or (enabled and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED")) then
		obj:SetTextColor(1.0, 0.78, 0.0)
	elseif enabled and reason ~= "DEP_DISABLED" then
		obj:SetTextColor(1.0, 0.1, 0.1)
	else
		obj:SetTextColor(0.5, 0.5, 0.5)
	end

	local label = title or name
	if isChild then
		label = "    " .. label
	end
	-- When collapsed on a main header, show how many children are hidden.
	if category and IsCategoryCollapsed(category) and not isChild then
		local group = GetCategoryGroup(category)
		local count = group and #group or 0
		if count > 0 then
			label = label .. " |cff808080(" .. count .. ")|r"
		end
	end
	obj:SetText(label)

	obj = entry.Status
	if not loadable and reason then
		obj:SetText(_G["ADDON_" .. reason])
	else
		obj:SetText("")
	end

	if enabled ~= AddonList.startStatus[addonIndex] and reason ~= "DEP_DISABLED"
		or (reason ~= "INTERFACE_VERSION" and tContains(AddonList.outOfDateIndexes, addonIndex))
		or (reason == "INTERFACE_VERSION" and not tContains(AddonList.outOfDateIndexes, addonIndex)) then
		if enabled then
			if AddonList_IsAddOnLoadOnDemand(addonIndex) then
				AddonList_SetStatus(entry, true, false, false)
			else
				AddonList_SetStatus(entry, false, false, true)
			end
		else
			AddonList_SetStatus(entry, false, false, true)
		end
	else
		AddonList_SetStatus(entry, false, true, false)
	end

	entry:SetID(addonIndex)
	entry:Show()
end

function AddonList_Update()
	if #sortedAddonList == 0 then
		BuildMasterAddonList()
	end

	local numEntrys = #sortedAddonList
	local entryName = "AddonListEntry"

	for i = 1, MAX_ADDONS_DISPLAYED do
		local listIndex = AddonList.offset + i
		local entryID = entryName .. i
		local entry = _G[entryID]

		if not entry then
			entry = CreateFrame("Button", entryID, AddonList, "AddonListEntryTemplate")
			entry:SetID(i)

			if i == 1 then
				entry:SetPoint("TOPLEFT", AddonList, 10, -70)
			else
				entry:SetPoint("TOP", _G[entryName .. (i - 1)], "BOTTOM", 0, -4)
			end

			entry.Reload:SetText(Private.REQUIRES_RELOAD)
			entry.LoadAddonButton:SetText(Private.LOAD_ADDON)
		end

		local row = sortedAddonList[listIndex]
		if not row then
			entry:Hide()
			entry.category = nil
		elseif type(row) == "string" then
			local mainIndex = FindAddonIndexByCategoryName(row)
			if mainIndex then
				-- ACP: category header IS the main addon (checkbox + collapse).
				RenderAddonRow(entry, mainIndex, row, false)
			else
				-- Pure text category (e.g. Libraries, or prefix with no main addon).
				entry.category = row
				entry:SetID(0)
				entry.Enabled:Hide()
				entry.Title:Hide()
				entry.Status:Hide()
				entry.Reload:Hide()
				entry.LoadAddonButton:Hide()
				entry.Security:Hide()
				entry.Header:Show()
				if row == LIBRARIES_KEY then
					entry.Header:SetText(Private.LIBRARIES or "Libraries")
				else
					entry.Header:SetText(row)
				end
				entry.Header:SetTextColor(1.0, 0.82, 0.0)
				entry.Collapse:Show()
				entry.Collapse:ClearAllPoints()
				entry.Collapse:SetPoint("LEFT", entry, "LEFT", 4, 0)
				entry.Header:ClearAllPoints()
				entry.Header:SetPoint("LEFT", entry.Collapse, "RIGHT", 4, 0)
				if IsCategoryCollapsed(row) then
					entry.Collapse.Icon:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomInButton-Up")
				else
					entry.Collapse.Icon:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up")
				end
				entry:Show()
			end
		else
			RenderAddonRow(entry, row, nil, IsChildAddon(row))
		end
	end

	FauxScrollFrame_Update(AddonListScrollFrame, numEntrys, MAX_ADDONS_DISPLAYED, ADDON_BUTTON_HEIGHT)

	if AddonList_HasAnyChanged() then
		AddonListOkayButton:SetText(Private.RELOADUI)
		AddonList.shouldReload = true
	else
		AddonListOkayButton:SetText(OKAY)
		AddonList.shouldReload = false
	end
	AddonList_FitOkayButton()
end

local OKAY_BUTTON_MIN_WIDTH = 80

function AddonList_FitOkayButton()
	local button = AddonListOkayButton
	if not button then
		return
	end
	local fs = button.GetFontString and button:GetFontString()
	if not fs then
		fs = _G[button:GetName() .. "Text"]
	end
	local textWidth = (fs and fs.GetStringWidth and fs:GetStringWidth()) or 0
	-- Horizontal padding so the label is not flush with the button art.
	local width = math.max(OKAY_BUTTON_MIN_WIDTH, math.ceil(textWidth + 32))
	button:SetWidth(width)
end

function AddonList_IsAddOnLoadOnDemand(index)
	local lod = false
	if ( IsAddOnLoadOnDemand(index) ) then

		local deps = GetAddOnDependencies(index)
		local okay = true;
		for i = 1, select('#', deps) do
			local dep = select(i, deps)
			if ( dep and not IsAddOnLoaded(select(i, deps)) ) then
				okay = false;
				break;
			end
		end
		lod = okay;
	end
	return lod;
end

function AddonList_Enable(index, enabled)
	local character = UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown);
	if IsProtectedAddOn(index) then
		-- Keep SarychUI / ClassicAPI always on.
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		EnableAddOn(index, character);
		AddonList_Update();
		return
	end
	if ( enabled ) then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		EnableAddOn(index,character);
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF);
		DisableAddOn(index,character);
	end

	-- Enabling or disabling the main addon applies the same state to every child.
	local name = GetAddOnInfo(index)
	local group = GetCategoryGroup(name) or GetCategoryGroup(SpecialCaseName(name))
	if group and group.main == index then
		for _, childIndex in ipairs(group) do
			if not IsProtectedAddOn(childIndex) then
				if enabled then
					EnableAddOn(childIndex, character)
				else
					DisableAddOn(childIndex, character)
				end
			end
		end
	end

	AddonList_Update();
end

function AddonList_EnableAll(self, button, down)
	local character = UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown);
	EnableAllAddOns(character);
	ProtectCoreAddOns(character);
	AddonList_Update();
end

function AddonList_DisableAll(self, button, down)
	local character = UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown);
	DisableAllAddOns(character);
	ProtectCoreAddOns(character);
	AddonList_Update();
end

function AddonList_LoadAddOn(index)
	if ( not AddonList_IsAddOnLoadOnDemand(index) ) then return end
	LoadAddOn(index)
	if ( IsAddOnLoaded(index) ) then
		AddonList.startStatus[index] = true
	end
	AddonList_Update()
end

function AddonList_OnOkay()
	PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK);
	AddonList_Hide(true);
	if ( AddonList.shouldReload ) then
		ReloadUI();
	end
end

function AddonList_OnCancel()
	AddonList_Hide(false);
end

function AddonListScrollFrame_OnVerticalScroll(self, offset)
	local scrollbar = _G[self:GetName().."ScrollBar"];
	scrollbar:SetValue(offset);
	AddonList.offset = floor((offset / ADDON_BUTTON_HEIGHT) + 0.5);
	AddonList_Update();
	if ( GameTooltip:IsShown() ) then
		AddonTooltip_Update(GameTooltip:GetOwner(), true);
		GameTooltip:Show()
	end
end

function AddonList_OnShow(self)
	if not IsAddonListFeatureEnabled() then
		HideUIPanel(self)
		return
	end
	if ( not self.startStatus ) then
		AddonList_Setup(self);
	else
		UIDropDownMenu_Initialize(AddonListCharacterDropDown, AddonListCharacterDropDown_Initialize);
		UIDropDownMenu_SetSelectedValue(AddonListCharacterDropDown, UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown));
		BuildMasterAddonList()
	end
	AddonList_Update();
end

function AddonList_OnHide(self)
	PlaySound("UChatScrollButton");
	if ( self.save ) then
		SaveAddOns();
	else
		ResetAddOns();
	end
	self.save = false;
end

function AddonList_HasOutOfDate()
	local hasOutOfDate = false;
	local character = UnitName("player");
	for i=1, GetNumAddOns() do
		local name, title, notes, loadable, reason = GetAddOnInfo(i);
		local enabled = (GetAddOnEnableState(character, i) > 0);
		if ( enabled and not loadable and reason == "INTERFACE_VERSION" ) then
			hasOutOfDate = true;
			break;
		end
	end
	return hasOutOfDate;
end

function AddonList_SetSecurityIcon(texture, index)
	local width = 64;
	local height = 16;
	local iconWidth = 16;
	local increment = iconWidth/width;
	local left = (index - 1) * increment;
	local right = index * increment;
	texture:SetTexCoord( left, right, 0, 1.0);
end

function AddonList_DisableOutOfDate()
	local character = UnitName("player");
	for i=1, GetNumAddOns() do
		local name, title, notes, loadable, reason = GetAddOnInfo(i);

		local enabled = (GetAddOnEnableState(character , i) > 0);
		if ( enabled and not loadable and reason == "INTERFACE_VERSION" ) then
			DisableAddOn(i, true);			
		end
	end
	SaveAddOns();
end

--[[function AddonListCharacterDropDown_OnClick(self)
	UIDropDownMenu_SetSelectedValue(AddonListCharacterDropDown, self.value);
	AddonList_Update();
end]]

function AddonListCharacterDropDown_Initialize()
	local selectedValue = nil -- UIDropDownMenu_GetSelectedValue(AddonListCharacterDropDown);
	local info = UIDropDownMenu_CreateInfo();
	info.text = ALL;
	info.value = true;
	info.disabled = true;
	--info.func = AddonListCharacterDropDown_OnClick;
	--info.checked = (selectedValue) and nil or 1;
	UIDropDownMenu_AddButton(info);

	local info = UIDropDownMenu_CreateInfo();
	info.text = UnitName("player");
	info.value = info.text
	info.checked = (selectedValue == info.value) and 1 or nil;
	UIDropDownMenu_AddButton(info);
end

function AddonTooltip_BuildDeps(...)
	local deps = "";
	for i=1, select("#", ...) do
		if ( i == 1 ) then
			deps = Private.ADDON_DEPENDENCIES .. select(i, ...);
		else
			deps = deps..", "..select(i, ...);
		end
	end
	return deps;
end

function AddonTooltip_Update(owner, scrolling)
	local index = owner:GetID();
	-- Skip pure category headers (Libraries / prefix-only); main-addon headers have a real id.
	if ( not index or index < 1 ) then
		return
	end
	local name, title, notes, loadable, reason, security = GetAddOnInfo(index);

	GameTooltip:ClearLines();

	if ( security == "BANNED" ) then
		GameTooltip:SetText(ADDON_BANNED_TOOLTIP);
	else
		GameTooltip:AddLine(title or name);

		GameTooltip:AddLine(notes, 1, 1, 1);
		GameTooltip:AddLine(AddonTooltip_BuildDeps(GetAddOnDependencies(index)));

		if ( reason ~= "DEMAND_LOADED" ) then
			local author = GetAddOnMetadata(index, "Author");
			local version = GetAddOnMetadata(index, "Version");
			if ( author or version ) then
				GameTooltip:AddLine(" ");

				if ( author ) then
					GameTooltip:AddLine("Author: "..author, .7, .7, .7);
				end

				if ( version ) then
					GameTooltip:AddLine("Version: "..version, .7, .7, .7);
				end
			end
		end

		if ( loadable ) then
			local now = GetTime();
			if ( not MEMORY_QUERY_THROTTLE or (not scrolling and (now - MEMORY_QUERY_THROTTLE) > 10) ) then
				UpdateAddOnMemoryUsage();
				MEMORY_QUERY_THROTTLE = now;
			end

			local memory, string = GetAddOnMemoryUsage(index);
			if ( memory > 1000 ) then
				memory = memory / 1000;
				string = TOTAL_MEM_MB_ABBR;
			else
				string = TOTAL_MEM_KB_ABBR;
			end
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine(format(string, memory));
		elseif ( reason ) then
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine(_G["ADDON_"..reason]);
		end
	end

	GameTooltip:Show()
end

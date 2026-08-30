-- SarychUI Options Core — custom Details-like settings (perf-first).
-- AceConfig tables = DATA only. No AceGUI visuals. No ENP in this window.
local SUI = SarychUI
local ADDON_NAME = "SarychUI"

SUI.OptionsCore = SUI.OptionsCore or {}
local OC = SUI.OptionsCore

local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tonumber = tonumber
local tinsert = table.insert
local sort = table.sort
local pcall = pcall
local math = math
local CreateFrame = CreateFrame
local debugprofilestart = debugprofilestart
local debugprofilestop = debugprofilestop

local T = SUI.OptionsTheme
local R = SUI.OptionsRenderer
local OW = SUI.OptionsWindow

OC._sections = OC._sections or {}
OC._sectionOrder = OC._sectionOrder or {}
OC._tabState = OC._tabState or {} -- [sectionId] = tabKey
OC._subTabState = OC._subTabState or {} -- [sectionId .. "/" .. tabKey] = subTabKey
OC._addonListSelected = nil -- selected addon key inside Аддоны → Список
OC._addonListTabState = OC._addonListTabState or {} -- [addonKey] = nested tab key
OC._addonListScroll = 0 -- left list vertical scroll offset
OC._twoPaneSelected = OC._twoPaneSelected or {} -- [pathKey] = selected child key
OC._twoPaneScroll = OC._twoPaneScroll or {} -- [pathKey] = scroll offset
OC._currentId = nil
OC._currentTabKey = nil
OC._currentSubTabKey = nil
OC._open = false
OC._navBuilt = false
OC._structureDirty = true

-- Profiling (enable: /run SarychUI_OPTIONS_DEBUG=true)
OC._perf = OC._perf or {
	created = 0,
	reused = 0,
	refresh = 0,
	getCalls = 0,
	hiddenCalls = 0,
	disabledCalls = 0,
}

local function DebugEnabled()
	return _G.SarychUI_OPTIONS_DEBUG == true
		or (SUI.db and SUI.db.global and SUI.db.global.debugOptions)
end

local function PerfStart()
	if debugprofilestart then debugprofilestart() end
	return debugprofilestop and debugprofilestop() or 0
end

local function PerfMs(t0)
	if not debugprofilestop then return 0 end
	return debugprofilestop() - (t0 or 0)
end

local function DebugPrint(...)
	if DebugEnabled() then
		print("|cff66ccffSUI Options:|r", ...)
	end
end

local function Safe(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function ResolveName(opt)
	if not opt then return "" end
	local n = opt.name
	if type(n) == "function" then n = Safe(n) end
	n = n and tostring(n) or ""
	if n ~= "" and SUI and SUI.T then
		n = SUI:T(n)
	end
	return n
end

local function IsHidden(opt)
	OC._perf.hiddenCalls = OC._perf.hiddenCalls + 1
	if not opt then return true end
	local h = opt.hidden
	if type(h) == "function" then return Safe(h) and true or false end
	return h and true or false
end

-----------------------------------------------------------------------
-- Data source
-----------------------------------------------------------------------
function OC:GetRootOptionsTable()
	if SUI._customOptionsRoot then
		return SUI._customOptionsRoot
	end
	local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
	if not reg or not reg.GetOptionsTable then
		return nil
	end
	return reg:GetOptionsTable(ADDON_NAME, "dialog", "SarychUIOptionsCore")
end

local function SortedGroupArgs(args)
	local list = {}
	if type(args) ~= "table" then return list end
	for k, v in pairs(args) do
		if type(v) == "table" and v.type == "group" and not v.inline and not IsHidden(v) then
			tinsert(list, { key = k, order = tonumber(v.order) or 100, opt = v })
		end
	end
	sort(list, function(a, b)
		if a.order == b.order then return tostring(a.key) < tostring(b.key) end
		return a.order < b.order
	end)
	return list
end

-- Nested groups that should become content tabs (not left-nav children).
function OC:GetTabGroups(opt)
	if not opt or type(opt.args) ~= "table" then return {} end
	if opt.childGroups == "tree" then return {} end
	local groups = SortedGroupArgs(opt.args)
	if #groups < 1 then return {} end
	if opt.childGroups == "tab" or opt.childGroups == "tabs" or #groups >= 2 then
		for _, g in ipairs(groups) do
			g.label = ResolveName(g.opt)
		end
		return groups
	end
	return {}
end

-----------------------------------------------------------------------
-- Section registry (SarychUI only — never ENP)
-----------------------------------------------------------------------
function OC:ClearSections()
	for k in pairs(self._sections) do
		self._sections[k] = nil
	end
	for i = #self._sectionOrder, 1, -1 do
		self._sectionOrder[i] = nil
	end
	self._navBuilt = false
end

function OC:RegisterSection(id, data)
	if not id or not data then return end
	if not self._sections[id] then
		tinsert(self._sectionOrder, id)
	end
	self._sections[id] = data
end

function OC:BuildSectionsFromAce()
	local t0 = PerfStart()
	self:ClearSections()

	local root = self:GetRootOptionsTable()
	if root and root.args then
		local tops = SortedGroupArgs(root.args)
		-- Also include top-level groups that SortedGroupArgs already filters.
		-- Re-scan tops from root.args with group type (SortedGroupArgs skips inline).
		for _, top in ipairs(tops) do
			local topId = "sui:" .. top.key
			local childGroups = top.opt.childGroups
			local children = SortedGroupArgs(top.opt.args)

			-- Аддоны: один пункт nav (как Система) — сразу two-pane список, без «Управление».
			if top.key == "addons" then
				local ported = top.opt.args and top.opt.args.ported
				self:RegisterSection(topId, {
					id = topId,
					label = ResolveName(top.opt),
					depth = 0,
					opt = ported or top.opt,
					path = ported and { top.key, "ported" } or { top.key },
					isAddonList = true,
				})
			-- Left nav: children of tree/modules/general become nav items.
			-- Система (system) stays one nav item with content tabs.
			elseif #children > 0 and (childGroups == "tree" or top.key == "modules" or top.key == "general") then
				self:RegisterSection(topId, {
					id = topId,
					label = ResolveName(top.opt),
					depth = 0,
					opt = top.opt,
					path = { top.key },
					isParent = true,
				})
				for _, child in ipairs(children) do
					local childId = topId .. "/" .. child.key
					self:RegisterSection(childId, {
						id = childId,
						label = ResolveName(child.opt),
						depth = 1,
						opt = child.opt,
						path = { top.key, child.key },
					})
				end
			else
				self:RegisterSection(topId, {
					id = topId,
					label = ResolveName(top.opt),
					depth = 0,
					opt = top.opt,
					path = { top.key },
				})
			end
		end
	else
		self:RegisterSection("sui:fallback", {
			id = "sui:fallback",
			label = "SarychUI",
			depth = 0,
			opt = { type = "group", args = {}, name = "SarychUI" },
			path = {},
		})
	end

	self._structureDirty = false
	DebugPrint(string.format("BuildSections: %.2f ms, sections=%d", PerfMs(t0), #self._sectionOrder))
end

function OC:RebuildNav()
	local t0 = PerfStart()
	local OW = SUI.OptionsWindow
	if not OW then return end
	OW:CreateRoot()
	OW:ClearNav()
	for _, id in ipairs(self._sectionOrder) do
		local sec = self._sections[id]
		if sec then
			OW:AddNavItem(id, sec.label, sec.depth or 0, function(clickedId)
				OC:SelectSection(clickedId)
			end)
		end
	end
	self._navBuilt = true
	DebugPrint(string.format("BuildNav: %.2f ms, items=%d", PerfMs(t0), #self._sectionOrder))
end

function OC:InvalidateStructure()
	self._structureDirty = true
	self._navBuilt = false
end

-----------------------------------------------------------------------
-- Content render (section + optional tabs)
-----------------------------------------------------------------------
function OC:RenderCurrentContent()
	local id = self._currentId
	local sec = id and self._sections[id]
	if not sec then return end

	local OW = SUI.OptionsWindow
	local R = SUI.OptionsRenderer
	if not OW or not R then return end

	local t0 = PerfStart()
	OC._perf.created = 0
	OC._perf.reused = 0

	-- AceConfig inheritance (parent get/set/disabled) needs the live root table.
	local root = self:GetRootOptionsTable()
	if type(root) == "function" then
		local ok, tbl = pcall(root, "dialog", "SarychUIOptionsCore")
		if ok and type(tbl) == "table" then
			root = tbl
		end
	end
	if type(root) == "table" then
		SUI._activeAceOptionsRoot = root
	end
	SUI._activeOptionsCore = self

	OW:ClearContent()
	local child = OW.contentChild
	if child and OW.contentScroll then
		child:SetWidth(math.max(200, (OW.contentScroll:GetWidth() or 600) - 4))
	end

	local opt = sec.opt
	local path = sec.path or {}

	-- Special: Аддоны — two-pane (left names / right settings).
	if sec.isAddonList or id == "sui:addons" or id == "sui:addons/ported" then
		OW:HideTabs()
		self._currentTabKey = nil
		R:RenderTwoPaneAddonList(OW.contentChild, opt, path)
		DebugPrint(string.format(
			"RenderAddonList(%s): %.2f ms, selected=%s",
			tostring(id), PerfMs(t0), tostring(self._addonListSelected)
		))
		return
	end

	local tabs = self:GetTabGroups(opt)
	local tabBarExtra = opt and (opt.suiTabBarExtras or opt.suiTabBarExtra) or nil

	if #tabs > 0 then
		local saved = self._tabState[id]
		local activeKey = self._currentTabKey
		if not activeKey then
			activeKey = saved
		end
		local found
		for _, tab in ipairs(tabs) do
			if tab.key == activeKey then found = tab break end
		end
		if not found then
			activeKey = tabs[1].key
			found = tabs[1]
		end
		self._currentTabKey = activeKey
		self._tabState[id] = activeKey

		-- Prefer per-tab extras (e.g. SpeedyLoad enable on «Быстрая загрузка»).
		local activeTabExtra = found and found.opt and (found.opt.suiTabBarExtras or found.opt.suiTabBarExtra) or nil
		local effectiveTabBarExtra = activeTabExtra or tabBarExtra

		OW:SetTabs(tabs, activeKey, function(tabKey)
			OC._currentTabKey = tabKey
			OC._tabState[id] = tabKey
			OC._currentSubTabKey = nil -- resolve from saved subtab state for new tab
			OC:RenderCurrentContent()
		end, effectiveTabBarExtra)

		local tabPath = {}
		for i = 1, #path do tabPath[i] = path[i] end
		tinsert(tabPath, found.key)

		-- Two-pane list tabs (e.g. Миникарта → Кнопки аддонов).
		if found.opt and found.opt.suiTwoPane then
			OW:SetSubTabs(nil)
			self._currentSubTabKey = nil
			R:RenderTwoPaneAddonList(OW.contentChild, found.opt, tabPath)
			DebugPrint(string.format(
				"RenderTwoPaneTab(%s/%s): %.2f ms",
				tostring(id), tostring(activeKey), PerfMs(t0)
			))
			return
		end

		-- Second-level subtabs inside the selected tab (non-inline groups only).
		local subtabs = self:GetTabGroups(found.opt)
		if #subtabs > 0 then
			local subStateKey = id .. "/" .. activeKey
			local savedSub = self._subTabState[subStateKey]
			local subKey = self._currentSubTabKey or savedSub
			local subFound
			for _, st in ipairs(subtabs) do
				if st.key == subKey then subFound = st break end
			end
			if not subFound then
				subKey = subtabs[1].key
				subFound = subtabs[1]
			end
			self._currentSubTabKey = subKey
			self._subTabState[subStateKey] = subKey

			local subPath = {}
			for i = 1, #tabPath do subPath[i] = tabPath[i] end
			tinsert(subPath, subFound.key)

			-- Subtab two-pane with shared header (Ауры → Настройки заклинаний):
			-- add-spell row first, then type subtabs in content, then two-pane list.
			if subFound.opt and subFound.opt.suiTwoPane then
				OW:SetSubTabs(nil) -- subtabs live inside content, under the add block
				local theme = SUI.OptionsTheme
				local contentPad = (theme and theme.sizes and theme.sizes.contentPad) or 4
				local y = -contentPad
				local child = OW.contentChild

				-- Shared parent controls (add spell one-row).
				if found.opt and type(found.opt.args) == "table" then
					local shared = {}
					for k, v in pairs(found.opt.args) do
						if type(v) == "table" and v.type then
							local isTabGroup = v.type == "group" and not v.inline and not v.dialogInline and not v.guiInline
							if not isTabGroup then
								tinsert(shared, { key = k, order = tonumber(v.order) or 100, opt = v })
							end
						end
					end
					sort(shared, function(a, b)
						if a.order == b.order then return tostring(a.key) < tostring(b.key) end
						return a.order < b.order
					end)
					for _, entry in ipairs(shared) do
						local childPath = {}
						for i = 1, #tabPath do childPath[i] = tabPath[i] end
						tinsert(childPath, entry.key)
						y = R:RenderControl(child, entry.key, entry.opt, childPath, y, contentPad)
					end
					y = y - 4
				end

				-- Type subtabs (cc / cast / …) under the add block.
				local subBarH = 0
				if OW.RenderInlineSubTabs then
					subBarH = OW:RenderInlineSubTabs(child, y, subtabs, subKey, function(subTabKey)
						if OC._currentSubTabKey == subTabKey then
							return
						end
						OC._currentSubTabKey = subTabKey
						OC._subTabState[subStateKey] = subTabKey
						-- Keep add-row type select in sync with the active type tab.
						if found.opt and found.opt.args and found.opt.args.addSpell then
							local add = found.opt.args.addSpell
							if add._syncSpellType then
								add._syncSpellType(subTabKey)
							end
						end
						OC:RenderCurrentContent()
					end) or 0
				end
				y = y - subBarH - 6

				local listOpt = { type = "group", args = {} }
				if type(subFound.opt.args) == "table" then
					for k, v in pairs(subFound.opt.args) do
						listOpt.args[k] = v
					end
				end
				-- Host frame for the two-pane so it starts below add+subtabs.
				local listHost = CreateFrame("Frame", nil, child)
				listHost:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
				listHost:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
				local hostW = child:GetWidth()
				if hostW and hostW > 80 then
					listHost:SetWidth(hostW)
				end
				R:RenderTwoPaneAddonList(listHost, listOpt, subPath)
				-- Keep page height = scroll viewport so only the two panes scroll.
				local scrollH = (OW.contentScroll and OW.contentScroll:GetHeight()) or 0
				if scrollH > 40 then
					child:SetHeight(scrollH)
				else
					local lh = listHost:GetHeight() or 40
					child:SetHeight(math.max(40, -y + lh + 8))
				end
				if OW.SetContentScrollLocked then
					OW:SetContentScrollLocked(true)
				end
			else
				OW:SetSubTabs(subtabs, subKey, function(subTabKey)
					OC._currentSubTabKey = subTabKey
					OC._subTabState[subStateKey] = subTabKey
					OC:RenderCurrentContent()
				end)
				R:RenderSection(OW.contentChild, subFound.opt, subPath)
			end
		else
			OW:SetSubTabs(nil)
			self._currentSubTabKey = nil
			R:RenderSection(OW.contentChild, found.opt, tabPath)
		end
	elseif tabBarExtra then
		-- No content tabs, but enable (and maybe other extras) stay on the tab bar.
		-- If the module is on, render root inline blocks / controls in the body.
		-- If everything is hidden (module off), show the disabled notice on the bar.
		OW:SetTabs({}, nil, nil, tabBarExtra)
		self._currentTabKey = nil
		self._currentSubTabKey = nil

		local hasVisibleContent = false
		if opt and type(opt.args) == "table" then
			for k, v in pairs(opt.args) do
				if k ~= "disabledNotice" and type(v) == "table" and v.type and not IsHidden(v) then
					hasVisibleContent = true
					break
				end
			end
		end

		if hasVisibleContent then
			local title = opt and opt.suiTabBarTitle
			if type(title) == "function" then
				local ok, v = pcall(title)
				title = ok and v or nil
			end
			if type(title) ~= "string" or title == "" then
				title = nil
			end
			OW._tabBarNoticeText = title
			if title and OW.SetTabBarNotice then
				OW:SetTabBarNotice(title)
			elseif OW.ClearTabBarNotice then
				OW:ClearTabBarNotice()
			end
			R:RenderSection(OW.contentChild, opt, path)
		else
			local notice
			if opt and opt.args and opt.args.disabledNotice then
				local n = opt.args.disabledNotice.name
				if type(n) == "function" then
					local ok, v = pcall(n)
					notice = ok and v or nil
				else
					notice = n
				end
			end
			notice = notice or (SUI.L and SUI.L["Module_Disabled_Notice"])
				or "Модуль выключен. Включите модуль, чтобы открыть его настройки."
			OW._tabBarNoticeText = notice
			if OW.SetTabBarNotice then
				OW:SetTabBarNotice(notice)
			end
			if OW.contentChild then
				OW.contentChild:SetHeight(1)
			end
		end
	else
		OW:HideTabs()
		self._currentTabKey = nil
		self._currentSubTabKey = nil
		R:RenderSection(OW.contentChild, opt, path)
	end

	DebugPrint(string.format(
		"RenderSection(%s): %.2f ms, created=%d reused=%d",
		tostring(id), PerfMs(t0), OC._perf.created, OC._perf.reused
	))
end

function OC:SelectSection(id)
	local sec = self._sections[id]
	if not sec then return end
	-- Parent overview: jump to first child if any.
	if sec.isParent then
		local prefix = id .. "/"
		for _, sid in ipairs(self._sectionOrder) do
			if sid:sub(1, #prefix) == prefix then
				id = sid
				sec = self._sections[id]
				break
			end
		end
	end
	if not sec then return end

	self._currentId = id
	self._currentTabKey = self._tabState[id]
	self._currentSubTabKey = nil -- restored from _subTabState after main tab resolves

	local OW = SUI.OptionsWindow
	if OW then
		OW:SetActiveNav(id)
		-- Content section title removed everywhere (nav already shows the name).
		OW:SetSectionTitleVisible(false)
	end
	self:RenderCurrentContent()
end

-- Switch content tab inside the current section (e.g. Сумки → Стандартные сумки).
function OC:SelectTab(tabKey)
	if not tabKey or not self._currentId then
		return
	end
	self._currentTabKey = tabKey
	self._tabState[self._currentId] = tabKey
	self._currentSubTabKey = nil
	self:RenderCurrentContent()
end

-- CRITICAL: do NOT full-rebuild UI on every set (was the main lag source).
function OC:OnSettingChanged()
	-- Intentionally empty for value commits.
	-- Widgets already show the new value; hidden/disabled edge cases
	-- can call InvalidateStructure + Refresh manually if needed.
	OC._perf.refresh = OC._perf.refresh + 1
end

function OC:Refresh()
	if not self._open then return end
	-- Full rebuild mid-drag/edit destroys the active widget (slider capture / focus).
	if SUI._optionsSliderDragging or SUI._optionsTextEditing then
		SUI._pendingOptionsRefresh = true
		return
	end
	-- Full rebuild destroys open dropdown menus (Bags mode select, etc.).
	if SUI.OptionsWidgets and SUI.OptionsWidgets.IsDropdownOpen and SUI.OptionsWidgets:IsDropdownOpen() then
		self._refreshAfterDropdown = true
		return
	end
	local OW = SUI.OptionsWindow
	if OW and self._currentId and OW.SetActiveNav then
		OW:SetActiveNav(self._currentId)
	end

	-- Preserve content scroll across structure refreshes (toggles/rebuilds).
	-- Tab/section switches call RenderCurrentContent directly and correctly reset.
	local savedScroll
	if OW and OW.contentScroll and not OW._contentScrollLocked then
		savedScroll = OW.contentScroll:GetVerticalScroll() or 0
	end

	self:RenderCurrentContent()

	if savedScroll and OW and OW.contentScroll then
		local function applyScroll()
			local scroll = OW.contentScroll
			if not scroll or OW._contentScrollLocked then
				return
			end
			local max = scroll:GetVerticalScrollRange() or 0
			local y = savedScroll
			if y > max then y = max end
			if y < 0 then y = 0 end
			scroll:SetVerticalScroll(y)
		end
		applyScroll()
		-- Range/height often settles one frame after widgets layout.
		local f = CreateFrame("Frame")
		local frames = 0
		f:SetScript("OnUpdate", function(self)
			frames = frames + 1
			applyScroll()
			if frames >= 2 then
				self:SetScript("OnUpdate", nil)
			end
		end)
	end
end

function OC:EnsureStructure()
	if self._structureDirty or not self._navBuilt or #self._sectionOrder == 0 then
		self:BuildSectionsFromAce()
		self:RebuildNav()
	end
end

function OC:IsOpen()
	return self._open and SUI.OptionsWindow and SUI.OptionsWindow:IsShown()
end

function OC:EnsureDataReady()
	-- Register Ace tables once (modules/addons/profiles). Never touch ENP here.
	if SUI.InitializeOptions and not SUI._optionsTableRegistered then
		SUI:InitializeOptions()
	end
	if SUI.BuildOptionsTable then
		SUI:BuildOptionsTable()
	end
	if SUI.EnsureAddOnOptions then
		SUI:EnsureAddOnOptions()
	end
end

function OC:Open()
	local tOpen = PerfStart()
	if SUI.IsPlayerInCombat and SUI:IsPlayerInCombat() then
		if SUI.PrintOptionsUnavailableInCombat then
			SUI:PrintOptionsUnavailableInCombat()
		end
		return
	end

	self:EnsureDataReady()

	if SUI.CloseGladiusExConfig then SUI:CloseGladiusExConfig() end
	if SUI.CloseMapsterConfig then SUI:CloseMapsterConfig() end
	if SUI.CloseCarboniteConfig then SUI:CloseCarboniteConfig() end
	if SUI.CloseNamePlatesConfig then SUI:CloseNamePlatesConfig() end
	local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
	if ACD and ACD.OpenFrames and ACD.OpenFrames[ADDON_NAME] then
		ACD:Close(ADDON_NAME)
	end

	local OW = SUI.OptionsWindow
	if not OW then
		print("|cffffd200SarychUI:|r OptionsWindow not loaded.")
		return
	end

	OW:CreateRoot()
	self:EnsureStructure()

	local first = self._currentId
	if not first or not self._sections[first] then
		-- Prefer first non-parent leaf.
		for _, sid in ipairs(self._sectionOrder) do
			local s = self._sections[sid]
			if s and not s.isParent then
				first = sid
				break
			end
		end
		first = first or self._sectionOrder[1]
	end

	OW:Show()
	self._open = true
	if first then
		self:SelectSection(first)
	end

	DebugPrint(string.format("Open: %.2f ms", PerfMs(tOpen)))
end

function OC:Close()
	self._open = false
	if SUI.OptionsWindow then
		SUI.OptionsWindow:Hide()
	end
	if not SUI._optionsClosing and SUI.OnSarychUIConfigHidden then
		SUI:OnSarychUIConfigHidden()
	end
end

function OC:Toggle()
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end

function SUI:OpenCustomOptions()
	self.OptionsCore:Open()
end

function SUI:CloseCustomOptions()
	self.OptionsCore:Close()
end

function SUI:ToggleCustomOptions()
	self.OptionsCore:Toggle()
end

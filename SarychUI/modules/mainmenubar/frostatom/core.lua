-- SarychUI: FrostAtomUI action bars (ported).
-- Minimal runtime shim replacing the FrostAtomUI `ns` framework pieces the
-- action bar code depends on: media, event mixin, faders,
-- module registry and config access.
-- Config lives in SarychUI.db.profile.modules.mainmenubar.frostatom.

local FA = {}
SarychUI.FrostAtomBars = FA

local floor, abs, min = math.floor, math.abs, math.min
local tremove = table.remove
local InCombatLockdown = InCombatLockdown

FA.PLAYER_CLASS = select(2, UnitClass("player"))

--------------------------------------------------------------------
-- Media
--------------------------------------------------------------------
FA.Media = {
	blank = "Interface\\Buttons\\WHITE8x8",
	statusbar = "Interface\\Buttons\\WHITE8x8",
	border = "Interface\\Tooltips\\UI-Tooltip-Border",
	questionMark = "Interface\\Icons\\INV_Misc_QuestionMark",
}

--------------------------------------------------------------------
-- Small utilities
--------------------------------------------------------------------
function FA.noop() end

function FA.SetShown(region, shown)
	if shown then
		region:Show()
	else
		region:Hide()
	end
end

function FA.Mixin(target, ...)
	for i = 1, select("#", ...) do
		local source = select(i, ...)
		for key, value in pairs(source) do
			target[key] = value
		end
	end
	return target
end

function FA.tContains(tbl, item)
	for i = 1, #tbl do
		if tbl[i] == item then
			return i
		end
	end
end

function FA.tDeleteItem(tbl, item)
	local index = FA.tContains(tbl, item)
	if index then
		return tremove(tbl, index)
	end
end

local destroyFrame

local function destroyChildren(child, ...)
	if child then
		destroyFrame(child)
		return destroyChildren(...)
	end
end

function destroyFrame(frame, deep)
	if not frame then
		return
	end
	frame:Hide()
	frame:SetScript("OnShow", frame.Hide)
	frame:UnregisterAllEvents()
	if deep then
		destroyChildren(frame:GetChildren())
	end
end
FA.DestroyFrame = destroyFrame

function FA.GridPoint(point, i, perRow, size)
	i = i - 1
	local column, row = i % perRow, floor(i / perRow)
	local xSign = point:find("RIGHT") and -1 or 1
	local ySign = point:find("BOTTOM") and 1 or -1
	return point, xSign * column * size, ySign * row * size
end

-- One physical pixel in UI units of `region` (defaults to UIParent).
function FA.PixelPerfect(pixels, region)
	local _, physH = (GetCVar("gxResolution") or ""):match("^(%d+)x(%d+)")
	physH = tonumber(physH)
	region = region or UIParent
	if region and not region.GetEffectiveScale then
		region = region:GetParent()
	end
	local scale = region and region:GetEffectiveScale() or 1
	if not physH or physH <= 0 or not scale or scale <= 0 then
		return pixels
	end
	return pixels * 768 / physH / scale
end

function FA.CreateBackdrop(edgeSize, inset)
	inset = inset or FA.PixelPerfect(1)
	return {
		edgeFile = FA.Media.border,
		edgeSize = edgeSize or 8,
		bgFile = FA.Media.blank,
		insets = { top = inset, bottom = inset, left = inset, right = inset },
	}
end

local PRINT_PREFIX = "|cffffd200SarychUI Панели команд:|r "
function FA.Print(format, ...)
	local prefix, text = PRINT_PREFIX, format
	if SarychUI and SarychUI.T then
		prefix = SarychUI:T(PRINT_PREFIX)
		text = SarychUI:T(format)
	end
	if select("#", ...) > 0 then
		print(prefix .. text:format(...))
	else
		print(prefix .. tostring(text))
	end
end

--------------------------------------------------------------------
-- Event mixin (ported FrostAtomUI Core/Events.lua)
--------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local callbacks = {}
local unitCallbacks = {}
local registrations = {}

local function resolveHandler(owner, event, handler)
	handler = handler or event
	if type(handler) ~= "function" then
		local method = owner[handler]
		assert(type(method) == "function", ("no method [%s] for event %s"):format(tostring(handler), event))
		handler = method
	end
	return handler
end

local function retain(event)
	local count = registrations[event] or 0
	if count == 0 then
		eventFrame:RegisterEvent(event)
	end
	registrations[event] = count + 1
end

local function release(event, count)
	if count == 0 then
		return
	end
	local remaining = (registrations[event] or 0) - count
	if remaining < 0 then remaining = 0 end
	registrations[event] = remaining
	if remaining == 0 then
		eventFrame:UnregisterEvent(event)
	end
end

local function newList()
	return { firing = 0, dirty = false }
end

local function findRecord(list, owner, handler)
	for i = 1, #list do
		local record = list[i]
		if record.owner == owner and record.handler == handler and not record.removed then
			return record, i
		end
	end
end

local function compact(list)
	local n = 0
	for i = 1, #list do
		local record = list[i]
		list[i] = nil
		if not record.removed then
			n = n + 1
			list[n] = record
		end
	end
	list.dirty = false
end

local function addRecord(list, owner, event, handler)
	if findRecord(list, owner, handler) then
		return
	end
	list[#list + 1] = { owner = owner, handler = handler }
	retain(event)
end

local function removeRecord(list, owner, handler)
	local record, index = findRecord(list, owner, handler)
	if not record then
		return 0
	end
	record.removed = true
	if list.firing == 0 then
		tremove(list, index)
	else
		list.dirty = true
	end
	return 1
end

local function removeOwner(list, owner)
	local removed = 0
	for i = 1, #list do
		local record = list[i]
		if record.owner == owner and not record.removed then
			record.removed = true
			removed = removed + 1
		end
	end
	if removed > 0 then
		if list.firing == 0 then
			compact(list)
		else
			list.dirty = true
		end
	end
	return removed
end

local function removeFromList(list, owner, event, handler)
	if handler then
		return removeRecord(list, owner, resolveHandler(owner, event, handler))
	end
	return removeOwner(list, owner)
end

local function fireList(list, ...)
	local n = #list
	if n == 0 then
		return
	end
	list.firing = list.firing + 1
	for i = 1, n do
		local record = list[i]
		if not record.removed then
			record.handler(record.owner, ...)
		end
	end
	list.firing = list.firing - 1
	if list.dirty and list.firing == 0 then
		compact(list)
	end
end

local EventMixin = {}
FA.EventMixin = EventMixin

function EventMixin:RegisterEvent(event, handler)
	handler = resolveHandler(self, event, handler)
	local list = callbacks[event]
	if not list then
		list = newList()
		callbacks[event] = list
	end
	addRecord(list, self, event, handler)
end

function EventMixin:UnregisterEvent(event, handler)
	local list = callbacks[event]
	if list then
		release(event, removeFromList(list, self, event, handler))
	end
end

function EventMixin:RegisterUnitEvent(event, unit, handler)
	handler = resolveHandler(self, event, handler)
	local byUnit = unitCallbacks[event]
	if not byUnit then
		byUnit = {}
		unitCallbacks[event] = byUnit
	end
	local list = byUnit[unit]
	if not list then
		list = newList()
		byUnit[unit] = list
	end
	addRecord(list, self, event, handler)
end

local function removeOwnerFromUnits(byUnit, owner)
	local removed = 0
	for _, list in pairs(byUnit) do
		removed = removed + removeOwner(list, owner)
	end
	return removed
end

function EventMixin:UnregisterUnitEvent(event, unit, handler)
	local byUnit = unitCallbacks[event]
	if not byUnit then
		return
	end
	if not unit then
		release(event, removeOwnerFromUnits(byUnit, self))
		return
	end
	local list = byUnit[unit]
	if list then
		release(event, removeFromList(list, self, event, handler))
	end
end

function EventMixin:UnregisterAllEvents()
	for event, list in pairs(callbacks) do
		release(event, removeOwner(list, self))
	end
	for event, byUnit in pairs(unitCallbacks) do
		release(event, removeOwnerFromUnits(byUnit, self))
	end
end

function FA:Fire(event, ...)
	local list = callbacks[event]
	if list then
		fireList(list, ...)
	end
	local byUnit = unitCallbacks[event]
	if byUnit then
		local unitList = byUnit[(...)]
		if unitList then
			fireList(unitList, ...)
		end
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	FA:Fire(event, ...)
end)

local addonWaiters = {}
local addonWatcher = FA.Mixin({}, EventMixin)

local function onAddonLoaded(_, addon)
	local waiters = addonWaiters[addon]
	if not waiters then
		return
	end
	addonWaiters[addon] = nil
	for i = 1, #waiters do
		waiters[i]()
	end
	if not next(addonWaiters) then
		addonWatcher:UnregisterEvent("ADDON_LOADED")
	end
end

function FA:OnAddonLoaded(addon, callback)
	if IsAddOnLoaded(addon) then
		callback()
		return
	end
	local waiters = addonWaiters[addon]
	if not waiters then
		waiters = {}
		addonWaiters[addon] = waiters
		addonWatcher:RegisterEvent("ADDON_LOADED", onAddonLoaded)
	end
	waiters[#waiters + 1] = callback
end

--------------------------------------------------------------------
-- Modules
--------------------------------------------------------------------
local modules = {}
FA.ModulePrototype = FA.Mixin({}, EventMixin)

function FA:NewModule(name)
	assert(not modules[name], ("module [%s] already exists"):format(name))
	local module = FA.Mixin({ name = name }, FA.ModulePrototype)
	modules[name] = module
	return module
end

function FA:GetModule(name)
	return assert(modules[name], ("module [%s] is not loaded"):format(tostring(name)))
end

--------------------------------------------------------------------
-- Faders (ported FrostAtomUI Core/Util.lua)
--------------------------------------------------------------------
local FADE_INTERVAL = 0.05
local FADE_IN_SPEED = 6
local FADE_OUT_SPEED = 2.5
local FADE_EPSILON = 0.01

local faders = {}
local FaderMixin = {}
local inCombat = InCombatLockdown() and true or false

local function anyMouseOver(frames)
	for i = 1, #frames do
		local frame = frames[i]
		if frame:IsVisible() and frame:IsMouseOver() then
			return true
		end
	end
	return false
end

local function isAwake(fader)
	if not fader.enabled then
		return true
	end
	local combat = fader.combat
	if combat == "combat" then
		if inCombat then
			return true
		end
	elseif combat == "nocombat" then
		if not inCombat then
			return true
		end
	elseif not fader.mouseover then
		return true
	end
	if fader.isActive and fader.isActive() then
		return true
	end
	return fader.mouseover and anyMouseOver(fader.hover)
end

function FaderMixin:UpdateMouse(awake)
	local frames = self.mouse
	if not frames or InCombatLockdown() then
		return
	end
	if awake == nil then
		awake = isAwake(self)
	end
	local enabled = self.combat == "any" or awake or (inCombat and self.mouseover)
	if enabled == self.mouseEnabled then
		return
	end
	self.mouseEnabled = enabled
	for i = 1, #frames do
		frames[i]:EnableMouse(enabled)
	end
end

function FaderMixin:SetMouseFrames(frames)
	self.mouse = frames
	self.mouseEnabled = nil
	self:UpdateMouse()
end

function FaderMixin:SetAlpha(alpha)
	self.current = alpha
	for i = 1, #self.frames do
		self.frames[i]:SetAlpha(alpha)
	end
end

function FaderMixin:Update(elapsed)
	local awake = isAwake(self)
	if self.mouse then
		self:UpdateMouse(awake)
	end
	local target = awake and 1 or self.alpha
	if abs(target - self.current) < FADE_EPSILON then
		self:SetAlpha(target)
		return
	end
	local speed = target > self.current and FADE_IN_SPEED or FADE_OUT_SPEED
	self:SetAlpha(self.current + (target - self.current) * min(elapsed * speed, 1))
end

function FaderMixin:Configure(mouseover, alpha, combat)
	self.mouseover = mouseover and true or false
	self.combat = combat or "any"
	self.enabled = self.mouseover or self.combat ~= "any"
	self.alpha = alpha or 0
	if not self.enabled then
		self:SetAlpha(1)
	end
	self:UpdateMouse()
end

function FA.CreateFader(frames, hover, isActive)
	local fader = FA.Mixin({
		frames = frames,
		hover = hover or frames,
		isActive = isActive,
		enabled = false,
		mouseover = false,
		combat = "any",
		alpha = 0,
		current = 1,
	}, FaderMixin)
	faders[#faders + 1] = fader
	return fader
end

local untilNextFade = 0
local fadeRunner = CreateFrame("Frame")
fadeRunner:SetScript("OnUpdate", function(_, elapsed)
	untilNextFade = untilNextFade - elapsed
	if untilNextFade > 0 then
		return
	end
	elapsed = FADE_INTERVAL - untilNextFade
	untilNextFade = FADE_INTERVAL
	for i = 1, #faders do
		local fader = faders[i]
		if fader.enabled or fader.current ~= 1 then
			fader:Update(elapsed)
		end
	end
end)

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWatcher:SetScript("OnEvent", function(_, event)
	inCombat = event == "PLAYER_REGEN_DISABLED"
	for i = 1, #faders do
		local fader = faders[i]
		if fader.combat ~= "any" then
			fader:Update(1)
		elseif fader.mouse then
			fader:UpdateMouse()
		end
	end
end)

--------------------------------------------------------------------
-- Config access
--------------------------------------------------------------------
function FA.ModuleDB()
	local p = SarychUI and SarychUI.db and SarychUI.db.profile
	local mods = p and p.modules
	return mods and mods.mainmenubar
end

function FA.DB()
	local db = FA.ModuleDB()
	return db and db.frostatom
end

-- Lazy proxy so ported code can keep `config.someKey` syntax.
FA.config = setmetatable({}, {
	__index = function(_, key)
		local db = FA.DB()
		return db and db[key]
	end,
	__newindex = function(_, key, value)
		local db = FA.DB()
		if db then
			db[key] = value
		end
	end,
})

-- Active = module enabled and the session booted with FrostAtomUI bars.
-- (FA.bootMode is fixed by the mainmenubar module on first Enable.)
function FA.IsActive()
	local db = FA.ModuleDB()
	if not db or not db.enabled or FA.DB() == nil then
		return false
	end
	return (FA.bootMode or db.barMode) == "frostatom"
end

-- Selected in options (may differ from bootMode until /reload).
function FA.IsSelected()
	local db = FA.ModuleDB()
	return db ~= nil and db.barMode == "frostatom"
end

-- Position tables are flat: { point, relativePoint, x, y }.
function FA.ApplyPoint(frame, t)
	if not frame or type(t) ~= "table" then
		return
	end
	if frame:IsProtected() and InCombatLockdown() then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint(t.point or "CENTER", UIParent, t.relativePoint or t.point or "CENTER", t.x or 0, t.y or 0)
end

-- Russian labels for bars / frames.
FA.LABELS = {
	bar1 = "Панель команд 1",
	bar2 = "Панель команд 2",
	bar3 = "Панель команд 3",
	bar4 = "Панель команд 4",
	bar5 = "Панель команд 5",
	bar6 = "Панель команд 6",
	bar7 = "Панель команд 7",
	bar8 = "Панель команд 8",
	bar9 = "Панель команд 9",
	bar10 = "Панель команд 10",
	stance = "Панель стоек",
	pet = "Панель питомца",
	totemBar = "Панель тотемов",
	vehicleExit = "Выход из транспорта",
	microMenu = "Микроменю",
	bagButton = "Кнопка сумки",
	experienceBar = "Опыт / репутация",
	playerCastbar = "Полоса каста",
}

function FA.Label(key)
	return FA.LABELS[key] or tostring(key)
end

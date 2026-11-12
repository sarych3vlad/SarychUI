--[[-------------------------------------------------------------------------
-- BindConfig.lua
--
-- This file contains the definitions of the binding configuration panel.
--
-- Events registered:
--   None
-------------------------------------------------------------------------]]--

local _, private = ...
local addonName, addon = "SarychUIClique", private.Clique
local L = addon.L

local MAX_ROWS = 12

function SarychUICliqueConfig:ShowWithSpellBook()
    self:ClearAllPoints()
    self:SetParent(SpellBookFrame)
    self:SetPoint("LEFT", SpellBookFrame, "RIGHT", 55, 0)
    self:Show()
end

function SarychUICliqueConfig:OnShow()
    if not addon.settings or InCombatLockdown() then self:Hide(); return end
    if not self.initialized then
        self:SetupGUI()
        self:HijackSpellbook()
        self.initialized = true
    end

    -- Hide the alertTab if the spellbook isn't shown
    if SpellButton1:IsVisible() then
        self.bindAlert:Show()
    else
        self.bindAlert:Hide()
    end

    SarychUICliqueSpellTab:SetChecked(true)
    self:UpdateList()
    self:EnableSpellbookButtons()
    self:UpdateAlert()
end

function SarychUICliqueConfig:OnHide()
    CloseDropDownMenus()
    self:ClearAllPoints()
    self:SetParent(UIParent)
    HideUIPanel(self)
    SarychUICliqueSpellTab:SetChecked(false)
    self:UpdateAlert()
end

-- Reserve space for the localized labels instead of clipping them to fixed widths.
function SarychUICliqueConfig:LayoutFooter()
    local padding, gap, bottom = 12, 6, 8
    local function fit(button)
        local width = math.ceil(button:GetFontString():GetStringWidth()) + 24
        button:SetSize(math.max(80, width), 22)
        button:ClearAllPoints()
        return button:GetWidth()
    end
    local spell, other, options = self.page1.button_spell, self.page1.button_other, self.page1.button_options
    local total = fit(spell) + fit(other) + fit(options) + gap * 2 + padding * 2
    local save, cancel = self.page2.button_save, self.page2.button_cancel
    local editTotal = fit(save) + fit(cancel) + gap + padding * 2
    self:SetWidth(math.max(333, total, editTotal))
    spell:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", padding, bottom)
    other:SetPoint("LEFT", spell, "RIGHT", gap, 0)
    options:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -padding, bottom)
    save:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", padding, bottom)
    cancel:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -padding, bottom)
    self.Inset:ClearAllPoints()
    self.Inset:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -60)
    self.Inset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -6, 38)
end

function SarychUICliqueConfig:LayoutColumns()
    local page = self.page1
    local bindingWidth = math.max(120, math.ceil(page.column2:GetFontString():GetStringWidth()) + 20)
    local available = self:GetWidth() - 10 -- Inset: 4 left, 6 right.
    page.column2:ClearAllPoints()
    page.column2:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    WhoFrameColumn_SetWidth(page.column2, bindingWidth)
    page.column1:ClearAllPoints()
    page.column1:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    WhoFrameColumn_SetWidth(page.column1, available - bindingWidth)
    local scrollSpace = page.slider:IsShown() and 18 or 0
    for _, row in ipairs(self.rows) do
        row.bind:ClearAllPoints()
        row.bind:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8 - scrollSpace, -3)
        row.bind:SetWidth(bindingWidth - 16 - scrollSpace)
        row.name:ClearAllPoints()
        row.name:SetWidth(0)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 3, 0)
        row.name:SetPoint("TOPRIGHT", row.bind, "TOPLEFT", -6, 0)
        row.info:ClearAllPoints()
        row.info:SetWidth(0)
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.info:SetPoint("TOPRIGHT", row.name, "BOTTOMRIGHT", 0, -2)
    end
end

function SarychUICliqueConfig:SetupGUI()
    self.rows = {}
    for i = 1, MAX_ROWS do
        self.rows[i] = CreateFrame("Button", "SarychUICliqueRow" .. i, self.page1, "SarychUICliqueRowTemplate")
    end

    self.rows[1]:ClearAllPoints()
    self.rows[1]:SetPoint("TOPLEFT", "SarychUICliqueConfigPage1Column1", "BOTTOMLEFT", 0, -3)
    self.rows[1]:SetPoint("RIGHT", SarychUICliqueConfigPage1Column2, "RIGHT", 0, 0)

    for i = 2, MAX_ROWS do
        self.rows[i]:ClearAllPoints()
        self.rows[i]:SetPoint("TOPLEFT", self.rows[i - 1], "BOTTOMLEFT")
        self.rows[i]:SetPoint("RIGHT", SarychUICliqueConfigPage1Column2, "RIGHT", 0, 0)
    end

    _G[self:GetName() .. "TitleText"]:SetText(L["Clique Binding Configuration"])

    self.dialog = _G["SarychUICliqueDialog"]
    self.dialog.title = _G["SarychUICliqueDialogTitleText"]
    self.dialog:SetUserPlaced(false)
    self.dialog:ClearAllPoints()
    self.dialog:SetPoint("CENTER", self, "CENTER", 30, 0)

    self.dialog.title:SetText(L["Set binding"])
    self.dialog.button_accept:SetText(L["Accept"])

    self.dialog.button_binding:SetText(L["Set binding"])
    local desc = L["In order to specify a binding, move your mouse over the button labelled 'Set binding' and either click with your mouse or press a key on your keyboard. You can modify the binding by holding down a combination of the alt, control and shift keys on your keyboard."]
    self.dialog.desc:SetText(desc)

    self.alert = _G["SarychUICliqueTabAlert"]

    self.bindAlert.text:SetText(L["You are in Clique binding mode"])

    self.close = _G[self:GetName() .. "CloseButton"]
    self.close:SetScript("OnClick", function()
        HideUIPanel(SarychUICliqueConfig)
    end)

    self.page1.column1:SetText(L["Action"])
    self.page1.column2:SetText(L["Binding"])

    -- Set columns up to handle sorting
    self.page1.column1.sortType = "name"
    self.page1.column2.sortType = "key"
    self.page1.sortType = self.page1.column2.sortType

    self.page1.button_spell:SetText(L["Bind spell"])
    self.page1.button_other:SetText(L["Bind other"])
    self.page1.button_options:SetText(L["Options"])

    self.page2.button_binding:SetText(L["Set binding"])
    self.page2.button_save:SetText(L["Save"])
    self.page2.button_cancel:SetText(L["Cancel"])
    self:LayoutFooter()
    self:LayoutColumns()
    local desc = L["You can use this page to create a custom macro to be run when activating a binding on a unit. When creating this macro you should keep in mind that you will need to specify the target of any actions in the macro by using the 'mouseover' unit, which is the unit you are clicking on. For example, you can do any of the following:\n\n/cast [target=mouseover] Regrowth\n/cast [@mouseover] Regrowth\n/cast [@mouseovertarget] Taunt\n\nHover over the 'Set binding' button below and either click or press a key with any modifiers you would like included. Then edit the box below to contain the macro you would like to have run when this binding is activated."]

    self.page2.desc:SetText(desc)
    self.page2.editbox = SarychUICliqueScrollFrameEditBox

    self.page1:Show()
end

function SarychUICliqueConfig:Column_OnClick(frame, button)
    self.page1.sortType = frame.sortType
    self:UpdateList()
end

function SarychUICliqueConfig:HijackSpellbook()
    self.spellbookButtons = {}

    for idx = 1, 12 do
        local parent = _G["SpellButton" .. idx]
        local button = CreateFrame("Button", "SarychUICliqueSpellbookButton" .. idx, parent, "SarychUICliqueSpellbookButtonTemplate")
        button.spellbutton = parent
        button:EnableKeyboard(false)
        button:EnableMouseWheel(true)
        button:RegisterForClicks("AnyDown")
        button:SetID(parent:GetID())
        self.spellbookButtons[idx] = button
    end

    SpellBookFrame:HookScript("OnShow", function(frame)
        self:EnableSpellbookButtons()
    end)
    SpellBookFrame:HookScript("OnHide", function(frame)
        self:EnableSpellbookButtons()
    end)

    self:EnableSpellbookButtons()
end

function SarychUICliqueConfig:EnableSpellbookButtons()
    local enabled;

    if self.page1:IsVisible() and SpellBookFrame:IsVisible() then
        enabled = true
    end

    if self.spellbookButtons then
        for idx, button in ipairs(self.spellbookButtons) do
            if enabled and button.spellbutton:IsEnabled() == 1 then
                button:Show()
            else
                button:Hide()
            end
        end
    end
end

-- Spellbook button functions
function SarychUICliqueConfig:Spellbook_EnableKeyboard(button, motion)
    button:EnableKeyboard(true)
end

function SarychUICliqueConfig:Spellbook_DisableKeyboard(button, motion)
    button:EnableKeyboard(false)
end

function SarychUICliqueConfig:Spellbook_OnBinding(button, key)
    if key == "ESCAPE" then
        HideUIPanel(SarychUICliqueConfig)
        return
    end

    local slot = SpellBook_GetSpellID(button:GetParent():GetID())
    local name, spellSubName, subtype = GetSpellName(slot, SpellBookFrame.bookType)
    local texture = GetSpellTexture(slot, SpellBookFrame.bookType)

    if spellSubName == "" then
        spellSubName = nil
    end

    local key = addon:GetCapturedKey(key)
    if not key then
        return
    end

    local succ, err = addon:AddBinding{
        key = key,
        type = "spell",
        spell = name,
        spellSubName = spellSubName,
        icon = texture
    }

    SarychUICliqueConfig:UpdateList()
end

function SarychUICliqueConfig:Button_OnClick(button)
    -- Click handler for "Bind spell" button
    if button == self.page1.button_spell then
        ShowUIPanel(SpellBookFrame)
        SarychUICliqueConfig:ShowWithSpellBook()

    -- Click handler for "Bind other" button
    elseif button == self.page1.button_other then
        local config = SarychUICliqueConfig
        local menu = {
            {
                text = L["Select a binding type"],
                isTitle = true,
                notCheckable = true,
            },
            {
                text = L["Target clicked unit"],
                func = function()
                    self:SetupCaptureDialog("target")
                end,
                notCheckable = true,
            },
            {
                text = L["Open unit menu"],
                func = function()
                    self:SetupCaptureDialog("menu")
                end,
                notCheckable = true,
            },
            {
                text = L["Run custom macro"],
                func = function()
                    config.page1:Hide()
                    config.page2.bindType = "macro"
                    -- Clear out the entries
                    config.page2.bindText:SetText(L["No binding set"])
                    config.page2.editbox:SetText("")
                    config.page2.button_save:Disable()
                    config.page2:Show()
                end,
                notCheckable = true,
            },
        }
        UIDropDownMenu_SetAnchor(self.dropdown, 0, 0, "BOTTOMLEFT", self.page1.button_other, "TOP")
        EasyMenu(menu, self.dropdown, nil, 0, 0, "MENU", nil)

    -- Click handler for "Edit" button
    elseif button == self.page1.button_options then
        HideUIPanel(SpellBookFrame)
        HideUIPanel(SarychUICliqueConfig)
        addon:OpenSUIOptions()
    elseif button == self.page2.button_save then
        -- Check the input
        local key = self.page2.key
        local macrotext = self.page2.editbox:GetText()

        if self.page2.binding then
            self.page2.binding.key = key
            self.page2.binding.macrotext = macrotext
            self.page2.binding = nil
            addon:FireMessage("BINDINGS_CHANGED")
        else
            local succ, err = addon:AddBinding{
                key = key,
                type = "macro",
                macrotext = macrotext,
            }
        end
        self:UpdateList()
        self.page2:Hide()
        self.page1:Show()
    elseif button == self.page2.button_cancel then
        self.page2.binding = nil
        self.page2:Hide()
        self.page1:Show()
    end
end

local memoizeBindings = setmetatable({}, {__index = function(t, k, v)
    local binbits = addon:GetBinaryBindingKey(k)
    rawset(t, k, binbits)
    return binbits
end})

local compareFunctions;
compareFunctions = {
    name = function(a, b)
        local texta = addon:GetBindingActionText(a.type, a)
        local textb = addon:GetBindingActionText(b.type, b)
        if texta == textb then
            return compareFunctions.key(a, b)
        end
        return texta < textb
    end,
    key = function(a, b)
        local keya = addon:GetBindingKey(a)
        local keyb = addon:GetBindingKey(b)
        if keya == keyb then
            return memoizeBindings[a] < memoizeBindings[b]
        elseif not keya or not keyb then
            return false
        else
            return keya < keyb
        end
    end,
    binding = function(a, b)
        local mem = memoizeBindings
		if mem[a] == mem[b] then
			return compareFunctions.name(a, b)
		else
			return mem[a] < mem[b]
		end
    end,
}

-- Mapping between binding entry and index in profile
function SarychUICliqueConfig:UpdateList()
    local page = self.page1
    local binds = addon.bindings

    -- GUI not created yet
    if not self.initialized then
        return
    elseif not self:IsVisible() then
        return
    end

    -- Sort the bindings
    local sort = {}
    for idx, entry in pairs(binds) do
        sort[#sort + 1] = entry
    end

    if page.sortType then
        table.sort(sort, compareFunctions[page.sortType])
    else
        table.sort(sort, compareFunctions.key)
    end

    -- Enable or disable the scroll bar
    if #sort > MAX_ROWS - 1 then
        -- Set up the scrollbar for the item list
        page.slider:SetMinMaxValues(0, #sort - MAX_ROWS)

        -- Adjust and show
        if not page.slider:IsShown() then
            page.slider:SetValue(0)
            page.slider:Show()
        end
    elseif page.slider:IsShown() then
        page.slider:Hide()
    end

    self:LayoutColumns()

    -- Update the rows in the list
    local offset = page.slider:GetValue() or 0
    for idx, row in ipairs(self.rows) do
        local offsetIndex = offset + idx
        if sort[offsetIndex] then
            local bind = sort[offsetIndex]
            row.icon:SetTexture(addon:GetBindingIcon(bind))
            row.name:SetText(addon:GetBindingActionText(bind.type, bind))
            row.info:SetText(addon:GetBindingInfoText(bind))
            row.bind:SetText(addon:GetBindingKeyComboText(bind))
            row.binding = bind
            row:Show()
        else
            row:Hide()
        end
    end
end

function SarychUICliqueConfig:ClearEditPage()
end

function SarychUICliqueConfig:ShowEditPage()
    self:ClearEditPage()
    self.page1:Hide()
    self.page3:Show()
end

function SarychUICliqueConfig:Save_OnClick(button, down)
end

function SarychUICliqueConfig:Cancel_OnClick(button, down)
    self:ClearEditPage()
    self.page3:Hide()
    self.page1:Show()
end

function SarychUICliqueConfig:SetupCaptureDialog(type, binding)
    self.dialog.bindType = type
    self.dialog.binding = binding

    if not binding then
        local actionText = addon:GetBindingActionText(type, binding)
        self.dialog.title:SetText(L["Set binding: %s"]:format(actionText))
    else
        -- This is a change to an existing binding
        local actionText = addon:GetBindingActionText(type, binding)
        self.dialog.title:SetText(L["Change binding: %s"]:format(actionText))
    end

    self.dialog.bindText:SetText("")
    self.dialog:Show()
end

function SarychUICliqueConfig:BindingButton_OnClick(button, key)
    local dialog = SarychUICliqueDialog
    dialog.key = addon:GetCapturedKey(key)
    if dialog.key then
        SarychUICliqueDialog.bindText:SetText(addon:GetBindingKeyComboText(dialog.key))
    end
end

function SarychUICliqueConfig:MacroBindingButton_OnClick(button, key)
    local key = addon:GetCapturedKey(key)
    if key then
        self.page2.key = key
        self.page2.bindText:SetText(addon:GetBindingKeyComboText(key))
        self.page2.button_save:Enable()
    else
        self.page2.bindText:SetText(L["No binding set"])
        self.page2.button_save:Disable()
    end
end

function SarychUICliqueConfig:AcceptSetBinding()
    local dialog = SarychUICliqueDialog
    local key = dialog.key

    if dialog.binding then
        -- This was a CHANGE binding instead of a SET binding
        dialog.binding.key = key
        dialog.binding = nil
        -- Do not forget to update the attributes as well
        self:UpdateList()
        addon:FireMessage("BINDINGS_CHANGED")
    else
        local succ, err = addon:AddBinding{
            key = key,
            type = dialog.bindType,
        }
        if succ then
            self:UpdateList()
        end
    end
    dialog:Hide()
end

local function toggleSet(binding, set, ...)
    local exclude = {}
    for i = 1, select("#", ...) do
        local item = select(i, ...)
        table.insert(exclude, item)
    end

    return function()
        if not binding.sets then
            binding.sets = {}
        end
        if binding.sets[set] then
            binding.sets[set] = nil
        else
            binding.sets[set] = true
        end

        for idx, exclset in ipairs(exclude) do
            binding.sets[exclset] = nil
        end

        UIDropDownMenu_Refresh(UIDROPDOWNMENU_OPEN_MENU, nil, UIDROPDOWNMENU_MENU_LEVEL)
        SarychUICliqueConfig:UpdateList()
        addon:FireMessage("BINDINGS_CHANGED")
    end
end

function SarychUICliqueConfig:Row_OnClick(frame, button)
    local binding = frame.binding
    local actionText = addon:GetBindingActionText(binding.type, binding)

    local menu = {
        {
            text = L["Configure binding: '%s'"]:format(actionText:sub(1,15)),
            notCheckable = true,
            isTitle = true,
        },
        {
            text = L["Change binding"],
            func = function()
                local binding = frame.binding
                self:SetupCaptureDialog(binding.type, binding)
            end,
            notCheckable = true,
        },
        {
            text = L["Delete binding"],
            func = function()
                addon:DeleteBinding(frame.binding)
                self:UpdateList()
            end,
            notCheckable = true,
        },
    }

    if binding.type == "spell" and binding.spellSubName then
        -- Enable a 'Remove Rank' option
        menu[#menu+1] = {
        	text = L["Remove spell rank"],
            func = function()
                local binding = frame.binding
                binding.spellSubName = nil
                self:UpdateList()
                addon:FireMessage("BINDINGS_CHANGED")
            end,
            notCheckable = true,
        }
    end

    if binding.type == "macro" then
        -- Replace 'Change Binding' with 'Edit macro'
        menu[2] = {
            text = L["Edit macro"],
            func = function()
                self.page2.bindType = "macro"
                local bindText = addon:GetBindingKeyComboText(binding)
                self.page2.bindText:SetText(bindText)
                self.page2.binding = binding
                self.page2.key = binding.key
                self.page2.editbox:SetText(binding.macrotext)
                self.page2.button_save:Enable()
                self.page1:Hide()
                self.page2:Show()
            end,
            notCheckable = true,
        }
    end

    local submenu = {
        text = L["Enable/Disable binding-sets"],
        hasArrow = true,
        notCheckable = true,
        menuList = {},
    }
    table.insert(menu, submenu)

    table.insert(submenu.menuList, {
        text = L["Default"],
        checked = function() return binding.sets["default"] end,
        func = toggleSet(binding, "default"),
        tooltipTitle = L["Clique: 'default' binding-set"],
        tooltipText = L["A binding that belongs to the 'default' binding-set will always be active on your unit frames, unless you override it with another binding."],
        -- keepShownOnClick = true,
    })

    table.insert(submenu.menuList, {
        text = L["Friend"],
        checked = function() return binding.sets["friend"] end,
        func = toggleSet(binding, "friend"),
        tooltipTitle = L["Clique: 'friend' binding-set"],
        tooltipText = L["A binding that belongs to the 'frield' binding-set will only be active when clicking on unit frames that display friendly units, i.e. those you can heal and assist. If you click on a unit that you cannot heal or assist, nothing will happen."],
        -- keepShownOnClick = true,
    })

    table.insert(submenu.menuList, {
        text = L["Enemy"],
        checked = function() return binding.sets["enemy"] end,
        func = toggleSet(binding, "enemy"),
        tooltipTitle = L["Clique: 'enemy' binding-set"],
        tooltipText = L["A binding that belongs to the 'enemy' binding-set will always be active when clicking on unit frames that display enemy units, i.e. those you can attack. If you click on a unit that you cannot attack, nothing will happen."],
        -- keepShownOnClick = true,
    })

    table.insert(submenu.menuList, {
        text = L["Out-of-combat (ONLY)"],
        checked = function() return binding.sets["ooc"] end,
        func = toggleSet(binding, "ooc"),
        tooltipTitle = L["Clique: 'ooc' binding-set"],
        tooltipText = L["A binding that belongs to the 'ooc' binding-set will only be active when the player is out-of-combat, regardless of the other binding-sets this binding belongs to. As soon as the player enters combat, these bindings will no longer be active, so be careful when choosing this binding-set for any spells you use frequently."],
        -- keepShownOnClick = true,
    })

	table.insert(submenu.menuList, {
        text = L["Primary talent spec (ONLY)"],
        checked = function() return binding.sets["pritalent"] end,
        func = toggleSet(binding, "pritalent"),
        tooltipTitle = L["Clique: 'pritalent' binding-set"],
        tooltipText = L["A binding that belongs to the 'pritalent' binding-set is only active when the player is currently using their primary talent spec, regardless of the other binding-sets that this binding belongs to."],
        -- keepShownOnClick = true,
    })

	table.insert(submenu.menuList, {
        text = L["Secondary talent spec (ONLY)"],
        checked = function() return binding.sets["sectalent"] end,
        func = toggleSet(binding, "sectalent"),
        tooltipTitle = L["Clique: 'sectalent' binding-set"],
        tooltipText = L["A binding that belongs to the 'sectalent' binding-set is only active when the player is currently using their secondary talent spec, regardless of the other binding-sets that this binding belongs to."],
        -- keepShownOnClick = true,
    })

    table.insert(submenu.menuList, {
        text = L["Hovercast bindings (target required)"],
        checked = function() return binding.sets["hovercast"] end,
        func = toggleSet(binding, "hovercast", "global"),
        tooltipTitle = L["Clique: 'hovercast' binding-set"],
        tooltipText = L["A binding that belongs to the 'hovercast' binding-set is active whenever the mouse is over a unit frame, or a character in the 3D world. This allows you to use 'hovercasting', where you hover over a unit in the world and press a key to cast a spell on them. THese bindings are also active over unit frames."],
        -- keepShownOnClick = true,
    })

    table.insert(submenu.menuList, {
        text = L["Global bindings (no target)"],
        checked = function() return binding.sets["global"] end,
        func = toggleSet(binding, "global", "hovercast"),
        tooltipTitle = L["Clique: 'global' binding-set"],
        tooltipText = L["A binding that belongs to the 'global' binding-set is always active. If the spell requires a target, you will be given the 'casting hand', otherwise the spell will be cast. If the spell is an AOE spell, then you will be given the ground targeting circle."],
        -- keepShownOnClick = true,
    })

    EasyMenu(menu, self.dropdown, "cursor", 0, 0, "MENU", nil)
end

function SarychUICliqueConfig:SpellTab_OnClick(frame)
    if self:IsVisible() then
        HideUIPanel(SarychUICliqueConfig)
    elseif SpellBookFrame:IsVisible() then
        self:ShowWithSpellBook()
    else
        ShowUIPanel(SarychUICliqueConfig)
    end
end

function SarychUICliqueConfig:UpdateAlert(type)
    local alert = SarychUICliqueTabAlert
    if not addon.settings.alerthidden and SpellBookFrame:IsVisible() and SarychUICliqueConfig:IsVisible() then
        alert.type = type
        alert.text:SetText(L["When both the Clique binding configuration window and the spellbook are open, you can set new bindings simply by performing them on the spell icon in your spellbook. Simply move your mouse over a spell and then click or press a key on your keyboard along with any combination of the alt, control, and shift keys. The new binding will be added to your binding configuration."])
        alert:Show()
    else
        alert:Hide()
    end
end

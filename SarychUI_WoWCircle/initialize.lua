local SUI, extension = SarychUI, SarychUI.WoWCircle

function extension:MigrateFilters()
    local chat = SUI.db.profile.modules.chat
    if not chat or chat.wowcircleFiltersMigrated then return end
    local aliases, known = {}, {}
    for index, pattern in ipairs(self.LegacySpamDefaults) do
        aliases[pattern] = SUI.ChatSpamDefaults[index]
        known[pattern] = true
    end
    for _, pattern in ipairs(SUI.ChatSpamDefaults) do known[pattern] = true end
    local custom, seen = chat.spamCustomList or {}, {}
    for _, pattern in ipairs(custom) do seen[pattern] = true end
    for _, pattern in ipairs(chat.spamEnabledList or {}) do
        if not known[pattern] and not seen[pattern] then
            custom[#custom + 1] = pattern
            seen[pattern] = true
        end
    end
    chat.spamCustomList = custom
    for index, pattern in ipairs(chat.spamDeletedList or {}) do
        chat.spamDeletedList[index] = aliases[pattern] or pattern
    end
    chat.wowcircleFiltersMigrated = true
end

local enable = extension.Enable
function extension:Enable()
    self:GetDB()
    self:MigrateFilters()
    enable(self)
    if SarychUI_RefreshCachedSpamPatterns then SarychUI_RefreshCachedSpamPatterns() end
end

extension:GetDB()
extension:MigrateFilters()
SUI:RegisterExtension("wowcircle", extension)
if SarychUI_RefreshCachedSpamPatterns then SarychUI_RefreshCachedSpamPatterns() end

-- Options may have been prebuilt by another addon during loading.
if SUI._optionsTableBuilt and SUI.AddModuleOptions then
    SUI:AddModuleOptions()
    SUI:NotifySarychUIOptionsChange()
end

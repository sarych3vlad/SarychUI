-- Character mail settings and address history, independent of UI profiles.
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
local function Defaults(target, source)
    for key, value in pairs(source) do
        if key ~= "*" then
            if target[key] == nil then target[key] = Copy(value)
            elseif type(value) == "table" then Defaults(target[key], value) end
        end
    end
end
local function AddNames(target, source)
    local seen = {}
    for _, name in ipairs(target) do seen[name] = true end
    for _, name in ipairs(source or {}) do
        if not seen[name] then target[#target + 1] = name; seen[name] = true end
    end
end
function SarychUI_CreatePostalStorage(defaults)
    Postal3DB = Postal3DB or {}
    local db = Postal3DB
    local character = UnitName("player") .. " - " .. GetRealmName()
    db.characters = db.characters or {}
    local function Migrate(key, old)
        if db.characters[key] then return end
        local settings = Copy(old or {})
        local book = settings.BlackBook or {}
        db.characters[key] = { settings = settings,
            addressBook = { contacts = Copy(book.contacts or {}), recent = Copy(book.recent or {}) } }
        book.contacts, book.recent = nil, nil
    end
    local profiles = db.profiles or {}
    for key, profile in pairs(db.profileKeys or {}) do Migrate(key, profiles[profile]) end
    Migrate(character, profiles[character] or profiles.Default)
    -- Retain addresses from unused legacy profiles before removing profile storage.
    local used = {}
    for _, profile in pairs(db.profileKeys or {}) do used[profile] = true end
    for name, profile in pairs(profiles) do
        if not used[name] and profile.BlackBook then
            AddNames(db.characters[character].addressBook.contacts, profile.BlackBook.contacts)
            AddNames(db.characters[character].addressBook.contacts, profile.BlackBook.recent)
        end
    end
    db.profiles, db.profileKeys = nil, nil
    db.global = db.global or {}
    Defaults(db.global, defaults.global)
    local data = db.characters[character]
    Defaults(data.settings, defaults.settings)
    setmetatable(data.settings.ModuleEnabledState, { __index = function() return true end })
    data.settings.ModuleEnabledState["*"] = nil
    return { settings = data.settings, addressBook = data.addressBook, global = db.global }
end

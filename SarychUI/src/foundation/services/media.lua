-- SarychUI Media Management
-- Handles fonts, textures, and sounds via LibSharedMedia

-- Check if LibSharedMedia is available
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

if not LSM then
	SarychUI:Print("|cffff0000LibSharedMedia-3.0 not found!|r Media management will be limited.")
	-- Create dummy media object
	SarychUI.Media = {
		GetFont = function(name) return "Fonts\\FRIZQT__.TTF" end,
		GetTexture = function(name) return "Interface\\TargetingFrame\\UI-StatusBar" end,
		GetSound = function(name) return "Sound\\Interface\\igQuestComplete.wav" end,
		GetFonts = function() return {} end,
		GetTextures = function() return {} end,
		GetSounds = function() return {} end,
	}
	return
end

-- Register custom fonts
local function RegisterFonts()
	LSM:Register("font", "SarychUI Homespun", [[Interface\AddOns\SarychUI\media\fonts\Homespun.ttf]])
end

-- Register custom textures
local function RegisterTextures()
	-- Publish bundled skins alongside media registered by other addons.
	local base = [[Interface\AddOns\SarychUI\media\cooldowns\]]
	for _, entry in ipairs({
		{ "Aesa", "aesa", { "Steel", "Ruben2", "Ruben", "LiteStepLite2", "LiteStepLite", "Frost", "Button" } },
	}) do
		for _, name in ipairs(entry[3]) do
			LSM:Register("statusbar", "SarychUI " .. entry[1] .. " - " .. name,
				base .. entry[2] .. "\\" .. name)
		end
	end
	-- LSM:Register("statusbar", "Texture Name", [[Interface\AddOns\SarychUI\media\textures\texture.tga]])
	
	-- Example: Register a smooth texture (if file exists)
	-- LSM:Register("statusbar", "SarychUI Smooth", [[Interface\AddOns\SarychUI\media\textures\smooth.tga]])
end

-- Register custom sounds
local function RegisterSounds()
	-- Add custom sounds here if needed
	-- LSM:Register("sound", "Sound Name", [[Interface\AddOns\SarychUI\media\sounds\sound.ogg]])
end

-- Initialize media
local function InitializeMedia()
	RegisterFonts()
	RegisterTextures()
	RegisterSounds()
end

-- Initialize on load
InitializeMedia()

-- Export media helper functions
SarychUI.Media = {
	-- Get a font
	GetFont = function(name)
		return LSM:Fetch("font", name)
	end,
	
	-- Get a texture
	GetTexture = function(name)
		return LSM:Fetch("statusbar", name)
	end,
	
	-- Get a sound
	GetSound = function(name)
		return LSM:Fetch("sound", name)
	end,
	
	-- Get all fonts
	GetFonts = function()
		return LSM:List("font")
	end,
	
	-- Get all textures
	GetTextures = function()
		return LSM:List("statusbar")
	end,
	
	-- Get all sounds
	GetSounds = function()
		return LSM:List("sound")
	end,
}

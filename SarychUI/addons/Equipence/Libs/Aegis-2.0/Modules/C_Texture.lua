--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local type = type;

local VERSION = 5;

local PORTRAIT_TEX_COORDS = { 0.05, 0.95, 0.05, 0.95 };
local PORTRAIT_MASK_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask";
local PORTRAIT_MASK_KEY = "aegis-portrait-mask";

--[[
	local AddOnName = ...
	local Aegis = LibStub("LibAegis-1.0")
	local C_Texture = Aegis:GetNamespace("C_Texture")

	-- Common atlases bundled inside this addon's embedded library copy:
	C_Texture.RegisterCommonAtlases(AddOnName, "libs\\LibAegis\\assets")

	-- Addon-specific atlases:
	C_Texture.RegisterAtlasTable(MyAddonAtlasData, AddOnName, "Resources")
	
	-- Override mode:
	C_Texture.RegisterAtlas("SomeAtlas", atlasInfo, {
		overrideNative = true,
	})
]]

local function ApplyAtlasManually(texture, atlasInfo, useAtlasSize)
	texture:SetTexture(atlasInfo.filename);
	texture:SetTexCoord(
		atlasInfo.leftTexCoord,
		atlasInfo.rightTexCoord,
		atlasInfo.topTexCoord,
		atlasInfo.bottomTexCoord
	);

	if texture.SetHorizTile then
		texture:SetHorizTile(atlasInfo.tilesHorizontally);
	end
	if texture.SetVertTile then
		texture:SetVertTile(atlasInfo.tilesVertically);
	end

	if useAtlasSize then
		texture:SetSize(atlasInfo.width, atlasInfo.height);
	end
end

local function ApplyPortraitMask(texture)
	local mask = texture[PORTRAIT_MASK_KEY];
	if mask then
		return true;
	end

	local parent = texture.GetParent and texture:GetParent();
	if not parent or not parent.CreateMaskTexture or not texture.AddMaskTexture then
		return false;
	end

	mask = parent:CreateMaskTexture();
	mask:SetAllPoints(texture);
	mask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE");
	texture:AddMaskTexture(mask);
	texture[PORTRAIT_MASK_KEY] = mask;
	return true;
end

Aegis:RegisterNamespace("C_Texture", VERSION, function(core, _, namespace, native)
	local registry = core:GetService("AtlasRegistry");

	local C_Texture = namespace or {};
	local useNative = native ~= nil;

	function C_Texture.RegisterAddonRoot(addonName, rootFolder)
		registry:RegisterAddonRoot(addonName, rootFolder);
	end

	function C_Texture.RegisterAtlas(name, info, options)
		return registry:RegisterAtlas(name, info, options);
	end

	function C_Texture.RegisterAtlasTable(atlasTable, addonName, rootFolder, options)
		return registry:RegisterAtlasTable(atlasTable, addonName, rootFolder, options);
	end

	function C_Texture.RegisterCommonAtlases(addonName, rootFolder, options)
		local atlasTable = core.data and core.data.CommonAtlasData;
		if not atlasTable then
			return true;
		end

		return registry:RegisterAtlasTable(atlasTable, addonName, rootFolder, options);
	end

	function C_Texture.GetAtlasInfo(name)
		local overrideInfo = registry:GetOverrideAtlasInfo(name);
		if overrideInfo then
			return overrideInfo;
		end

		if useNative and native.GetAtlasInfo then
			local nativeInfo = native.GetAtlasInfo(name);
			if nativeInfo then
				return nativeInfo;
			end
		end

		return registry:GetCustomAtlasInfo(name);
	end
	
	function C_Texture.HasAtlasInfo(name)
		return C_Texture.GetAtlasInfo(name) ~= nil;
	end

	function C_Texture.SetAtlas(texture, atlasName, useAtlasSize, filterMode, resetTexCoords, wrapModeHorizontal, wrapModeVertical)
		if not texture or type(atlasName) ~= "string" then
			return false;
		end

		-- Explicit custom override always wins
		local overrideInfo = registry:GetOverrideAtlasInfo(atlasName)
		if overrideInfo then
			ApplyAtlasManually(texture, overrideInfo, useAtlasSize);
			return true;
		end

		-- Trusted native atlas
		if useNative and native.GetAtlasInfo then
			local nativeInfo = native.GetAtlasInfo(atlasName);
			if nativeInfo then
				if texture.SetAtlas then
					texture:SetAtlas(
						atlasName,
						useAtlasSize,
						filterMode,
						resetTexCoords,
						wrapModeHorizontal,
						wrapModeVertical
					);
				else
					ApplyAtlasManually(texture, nativeInfo, useAtlasSize);
				end
				return true;
			end
		end

		-- Custom fallback atlas
		local customInfo = registry:GetCustomAtlasInfo(atlasName);
		if customInfo then
			ApplyAtlasManually(texture, customInfo, useAtlasSize);
			return true;
		end

		return false;
	end

	function C_Texture.SetPortraitToTexture(texture, texturePath)
		if not texture then
			return false;
		end

		if SetPortraitToTexture then
			SetPortraitToTexture(texture, texturePath);
			return true;
		end

		texture:SetTexture(texturePath);
		texture:SetTexCoord(0, 1, 0, 1);
		if ApplyPortraitMask(texture) then
			return true;
		end

		texture:SetTexCoord(
			PORTRAIT_TEX_COORDS[1],
			PORTRAIT_TEX_COORDS[2],
			PORTRAIT_TEX_COORDS[3],
			PORTRAIT_TEX_COORDS[4]
		);
		return true;
	end

	function C_Texture.ClearPortraitMask(texture)
		local mask = texture and texture[PORTRAIT_MASK_KEY];
		if not mask then
			return false;
		end

		if texture.RemoveMaskTexture then
			texture:RemoveMaskTexture(mask);
		end

		texture[PORTRAIT_MASK_KEY] = nil;
		return true;
	end

	return C_Texture;
end, { trustNative = true, wrapNative = true });
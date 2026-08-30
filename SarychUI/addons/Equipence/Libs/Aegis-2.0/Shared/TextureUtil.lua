--[[
    Aegis Framework
    Copyright (c) 2026 s0high. All rights reserved.

    Restricted proprietary library. See LICENSE for terms.
]]

local Aegis = LibStub("Aegis-2.0");

local type = type;
local unpack = unpack;

local VERSION = 3;

Aegis:RegisterNamespace("TextureUtil", VERSION, function(core, _, namespace)
	local TextureUtil = namespace or {};
	local C_Texture = core:GetNamespace("C_Texture");

	local function GetFinalNameFromTextureKit(fmt, textureKits)
		if type(textureKits) == "table" then
			return fmt:format(unpack(textureKits));
		end

		return fmt:format(textureKits);
	end

	local function SetupTextureKitOnFrame(textureKit, frame, fmt, setVisibility, useAtlasSize)
		if not frame then
			return false;
		end

		local success = false;
		if textureKit then
			local atlasName = GetFinalNameFromTextureKit(fmt, textureKit);
			if frame.GetObjectType and frame:GetObjectType() == "StatusBar" and frame.SetStatusBarTexture then
				success = frame:SetStatusBarTexture(atlasName);
			else
				success = C_Texture.SetAtlas(frame, atlasName, useAtlasSize);
			end
		end

		if setVisibility then
			frame:SetShown(success);
		end

		return success;
	end

	TextureUtil.GetFinalNameFromTextureKit = GetFinalNameFromTextureKit;
	-- Route textureKit setup through Aegis C_Texture so custom atlas data works on Classic clients.
	TextureUtil.SetupTextureKitOnFrame = SetupTextureKitOnFrame;

	return TextureUtil;
end);

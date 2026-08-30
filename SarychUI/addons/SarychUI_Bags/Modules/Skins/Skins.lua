local E = unpack(_G.SarychUI_Bags)
local S = E:GetModule("Skins")

local DEBUG_ELVUI_BAGS_SKIN = false

local function skinDebug(...)
	if not DEBUG_ELVUI_BAGS_SKIN then return end
	print("[SarychUI_Bags Skin]", ...)
end

local handleCloseButtonOnEnter = function(btn)
	if btn.Texture then
		btn.Texture:SetVertexColor(unpack(E.media.rgbvaluecolor))
	end
end

local handleCloseButtonOnLeave = function(btn)
	if btn.Texture then
		btn.Texture:SetVertexColor(1, 1, 1)
	end
end

function S:HandleCloseButton(f, point)
	if not f then return end

	if f.StripTextures then
		f:StripTextures()
	end

	if f.GetNormalTexture and f:GetNormalTexture() then
		f:SetNormalTexture("")
		f.SetNormalTexture = E.noop
	end
	if f.GetPushedTexture and f:GetPushedTexture() then
		f:SetPushedTexture("")
		f.SetPushedTexture = E.noop
	end

	if not f.Texture then
		f.Texture = f:CreateTexture(nil, "OVERLAY")
		f.Texture:Size(12, 12)
		f.Texture:Point("CENTER")
		f.Texture:SetTexture(E.Media.Textures.Close)
		f.Texture:SetVertexColor(1, 1, 1)
		f:EnableMouse(true)
		f:HookScript("OnEnter", handleCloseButtonOnEnter)
		f:HookScript("OnLeave", handleCloseButtonOnLeave)
		f:SetHitRectInsets(7, 6, 7, 6)
		skinDebug("close button styled")
	end

	if point then
		f:Point("TOPRIGHT", point, "TOPRIGHT", 2, 3)
	end
end

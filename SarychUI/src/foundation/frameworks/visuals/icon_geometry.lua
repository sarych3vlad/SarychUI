SarychUI.Frameworks = SarychUI.Frameworks or {}

-- The same icon inset and crop for styled buttons and their previews.
function SarychUI.Frameworks.ApplyButtonIconCrop(icon, button, inset)
	if button then
		inset = inset or 2
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
		icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
	end
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
end

-- The owner retains the snapshot; no second cache or update driver is needed.
-- Restore only geometry, never an old spell/item texture, color or visibility.
function SarychUI.Frameworks.SetIconCrop(icon, saved, enabled, button, inset)
	if not enabled then
		if saved then
			local region = saved.icon
			region:SetTexCoord(unpack(saved.coords))
			if saved.points then
				region:ClearAllPoints()
				for _, point in ipairs(saved.points) do region:SetPoint(unpack(point)) end
				region:SetSize(saved.width, saved.height)
			end
		end
		return nil
	end
	if not icon then return saved end
	if not saved then
		saved = { icon = icon, coords = { icon:GetTexCoord() } }
		if button then
			saved.width, saved.height, saved.points = icon:GetWidth(), icon:GetHeight(), {}
			for i = 1, icon:GetNumPoints() do saved.points[i] = { icon:GetPoint(i) } end
		end
	end
	SarychUI.Frameworks.ApplyButtonIconCrop(icon, button, inset)
	return saved
end

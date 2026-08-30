-- GladiusEx bootstrap for SarychUI embedding
-- Config layer always loads; runtime starts disabled until SarychUI enables the addon.

if not GladiusEx then return end

GladiusEx.defaultEnabledState = false

if GladiusEx.SetEnabledState then
	GladiusEx:SetEnabledState(false)
end

-- Apply active UI locale after all locale packs and UI maps are registered.
if SarychUI and SarychUI.ApplyUILocale then
	SarychUI:ApplyUILocale(SarychUI.ResolveSavedUILocale())
elseif SarychUI and SarychUI.Locales and SarychUI.Locales.enUS then
	SarychUI.L = SarychUI.Locales.enUS
end

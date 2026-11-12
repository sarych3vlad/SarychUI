-- Extensions share the module lifecycle and AceDB profile, but have their own UI list.
SarychUI.extensions = SarychUI.extensions or {}
SarychUI.extensionList = SarychUI.extensionList or {}

function SarychUI:RegisterExtension(key, extension)
	if not key or type(extension) ~= "table" or self.extensions[key] then
		error("Invalid or duplicate SarychUI extension: " .. tostring(key))
	end
	extension.isExtension = true
	self:RegisterModule(key, extension)
	self.extensions[key] = extension
	table.insert(self.extensionList, key)
	if self._optionsTableBuilt and self.RefreshExtensionOptions then
		self:RefreshExtensionOptions()
	end
	return extension
end

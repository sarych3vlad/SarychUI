-- Formatting used by the private nine-slice renderer.
function SarychUI.Compat.GetFinalNameFromTextureKit(fmt, textureKits)
    if type(textureKits) == "table" then return fmt:format(unpack(textureKits)) end
    if textureKits == nil then return fmt end
    return fmt:format(textureKits)
end

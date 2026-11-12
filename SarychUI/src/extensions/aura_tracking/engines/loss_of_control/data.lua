local _, private = ...;
private.LOSS_OF_CONTROL_SPELL_DATA = SarychUI.Data.AuraTracking:CreateView("lossOfControl");

tableMixin = function(object, ...)
	local mixins = {...};
	for _, mixin in pairs(mixins) do
		for k,v in next,mixin do
			object[k] = v;
		end
	end
	return object;
end
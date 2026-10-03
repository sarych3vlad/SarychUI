---------------
-- where ​... are the mixins to mixin
if not Mixin then
function Mixin(object, ...)
	if type(object) ~= "table" then
		return object;
	end
	for i = 1, select("#", ...) do
		local mixin = select(i, ...);
		if type(mixin) == "string" then
			mixin = _G[mixin];
		end
		if type(mixin) == "table" then
			for k, v in pairs(mixin) do
				object[k] = v;
			end
		end
	end
	return object;
end
end
-- where ​... are the mixins to mixin
function CreateFromMixins(...)
	return Mixin({}, ...);
end

function CreateAndInitFromMixin(mixin, ...)
	local object = CreateFromMixins(mixin);
	object:Init(...);
	return object;
end
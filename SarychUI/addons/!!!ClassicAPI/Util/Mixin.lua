local Select = select
local Pairs = pairs

if ( not Mixin ) then
	function Mixin(Object, ...)
		if ( type(Object) ~= "table" ) then
			return Object
		end
		for i = 1, Select("#", ...) do
			local Resolved = Select(i, ...)
			if ( type(Resolved) == "string" ) then
				Resolved = _G[Resolved]
			end
			if ( type(Resolved) == "table" ) then
				for k, v in Pairs(Resolved) do
					Object[k] = v
				end
			end
		end
		return Object
	end
end

function CreateFromMixins(...)
	return Mixin({}, ...)
end

function CreateAndInitFromMixin(Mixin, ...)
	local Object = CreateFromMixins(Mixin)
	Object:Init(...)
	return Object
end
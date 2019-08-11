#!/usr/bin/env lua

-- Generates a function usable by `__index` metamethod that will search
--  or call it's arguments from left to right
-- Can be used to create mixins
local function mix(...) local args = { ... }
	assert(#args > 0)
	if #args == 1 then return args[1] end
	return function(self, key)
		for n=1,#args do
			local arg = args[n]
			if type(arg) == 'table' and arg[key] ~= nil then
				return arg[key]
			elseif type(arg) == 'function' then
				return arg(self, key)
			end
		end
	end
end

return mix

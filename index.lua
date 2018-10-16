local class,ch = require("-class,coreHelpers")
local api = { }

local async = class:extend()
local id = 1

function async:init(f)
	self.id = id
	id = id + 1
	self.co = coroutine.create(f)
end

function async:run(...)
	-- ch.dprint("run " .. self.id)
	api.current = self
	local r = { coroutine.resume(self.co, ...) }
	-- ch.dprint("resume " .. (status and 'true' or 'false'))
	if not r[1] then
		ch.dprint("error")
		ch.dprint(r[2] .. debug.traceback())
	end
end

api.create = function(f)	
	return async:new(f)
end

api.yield = function()	
	-- api.current = 
	return coroutine.yield()
end

return { api = api } 
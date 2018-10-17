local class,l,w,time = require("-class,logger,windows,time")
local api = { }

local worker = class:extend()
function worker:getHandles() end
function worker:hit() end
function worker:hitByEvent(eventNo) end
function worker:stop()
	api.delWorker(self)
end
function worker:addToEventLoop()
	api.addWorker(self)
end


api.worker = worker

local async = class:extend()
local id = 1

function async:init(f)
	self.id = id
	id = id + 1
	self.firstTime = true
	self.co = coroutine.create(f)
end

function async:run(...)

	-- l.print("[%d] setup current id %d", thread.getCurrentThreadId(), self.id)
	api.current = self
	local status = coroutine.status(self.co)
	if status ~= "suspended" then
		l.print("try to run [%s] coroutine", status)
		return nil
	end

	local r
	if self.firstTime then
		self.firstTime = nil
		r = { coroutine.resume(self.co, self, ...) }
	else
		r = { coroutine.resume(self.co, ...) }
	end		
	if not r[1] then
		l.print("error while resuming async id: %d\n%s\n%s",self.id,r[2],debug.traceback())
	end
	table.remove(r, 1)
	return unpack(r)

	-- status = coroutine.status(self.co)
	-- l.print("[%d] async %d, status %s", thread.getCurrentThreadId(), self.id, status)
end

api.create = function(f)	
	return async:new(f)
end

api.yield = function(...)	
	return coroutine.yield(...)
end

api.resume = function(...)	
	return api.current:run(...)
end

local workers = { }

api.addWorker = function(worker)
	workers[#workers + 1] = worker
end

api.delWorker = function(worker)
	for i = 1, #workers  do
		if workers[i] == worker then
			table.remove(workers, i)
			break
		end
	end
end

local function hitWorkers()
	if #workers > 0 then
		for i = 1, #workers do
			local worker = workers[i]
			if worker then worker:hit() end
		end
	end
end

api.eventLoop = function()
	while true do
		if #workers < 1 then break end

		-- collect handles for WaitForMultipleObjects
		local handlesForWait = { }		
		local workerByIndexes = { }
		local msgWorker = nil

		for i = 1, #workers  do
			local worker = workers[i]
			if worker.msgWorker then
				msgWorker = worker
			end
			local handles = worker:getHandles()
			if handles then
				for j = 1, #handles do
					handlesForWait[#handlesForWait + 1] = handles[j]
					workerByIndexes[#workerByIndexes + 1] = { worker, j }
				end
			end			
		end

		if #handlesForWait > 0 then
			local result = w.MsgWaitForMultipleObjects(handlesForWait, false, 3, w.QS_ALLINPUT)

			if result >= w.WAIT_OBJECT_0 and result <= w.WAIT_OBJECT_LAST then

				-- l.print("result %d", result)
				if #handlesForWait == result then
					-- get for msg reader
					if msgWorker then
						msgWorker:hitByEvent(0)
					end
				else 

					-- calculate worker
					local index = result - w.WAIT_OBJECT_0
					local info = workerByIndexes[index + 1]
					local worker = info[1]
					worker:hitByEvent(info[2])
				end
			end
		else
			time.sleep(3)
		end

		-- hit worker without events
		hitWorkers()

	end
end

return { api = api } 
-- Background jobs: long work split into small steps that run from globalstep
-- within a time budget, taking turns. Persistent jobs survive a server restart.
local S = cb_core.S
local storage = core.get_mod_storage()

local jobs = {}
cb_core.jobs = jobs

local BUDGET_US = (tonumber(cb_core.setting("cubeborn.job_budget_ms", "15")) or 15) * 1000
local LAG_DTIME = 0.2
local budget_us = BUDGET_US

-- Another mod (the populate governor) may lower the budget for a while;
-- nil restores the default, 0 pauses the queue.
function jobs.set_budget(us)
	budget_us = us or BUDGET_US
end

function jobs.budget()
	return budget_us
end

local types = {}
local queue = {}
local next_id = math.max(storage:get_int("job_next_id"), 1)
local dirty, last_save = false, 0

local function save_now()
	local list = {}
	for _, job in ipairs(queue) do
		if job.persist then
			list[#list + 1] = { id = job.id, type = job.type, state = job.state, owner = job.owner, }
		end
	end
	storage:set_string("jobs", core.serialize(list))
	storage:set_int("job_next_id", next_id)
	dirty, last_save = false, core.get_us_time()
end

function jobs.register_type(name, def)
	assert(type(def.step) == "function", "job type needs step(): " .. name)
	types[name] = def
end

function jobs.start(type_name, state, opts)
	assert(types[type_name], "unknown job type: " .. type_name)
	opts = opts or {}
	local job = {
		id = next_id, type = type_name, state = state, owner = opts.owner,
		persist = opts.persist ~= false, on_done = opts.on_done, last_tenth = 0,
	}
	next_id = next_id + 1
	queue[#queue + 1] = job
	save_now()
	return job.id
end

function jobs.get(id)
	for _, job in ipairs(queue) do
		if job.id == id then
			return job
		end
	end
end

function jobs.list()
	return queue
end

local function remove(job)
	for i, j in ipairs(queue) do
		if j == job then
			table.remove(queue, i)
			break
		end
	end
	job.gone = true
	save_now()
end

function jobs.cancel(id)
	for _, job in ipairs(queue) do
		if job.id == id then
			remove(job)
			return true
		end
	end
	return false
end

function jobs.progress(job)
	local def = types[job.type]
	return def and def.progress and def.progress(job.state) or 0
end

local function notify(job, msg)
	core.log("action", "[cubeborn] job " .. job.id .. " (" .. job.type .. "): "
		.. core.get_translated_string("en", msg))
	if job.owner then
		core.chat_send_player(job.owner, msg)
	end
end

local function drop(job, err)
	core.log("error", "[cubeborn] job " .. job.id .. " (" .. job.type .. ") failed: "
		.. tostring(err):gsub("\n", " | "))
	remove(job)
	if job.owner then
		core.chat_send_player(job.owner, S("Job @1 failed, see the server log.", job.id))
	end
end

local function finish(job)
	remove(job)
	local def = types[job.type]
	if def.on_done then
		def.on_done(job.state, job)
	end
	if job.on_done then
		job.on_done(job.state, job)
	end
end

-- The jobs take turns, one step each, so that a long job (a pocket being
-- filled for hours) never holds back short ones (an admin's structure). A job
-- that returns "wait" sits out the rest of the slice; each slice starts one
-- job further on.
local turn = 0

-- Returns false when the job is finished or dropped.
local function run_step(job)
	local def = types[job.type]
	if not def then
		drop(job, "unknown job type")
		return false
	end
	local ok, res = xpcall(def.step, debug.traceback, job.state, job)
	if job.gone then
		return false
	end
	if not ok then
		drop(job, res)
		return false
	elseif res == "done" then
		finish(job)
		return false
	end
	dirty = true
	if def.label and def.progress then
		local tenth = math.floor(def.progress(job.state) * 10)
		if tenth > job.last_tenth and tenth < 10 then
			job.last_tenth = tenth
			notify(job, S("@1: @2%", def.label, tenth * 10))
		end
	end
	return res ~= "wait"
end

local function run_slice()
	local t0 = core.get_us_time()
	local active = {}
	for i, job in ipairs(queue) do
		active[i] = job
	end
	turn = turn % #active + 1
	local k = turn - 1
	while #active > 0 do
		k = k % #active + 1
		local job = active[k]
		if job.gone or not run_step(job) then
			table.remove(active, k)
			k = k - 1
		end
		if core.get_us_time() - t0 >= budget_us then
			break
		end
	end
end

core.register_globalstep(function(dtime)
	if queue[1] and dtime <= LAG_DTIME and budget_us > 0 then
		run_slice()
	end
	if dirty and core.get_us_time() - last_save > 1000000 then
		save_now()
	end
end)

core.register_on_shutdown(save_now)

core.register_on_mods_loaded(function()
	local list = core.deserialize(storage:get_string("jobs")) or {}
	for _, j in ipairs(list) do
		queue[#queue + 1] = { id = j.id, type = j.type, state = j.state, owner = j.owner,
			persist = true, last_tenth = 0, }
	end
	if #list > 0 then
		core.log("action", "[cubeborn] resumed " .. #list .. " background job(s)")
	end
end)

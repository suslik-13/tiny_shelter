-- /cb_dim: admin management of dimension pockets.
local S = cb_dimensions.S

local USAGE = S("Usage: /cb_dim <find|create|info|remove> [dimension] [x y z]")
local pending = {}

local function box_string(minp, maxp)
	return core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp)
end

local function tell(name, msg)
	if name and name ~= "" then
		core.chat_send_player(name, msg)
	end
end

-- done(ok, msg) is told the outcome; the owner gets the same messages in chat.
local function check_and_create(name, dim, minp, done)
	local function finish(ok, msg)
		tell(name, msg)
		if done then
			done(ok, msg)
		end
	end
	local maxp = vector.add(minp, vector.subtract(cb_dimensions.get_dim(dim).size, 1))
	local ok, err = cb_dimensions.validate_box(minp, maxp)
	if not ok then
		pending[dim] = nil
		return finish(false, err)
	end
	tell(name, S("Checking the place for '@1'...", dim))
	cb_core.check_area(minp, maxp, function(res)
		pending[dim] = nil
		if cb_dimensions.get(dim) then
			return finish(false, S("Pocket '@1' already exists.", dim))
		end
		-- Another pocket may have been registered while the place was checked;
		-- its barrier counts as natural, so check_area cannot see it.
		local valid, why = cb_dimensions.validate_box(minp, maxp)
		if not valid then
			return finish(false, why)
		end
		if not res.ok then
			if res.reason == "protected" then
				return finish(false, S("Place is protected at @1.", core.pos_to_string(res.pos)))
			end
			return finish(false, S("Place is occupied at @1.", core.pos_to_string(res.pos)))
		end
		cb_dimensions.start_create(dim, minp, name)
		finish(true, S("Creating pocket '@1' at @2.", dim, box_string(minp, maxp)))
	end)
end

-- Creates the pocket at the first free place (as /cb_dim create without
-- coordinates); done(ok, msg) once the fill job is started or it failed.
function cb_dimensions.create_auto(dim, owner, done)
	if cb_dimensions.get(dim) then
		return done(false, S("Pocket '@1' already exists.", dim))
	end
	if pending[dim] then
		return done(false, S("Pocket '@1' is already being checked.", dim))
	end
	pending[dim] = true
	cb_dimensions.find(dim, 1, function(found)
		if #found == 0 then
			pending[dim] = nil
			local msg = S("No free place found for '@1'.", dim)
			tell(owner, msg)
			return done(false, msg)
		end
		check_and_create(owner, dim, found[1].minp, done)
	end)
end

local actions = {}

function actions.find(name, dim)
	cb_dimensions.find(dim, 3, function(found)
		if #found == 0 then
			return tell(name, S("No free place found for '@1'.", dim))
		end
		for _, c in ipairs(found) do
			tell(name, S("Free place for '@1': @2", dim, box_string(c.minp, c.maxp)))
		end
	end)
	return true, S("Searching for free places for '@1'...", dim)
end

function actions.create(name, dim, coords)
	if cb_dimensions.get(dim) then
		return false, S("Pocket '@1' already exists.", dim)
	end
	if pending[dim] then
		return false, S("Pocket '@1' is already being checked.", dim)
	end
	if coords then
		pending[dim] = true
		check_and_create(name, dim, coords)
		return true
	end
	cb_dimensions.create_auto(dim, name, function() end)
	return true, S("Searching for free places for '@1'...", dim)
end

function actions.info()
	local dims = {}
	for dim in pairs(cb_dimensions.all()) do
		dims[#dims + 1] = dim
	end
	table.sort(dims)
	local lines = {}
	for _, dim in ipairs(dims) do
		local p = cb_dimensions.get(dim)
		local state = S("ready")
		if p.state ~= "ready" then
			local job = cb_dimensions.fill_job(dim)
			state = S("creating (@1%)", job and math.floor(cb_core.jobs.progress(job) * 100) or 0)
		end
		lines[#lines + 1] = S("@1: @2, @3", dim, box_string(p.minp, p.maxp), state)
	end
	if #lines == 0 then
		return true, S("No pockets.")
	end
	return true, table.concat(lines, "\n")
end

function actions.remove(_, dim)
	if not cb_dimensions.get(dim) then
		return false, S("Pocket '@1' does not exist.", dim)
	end
	local job = cb_dimensions.fill_job(dim)
	if job then
		cb_core.jobs.cancel(job.id)
	end
	cb_dimensions.remove(dim)
	return true, S("Pocket '@1' removed. Its blocks were left in place.", dim)
end

core.register_chatcommand("cb_dim", {
	params = "<find|create|info|remove> [dimension] [x y z]",
	description = S("Manage dimension pockets"),
	privs = { cb_admin = true, },
	func = function(name, param)
		local args = param:split(" ")
		local action, dim = args[1], args[2]
		if action == "info" then
			return actions.info()
		end
		if not actions[action] or not dim then
			return false, USAGE
		end
		if action ~= "remove" and not cb_dimensions.get_dim(dim) then
			return false, S("Unknown dimension '@1'. Known: @2.", dim, table.concat(cb_dimensions.dim_names(), ", "))
		end
		local coords
		if args[3] then
			local x, y, z = tonumber(args[3]), tonumber(args[4]), tonumber(args[5])
			if not (x and y and z) then
				return false, S("Invalid coordinates.")
			end
			coords = vector.round(vector.new(x, y, z))
		end
		return actions[action](name, dim, coords)
	end,
})

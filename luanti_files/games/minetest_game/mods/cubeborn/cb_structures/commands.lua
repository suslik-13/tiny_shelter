-- /cb_spawn: admins build structures.
local S = cb_structures.S

local USAGE = S("Usage: /cb_spawn <list|structure> [x y z]")

core.register_chatcommand("cb_spawn", {
	params = "<list|structure> [x y z]",
	description = S("Build a structure"),
	privs = { cb_admin = true, },
	func = function(name, param)
		local what, rest = param:match("^%s*(%S+)%s*(.-)%s*$")
		if not what then
			return false, USAGE
		end
		local variant
		what, variant = cb_structures.split_type(what)
		if what == "list" then
			local lines = {}
			for _, n in ipairs(cb_structures.type_names()) do
				local def = cb_structures.get_type(n)
				local v = def.variants and (" (" .. table.concat(def.variants, ", ") .. ")") or ""
				lines[#lines + 1] = S("@1: @2", n .. v, def.description or n)
			end
			if #lines == 0 then
				return true, S("No structures.")
			end
			return true, table.concat(lines, "\n")
		end
		if not cb_structures.get_type(what) then
			return false, S("Unknown structure '@1'.", what)
		end
		local def = cb_structures.get_type(what)
		if variant and table.indexof(def.variants or {}, variant) < 0 then
			return false, S("Unknown variant '@1' of '@2'.", variant, what)
		end
		local origin
		if rest ~= "" then
			local x, y, z = rest:match("^(-?%d+)%s+(-?%d+)%s+(-?%d+)$")
			if not x then
				return false, USAGE
			end
			origin = vector.new(tonumber(x), tonumber(y), tonumber(z))
		else
			local player = core.get_player_by_name(name)
			if not player then
				return false, S("Give coordinates when you are not in the game.")
			end
			local p = player:get_pos()
			origin = vector.new(math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5))
		end
		cb_structures.place(what, origin, name, function(res)
			if res.ok then
				core.chat_send_player(name, S("Building '@1' as structure #@2.", what, res.id))
				local words = cb_structures.get_type(what).biome_words
				if words then
					local data = core.get_biome_data(origin)
					local bname = data and core.get_biome_name(data.biome) or ""
					local fits = false
					for _, w in ipairs(words) do
						fits = fits or bname:find(w, 1, true) ~= nil
					end
					if not fits then
						core.chat_send_player(name, S("This biome is unusual for '@1'.", what))
					end
				end
			else
				core.chat_send_player(name, res.msg)
			end
		end, nil, { variant = variant, })
		return true, S("Checking the place for '@1'...", what)
	end,
})

-- The structure names (and variants) go into the command's help line once
-- every structure is registered.
local function names_line()
	local list = {}
	for _, n in ipairs(cb_structures.type_names()) do
		if not n:find(":", 1, true) then
			local def = cb_structures.get_type(n)
			list[#list + 1] = n .. (def.variants and "[:" .. table.concat(def.variants, "|") .. "]" or "")
		end
	end
	return table.concat(list, "|")
end

-- /cb_mob: admins summon Cubeborn mobs. The ender dragon is left out: it
-- belongs to the End fight.
local MAX_COUNT = 10
local SKIP = { ["cb_mobs_dim:ender_dragon"] = true, }

function cb_structures.mob_names()
	local list = {}
	for name, def in pairs(core.registered_entities) do
		if name:match("^cb_mobs_[a-z_]+:") and not SKIP[name]
				and (def._cmi_is_mob or name == "cb_mobs_dim:shulker") then
			list[#list + 1] = name
		end
	end
	table.sort(list)
	return list
end

local function short(name)
	return name:match(":(.+)$")
end

core.register_chatcommand("cb_mob", {
	params = "<list|mob> [count]",
	description = S("Summon a Cubeborn mob"),
	privs = { cb_admin = true, },
	func = function(name, param)
		local what, n = param:match("^%s*(%S+)%s*(%d*)%s*$")
		if not what then
			return false, S("Usage: /cb_mob <list|mob> [count]")
		end
		local names = cb_structures.mob_names()
		if what == "list" then
			local shorts = {}
			for _, full in ipairs(names) do
				shorts[#shorts + 1] = short(full)
			end
			return true, S("Mobs: @1", table.concat(shorts, ", "))
		end
		local found
		for _, full in ipairs(names) do
			if full == what or short(full) == what then
				found = full
			end
		end
		if not found then
			return false, S("Unknown mob '@1'. See /cb_mob list.", what)
		end
		local player = core.get_player_by_name(name)
		if not player then
			return false, S("Only in the game.")
		end
		local count = math.max(1, math.min(MAX_COUNT, tonumber(n) or 1))
		local pos = vector.add(player:get_pos(), vector.multiply(player:get_look_dir(), 3))
		pos.y = player:get_pos().y + 0.5
		for _ = 1, count do
			core.add_entity(vector.offset(pos, math.random() - 0.5, 0, math.random() - 0.5), found)
		end
		return true, S("Summoned @1 x @2.", count, short(found))
	end,
})

core.register_on_mods_loaded(function()
	local cmd = core.registered_chatcommands.cb_spawn
	if cmd then
		cmd.params = "<list|" .. names_line() .. "> [x y z]"
	end
	local mob = core.registered_chatcommands.cb_mob
	if mob then
		local shorts = {}
		for _, full in ipairs(cb_structures.mob_names()) do
			shorts[#shorts + 1] = short(full)
		end
		mob.params = "<list|" .. table.concat(shorts, "|") .. "> [count]"
	end
end)

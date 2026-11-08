-- Structure types and where a structure may stand.
local S = cb_structures.S
local types = {}

function cb_structures.register(name, def)
	assert(type(def.layout) == "function", "structure needs layout(): " .. name)
	def.dims = def.dims or { "overworld", }
	types[name] = def
end

function cb_structures.get_type(name)
	return types[name]
end

function cb_structures.type_names()
	local names = {}
	for name in pairs(types) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- "village:taiga" -> "village", "taiga"; a type name may contain ":" itself.
function cb_structures.split_type(what)
	if types[what] then
		return what, nil
	end
	local name, variant = what:match("^(.+):([^:]+)$")
	if name and types[name] and types[name].variants then
		return name, variant
	end
	return what, nil
end

-- The world a position belongs to: a pocket's dimension, "shell" inside a
-- pocket shell, "nether" inside the nether mod's range, else "overworld".
function cb_structures.dim_at(pos)
	local in_shell, pocket = cb_dimensions.is_shell(vector.round(pos))
	if pocket then
		return in_shell and "shell" or pocket.dim
	end
	if cb_core.profile.nether == "external" and nether and nether.DEPTH_FLOOR
			and pos.y >= nether.DEPTH_FLOOR and pos.y <= nether.DEPTH_CEILING then
		return "nether"
	end
	return "overworld"
end

-- A suspicious block ("sand" or "gravel") at pos whose brushing finds from
-- table `name` (nil: none yet); plain sand or gravel without cb_archaeology.
function cb_structures.suspicious(ctx, pos, kind, name, seed)
	local AR = rawget(_G, "cb_archaeology")
	local node = kind == "sand" and (AR and AR.SAND or "default:sand") or (AR and AR.GRAVEL or "default:gravel")
	if ctx.get(pos) == "ignore" then
		return
	end
	ctx.set(pos, node)
	if AR and name then
		ctx.after(function()
			if core.get_node(pos).name == node then
				AR.set_find(pos, name, seed)
			end
		end)
	end
end

function cb_structures.validate(name, minp, maxp)
	local def = types[name]
	if not def then
		return false, S("Unknown structure '@1'.", name)
	end
	local e0, e1 = core.get_mapgen_edges()
	if not (cb_core.inside(minp, e0, e1) and cb_core.inside(maxp, e0, e1)) then
		return false, S("The structure must lie inside the map generation limits.")
	end
	local dim = cb_structures.dim_at(minp)
	local one = dim ~= "shell" and dim == cb_structures.dim_at(maxp)
	for _, p in pairs(cb_dimensions.all()) do
		if one and cb_core.intersect(minp, maxp, p.minp, p.maxp) then
			local a, b = cb_dimensions.inner(p)
			one = cb_core.inside(minp, a, b) and cb_core.inside(maxp, a, b)
		end
	end
	if not one then
		return false, S("The structure must lie inside one dimension.")
	end
	-- jobs take turns now: a build must not race the fill of its pocket
	for _, p in pairs(cb_dimensions.all()) do
		if p.state ~= "ready" and cb_core.intersect(minp, maxp, p.minp, p.maxp) then
			return false, S("The pocket '@1' is still being created.", p.dim)
		end
	end
	if table.indexof(def.dims, dim) < 0 then
		return false, S("'@1' cannot be built in @2.", name, dim)
	end
	if (def.y_min and minp.y < def.y_min) or (def.y_max and maxp.y > def.y_max) then
		return false, S("'@1' must lie between heights @2 and @3.", name, tostring(def.y_min or "-"),
			tostring(def.y_max or "-"))
	end
	local other = cb_structures.registry.overlapping(minp, maxp)
	if other then
		return false, S("The place overlaps structure #@1.", other)
	end
	return true
end

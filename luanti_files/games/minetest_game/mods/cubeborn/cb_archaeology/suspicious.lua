-- Suspicious sand and gravel (spec cycle 9, 4.1; Mineclonia mcl_sus_nodes):
-- a structure records a find table in the node's meta; four brush strokes
-- uncover the find (three stage nodes in between), the block turns plain.
-- Left alone for 5 s, the brushing goes back one stage a second. Dug
-- without a brush it gives nothing.
local S = cb_archaeology.S
local A = cb_archaeology
A.SAND, A.GRAVEL = "cb_archaeology:suspicious_sand", "cb_archaeology:suspicious_gravel"
local STAGES, IDLE = 4, 5
local KEY_FIND, KEY_SEED = "cb_archaeology:find", "cb_archaeology:seed"
local state = {} -- by position hash: { stage, item, entity, dir, last }

function A.set_find(pos, name, seed)
	local meta = core.get_meta(pos)
	meta:set_string(KEY_FIND, name)
	meta:set_string(KEY_SEED, tostring(seed))
end

local function now()
	return core.get_us_time() / 1e6
end

local function forget(h)
	local st = state[h]
	if st and st.entity then
		st.entity:remove()
	end
	state[h] = nil
end

local function decay(h, pos, st)
	if state[h] ~= st then
		return
	end
	local def = core.registered_nodes[core.get_node(pos).name]
	if not def or not def._cb_main then
		return forget(h)
	end
	if now() - st.last >= IDLE then
		st.stage = st.stage - 1
		if st.stage <= 0 then
			core.swap_node(pos, { name = def._cb_main, })
			return forget(h)
		end
		core.swap_node(pos, { name = def._cb_main .. "_" .. st.stage, })
	end
	core.after(1, decay, h, pos, st)
end

-- One brush stroke on pos from the face towards dir (a unit vector out of
-- the block); returns the stage reached, STAGES when uncovered, 0 if pos is
-- not suspicious.
function A.brush(pos, user, dir)
	local def = core.registered_nodes[core.get_node(pos).name]
	if not def or not def._cb_main then
		return 0
	end
	local h = core.hash_node_position(pos)
	local st = state[h]
	if not st then
		local meta = core.get_meta(pos)
		local name = meta:get_string(KEY_FIND)
		st = { stage = 0, dir = dir, item = name ~= "" and A.find(name, tonumber(meta:get_string(KEY_SEED)) or 0), }
		if st.item then
			st.entity = core.add_entity(vector.add(pos, vector.multiply(dir, 0.38)), "cb_archaeology:find")
			if st.entity then
				st.entity:set_properties({ wield_item = st.item:get_name(), })
				if dir.z ~= 0 then
					st.entity:set_rotation(vector.new(0, math.pi / 2, 0))
				end
			end
		end
		state[h] = st
		core.after(1, decay, h, pos, st)
	end
	st.stage, st.last = st.stage + 1, now()
	if st.entity then
		st.entity:set_pos(vector.add(pos, vector.multiply(st.dir, 0.38 + 0.02 * st.stage)))
	end
	core.sound_play(def.sounds and def.sounds.dig or "", { pos = pos, gain = 0.5, max_hear_distance = 8, }, true)
	if st.stage < STAGES then
		core.swap_node(pos, { name = def._cb_main .. "_" .. st.stage, })
		return st.stage
	end
	if st.item then
		core.add_item(vector.add(pos, st.dir), st.item)
	end
	forget(h)
	local meta = core.get_meta(pos)
	meta:set_string(KEY_FIND, "")
	meta:set_string(KEY_SEED, "")
	core.swap_node(pos, { name = def._cb_parent, })
	local name = user and user.get_player_name and user:get_player_name()
	if user and user.get_wielded_item and not core.is_creative_enabled(name or "") then
		local tool = user:get_wielded_item()
		if tool:get_name() == A.BRUSH then
			tool:add_wear(math.ceil(65535 / 64))
			user:set_wielded_item(tool)
		end
	end
	return STAGES
end

core.register_entity("cb_archaeology:find", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		visual = "wielditem", visual_size = { x = 0.25, y = 0.25, },
		collisionbox = { 0, 0, 0, 0, 0, 0, },
	},
})

local function overlay(tiles, img)
	local out = {}
	for i, t in ipairs(tiles) do
		if type(t) == "table" then
			out[i] = table.copy(t)
			out[i].name = t.name .. "^" .. img
		else
			out[i] = t .. "^" .. img
		end
	end
	return out
end

local function register(name, parent, description)
	local base = core.registered_nodes[parent]
	local def = table.copy(base)
	def.name, def.mod_origin, def.type = nil, nil, nil
	def.description, def.drop = description, ""
	def._cb_main, def._cb_parent = name, parent
	def.groups = table.copy(base.groups)
	def.groups.suspicious, def.groups.falling_node = 1, 1
	def.on_destruct = function(pos)
		forget(core.hash_node_position(pos))
	end
	for i = 0, STAGES - 1 do
		local d = table.copy(def)
		d.tiles = overlay(base.tiles, "cb_archaeology_suspicious_overlay" .. (i > 0 and "_" .. i or "") .. ".png")
		if i > 0 then
			d.groups.not_in_creative_inventory = 1
		end
		core.register_node(i > 0 and name .. "_" .. i or name, d)
	end
end

register(A.SAND, "default:sand", S("Suspicious Sand"))
register(A.GRAVEL, "default:gravel", S("Suspicious Gravel"))

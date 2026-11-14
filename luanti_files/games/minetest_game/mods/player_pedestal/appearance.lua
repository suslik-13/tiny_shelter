-- Appearance cache: what a player looks like (model + skin + armor layer),
-- stored in mod storage so statues of offline players still show their
-- current skin and armor.
--
-- The engine cannot read an offline player's inventory/skin, so the look is
-- captured while the player is online: on join, on leave and whenever
-- player_api / 3d_armor / skinsdb change the player's textures. Captures are
-- debounced per player and written only if the result differs.

local storage = minetest.get_mod_storage()
local A = {}
player_pedestal.appearance = A

local mem = {}         -- name -> appearance table (also caches storage reads)
local ser = {}         -- name -> last serialized snapshot (online players)
local pending = {}     -- name -> true while a debounced capture is scheduled
local listeners = {}   -- fn(name, appearance) called when an appearance changes
local last_mesh        -- model used by real players, for the default look
local DEBOUNCE = 2
local KEY = "a:"

function A.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

local function default_skin()
	if minetest.global_exists("skins") and skins.get and skins.default then
		local skin = skins.get(skins.default)
		if skin and skin.get_texture then
			return skin:get_texture()
		end
	end
	if minetest.global_exists("armor") and armor.default_skin then
		return armor.default_skin .. ".png"
	end
	return "character.png"
end

-- Model of player_api's current default, used until a real player was seen.
local function default_mesh()
	if last_mesh then
		return last_mesh
	end
	local models = player_api.registered_models or {}
	for _, m in ipairs({ "skinsdb_3d_armor_character_5.b3d", "3d_armor_character.b3d", "character.b3d" }) do
		if models[m] then
			return m
		end
	end
	return "character.b3d"
end

function A.default()
	local mesh = default_mesh()
	local textures = { default_skin() }
	local def = (player_api.registered_models or {})[mesh]
	local n = def and def.textures and #def.textures or 1
	for i = 2, n do
		textures[i] = "blank.png"
	end
	return { mesh = mesh, textures = textures, visual_size = { x = 1, y = 1, z = 1 }, default = true }
end

local function snapshot(player)
	local p = player:get_properties()
	if p.visual ~= "mesh" or not p.mesh or p.mesh == "" then
		return nil
	end
	local textures = {}
	for i, t in ipairs(p.textures or {}) do
		textures[i] = t
	end
	-- 3d_armor layout is {skin, armor, wielditem}: drop the wielded item,
	-- a statue shows skin + armor only (and wield changes would cause writes).
	if minetest.global_exists("armor") and #textures >= 3 then
		textures[3] = "blank.png"
	end
	local vs = p.visual_size or { x = 1, y = 1 }
	return { mesh = p.mesh, textures = textures, visual_size = { x = vs.x, y = vs.y, z = vs.z or vs.x } }
end

function A.capture(player)
	local name = player:get_player_name()
	local snap = snapshot(player)
	if not snap then
		return
	end
	last_mesh = snap.mesh
	local s = minetest.serialize(snap)
	if ser[name] == nil then
		ser[name] = storage:get_string(KEY .. name)
	end
	if ser[name] == s then
		return
	end
	ser[name] = s
	storage:set_string(KEY .. name, s)
	mem[name] = snap
	for _, fn in ipairs(listeners) do
		fn(name, snap)
	end
end

function A.schedule(player)
	if not player or not player.get_player_name then
		return
	end
	local name = player:get_player_name()
	if name == "" or pending[name] then
		return
	end
	pending[name] = true
	minetest.after(DEBOUNCE, function()
		pending[name] = nil
		local p = minetest.get_player_by_name(name)
		if p then
			A.capture(p)
		end
	end)
end

function A.get(name)
	local a = mem[name]
	if a then
		return a
	end
	local s = storage:get_string(KEY .. name)
	if s ~= "" then
		a = minetest.deserialize(s)
	end
	if type(a) == "table" and a.mesh and a.textures then
		mem[name] = a
		return a
	end
	return A.default()
end

function A.has(name)
	return mem[name] ~= nil or storage:contains(KEY .. name)
end

-- Drop in-memory copies of offline players, storage stays the source.
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	A.capture(player)
	mem[name] = nil
	ser[name] = nil
end)

minetest.register_on_joinplayer(function(player)
	A.schedule(player)
end)

-- Catch every visual change made through player_api (3d_armor and skinsdb
-- both end up here).
for _, fname in ipairs({ "set_textures", "set_model" }) do
	local orig = player_api[fname]
	if orig then
		player_api[fname] = function(player, ...)
			local r = orig(player, ...)
			A.schedule(player)
			return r
		end
	end
end

if minetest.global_exists("armor") and armor.register_on_update then
	armor:register_on_update(function(player)
		A.schedule(player)
	end)
end

-- Jukebox and music discs (spec cycle 10). The 13 discs and their music come
-- from Secret Terra (st_items, music synthesized by tools/sounds/music.py):
-- Minecraft's disc ids, our own titles and tunes. A jukebox plays a disc for
-- everyone within 64 nodes until it is taken out or the jukebox is broken.
-- Sources as in Minecraft: creepers killed by skeletons (cat, stal, ward,
-- 11), dungeon, stronghold, bastion, ancient city (with disc fragments),
-- trail ruins, vaults, trial chamber supply, a ghast killed by its own
-- returned fireball (tears). The chicken jockey's disc (lava chicken) has no
-- source here: there is no chicken jockey.
local S = cb_items.S
local J = {}
cb_items.jukebox = J
J.NODE, J.FRAGMENT = "cb_items:jukebox", "cb_items:disc_fragment_5"
J.RANGE = 64

-- id, our title, creeper disc, the music file
J.DISCS = {
	{ "cat", "Whisker Waltz", true, sound = "cb_items_disc_cat", },
	{ "stal", "Smoky Corner", true, sound = "cb_items_disc_stal", },
	{ "ward", "Hollow Halls", true, sound = "cb_items_disc_ward", },
	{ "11", "Static", true, sound = "cb_items_disc_11", },
	{ "pigstep", "Crimson Strut", false, sound = "cb_items_disc_pigstep", },
	{ "otherside", "Far Lights", false, sound = "cb_items_disc_otherside", },
	{ "5", "Deep Echo", false, sound = "cb_items_disc_5", },
	{ "relic", "Buried Song", false, sound = "cb_items_disc_relic", },
	{ "precipice", "Edge of the Climb", false, sound = "cb_items_disc_precipice", },
	{ "creator", "Builder's Anthem", false, sound = "cb_items_disc_creator", },
	{ "creator_music_box", "Builder's Lullaby", false, sound = "cb_items_disc_creator_music_box", },
	{ "tears", "Rain Below", false, sound = "cb_items_disc_tears", },
	{ "lava_chicken", "Hot Feathers", false, sound = "cb_items_disc_lava_chicken", },
}
J.CREEPER = {}

function J.disc(id)
	return "cb_items:disc_" .. id
end

for _, d in ipairs(J.DISCS) do
	core.register_craftitem(J.disc(d[1]), {
		description = S("Music Disc") .. "\n" .. core.colorize("#aaaaaa", S(d[2])),
		inventory_image = "cb_items_disc_" .. d[1] .. ".png",
		stack_max = 1,
		groups = { music_disc = 1, },
		_cb_track = d.sound,
		_cb_title = d[2],
	})
	if d[3] then
		J.CREEPER[#J.CREEPER + 1] = J.disc(d[1])
	end
end

core.register_craftitem(J.FRAGMENT, {
	description = S("Disc Fragment") .. "\n" .. S("Nine fragments make a music disc"),
	inventory_image = "cb_items_disc_fragment_5.png",
})
core.register_craft({ type = "shapeless", output = J.disc("5"), recipe = {
	J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, J.FRAGMENT, }, })

-- Playing ----------------------------------------------------------------

local playing = {} -- hash -> sound handle

local function stop(pos)
	local h = core.hash_node_position(pos)
	if playing[h] then
		core.sound_stop(playing[h])
		playing[h] = nil
	end
end

function J.playing(pos)
	return playing[core.hash_node_position(pos)] ~= nil
end

function J.insert(pos, stack, player)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()
	if not inv:is_empty("disc") or core.get_item_group(stack:get_name(), "music_disc") == 0 then
		return false
	end
	local disc = stack:take_item(1)
	inv:set_stack("disc", 1, disc)
	local def = disc:get_definition()
	stop(pos)
	playing[core.hash_node_position(pos)] = core.sound_play(def._cb_track,
		{ pos = pos, gain = 1.0, max_hear_distance = J.RANGE, })
	for _, obj in ipairs(core.get_objects_inside_radius(pos, J.RANGE)) do
		if obj:is_player() then
			core.chat_send_player(obj:get_player_name(), core.colorize("#55ffff", S("Now playing: @1", S(def._cb_title))))
		end
	end
	return true
end

function J.eject(pos)
	stop(pos)
	local inv = core.get_meta(pos):get_inventory()
	local disc = inv:get_stack("disc", 1)
	if not disc:is_empty() then
		inv:set_stack("disc", 1, ItemStack(""))
		core.add_item(vector.offset(pos, 0, 1, 0), disc)
	end
	return disc
end

core.register_node(J.NODE, {
	description = S("Jukebox") .. "\n" .. S("Plays music discs"),
	tiles = { "cb_items_jukebox_top.png", "cb_items_jukebox_side.png", "cb_items_jukebox_side.png", },
	is_ground_content = false,
	groups = { choppy = 2, oddly_breakable_by_hand = 2, flammable = 1, },
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)
		core.get_meta(pos):get_inventory():set_size("disc", 1)
	end,
	on_rightclick = function(pos, _, clicker, itemstack)
		if not (clicker and clicker:is_player()) or core.is_protected(pos, clicker:get_player_name()) then
			return itemstack
		end
		if not core.get_meta(pos):get_inventory():is_empty("disc") then
			J.eject(pos)
			return itemstack
		end
		J.insert(pos, itemstack, clicker)
		return itemstack
	end,
	on_destruct = function(pos)
		J.eject(pos)
	end,
})
core.register_craft({ output = J.NODE, recipe = {
	{ "group:wood", "group:wood", "group:wood", }, { "group:wood", "default:diamond", "group:wood", },
	{ "group:wood", "group:wood", "group:wood", }, }, })

-- Sources ----------------------------------------------------------------

local function one(list)
	return list[math.random(#list)]
end

-- A creeper killed by a skeleton: Luanti's mob arrows hit with the target as
-- the puncher, so "killed by a skeleton" is read as: the last hit was not a
-- player's and a skeleton (or stray, bogged) is within 20 nodes.
J.SKELETONS = { "mobs_skeletons:skeleton", "mobs_skeletons:skeleton_archer", "mobs_skeletons:skeleton_archer_dark",
	"cb_mobs_overworld:stray", "cb_mobs_trial:bogged", }
function J.creeper_disc(pos, last_hit_by_player)
	if last_hit_by_player then
		return nil
	end
	local skel = {}
	for _, n in ipairs(J.SKELETONS) do
		skel[n] = true
	end
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 20)) do
		local e = obj:get_luaentity()
		if e and skel[e.name] then
			local disc = one(J.CREEPER)
			core.add_item(pos, disc)
			return disc
		end
	end
	return nil
end

core.register_on_mods_loaded(function()
	local creeper = core.registered_entities["cb_mobs_overworld:creeper"]
	if creeper then
		local punch, die = creeper.do_punch, creeper.on_die
		creeper.do_punch = function(self, hitter, ...)
			self._cb_hit_by_player = hitter and hitter.is_player and hitter:is_player() or false
			if punch then
				return punch(self, hitter, ...)
			end
		end
		creeper.on_die = function(self, pos, ...)
			J.creeper_disc(pos, self._cb_hit_by_player)
			if die then
				return die(self, pos, ...)
			end
		end
	end
	local N = rawget(_G, "cb_mobs_nether")
	if N and N.fireball_hit then
		local hit = N.fireball_hit
		N.fireball_hit = function(ball, obj)
			local pos = obj:get_pos()
			local r = hit(ball, obj)
			if r == "killed" and pos then
				core.add_item(pos, J.disc("tears"))
			end
			return r
		end
	end
	-- chests
	local loot = rawget(_G, "cb_structures") and cb_structures.loot
	if loot and loot.add_pool then
		local function pool(tbl, id, w, none)
			loot.add_pool(tbl, { rolls = { 1, 1, }, entries = { { w = none, }, { items = { id, }, w = w, }, }, })
		end
		pool("stronghold_corridor", J.disc("otherside"), 1, 39)
		pool("bastion_treasure", J.disc("pigstep"), 1, 9)
		pool("ancient_city", J.disc("otherside"), 1, 19)
		loot.add_pool("ancient_city", { rolls = { 1, 1, }, entries = { { w = 7, }, { items = { J.FRAGMENT, }, w = 3, n = { 1, 3, }, }, }, })
		pool("trial_chambers_supply", J.disc("creator_music_box"), 1, 49)
	end
	if rawget(_G, "dungeon_loot") and dungeon_loot.register then
		dungeon_loot.register({ { name = J.disc("cat"), chance = 0.05, }, { name = J.disc("otherside"), chance = 0.03, }, })
	end
	local A = rawget(_G, "cb_archaeology")
	if A and A.FINDS and A.FINDS.trail_ruins_rare then
		table.insert(A.FINDS.trail_ruins_rare, { items = { J.disc("relic"), }, w = 1, })
	end
	local TS = rawget(_G, "cb_mobs_trial") and cb_mobs_trial.trial
	if TS and TS.VAULT_LOOT and TS.VAULT_LOOT[3] then
		table.insert(TS.VAULT_LOOT[3].entries, { items = { J.disc("precipice"), }, w = 2, })
		table.insert(TS.VAULT_LOOT[3].entries, { items = { J.disc("creator"), }, w = 1, })
	end
end)

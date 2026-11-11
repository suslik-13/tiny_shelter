-- The xdecor enchantment table, reworked (spec 4.3): bookshelves around it,
-- three offers per item, option N costs N mese and N experience levels.
-- The node stays xdecor's, so tables already in the worlds work the new way.
local E = cb_enchanting
local S = E.S
local NAME = "xdecor:enchantment_table"
local MESE = { ["default:mese_crystal"] = true, ["imese:industrial_mese_crystal"] = true, }
local SHELVES = { "default:bookshelf", "xdecor:bookshelf", }
E.MAX_SHELVES = 30 / 2

local function X()
	return rawget(_G, "cb_xp")
end

-- Bookshelves two nodes away (5x5 ring, the table's height and one above)
-- with air between them and the table, at most 15.
function E.shelves(pos)
	local n = 0
	for dy = 0, 1 do
		for dx = -2, 2 do
			for dz = -2, 2 do
				if math.max(math.abs(dx), math.abs(dz)) == 2 then
					local p = vector.offset(pos, dx, dy, dz)
					local mid = vector.offset(pos, dx / 2 >= 0 and math.ceil(dx / 2) or math.floor(dx / 2), dy,
						dz / 2 >= 0 and math.ceil(dz / 2) or math.floor(dz / 2))
					if table.indexof(SHELVES, core.get_node(p).name) > 0 and core.get_node(mid).name == "air" then
						n = n + 1
					end
				end
			end
		end
	end
	return math.min(n, E.MAX_SHELVES)
end

local function seed(player)
	local meta = player:get_meta()
	local s = meta:get_int("cb_ench_seed")
	if s == 0 then
		s = math.random(1, 2147483646)
		meta:set_int("cb_ench_seed", s)
	end
	return s
end

local function hash(str)
	local h = 0
	for i = 1, #str do
		h = (h * 31 + str:byte(i)) % 2147483647
	end
	return h
end

-- What the table rolls with: a plain book becomes an enchanted book.
local function target(stack)
	if stack:get_name() == "default:book" then
		return ItemStack("cb_enchanting:book")
	end
	return stack
end

local function enchantable(stack)
	if stack:get_name() == "default:book" then
		return true
	end
	local c = E.class(stack:get_name())
	return c ~= nil and c ~= "book" and next(E.get(stack)) == nil
end

-- Three offers {level, power, ench, hint} (or false) for the stack; the same
-- until the player enchants something.
function E.offers(player, stack, shelves)
	if not enchantable(stack) then
		return { false, false, false, }
	end
	local item = target(stack)
	local rand = PcgRandom((seed(player) + hash(item:get_name())) % 2147483647)
	local r = E.rnd
	local base = r(rand, 1, 8) + math.floor(shelves / 2) + r(rand, 0, shelves)
	local powers = { math.max(base / 3, 1), base * 2 / 3 + 1, math.max(base, shelves * 2), }
	local out = {}
	for i, power in ipairs(powers) do
		power = math.min(power, 30)
		local ench = E.random(item, power, false, rand)
		if ench then
			local names = {}
			for n in pairs(ench) do
				names[#names + 1] = n
			end
			table.sort(names)
			local hint = names[rand:next(1, #names)]
			out[i] = { level = math.min(30, math.max(i, math.floor(power))), power = power, ench = ench,
				hint = E.label(hint, ench[hint]), }
		else
			out[i] = false
		end
	end
	return out
end

-- Experience points the option costs: the points of the last `n` levels.
function E.xp_cost(name, n)
	local x = X()
	if not x then
		return 0
	end
	local lvl = x.level_of(x.get(name))
	return x.points_for(lvl) - x.points_for(math.max(0, lvl - n))
end

local open = {}
E.table_viewers = open

local function formspec(pos, player)
	local name = player:get_player_name()
	local inv = core.get_meta(pos):get_inventory()
	local loc = "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z
	local fs = {
		"size[9,8.6;]no_prepend[]bgcolor[#080808BB;true]listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]",
		"background9[0,0;9,9;ench_ui.png;6]",
		"list[" .. loc .. ";tool;0.9,2.9;1,1;]list[" .. loc .. ";mese;2,2.9;1,1;]image[2,2.9;1,1;mese_layout.png]",
		"list[current_player;main;0.55,4.5;8,4;]listring[current_player;main]listring[" .. loc .. ";tool]",
		"listring[current_player;main]listring[" .. loc .. ";mese]",
	}
	local offers = E.offers(player, inv:get_stack("tool", 1), E.shelves(pos))
	local x = X()
	local lvl = x and x.level_of(x.get(name)) or 0
	-- no cb_xp (experience off): no level limits, no costs
	local free = not x or x.is_admin(name)
	local mese = inv:get_stack("mese", 1):get_count()
	for i, o in ipairs(offers) do
		local y = 0.6 + (i - 1) * 1.1
		if o then
			local text = S("@1 . . . ?", o.hint)
			local cost = x and S("Level @1: @2 mese, @3 XP", o.level, i, free and 0 or E.xp_cost(name, i))
				or S("@1 mese", i)
			if not free and lvl < o.level then
				cost = S("Needs level @1", o.level)
			elseif mese < i then
				cost = S("Needs @1 mese", i)
			end
			fs[#fs + 1] = "image_button[3.6," .. y .. ";5,1;bg_btn.png;opt" .. i .. ";"
				.. core.formspec_escape(text .. "\n" .. cost) .. "]"
		end
	end
	if not offers[1] and not offers[2] and not offers[3] then
		fs[#fs + 1] = "label[3.8,1.6;" .. core.formspec_escape(S("Put a tool or a book")) .. "]"
	end
	return table.concat(fs)
end

local function show(pos, player)
	local name = player:get_player_name()
	open[name] = pos
	core.show_formspec(name, "cb_enchanting:table", formspec(pos, player))
end

-- Enchants the item on the table with offer `i`; false and a message if it cannot.
function E.do_enchant(pos, player, i)
	local name = player:get_player_name()
	local inv = core.get_meta(pos):get_inventory()
	local stack = inv:get_stack("tool", 1)
	local o = E.offers(player, stack, E.shelves(pos))[i]
	if not o then
		return false, S("Nothing to enchant")
	end
	local x = X()
	local admin = x and x.is_admin(name)
	local mese = inv:get_stack("mese", 1)
	if mese:get_count() < i then
		return false, S("Needs @1 mese", i)
	end
	if x and not admin then
		if x.level_of(x.get(name)) < o.level then
			return false, S("Needs level @1", o.level)
		end
		x.spend(name, E.xp_cost(name, i))
	end
	mese:take_item(i)
	inv:set_stack("mese", 1, mese)
	if stack:get_name() == "default:book" then
		stack = ItemStack("cb_enchanting:book")
	end
	E.set(stack, o.ench)
	inv:set_stack("tool", 1, stack)
	player:get_meta():set_int("cb_ench_seed", math.random(1, 2147483646))
	core.sound_play("xdecor_enchanting", { to_player = name, gain = 0.8, }, true)
	return true
end


-- Whether `name` may still use the table at `pos` (the formspec stays open
-- while the player walks away or the area gets protected).
local function can_use(pos, player)
	return core.get_node(pos).name == NAME and vector.distance(player:get_pos(), pos) <= 8
		and not core.is_protected(pos, player:get_player_name())
end

function E.table_fields(player, fields)
	local name = player:get_player_name()
	local pos = open[name]
	if fields.quit or not pos then
		open[name] = nil
		return true
	end
	if not can_use(pos, player) then
		open[name] = nil
		return true
	end
	for i = 1, 3 do
		if fields["opt" .. i] then
			local ok, msg = E.do_enchant(pos, player, i)
			if not ok and msg then
				core.chat_send_player(name, msg)
			end
			show(pos, player)
		end
	end
	return true
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "cb_enchanting:table" then
		return E.table_fields(player, fields)
	end
end)

core.register_on_leaveplayer(function(player)
	open[player:get_player_name()] = nil
end)

local function refresh_viewers(pos)
	for name, p in pairs(open) do
		local player = core.get_player_by_name(name)
		if player and vector.equals(p, pos) then
			if can_use(pos, player) then
				show(pos, player)
			else
				open[name] = nil
			end
		end
	end
end

core.register_on_mods_loaded(function()
	local def = core.registered_nodes[NAME]
	if not def then
		return
	end
	local construct = def.on_construct
	core.override_item(NAME, {
		on_construct = function(pos)
			if construct then
				construct(pos)
			end
			core.get_meta(pos):set_string("formspec", "")
		end,
		on_rightclick = function(pos, _, clicker)
			if clicker and clicker:is_player() and not core.is_protected(pos, clicker:get_player_name()) then
				show(pos, clicker)
			end
		end,
		on_receive_fields = function() end,
		allow_metadata_inventory_put = function(pos, listname, _, stack, player)
			if core.is_protected(pos, player:get_player_name()) then
				return 0
			end
			if listname == "mese" and MESE[stack:get_name()] then
				return stack:get_count()
			elseif listname == "tool" and enchantable(stack) then
				return 1
			end
			return 0
		end,
		allow_metadata_inventory_take = function(pos, _, _, stack, player)
			if core.is_protected(pos, player:get_player_name()) then
				return 0
			end
			return stack:get_count()
		end,
		on_metadata_inventory_put = function(pos)
			refresh_viewers(pos)
		end,
		on_metadata_inventory_take = function(pos)
			refresh_viewers(pos)
		end,
	})
end)

core.register_lbm({
	label = "Cubeborn enchantment table: drop xdecor's formspec",
	name = "cb_enchanting:table_formspec",
	nodenames = { NAME, },
	run_at_every_load = true,
	action = function(pos)
		local meta = core.get_meta(pos)
		if meta:get_string("formspec") ~= "" then
			meta:set_string("formspec", "")
		end
	end,
})

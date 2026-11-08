-- Carpet and chest of a tamed llama (spec cycle 3, 6.3). The carpet shows
-- on the model (Mineclonia's decor textures); the chest holds 3 x strength
-- slots, kept as item strings in _inv (the llama's staticdata) and dropped
-- on death. Only the owner opens it (sneak + right-click); the window
-- closes beyond REACH or when the llama is gone.
local S, TR = cb_mobs_trader.S, cb_mobs_trader
TR.CHEST, TR.CHEST_FORM, TR.REACH = "default:chest", "cb_mobs_trader:chest", 6
local by_lid = setmetatable({}, { __mode = "v", }) -- _lid -> llama
local viewers = {} -- _lid -> player name

local function take_one(clicker, stack)
	if not core.is_creative_enabled(clicker:get_player_name()) then
		stack:take_item()
		clicker:set_wielded_item(stack)
	end
end

local function give(player, stack)
	local left = player:get_inventory():add_item("main", stack)
	if not left:is_empty() then
		core.add_item(player:get_pos(), left)
	end
end

local function inv_name(self)
	if not self._lid then
		self._lid = tostring(math.random(1, 2147483646))
	end
	return "cb_llama_" .. self._lid
end

local function user_ok(lid, player)
	local e = by_lid[lid]
	local pos = e and e.object:get_pos()
	return pos and player and player:get_player_name() == e.owner
		and vector.distance(pos, player:get_pos()) <= TR.REACH + 2
end

function TR.save_chest(self)
	local inv = self._lid and core.get_inventory({ type = "detached", name = "cb_llama_" .. self._lid, })
	if not inv or inv:get_size("main") == 0 then
		return
	end
	local list = {}
	for i, st in ipairs(inv:get_list("main")) do
		list[i] = st:to_string()
	end
	self._inv = list
end

local created = {}
function TR.chest_inv(self)
	local name = inv_name(self)
	local lid = self._lid
	by_lid[lid] = self
	if created[name] then
		return core.get_inventory({ type = "detached", name = name, })
	end
	local function saved()
		local e = by_lid[lid]
		if e then
			TR.save_chest(e)
		end
	end
	local inv = core.create_detached_inventory(name, {
		allow_put = function(_, _, _, stack, player)
			return user_ok(lid, player) and stack:get_count() or 0
		end,
		allow_take = function(_, _, _, stack, player)
			return user_ok(lid, player) and stack:get_count() or 0
		end,
		allow_move = function(_, _, _, _, _, n, player)
			return user_ok(lid, player) and n or 0
		end,
		on_put = saved,
		on_take = saved,
		on_move = saved,
	})
	created[name] = true
	inv:set_size("main", 3 * (self._strength or 1))
	inv:set_list("main", self._inv or {})
	return inv
end

function TR.open_chest(self, player)
	TR.chest_inv(self)
	local pname = player:get_player_name()
	viewers[self._lid] = pname
	core.show_formspec(pname, TR.CHEST_FORM, ("formspec_version[4]size[10.6,9.6]label[0.4,0.4;%s]"
		.. "list[detached:cb_llama_%s;main;0.4,0.8;%d,3;]list[current_player;main;0.4,4.6;8,4;]"
		.. "listring[detached:cb_llama_%s;main]listring[current_player;main]"):format(
		core.formspec_escape(self._chest_title or S("Llama")), self._lid, self._strength or 1, self._lid))
end

local function close(lid)
	local name = viewers[lid]
	viewers[lid] = nil
	if name then
		core.close_formspec(name, TR.CHEST_FORM)
	end
	TR.release_chest(lid)
end

-- When nobody looks into it any more the chest's contents go back into the
-- llama (its staticdata) and the detached inventory is freed; it is made
-- again on the next opening.
function TR.release_chest(lid)
	local name = "cb_llama_" .. lid
	if not created[name] then
		by_lid[lid] = nil
		return
	end
	local e = by_lid[lid]
	if e and e.object and e.object:get_pos() then
		TR.save_chest(e)
	end
	core.remove_detached_inventory(name)
	created[name], by_lid[lid] = nil, nil
end

local function closed_by(pname)
	for lid, name in pairs(viewers) do
		if name == pname then
			viewers[lid] = nil
			TR.release_chest(lid)
		end
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= TR.CHEST_FORM or not fields.quit then
		return
	end
	closed_by(player:get_player_name())
	return true
end)

core.register_on_leaveplayer(function(player)
	closed_by(player:get_player_name())
end)

-- From the llama's half-second step.
function TR.gear_step(self)
	local lid = self._lid
	local name = lid and viewers[lid]
	if not name then
		return
	end
	local player = core.get_player_by_name(name)
	if not player or vector.distance(player:get_pos(), self.object:get_pos()) > TR.REACH then
		close(lid)
	end
end

function TR.gear_click(self, clicker, stack)
	if not self.tamed or self.child or self._tid or self.driver then
		return false
	end
	local name = stack:get_name()
	local colour = name:match("^cb_blocks:carpet_(.+)$")
	if colour and TR.DECOR[colour] then
		if colour ~= self._carpet then
			local old = self._carpet
			self._carpet = colour
			take_one(clicker, stack)
			if old then
				give(clicker, ItemStack("cb_blocks:carpet_" .. old))
			end
			TR.retexture(self)
		end
		return true
	end
	if name == TR.CHEST and not self._chest then
		self._chest, self._inv = true, {}
		take_one(clicker, stack)
		TR.retexture(self)
		return true
	end
	local ctrl = clicker:get_player_control()
	if self._chest and ctrl and ctrl.sneak then
		if clicker:get_player_name() == self.owner then
			TR.open_chest(self, clicker)
		end
		return true
	end
	return false
end

function TR.drop_gear(self)
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	if self._lid then
		TR.save_chest(self)
		close(self._lid)
	end
	if self._chest then
		for _, s in ipairs(self._inv or {}) do
			if s ~= "" then
				core.add_item(pos, s)
			end
		end
		core.add_item(pos, TR.CHEST)
	end
	if self._carpet then
		core.add_item(pos, "cb_blocks:carpet_" .. self._carpet)
	end
	self._chest, self._inv, self._carpet = nil, nil, nil
	if self._lid and created["cb_llama_" .. self._lid] then
		core.remove_detached_inventory("cb_llama_" .. self._lid)
		created["cb_llama_" .. self._lid] = nil
	end
end

-- { "mod:skill1" = {...}, ...}
skills.registered_skills = {}
skills.blocking_skills = {}  -- {"pl_name" = "mod:active_skill"}, to disable skills non-permanently

local T = minetest.get_translator("skills")
local get_player_by_name = minetest.get_player_by_name

local function initialize_def() end
local function update_players_skill_def() end
local function update_player_skill_def() end
local function init_subtable() end
local function update_pl_skill_data() end

local string_metatable = getmetatable("")

local on_unlocks = {
	globals = {},
	specific = {}  -- {"skill_prefix" = {callback1, callback2...}}
}


minetest.register_on_joinplayer(function(player)
	skills.cast_passive_skills(player:get_player_name())
end)



minetest.register_on_leaveplayer(function(player, timed_out)
	local pl_name = player:get_player_name()
	local pl_skills = pl_name:get_unlocked_skills()

	for skill_name, def in pairs(pl_skills) do
		def:stop()
	end
end)





--
--
-- PUBLIC FUNCTIONS
--
--

function skills.register_skill(internal_name, def)
	def = initialize_def(internal_name, def)

   skills.registered_skills[internal_name:lower()] = def

   update_players_skill_def(def)
end



function skills.register_skill_based_on(original_name, variant_name, def)
	local original = table.copy(skills.get_skill_def(original_name))
	def = skills.override_table(original, def)
	def.internal_name = variant_name:lower()

	skills.registered_skills[variant_name:lower()] = def

	update_players_skill_def(def)
end



function skills.register_on_unlock(func, prefix)
	if prefix then
		init_subtable(on_unlocks.specific, prefix)
		table.insert(on_unlocks.specific[prefix], func)
	else
		table.insert(on_unlocks.globals, func)
	end
end



function skills.unlock_skill(pl_name, skill_name)
	skill_name = skill_name:lower()

	if not skills.does_skill_exist(skill_name) or pl_name:has_skill(skill_name) then
		return false
	end

	init_subtable(skills.player_skills, pl_name) -- init the skills' table
	init_subtable(skills.player_skills[pl_name], skill_name) -- init the single skill's table
	init_subtable(skills.player_skills[pl_name][skill_name], "data") -- init the skill's data table

	local pl_skill = update_player_skill_def(pl_name, skill_name)

	-- on_unlock callbacks
	local skill_prefix = skill_name:split(":")[1]
	if on_unlocks.specific[skill_prefix] then
		for _, specific_callback in pairs(on_unlocks.specific[skill_prefix]) do
			specific_callback(pl_skill)
		end
	end
	for _, global_callback in pairs(on_unlocks.globals) do global_callback(pl_skill) end

	if pl_skill.passive then pl_skill:enable() end

	return true
end
string_metatable.__index["unlock_skill"] = skills.unlock_skill



function skills.remove_skill(pl_name, skill_name)
	skill_name = skill_name:lower()
	local skill = pl_name:get_skill(skill_name)

	if not skill then return false end

	pl_name:disable_skill(skill_name)
	skills.player_skills[pl_name][skill_name] = nil

	return true
end
string_metatable.__index["remove_skill"] = skills.remove_skill



function skills.get_skill(pl_name, skill_name)
   local pl_skills = skills.player_skills[pl_name]

	if
		not skills.does_skill_exist(skill_name)
		or
		pl_skills == nil or pl_skills[skill_name:lower()] == nil
	then
   	return false
	end

	local pl_skill_table = skills.player_skills[pl_name][skill_name:lower()]
	pl_skill_table.player = minetest.get_player_by_name(pl_name)

   return pl_skill_table
end
string_metatable.__index["get_skill"] = skills.get_skill



function skills.has_skill(pl_name, skill_name)
   return pl_name:get_skill(skill_name) ~= false
end
string_metatable.__index["has_skill"] = skills.has_skill



function skills.cast_skill(pl_name, skill_name, args)
   local skill = pl_name:get_skill(skill_name)

	if skill then
		return skill:cast(args)
	else
		return false
	end

end
string_metatable.__index["cast_skill"] = skills.cast_skill



function skills.start_skill(pl_name, skill_name, args)
   local skill = pl_name:get_skill(skill_name)

	if skill then
		return skill:start(args)
	else
		return false
	end

end
string_metatable.__index["start_skill"] = skills.start_skill



function skills.stop_skill(pl_name, skill_name)
   local skill = pl_name:get_skill(skill_name)

	if skill then
		return skill:stop()
	else
		return false
	end

end
string_metatable.__index["stop_skill"] = skills.stop_skill



function skills.enable_skill(pl_name, skill_name)
	local skill = pl_name:get_skill(skill_name)

	if not skill then return false end

	return skill:enable()
end
string_metatable.__index["enable_skill"] = skills.enable_skill



function skills.disable_skill(pl_name, skill_name)
   local skill = pl_name:get_skill(skill_name)

	if not skill then return false end

	return skill:disable()
end
string_metatable.__index["disable_skill"] = skills.disable_skill



function skills.get_skill_def(skill_name)
   if not skills.does_skill_exist(skill_name) then
   	return false
   end

   return skills.registered_skills[skill_name:lower()]
end



function skills.does_skill_exist(skill_name)
   return skill_name and skills.registered_skills[skill_name:lower()]
end



function skills.get_registered_skills(prefix)
	local registered_skills = {}

	for name, def in pairs(skills.registered_skills) do
		if prefix and string.split(name, ":")[1]:match(prefix) then
			registered_skills[name] = def
		elseif prefix == nil then
			registered_skills[name] = def
		end
	end

   return registered_skills
end



function skills.get_unlocked_skills(pl_name, prefix)
	local skills = skills.get_registered_skills(prefix)
	local unlocked_skills = {}

	for name, def in pairs(skills) do
		if pl_name:has_skill(name) then
			unlocked_skills[name] = def
		end
	end

	return unlocked_skills
end
string_metatable.__index["get_unlocked_skills"] = skills.get_unlocked_skills



function skills.basic_checks_in_order_to_cast(skill)
	local active_blocking_skill = skills.blocking_skills[skill.pl_name]
	local is_blocked_by_another_skill = (
		active_blocking_skill
		and active_blocking_skill ~= skill.internal_name
		and skill.can_be_blocked_by_other_skills
	)

	if is_blocked_by_another_skill then return false end

	if not skill.data._enabled then
		if skills.settings.chat_warnings.disabled ~= false then
			skills.error(skill.pl_name, T("You can't use the @1 skill now", skill.name))
		end
		
		return false
	end

	return get_player_by_name(skill.pl_name)
end





--
--
-- PRIVATE FUNCTIONS
--
--

function update_players_skill_def(def)
   for pl_name, skills in pairs(skills.player_skills) do
		update_player_skill_def(pl_name, def.internal_name)
   end
end



function update_player_skill_def(pl_name, skill_name)
	local def = skills.get_skill_def(skill_name)
	local pl_skills = skills.player_skills[pl_name]
	local skill = pl_name:get_skill(skill_name)

	if skill then
		skill = table.copy(def)
		skill.pl_name = pl_name
		skill.player = minetest.get_player_by_name(pl_name)
		skill.data = update_pl_skill_data(pl_name, skill.internal_name)

		pl_skills[skill_name] = skill
	end

	return pl_skills[skill_name]
end



function initialize_def(internal_name, def)
	local empty_func = function() end
	local logic = def.cast or empty_func
	def.internal_name = internal_name
	def.passive = def.passive or false
	def.cooldown = def.cooldown or 0
	def.description = def.description or "No description."
	def.sounds = def.sounds or {}
	def.attachments = def.attachments or {}
	def.cooldown_timer = 0
	def.is_active = false
	def.data = def.data or {}
	def.on_start = def.on_start or empty_func
	def.on_stop = def.on_stop or empty_func
	def.data = def.data or {}
	def.data._particles = {}
	def.data._enabled = true
	if def.can_be_blocked_by_other_skills == nil then def.can_be_blocked_by_other_skills = true end

	def.cast = function(self, args)
		return skills.cast(self, logic, def, args)
	end

	def.start = function(self, args)
		return skills.start(self, def, args)
   end

	def.stop = function(self)
		return skills.stop(self)
   end

	def.disable = function(self)
		if not self.data._enabled then return false end

		self:stop()
		self.data._enabled = false

		return true
	end

	def.enable = function(self)
		if self.data._enabled then return false end

		self.data._enabled = true
		if self.passive then
			self.pl_name:start_skill(self.internal_name)
		end

		return true
	end

   return def
end



function init_subtable(table, subtable_name)
   table[subtable_name] = table[subtable_name] or {}
end



function skills.play_sound(skill, sound, ephemeral)
	if not sound then return false end

	sound.pos = skill.player:get_pos()
	if sound.to_player then sound.to_player = skill.pl_name end
	if sound.object then sound.object = skill.player end

	return minetest.sound_play(sound, sound, ephemeral)
end



function update_pl_skill_data(pl_name, skill_name)
	local skill_def = skills.get_skill_def(skill_name)
	local pl_data = table.copy(skills.player_skills[pl_name][skill_name].data)

   -- adding any new data's properties declared in the def table
   -- to the already existing player's data table
   for key, def_value in pairs(skill_def.data) do
		if pl_data[key] == nil then pl_data[key] = def_value end

		-- if an old property's type changed, then reset it
		if type(pl_data[key]) ~= type(def_value) then pl_data[key] = def_value end
   end

	return pl_data
end
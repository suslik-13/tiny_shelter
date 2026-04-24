--[[

	Mobs Banshee - Adds banshees.
	Copyright © 2018, 2020 Hamlet and contributors.

	Licensed under the EUPL, Version 1.2 or – as soon they will be
	approved by the European Commission – subsequent versions of the
	EUPL (the "Licence");
	You may not use this work except in compliance with the Licence.
	You may obtain a copy of the Licence at:

	https://joinup.ec.europa.eu/software/page/eupl
	https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32017D0863

	Unless required by applicable law or agreed to in writing,
	software distributed under the Licence is distributed on an
	"AS IS" basis,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
	implied.
	See the Licence for the specific language governing permissions
	and limitations under the Licence.

--]]

--
-- Entity definition
--

mobs:register_mob('mobs_banshee:banshee', {
	type = 'monster',
	hp_min = minetest.PLAYER_MAX_HP_DEFAULT,
	hp_max = minetest.PLAYER_MAX_HP_DEFAULT,
	armor = 100,
	walk_velocity = 1,
	run_velocity = 5.2,
	walk_chance = 1,
	jump = true,
	jump_height = 1.1,
	stepheight = 1.1,
	pushable = false,
	view_range = 15,
	damage = 9999,
	knock_back = false,
	water_damage = 0,
	lava_damage = 0,
	light_damage = 9999,
	suffocation = 0,
	floats = 0,
	reach = 14,
	attack_type = 'dogfight',
	specific_attack = {'player', 'mobs_humans:human'},
	blood_amount = 0,
	--immune_to = {
	--	{'all'}
	--},
	makes_footstep_sound = false,
	sounds = {
		distance = 30,
		random = 'mobs_banshee_1',
		war_cry = 'mobs_banshee_2',
		attack = 'mobs_banshee_2'
	},
	visual = 'mesh',
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
	textures = {
		{'mobs_banshee_1.png'},
		{'mobs_banshee_2.png'}
	},
	mesh = 'character.b3d',
	animation = {
		stand_start = 81,
		stand_end = 160,
		stand_speed = 30,
		walk_start = 168,
		walk_end = 187,
		walk_speed = 30,
		run_start = 168,
		run_end = 187,
		run_speed = 30,
	},

	after_activate = function(self, staticdata, def, dtime)
		self.spawned = true
		self.counter = 0
		self.object:set_properties({
			counter = self.counter,
			spawned = self.spawned
		})

		local position = self.object:get_pos()
		minetest.place_node(position, {name = 'mobs_banshee:glowing_node'})
	end,

	do_custom = function(self, dtime)
		if (mobs_banshee.banshee_daytime_check == true) then

			if (self.light_damage ~= 0) then
				self.light_damage = 0

				self.object:set_properties({
					light_damage = self.light_damage
				})
			end

			if (self.spawned == true) then
				local b_dayTime = mobs_banshee.fn_DayOrNight()

				if (b_dayTime == true) then
					self.object:remove()

				else
					self.spawned = false
					self.object:set_properties({
						spawned = self.spawned
					})

				end

			else
				if (self.counter < 15.0) then
					self.counter = (self.counter + dtime)

					self.object:set_properties({
						counter = self.counter
					})

				else
					local b_dayTime = mobs_banshee.fn_DayOrNight()

					if (b_dayTime == true) then
						self.object:remove()

					else
						self.counter = 0

						self.object:set_properties({
							counter = self.counter
						})

					end
				end
			end
		else
			if (self.light_damage ~= 9999) then
				self.light_damage = 9999

				self.object:set_properties({
					light_damage = self.light_damage
				})
			end
		end
	end
})

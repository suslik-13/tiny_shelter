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
-- Glowing node
--

minetest.register_node('mobs_banshee:glowing_node', {
	description = "Banshee's Glowing Node",
	groups = {not_in_creative_inventory = 1},
	drawtype = 'airlike',
	walkable = false,
	pointable = false,
	diggable = false,
	climbable = false,
	buildable_to = true,
	floodable = true,
	light_source = 6,

	on_construct = function(pos)
		minetest.get_node_timer(pos):start(15)
	end,

	on_timer = function(pos, elapsed)
		local b_dayTime = mobs_banshee.fn_DayOrNight()

		if (b_dayTime == true) then
			minetest.get_node_timer(pos):stop()
			minetest.set_node(pos, {name = 'air'})
		end

		return true
	end
})

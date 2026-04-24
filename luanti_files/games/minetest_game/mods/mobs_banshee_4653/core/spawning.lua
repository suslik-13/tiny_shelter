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
-- Entity spawners
--

mobs:spawn({
	name = 'mobs_banshee:banshee',
	nodes = {'bones:bones', 'mobs_humans:human_bones'},
	neighbors = {'air'},
	max_light = 4,
	min_light = 0,
	interval = 60,
	chance = 7,
	active_object_count = 1,
	min_height = -30912,
	max_height = 31000,
	day_toggle = false
})

mobs:register_egg('mobs_banshee:banshee',
	'Banshee',
	'bones_front.png', -- the texture displayed for the egg in inventory
	0, -- egg image in front of your texture (1 = yes, 0 = no)
	false -- if set to true this stops spawn egg appearing in creative
)


--
-- Alias
--

mobs:alias_mob('mobs:banshee', 'mobs_banshee:banshee')

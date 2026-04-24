--[[

	Mobs Banshee - Adds banshees.
	Copyright © 2018, 2020 Hamlet <hamlatmesehub@riseup.net> and contributors.

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
-- Global mod's namespace
--

mobs_banshee = {}


--
-- Constants
--

mobs_banshee.banshee_daytime_check =
	minetest.settings:get_bool('mobs_banshee_daytime_check')

if (mobs_banshee.banshee_daytime_check == nil) then
	mobs_banshee.banshee_daytime_check = false
end


--
-- Procedures
--

-- Minetest logger
local pr_LogMessage = function()

	-- Constant
	local s_LOG_LEVEL = minetest.settings:get('debug_log_level')

	-- Body
	if (s_LOG_LEVEL == nil)
	or (s_LOG_LEVEL == 'action')
	or (s_LOG_LEVEL == 'info')
	or (s_LOG_LEVEL == 'verbose')
	then
		minetest.log('action', '[Mod] Mobs Banshee [v0.3.4] loaded.')
	end
end


-- Subfiles loader
local pr_LoadSubFiles = function()

	-- Constant
	local s_MOD_PATH = minetest.get_modpath('mobs_banshee')

	-- Body
	dofile(s_MOD_PATH .. '/core/function.lua')
	dofile(s_MOD_PATH .. '/core/node.lua')
	dofile(s_MOD_PATH .. '/core/mob.lua')
	dofile(s_MOD_PATH .. '/core/spawning.lua')

end


--
-- Main body
--

pr_LoadSubFiles()
pr_LogMessage()

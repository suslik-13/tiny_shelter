yl_speak_up = {}

-- human-readable version
yl_speak_up.version = "05.11.23 first publication"

-- some mods (i.e. yl_speak_up_addons) need to be called again when
-- this mod is reloaded via chat command "/npc_talk_reload";
-- this is a list of such functions
yl_speak_up.inform_when_reloaded = {}

yl_speak_up.register_on_reload = function(fun, desc)
	-- avoid double entries
	for i, f in ipairs(yl_speak_up.inform_when_reloaded) do
		if(f == fun) then
			return
		end
	end
	table.insert(yl_speak_up.inform_when_reloaded, fun)
	minetest.log("action","[MOD] yl_speak_up Will execute function \""..tostring(desc)..
		"\" on each reload.")
	-- execute it once so that the calling mod doesn't have to do that manually
	fun()
end


local modpath = minetest.get_modpath("yl_speak_up")..DIR_DELIM
yl_speak_up.worldpath = minetest.get_worldpath()..DIR_DELIM
yl_speak_up.modpath = modpath

yl_speak_up.modstorage = minetest.get_mod_storage()

-- status
-- 0: NPCs may speak
-- 1: NPCs may not speak
-- 2: NPCs must selfdestruct on load. Their dialogs remain safed
yl_speak_up.status = yl_speak_up.modstorage:get_int("status") or 0

-- needed for assigning individual IDs (n_id) to NPC
yl_speak_up.number_of_npcs = yl_speak_up.modstorage:get_int("amount") or 0

-- we need to know how many quests exist in this world;
-- if a quest shall be copied to a new world, its variable needs to be created
-- manually first, then a quest beeing created, and *then* the quest file copied
yl_speak_up.number_of_quests = yl_speak_up.modstorage:get_int("max_quest_nr") or 0

-- which player (key) is talking to which NPC?
yl_speak_up.speak_to = {}

-- allow to request the highest possible version number for formspec_version
-- for each individual player; formspec_version...
--    ver 1 looks very bad because button height can't be set)
--    ver 2 works pretty well because the code has workarounds for the scroll elements
--    ver 3 is what this was developed with and looks best
yl_speak_up.fs_version = {}

-- used for storing custom functions only this server may have
yl_speak_up.custom_server_functions = {}

-- may store a table of registered mobs in the future; currently not really used
yl_speak_up.mob_table = {}

-- the real implementation happens in interface_mobs_api.lua
-- mob implementations may need this at an earlier point
yl_speak_up.mobs_on_rightclick = function(self, clicker)
	if(not(yl_speak_up.do_mobs_on_rightclick)) then
		return false
	end
	return yl_speak_up.do_mobs_on_rightclick(self, clicker)
end

yl_speak_up.mobs_after_activate = function(self, staticdata, def, dtime)
	if(not(yl_speak_up.do_mobs_after_activate)) then
		return false
	end
	return yl_speak_up.do_mobs_after_activate(self, staticdata, def, dtime)
end

-- Some files may or may not exist on the server - they contain adjustments
-- local to the server.
-- Here you can override what you need for YOUR SERVER.
-- Note: These files here are NOT part of the git repository and will NOT be
--       overwritten when the mod is updated. You need to maintain them
--       yourself for your server!
-- This is a local function for security reasons.
local yl_speak_up_execute_if_file_exists = function(reason)
	local file_name = ""
	if(reason == "config") then
		-- This mod is configured through a config file. Here in this
		-- file you can keep and maintain your own local config.
		--
		-- This file will be loaded and executed (if it exists) at
		-- startup AND each time when the command /npc_talk_reload
		-- is given.
		file_name = modpath.."local_server_config.lua"
	elseif(reason == "reload") then
		-- Add functions that exist only on your server. This is for
		-- example useful for overriding and adding functions found
		-- in the file:
		--       custom_functions_you_can_override.lua
		--
		-- This file will be loaded and executed (if it exists) at
		-- startup AND each time when the command /npc_talk_reload
		-- is given.
		file_name = modpath.."local_server_do_on_reload.lua"
	elseif(reason == "startup") then
		-- Add functionality that exists only on your server and that
		-- is exectuted only ONCE when this mod here is LOADED - not
		-- each time the reload command is executed.
		-- This is useful for calling minetest.register_* functions,
		-- i.e. for registering new chat commands.
		file_name = modpath.."local_server_do_once_on_startup.lua"
	else
		-- *only* the file names above are allowed
		return
	end
	-- actually check if the file exists (it's optional after all)
	local file, err = io.open(file_name, "r")
	if(err) then
		minetest.log("action","[MOD] yl_speak_up Ignoring non-existing file \'"..file_name..
				"\' (may contain server-side adjustments).")
		return
	end
	io.close(file)
	minetest.log("action","[MOD] yl_speak_up Found and executing file \'"..file_name..
				"\' with server-side adjustments.")
	dofile(file_name)

end


-- the functions in here can be reloaded without restarting the server
--	log_entry: what to write in the logfile
yl_speak_up.reload = function(modpath, log_entry)
	-- the server-specific configuration
	dofile(modpath .. "config.lua")

	-- Here you can override config values for YOUR SERVER.
	yl_speak_up_execute_if_file_exists("config")

	-- those paths are set in config.lua - so make sure they exist
	minetest.mkdir(yl_speak_up.worldpath..yl_speak_up.path)
	minetest.mkdir(yl_speak_up.worldpath..yl_speak_up.inventory_path)
	minetest.mkdir(yl_speak_up.worldpath..yl_speak_up.log_path)
	minetest.mkdir(yl_speak_up.worldpath..yl_speak_up.quest_path)

	-- logging and showing the log
	dofile(modpath .. "api/api_logging.lua")
	-- players *and* npc need privs for certain things; this here handles the NPC side of things
	dofile(modpath .. "npc_privs.lua")
	-- add generic dialogs
	dofile(modpath .. "add_generic_dialogs.lua")
	-- handle on_player_receive_fields and showing of formspecs
	dofile(modpath .. "show_fs.lua")
	-- needs to be registered after show_fs.lua so that it can register its formspecs:
	dofile(modpath .. "fs/fs_show_log.lua")
	-- general decoration part for main formspec, trade window etc.
	dofile(modpath .. "api/api_decorated.lua")
	-- change dialog d_dynamic via an extra function on the fly when the player talks to the NPC:
	dofile(modpath .. "dynamic_dialog.lua")
	-- the formspec and input handling for the main dialog
	dofile(modpath .. "api/api_talk.lua")
	dofile(modpath .. "fs/fs_talkdialog.lua")

	-- As the name says: a collection of custom functions that you can
	-- override on your server or in your game to suit your needs;
	-- Note: No special privs are needed to call custom functions. But...
	--       of course you can change them only if you have access to
	--       the server's file system or can execute lua code.
	-- Note: Please do not edit this file. Instead, create and edit the
	--       file "local_server_do_on_reload.lua"!
	dofile(modpath .. "api/custom_functions_you_can_override.lua")

	-- execute preconditions, actions and effects
	dofile(modpath .. "exec_eval_preconditions.lua")
	dofile(modpath .. "exec_actions.lua")
	-- the formspecs for the actions:
	dofile(modpath .. "fs/fs_action_npc_wants.lua")
	dofile(modpath .. "fs/fs_action_npc_gives.lua")
	dofile(modpath .. "fs/fs_action_text_input.lua")
	dofile(modpath .. "fs/fs_action_evaluate.lua")
	-- execute and apply effects:
	dofile(modpath .. "exec_apply_effects.lua")
	dofile(modpath .. "npc_talk_debug.lua")
	-- execute lua code directly (preconditions and effects) - requires priv
	dofile(modpath .. "eval_and_execute_function.lua")
	-- provide the NPC with an initial (example) dialog and store name, descr and owner:
	dofile(modpath .. "initial_config.lua")
	-- set name, description and owner (owner only with npc_talk_master priv)
	dofile(modpath .. "fs/fs_initial_config.lua")
	-- inspect and accept items the player gave to the NPC
	dofile(modpath .. "fs/fs_player_offers_item.lua")
	-- inventory management, trading and handling of quest items:
	dofile(modpath .. "api/api_inventory.lua")
	dofile(modpath .. "fs/fs_inventory.lua")
	-- limit how much the NPC shall buy and sell
	dofile(modpath .. "api/api_trade.lua")
	dofile(modpath .. "fs/fs_trade_limit.lua")
	dofile(modpath .. "fs/fs_edit_trade_limit.lua")
	-- trade one item(stack) against one other item(stack)
	dofile(modpath .. "api/api_trade_inv.lua")
	dofile(modpath .. "fs/fs_do_trade_simple.lua")
	dofile(modpath .. "fs/fs_add_trade_simple.lua")
	-- just click on a button to buy items from the trade list
	dofile(modpath .. "fs/fs_trade_via_buy_button.lua")
	-- easily accessible list of all trades the NPC offers
	dofile(modpath .. "fs/fs_trade_list.lua")
	-- handle variables for quests for player-owned NPC
	dofile(modpath .. "quest_api.lua")
	-- setting skin, wielded item etc.
	dofile(modpath .. "api/api_fashion.lua")
	-- properties for NPC without specific dialogs that want to make use of
	-- some generic dialogs
	dofile(modpath .. "api/api_properties.lua")
	-- the main functionality of the mod
	dofile(modpath .. "functions_dialogs.lua")
	dofile(modpath .. "functions_save_restore_dialogs.lua")
	dofile(modpath .. "functions_talk.lua")
	-- implementation of the chat commands registered in register_once.lua:
	dofile(modpath .. "chat_commands.lua")

	-- show a list of all NPC the player can edit
	dofile(modpath .. "api/api_npc_list.lua")
	dofile(modpath .. "fs/fs_npc_list.lua")

	-- this may load custom things like preconditions, actions, effects etc.
	-- which may depend on the existance of other mods
	dofile(modpath .. "addons/load_addons.lua")

	-- some general functions that are useful for mobs_redo
	-- (react to right-click, nametag color etc.)
	-- only gets loaded if mobs_redo (mobs) exists as mod
	dofile(modpath .. "interface_mobs_api.lua")

	-- export dialog for cut&paste in .json format
	dofile(modpath .. "export_to_ink.lua")
	dofile(modpath .. "fs/fs_export.lua")

	dofile(modpath .. "import_from_ink.lua")

	-- edit_mode.lua has been moved to the mod npc_talk_edit:
--	dofile(modpath .. "editor/edit_mode.lua")

	-- initialize and load all registered generic dialogs
	yl_speak_up.load_generic_dialogs()

	if(log_entry) then
		minetest.log("action","[MOD] yl_speak_up "..tostring(log_entry))
	end

	-- reload all mods that may have to add something as well
	for i, f in ipairs(yl_speak_up.inform_when_reloaded) do
		f()
	end

	-- Add functionality that exist only on your server.
	yl_speak_up_execute_if_file_exists("reload")
end


-- register all the necessary things; this ought to be done only once
-- (although most might work without a server restart as well; but we
-- better want to be on the safe side here)
dofile(modpath .. "register_once.lua")

-- Register things that are only used on your server.
yl_speak_up_execute_if_file_exists("startup")


-- load all those files that can also be reloaded without a server restart
-- load here for the first time:
yl_speak_up.reload(modpath, "loaded")

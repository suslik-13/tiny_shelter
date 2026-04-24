-- Note: This config file is not intended to be edited directly.
--       Like all my mods, it foremost provides an interface/api so
--       that another mod (i.e. a server specific one written by you)
--       can call functions here and do the settings.
--
--       That way you can update this mod easily and keep your settings
--       in a seperate mod and even override functions there if you
--       want.
--
--       So please use a seperate config mod!

-- Do the NPCs talk right after they spawned? Change this only if you
-- want to globally prevent NPC from talking.
yl_speak_up.talk_after_spawn = true

------------------------------------------------------------------------------
-- Config values you can adjust
------------------------------------------------------------------------------

-- how many buttons will be shown simultaneously without having to scroll?
-- Changing this value might not be a too good idea as it might break
-- formspecs.
yl_speak_up.max_number_of_buttons = 7
-- how many buttons can be added to one dialog?
yl_speak_up.max_number_of_options_per_dialog = 15

-- how many rows and cols shall be used for the trade overview list?
yl_speak_up.trade_max_rows = 10
-- change the rows above as needed, but do not increase the cols
-- above 12 (there is no room for more)
yl_speak_up.trade_max_cols = 12

-- how many prerequirements can the player define per dialog option?
yl_speak_up.max_prerequirements = 12
-- how many actions can there be per dialog option?
-- for now, more than one doesn't make sense
yl_speak_up.max_actions = 1
-- how many effects can the player define per dialog option?
yl_speak_up.max_result_effects = 6

-- An option may be choosen automaticly without the player having to click if all of its
-- preconditions are true and the mode is set to automatic. Now, if the choosen target
-- dialog has an option that also uses this automatic mode, infinite loops might be
-- created. This option exists to avoid them. Any small value will do.
yl_speak_up.max_allowed_recursion_depth = 5

-- nametag colors based on the NPC's health are a bit too colorful
-- (and besides, NPC should not get hurt anyway) - so use fixed colors
yl_speak_up.nametag_color_when_not_muted = "#00DDDD"
yl_speak_up.nametag_color_when_muted     = "#FF00FF"

-- NPC can send a message to all players as an effect;
-- this text will be put in front of this message so that you and your players
-- know that it originated from an NPC (just make sure this returns a string)
yl_speak_up.chat_all_prefix = minetest.colorize("#0000FF", "[NPC] ")
-- the NPC will use this color when sending a chat message
yl_speak_up.chat_all_color = "#AAAAFF"


------------------------------------------------------------------------------
-- Skin and mesh definition - will be extended in i.e. npc_talk
-- Don't edit here.
------------------------------------------------------------------------------
-- diffrent NPC may use diffrent models
-- IMPORTANT: If you want to support an NPC with a diffrent model, provide
--            an entry in this array! Else setting its skin will fail horribly.
yl_speak_up.mesh_data = {}
yl_speak_up.mesh_data["error"] = {
	texture_index = 1,
	can_show_wielded_items = false,
	}


-- diffrent mob types may want to wear diffrent skins - even if they share the
-- same model/mesh
yl_speak_up.mob_skins = {}
-- some models support capes
yl_speak_up.mob_capes = {}


-- some mobs (in particular from mobs_redo) can switch between follow (their owner),
-- stand and walking when they're right-clicked; emulate this behaviour for NPC in
-- this list
yl_speak_up.emulate_orders_on_rightclick = {}

-- add a special line for a particluar mob (i.e. picking mob up via menu entry
-- instead of lasso)
-- index: entity name; values: table with indices...
-- 	condition         a condition (i.e. a function)
-- 	text_if_true      text shown on button if the condition is true
-- 	text_if_false     text shown on button if the condition is false
-- 	execute_function  function to call when this button is selected
yl_speak_up.add_on_rightclick_entry = {}

------------------------------------------------------------------------------
-- Extend this in your own mod or i.e. in npc_talk
------------------------------------------------------------------------------
-- some properties from external NPC can be edited and changed (they have the self. prefix),
-- and it is possible to react to property changes with handlers;
--     key: name of the property (i.e. self.order);
--     value: function that reacts to attempts to change the property
-- For an example, see custom_functions_you_can_override.lua
yl_speak_up.custom_property_handler = {}


------------------------------------------------------------------------------
-- Path definitions (usually there is no need to change this)
------------------------------------------------------------------------------
-- What shall we call the folder all the dialogs will reside in?
yl_speak_up.path = "yl_speak_up_dialogs"

-- What shall we call the folder all the inventories of the NPC will reside in?
yl_speak_up.inventory_path = "yl_speak_up_inventories"

-- Where shall player-specific varialbes (usually quest states) be stored?
yl_speak_up.player_vars_save_file = "yl_speak_up_player_vars"

-- Where to store the logfiles for the individual NPC
yl_speak_up.log_path = "yl_speak_up_log"

-- Where shall information about the quests be stored?
yl_speak_up.quest_path = "yl_speak_up_quests"

-- amount of time in seconds that has to have passed before the above file will be saved again
-- (more time can pass if no variable is changed)
yl_speak_up.player_vars_min_save_time = 60


------------------------------------------------------------------------------
-- Privs - usually no need to change
------------------------------------------------------------------------------
-- NPC need npc privs in order to use some preconditions, actions and effects.
--
-- Plaers need privs in order to add, edit and change preconditions, actions and
-- effects listed in yl_speak_up.npc_priv_names in npc_privs.lua.
--
-- The following player priv allows the player to use the "/npc_talk privs" command to
-- grant/revoke/see these npc privs for *all NPC - not only for those the player can edit!
-- * default: "npc_talk_admin" (but can also be set to "npc_master" or "privs" if you want)
yl_speak_up.npc_privs_priv = "npc_talk_admin"

-- depending on your server, you might want to allow /npc_talk privs to be used by players
-- who *don't* have the privs priv;
-- WANRING: "precon_exec_lua" and "effect_exec_lua" are dangerous npc privs. Only players
--          with the privs priv ought to be able to use those!
-- The privs priv is the fallback if nothing is specified here.
yl_speak_up.npc_priv_needs_player_priv = {}
-- these privs allow to create items out of thin air - similar to the "give" priv
yl_speak_up.npc_priv_needs_player_priv["effect_give_item"] = "give"
yl_speak_up.npc_priv_needs_player_priv["effect_take_item"] = "give"
-- on servers with travelnets and/or teleporters, you'd most likely want to allow every
-- player to let NPC teleport players around; the "interact" priv covers that
--yl_speak_up.npc_priv_needs_player_priv["effect_move_player"] = "interact"
-- on YourLand, travel is very restricted; only those who can teleport players around can
-- do it with NPC as well; for backward compatibility, this is set for all servers
yl_speak_up.npc_priv_needs_player_priv["effect_move_player"] = "bring"

------------------------------------------------------------------------------
-- Blacklists - not all blocks may be suitable for all effects NPC can do
------------------------------------------------------------------------------
-- these blacklists forbid NPC to use effects on blocks; format:
--   yl_speak_up.blacklist_effect_on_block_interact[ node_name ] = true
-- forbids all interactions;
-- use this if a node isn't prepared for a type of interaction with
-- an NPC and cannot be changed easily;
-- Example: yl_speak_up.blacklist_effect_on_block_right_click["default:chest"] = true
yl_speak_up.blacklist_effect_on_block_interact = {}
-- blocks the NPC shall not be able to place:
yl_speak_up.blacklist_effect_on_block_place = {}
-- blocks the NPC shall not be able to dig:
yl_speak_up.blacklist_effect_on_block_dig = {}
-- blocks the NPC shall not be able to punch:
yl_speak_up.blacklist_effect_on_block_punch = {}
-- blocks the NPC shall not be able to right-click:
yl_speak_up.blacklist_effect_on_block_right_click = {}
-- taking something out of the inventory of a block or putting something in
yl_speak_up.blacklist_effect_on_block_put = {}
yl_speak_up.blacklist_effect_on_block_take = {}
-- tools the NPC shall not be able to use (covers both punching and right-click):
yl_speak_up.blacklist_effect_tool_use = {}

-- If some items are for some reasons not at all acceptable as quest items,
-- blacklist them here. The data structure is the same as for the tables above.
yl_speak_up.blacklist_action_quest_item = {}


------------------------------------------------------------------------------
-- Texts
------------------------------------------------------------------------------
yl_speak_up.message_button_option_exit = "Farewell!"
yl_speak_up.message_button_option_prerequisites_not_met_default = "Locked answer"
yl_speak_up.message_tool_taken_because_of_lacking_priv = "We took the tool from you and logged this event. You used an admin item while lacking the neccessary priv npc_master"
yl_speak_up.text_new_dialog_id = "New dialog"
yl_speak_up.text_new_option_id = "New option"
yl_speak_up.text_new_prerequisite_id = "New prerequisite"
yl_speak_up.text_new_result_id = "New result"
yl_speak_up.text_version_warning = "You are using an outdated Minetest version!\nI will have a hard time talking to you properly, but I will try my best.\nYou can help me by upgrading to at least 5.3.0!\nGet it at https://minetest.net/downloads"
yl_speak_up.infotext = "Rightclick to talk"
-- it's possible to prevent players from trying actions (i.e. npc_gives, text_input, ..) too often;
-- if no special text is set, this one will be shown (tab "Limit guessing:" in edit options menu)
yl_speak_up.standard_text_if_action_failed_too_often = "You have tried so many times. I'm tired! "..
	"Come back when you really know the answer - but not too soon.\n $TEXT$"
-- it's also possible to prevent players from successfully executing actions too often (after all the
-- quest items are created from the finite NPC's inventory); this is the standard text that will be
-- shown by default (tab "Limit repeating:" in edit options menu)
yl_speak_up.standard_text_if_action_repeated_too_soon = "I don't have infinite ressources. If you lost "..
	"something I gave you - come back later and we may talk again.\n$TEXT$"

------------------------------------------------------------------------------
-- End of config.lua
------------------------------------------------------------------------------

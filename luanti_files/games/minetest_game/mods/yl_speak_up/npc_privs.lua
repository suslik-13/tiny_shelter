-- NPC also need privs to execute more dangerous commands

-- this table will hold the actual privs in the form of
-- indices of the form t[<npc_name>][<priv_name>] = True
yl_speak_up.npc_priv_table = {}

-- where shall the privs be stored so that they will be available after server restart?
yl_speak_up.npc_priv_path = minetest.get_worldpath().."/yl_speak_up_npc_privs.data"

-- these are deemed dangerous and checked
yl_speak_up.npc_priv_names = {
	"precon_exec_lua",
	"effect_exec_lua", "effect_give_item", "effect_take_item", "effect_move_player",
}

-- make sure this table exists
if(not(yl_speak_up.npc_priv_needs_player_priv)) then
	yl_speak_up.npc_priv_needs_player_priv = {}
end
-- and set it to   privs   if nothing is specified (because the *_lua are extremly dangerous npc_privs!)
for i, p in ipairs(yl_speak_up.npc_priv_names) do
	if(not(yl_speak_up.npc_priv_needs_player_priv[p])) then
		yl_speak_up.npc_priv_needs_player_priv[p] = "privs"
	end
end

-- either the npc with n_id *or* if generic_npc_id is set the generic npc with the
-- id generic_npc_id needs to have been granted priv_name
yl_speak_up.npc_has_priv = function(n_id, priv_name, generic_npc_id)
	-- fallback: disallow
	if(not(n_id) or not(priv_name)) then
		return false
	end
	-- remove the leading "_" from the n_id:
	if(generic_npc_id) then
		generic_npc_id = string.sub(generic_npc_id, 2)
	end
	-- if the precondition or effect come from a generic_npc and that
	-- generic npc has the desired priv, then the priv has been granted
	if(generic_npc_id
	   and yl_speak_up.npc_priv_table[generic_npc_id]
	   and yl_speak_up.npc_priv_table[generic_npc_id][priv_name]) then
		return true
	end
	if(not(yl_speak_up.npc_priv_table[n_id])
	   or not(yl_speak_up.npc_priv_table[n_id][priv_name])) then
		yl_speak_up.log_change("-", n_id,
			"error: NPC was denied priv priv "..tostring(priv_name)..".")
		return false
	end
	return true
end


yl_speak_up.npc_privs_load = function()
	local file,err = io.open( yl_speak_up.npc_priv_path, "rb")
	if (file == nil) then
		yl_speak_up.npc_priv_table = {}
		return
	end
	local data = file:read("*all")
	file:close()
	yl_speak_up.npc_priv_table = minetest.deserialize(data)
end


yl_speak_up.npc_privs_store = function()
	local file,err = io.open( yl_speak_up.npc_priv_path, "wb")
	if (file == nil) then
		return
	end
	file:write(minetest.serialize(yl_speak_up.npc_priv_table))
	file:close()
end


-- the privs for NPC can be set via the chat command defined in register_once.lua;
-- here is the implementation for that chat command:
-- a chat command to grant or deny or disallow npc these privs;
-- it is not checked if the NPC exists
--minetest.register_chatcommand( 'npc_talk_privs', {
--        description = "Grants or revokes the privilege <priv> to the "..
--		"yl_speak_up-NPC with the ID <n_id>.\n"..
--		"Call:  [grant|revoke] <n_id> <priv>\n"..
--		"If called with parameter [list], all granted privs for all NPC are shown.",
--        privs = {privs = true},
yl_speak_up.command_npc_talk_privs = function(pname, param)
	-- can the player see the privs for all NPC? or just for those he can edit?
	local list_all = false
	local ptmp = {}
	ptmp[yl_speak_up.npc_privs_priv] = true
	if(minetest.check_player_privs(pname, ptmp)) then
		list_all = true
	end
	if(not(param) or param == "") then
		-- if the npc priv has a player priv as requirement, then list that
		local tmp = {}
		for i, p in ipairs(yl_speak_up.npc_priv_names) do
			table.insert(tmp, tostring(p)..
					" ["..tostring(yl_speak_up.npc_priv_needs_player_priv[p]).."]")
		end
		minetest.chat_send_player(pname,
			"Usage: [grant|revoke|list] <n_id> <priv>\n"..
			"The following privilege exist [and require you to have this priv to set]:\n\t"..
			table.concat(tmp, ", ")..".")
		return
	end
	local player = minetest.get_player_by_name(pname)
	local parts = string.split(param, " ")
	if(parts[1] == "list") then
		local text = "This list contains the privs of each NPC you can edit "..
			"in the form of <npc_name>: <list of privs>"
		-- create list of all existing extra privs for npc
		for n_id, v in pairs(yl_speak_up.npc_priv_table) do
			if(list_all or yl_speak_up.may_edit_npc(player, n_id)) then
				text = text..".\n"..tostring(n_id)..":"
				local found = false
				for priv, w in pairs(v) do
					text = text.." "..tostring(priv)
					found = true
				end
				if(not(found)) then
					text = text.." <none>"
				end
			end
		end
		minetest.chat_send_player(pname, text..".")
		return
	end
	if((parts[1] ~= "grant" and parts[1] ~= "revoke") or #parts ~= 3) then
		minetest.chat_send_player(pname, "Usage: [grant|revoke] <n_id> <priv>")
		return
	end
	local command = parts[1]
	local n_id = parts[2]
	local priv = parts[3]
	if(table.indexof(yl_speak_up.npc_priv_names, priv) == -1) then
		minetest.chat_send_player(pname,
			"Unknown priv \""..tostring(priv).."\".\n"..
			"The following privilege exist:\n\t"..
			table.concat(yl_speak_up.npc_priv_names, ", ")..".")
		return
	end

	-- does the player have the necessary player priv to grant or revoke this npc priv?
	local ptmp = {}
	ptmp[yl_speak_up.npc_priv_needs_player_priv[priv]] = true
	if(not(minetest.check_player_privs(pname, ptmp))) then
		minetest.chat_send_player(pname, "You lack the \""..
			tostring(yl_speak_up.npc_priv_needs_player_priv[priv])..
			"\" priv required to grant or revoke this NPC priv!")
		return
	end

	-- does the player have the right to edit/change this npc?
	if(not(list_all) and not(yl_speak_up.may_edit_npc(player, n_id))) then
		minetest.chat_send_player(pname, "You can only set privs for NPC which you can edit. \""..
			tostring(n_id).." cannot be edited by you.")
		return
	end

	-- revoking privs of nonexistant NPC is allowed - but not granting them privs
	local id = tonumber(string.sub(n_id, 3)) or 0
	if(command == "grant" and not(yl_speak_up.npc_list[id])) then
		minetest.chat_send_player(pname,
			"Unknown NPC \""..tostring(n_id).."\".\n")
		return
	end
	if(command == "grant" and not(yl_speak_up.npc_priv_table[n_id])) then
		yl_speak_up.npc_priv_table[n_id] = {}
	end
	if(command == "grant") then
		yl_speak_up.npc_priv_table[n_id][priv] = true
	elseif(yl_speak_up.npc_priv_table[n_id]) then
		yl_speak_up.npc_priv_table[n_id][priv] = nil
	end
	local text = "New privs of NPC "..tostring(n_id)..":"
	local found = false
	if(yl_speak_up.npc_priv_table[n_id]) then
		for k, v in pairs(yl_speak_up.npc_priv_table[n_id]) do
			text = text.." "..tostring(k)
			found = true
		end
	end
	if(not(found)) then
		text = text.." <none>"
		yl_speak_up.npc_priv_table[n_id] = nil
	end
	minetest.chat_send_player(pname, text..".")
	yl_speak_up.npc_privs_store()
end

-- when the game is started: load the npc privs
yl_speak_up.npc_privs_load()


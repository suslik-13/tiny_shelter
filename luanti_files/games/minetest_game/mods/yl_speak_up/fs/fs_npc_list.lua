-- allow to sort the npc list, display more info on one NPC etc.
yl_speak_up.input_show_npc_list = function(player, formname, fields)
	local pname = player:get_player_name()
	-- teleport to NPC
	if(fields.teleport
	  and fields.selected_id
	  and yl_speak_up.cache_npc_list_per_player[pname]
	  and minetest.check_player_privs(pname, {teleport=true})) then
		local id = tonumber(fields.selected_id)
		if(not(id) or id < 0
		  or not(yl_speak_up.npc_list[id])
		  or table.indexof(yl_speak_up.cache_npc_list_per_player[pname], id) < 1) then
			minetest.chat_send_player(pname, "Sorry. Cannot find that NPC.")
			return
		end

		-- try cached position
		local pos = yl_speak_up.npc_list[id].pos
		local obj = yl_speak_up.npc_list_objects[id]
		if(obj) then
			pos = obj:get_pos()
		end
		if(not(pos) or not(pos.x) or not(pos.y) or not(pos.z)) then
			pos = yl_speak_up.npc_list[id].pos
		end
		if(not(pos) or not(pos.x) or not(pos.y) or not(pos.z)) then
			minetest.chat_send_player(pname, "Sorry. Cannot find position of that NPC.")
			return
		end
		player:set_pos(pos)
		minetest.chat_send_player(pname, "Teleporting to NPC with ID "..
			tostring(fields.selected_id)..': '..
			tostring(yl_speak_up.npc_list[id].name)..'.')
		return
	end
	-- sort by column or select an NPC
	if(fields.show_npc_list) then
		local selected = minetest.explode_table_event(fields.show_npc_list)
		-- sort by column
		if(selected.row == 1) then
			local old_sort = yl_speak_up.sort_npc_list_per_player[pname] or 0
			-- reverse sort
			if(old_sort == selected.column) then
				yl_speak_up.sort_npc_list_per_player[pname] = -1 * selected.column
			else -- sort by new col
				yl_speak_up.sort_npc_list_per_player[pname] = selected.column
			end
			-- show the update
			yl_speak_up.show_fs_ver(pname, "yl_speak_up:show_npc_list",
		                        yl_speak_up.get_fs_show_npc_list(pname, nil))
			return
		else
			-- show details about a specific NPC
			yl_speak_up.show_fs_ver(pname, "yl_speak_up:show_npc_list",
		                        yl_speak_up.get_fs_show_npc_list(pname, selected.row))
			return
		end
	end
	return
end


-- allow to toggle between trade entries and full log
-- Note: takes pname instead of player(object) as first parameter
yl_speak_up.get_fs_show_npc_list = function(pname, selected_row)
	-- which NPC can the player edit?
	local level = 0
	if(    minetest.check_player_privs(pname, {npc_master=true})
	    or minetest.check_player_privs(pname, {npc_talk_master=true})
	    or minetest.check_player_privs(pname, {npc_talk_admin=true})) then
		level = 2
	elseif(minetest.check_player_privs(pname, {npc_talk_owner=true})) then
		level = 1
	end
	if(level < 1) then
		return "size[5,1]label[0,0;Error: You do not have the npc_talk_owner priv.]"
	end

	local formspec_start = 'size[18,14.7]'..
			'label[4.5,0.5;List of all NPC (that you can edit)]'..
			'tablecolumns[' ..
				'color;text,align=right;'..	-- the ID
				'color;text,align=center;'..	-- is the NPC a generic one?
				'color;text,align=left;'..	-- the name of the NPC
				'color;text,align=center;'..	-- the name of the owner of the NPC
				'color;text,align=right;'..	-- number of trades offered
				'color;text,align=right;'..	-- number of properties set
				'color;text,align=right;'..	-- number of people who can edit NPC
				'color;text,align=center;'..	-- last known position
				'color;text,align=center]'..	-- does he have extra privs?
			'table[0.1,1.0;17.8,9.8;show_npc_list;'
	-- add information about a specific NPC (selected row)
	local info_current_row = ''
	if(selected_row
	  and selected_row > 1
	  and yl_speak_up.cache_npc_list_per_player[pname]
	  and yl_speak_up.cache_npc_list_per_player[pname][selected_row-1]) then
		local k = yl_speak_up.cache_npc_list_per_player[pname][selected_row-1]
		local data = yl_speak_up.npc_list[k]
		local line = yl_speak_up.cache_general_npc_list_lines[k]
		if(data) then
			local edit_list = {data.owner}
			if(data.may_edit) then
				for e, t in pairs(data.may_edit or {}) do
					table.insert(edit_list, e)
				end
			end
			local n_id = 'n_'..tostring(k)
			local priv_list = {}
			if(yl_speak_up.npc_priv_table[n_id]) then
				for priv, has_it in pairs(yl_speak_up.npc_priv_table[n_id]) do
					table.insert(priv_list, priv)
				end
			else
				priv_list = {'- none -'}
			end
			local prop_text = 'label[3.0,2.0;- none -]'
			if(data.properties) then
				local prop_list = {}
				for k, v in pairs(data.properties) do
					table.insert(prop_list, minetest.formspec_escape(
						tostring(k)..' = '..tostring(v)))
				end
				if(#prop_list > 0) then
					prop_text = 'dropdown[3.0,1.8;8,0.6;properties;'..
						table.concat(prop_list, ',')..';;]'
				end
			end
			local first_seen_at = '- unknown -'
			if(data.created_at and data.created_at ~= "") then
				first_seen_at = minetest.formspec_escape(os.date("%m/%d/%y", data.created_at))
			end
			-- allow those with teleport priv to easily visit their NPC
			local teleport_button = ''
			if(minetest.check_player_privs(pname, {teleport=true})) then
				-- the ID of the NPC we want to visit is hidden in a field; this is unsafe,
				-- but the actual check needs to happen when the teleport button is pressed
				-- anyway
				teleport_button = 'field[40,40;0,0;selected_id;;'..tostring(k)..']'..
						'button_exit[12.1,1.8;5,0.6;teleport;Teleport to this NPC]'
			end
			info_current_row =
				'container[0.1,11.2]'..
				'label[0.1,0.0;Name, Desc:]'..
				'label[3.0,0.0;'..tostring(line.n_name)..']'..
				'label[0.1,0.5;Typ:]'..
				'label[3.0,0.5;'..
					minetest.formspec_escape(tostring(data.typ or '- ? -'))..']'..
				'label[12.1,0.5;First seen at:]'..
				'label[14.4,0.5;'..
					first_seen_at..']'..
				'label[0.1,1.0;Can be edited by:]'..
				'label[3.0,1.0;'..
					minetest.formspec_escape(table.concat(edit_list, ', '))..']'..
				'label[0.1,1.5;Has the privs:]'..
				'label[3.0,1.5;'..
					minetest.formspec_escape(table.concat(priv_list, ', '))..']'..
				'label[0.1,2.0;Properties:]'..
					prop_text..
				teleport_button..
				'container_end[]'
		end
	else
		selected_row = 1
		info_current_row = 'label[0.1,11.2;Click on a column name/header in order to sort by '..
				'that column. Click it again in order to reverse sort order.\n'..
				'Click on a row to get more information about a specific NPC.\n'..
				'Only NPC that can be edited by you are shown.\n'..
				'Legend: \"G\": is generic NPC.  '..
				'\"#Tr\", \"#Pr\": Number of trades or properties the NPC offers.\n'..
				'        \"#Ed\": Number of players that can edit the NPC.  '..
				'\"Privs\": List of abbreviated names of privs the NPC has.]'
	end
	local formspec = {}

	-- TODO: blocks may also be talked to

	local tmp_liste = {}
	for k, v in pairs(yl_speak_up.npc_list) do
		-- show only NPC - not blocks
		if(type(k) == "number" and (level == 2
		  or (v.owner and v.owner == pname)
		  or (v.may_edit and v.may_edit[pname]))) then
			table.insert(tmp_liste, k)
		end
	end

	-- the columns with the colors count as well even though they can't be selected
	-- (don't sort the first column by n_<id> STRING - sort by <id> NUMBER)
	local col_names = {"id", "id", "is_generic", "is_generic", "n_name", "n_name",
			   "owner", "owner", "anz_trades", "anz_trades",
			   "anz_properties", "anz_properties", "anz_editors", "anz_editors",
			   "pos", "pos", "priv_list", "priv_list"}
	local sort_col = yl_speak_up.sort_npc_list_per_player[pname]
	if(not(sort_col) or sort_col == 0) then
		table.sort(tmp_liste)
	elseif(sort_col > 0) then
		-- it is often more helpful to sort in descending order
		local col_name = col_names[sort_col]
		table.sort(tmp_liste, function(a, b)
				return yl_speak_up.cache_general_npc_list_lines[a][col_name]
				     > yl_speak_up.cache_general_npc_list_lines[b][col_name]
			end)
	else
		local col_name = col_names[sort_col * -1]
		table.sort(tmp_liste, function(a, b)
				return yl_speak_up.cache_general_npc_list_lines[a][col_name]
				     < yl_speak_up.cache_general_npc_list_lines[b][col_name]
			end)
	end

	local col_headers = {'n_id', 'G', 'Name', 'Owner', '#Tr', '#Pr', '#Ed', 'Position', 'Privs'}
	for i, k in ipairs(col_headers) do
		if(    sort_col and sort_col == (i * 2)) then
			table.insert(formspec, 'yellow')
			table.insert(formspec, 'v '..k..' v')
		elseif(sort_col and sort_col == (i * -2)) then
			table.insert(formspec, 'yellow')
			table.insert(formspec, '^ '..k..' ^')
		else
			table.insert(formspec, '#FFFFFF')
			table.insert(formspec, k)
		end
	end
	yl_speak_up.cache_npc_list_per_player[pname] = tmp_liste

	for i, k in ipairs(tmp_liste) do
		local data = yl_speak_up.npc_list[k]
		local line = yl_speak_up.cache_general_npc_list_lines[k]
		-- own NPC are colored green, others white
		local owner_color = '#FFFFFF'
		if(data.owner == pname) then
			owner_color = '#00FF00'
		elseif (data.may_edit and data.may_edit[pname]) then
			owner_color = '#FFFF00'
		end
		table.insert(formspec, line.is_loaded_color)
		table.insert(formspec, line.n_id)
		table.insert(formspec, 'orange')
		table.insert(formspec, line.is_generic)
		table.insert(formspec, line.npc_color)
		table.insert(formspec, line.n_name)
		table.insert(formspec, owner_color) -- diffrent for each player
		table.insert(formspec, line.owner)
		table.insert(formspec, line.is_loaded_color)
		table.insert(formspec, line.anz_trades)
		table.insert(formspec, line.is_loaded_color)
		table.insert(formspec, line.anz_properties)
		table.insert(formspec, owner_color) -- diffrent for each player
		table.insert(formspec, line.anz_editors)
		table.insert(formspec, line.is_loaded_color)
		table.insert(formspec, line.pos)
		table.insert(formspec, line.is_loaded_color)
		table.insert(formspec, line.priv_list)
	end
	table.insert(formspec, ";"..selected_row.."]")
	return table.concat({formspec_start,
			table.concat(formspec, ','),
			info_current_row,
			'button_exit[0.1,14;19.6,0.6;exit;Exit]'}, '')
end


yl_speak_up.register_fs("npc_list",
	yl_speak_up.input_npc_list,
	yl_speak_up.get_fs_npc_list,
	-- no special formspec required:
	nil
)


-- at load/reload of the mod: read the list of existing NPC
yl_speak_up.npc_list_load()


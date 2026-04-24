-- allow owner to see and edit properties of the NPC

yl_speak_up.input_properties = function(player, formname, fields)
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local n_id = yl_speak_up.speak_to[pname].n_id

	if(fields and fields.back and fields.back ~= "") then
		yl_speak_up.show_fs(player, "initial_config",
			{n_id = n_id, d_id = yl_speak_up.speak_to[pname].d_id, false})
		return
	end

	local selected_row = nil
	if(fields and fields.store_new_val and fields.store_new_val ~= "" and fields.prop_val) then
		yl_speak_up.set_npc_property(pname, fields.prop_name, fields.prop_val, "manually")

	elseif(fields and fields.delete_prop and fields.delete_prop ~= "") then
		-- delete the old property
		yl_speak_up.set_npc_property(pname, fields.prop_name, nil, "manually")

	elseif(fields and fields.table_of_properties) then
		local selected = minetest.explode_table_event(fields.table_of_properties)
		if(selected.type == "CHG" or selected.type == "DLC") then
			selected_row = selected.row
		end
	end
	yl_speak_up.show_fs(player, "properties", {selected = selected_row})
end


yl_speak_up.get_fs_properties = function(pname, selected)
	if(not(pname)) then
		return ""
	end
	local n_id = yl_speak_up.speak_to[pname].n_id

	-- is the player editing this npc? if not: abort
	if(not(yl_speak_up.edit_mode[pname])
	  or (yl_speak_up.edit_mode[pname] ~= n_id)) then
		return ""
	end

	-- we want the long version with additional information
	local property_data = yl_speak_up.get_npc_properties_long_version(pname, true)
	if(not(property_data)) then
		-- something went wrong - there really is nothing useful we can do
		-- if the NPC we want to interact with doesn't exist or is broken
		return
	end
	local s = ""
	if(not(property_data.prop_names)) then
		property_data.prop_names = {}
	end
	local anz_prop = #property_data.prop_names
	for i, k in ipairs(property_data.prop_names) do
		local v = property_data.properties[k]
		s = s.."#BBBBFF,"..minetest.formspec_escape(k)..","..minetest.formspec_escape(v)..","
	end
	s = s.."#00FF00,add,Add a new property"

	if(not(selected) or selected == "") then
		selected = -1
	end
	local add_selected = "label[3.5,6.5;No property selected.]"
	selected = tonumber(selected)
	if(selected > anz_prop + 1 or selected < 1) then
		selected = -1
	elseif(selected > anz_prop) then
		add_selected = "label[0.2,6.5;Add new property:]"..
			"field[3.0,6.5;3.5,1.0;prop_name;;]"..
			"label[6.5,6.5;with value:]"..
			"field[8.2,6.5;4.5,1.0;prop_val;;]"..
			"button[8.2,7.8;2.0,1.0;store_new_val;Store]"
	-- external properties can usually only be read but not be changed
	elseif(string.sub(property_data.prop_names[selected], 1, 5) == "self."
	  and not(yl_speak_up.custom_property_handler[property_data.prop_names[selected]])) then
		add_selected = "label[3.5,6.5;Properties of the type \"self.\" usually cannot be modified.]"
	elseif(string.sub(property_data.prop_names[selected], 1, 6) == "server"
	  and not(minetest.check_player_privs(pname, {npc_talk_admin=true}))) then
		add_selected = "label[3.5,6.5;Properties starting with \"server\" can only be "..
				"changed by players\nwho have the \"npc_talk_admin\" priv."
	else
		local name = property_data.prop_names[selected]
		local val = minetest.formspec_escape(property_data.properties[name])
		local name_esc = minetest.formspec_escape(name)
		add_selected = "label[0.2,6.5;Change property:]"..
			"field[3.0,6.5;3.5,1.0;prop_name;;"..name_esc.."]"..
			"label[6.5,6.5;to value:]"..
			"field[8.2,6.5;4.5,1.0;prop_val;;"..val.."]"..
			"button[8.2,7.8;2.0,1.0;store_new_val;Store]"..
			"button[10.4,7.8;2.0,1.0;delete_prop;Delete]"
	end
	if(selected < 1) then
		selected = ""
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	local npc_name = minetest.formspec_escape(dialog.n_npc or "- nameless -")
	return table.concat({"size[12.5,8.5]",
		"label[2,0;Properties of ",
			npc_name,
			" (ID: ",
			tostring(n_id),
			"):]",
		"tablecolumns[color,span=1;text;text]",
		"table[0.2,0.5;12,4.0;table_of_properties;",
			s,
			";",
			tostring(selected),
			"]",
		"tooltip[0.2,0.5;12,4.0;",
			"Click on \"add\" to add a new property.\n",
			"Click on the name of a property to change or delete it.]",
		"label[2.0,4.5;"..
			"Properties are important for NPC that want to make use of generic dialogs.\n"..
			"Properties can be used to determine which generic dialog(s) shall apply to\n"..
			"this particular NPC and how they shall be configured. You need the\n"..
			"\"npc_talk_admin\" priv to edit properties starting with the text \"server\".]",
		"button[5.0,7.8;2.0,0.9;back;Back]",
		add_selected
		}, "")
end

yl_speak_up.get_fs_properties_wrapper = function(player, param)
	if(not(param)) then
		param = {}
	end
	local pname = player:get_player_name()
	return yl_speak_up.get_fs_properties(pname, param.selected)
end

yl_speak_up.register_fs("properties",
	yl_speak_up.input_properties,
	yl_speak_up.get_fs_properties_wrapper,
	-- force formspec version 1:
	1
)

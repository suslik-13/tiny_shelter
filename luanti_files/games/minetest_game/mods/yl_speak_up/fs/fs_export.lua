
yl_speak_up.export_to_simple_dialogs_language = function(dialog, n_id)

	local d_liste = yl_speak_up.get_dialog_list_for_export(dialog)

	local tmp = {}
	for i, d_id in ipairs(d_liste) do
		table.insert(tmp, "===")
		-- TODO: use labels here when available
		table.insert(tmp, tostring(yl_speak_up.d_id_to_d_name(dialog, d_id)))
		table.insert(tmp, "\n")
		-- :, > and = are not allowed as line start in simple dialogs
		-- just add a leading blank so that any :, > and = at the start are covered
		table.insert(tmp, " ")
		local t = dialog.n_dialogs[d_id].d_text or ""
		t = string.gsub(t, "\n([:>=])", "\n %1")
		table.insert(tmp, t)
		table.insert(tmp, "\n")
		for o_id, o_data in pairs(dialog.n_dialogs[d_id].d_options or {}) do
			local target_dialog = nil
			for r_id, r_data in pairs(o_data.o_results or {}) do
				if(r_data.r_type and r_data.r_type == "dialog") then
					target_dialog = r_data.r_value
				end
			end
			table.insert(tmp, ">")
			table.insert(tmp, yl_speak_up.d_id_to_d_name(dialog, target_dialog or "d_1"))
			table.insert(tmp, ":")
			table.insert(tmp, o_data.o_text_when_prerequisites_met)
			table.insert(tmp, "\n")
		end
		table.insert(tmp, "\n")
	end
	return table.concat(tmp, "")
end


yl_speak_up.input_export = function(player, formname, fields)
	if(fields and fields.back) then
		return yl_speak_up.show_fs(player, "talk")
	elseif(fields and fields.show_readable) then
		return yl_speak_up.show_fs(player, "export", "show_readable")
	elseif(fields and (fields.back_to_export or fields.show_export)) then
		return yl_speak_up.show_fs(player, "export", "show_export")
	elseif(fields and fields.show_ink_export) then
		return yl_speak_up.show_fs(player, "export", "show_ink_export")
	elseif(fields and fields.show_simple_dialogs) then
		return yl_speak_up.show_fs(player, "export", "show_simple_dialogs")
	elseif(fields and (fields.import or fields.back_from_error_msg)) then
		return yl_speak_up.show_fs(player, "export", "import")
	elseif(fields and fields.really_import and fields.new_dialog_input
	    and string.sub(fields.new_dialog_input, 1, 3) == "-> ") then
		local pname = player:get_player_name()
		if(not(pname) or not(yl_speak_up.speak_to[pname])) then
			return
		end
		local n_id   = yl_speak_up.speak_to[pname].n_id
		-- can the player edit this npc?
		if(not(yl_speak_up.may_edit_npc(player, n_id))) then
			return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:export",
				formspec = yl_speak_up.build_fs_quest_edit_error(
					"You do not own this NPC and are not allowed to edit it!",
					"back_from_error_msg")})
		end
		-- import in ink format
		local dialog = yl_speak_up.speak_to[pname].dialog
		local log = {}
		local log_level = 1
		yl_speak_up.parse_ink.import_from_ink(dialog, fields.new_dialog_input, log_level, log)
		-- save the changed dialog
		yl_speak_up.save_dialog(n_id, dialog)
		for i_, t_ in ipairs(log) do
			minetest.chat_send_player(pname, t_)
		end
		-- log the change
		return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:export",
				formspec = "size[10,3]"..
					"label[0.5,1.0;Partially imported dialog data in ink format "..
							" successfully.]"..
					"button[3.5,2.0;2,0.9;back_from_error_msg;Back]"
				})

	elseif(fields and fields.really_import and fields.new_dialog_input) then
		-- can that possibly be json format?
		if(not(string.sub(fields.new_dialog_input, 1, 1) == "{")) then
			return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:export",
				formspec = yl_speak_up.build_fs_quest_edit_error(
					"This does not seem to be in .json format. Please make sure "..
					"your import starts with a \"{\"!",
					"back_from_error_msg")})
		end
		-- importing in .json format requires the "privs" priv
		-- and it imports more information like npc name
		if(not(minetest.check_player_privs(player, {privs=true}))) then
			return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:export",
				formspec = yl_speak_up.build_fs_quest_edit_error(
					"You need the \"privs\" priv in order to import NPC data.",
					"back_from_error_msg")})
		end
		local pname = player:get_player_name()
		if(not(pname) or not(yl_speak_up.speak_to[pname])) then
			return
		end
		local n_id   = yl_speak_up.speak_to[pname].n_id
		-- actually import the dialog
		local new_dialog = minetest.parse_json(fields.new_dialog_input or "")
		if(not(new_dialog)) then
			return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:export",
				formspec = yl_speak_up.build_fs_quest_edit_error(
					"Failed to parse the .json data.",
					"back_from_error_msg")})
		end
		-- TODO: the dialog has to be checked if it is a valid one (very big TODO!)
		-- the ID has to be adjusted to this NPC
		new_dialog.n_id = n_id
		-- update the entity with name, description and owner
		if yl_speak_up.speak_to[pname].obj then
			local obj = yl_speak_up.speak_to[pname].obj
			local ent = obj:get_luaentity()
			if ent ~= nil then
				ent.yl_speak_up.npc_name = new_dialog.n_npc
				ent.yl_speak_up.npc_description = new_dialog.n_description
				ent.owner = new_dialog.npc_owner
				local i_text = new_dialog.n_npc .. "\n" ..
					new_dialog.n_description .. "\n" ..
					yl_speak_up.infotext
				obj:set_properties({infotext = i_text})
				yl_speak_up.update_nametag(ent)
			end
		end
		-- import self.yl_speak_up (contains skin, animation, properties and the like)
		local obj = yl_speak_up.speak_to[pname].obj
		if(obj and new_dialog.entity_yl_speak_up) then
			local entity = obj:get_luaentity()
			if(entity) then
				-- not all staticdata is changed
				local staticdata = entity:get_staticdata()
				-- we need to take the ID of this *current* NPC - not of the savedone!
				local old_id = entity.yl_speak_up.id
				new_dialog.entity_yl_speak_up.id = old_id
				-- provide the entity with the new data
				entity.yl_speak_up = new_dialog.entity_yl_speak_up
				-- textures and infotext may depend on the mod
				if(entity.yl_speak_up.entity_textures) then
					entity.textures = entity.yl_speak_up.entity_textures
				end
				if(entity.yl_speak_up.entity_infotext) then
					entity.infotext = entity.yl_speak_up.entity_infotext
				end
				-- update the entity
				local dtime_s = 1
				entity:on_activate(new_staticdata, dtime_s)
				-- apply the changes
				entity.object:set_properties(entity)
				if(entity.yl_speak_up.animation) then
					entity.object:set_animation(entity.yl_speak_up.animation)
				end
				-- get the updated staticdata (with new yl_speak_up values)
				local new_staticdata = entity:get_staticdata()
				-- update the nametag if possible
				yl_speak_up.update_nametag(entity)
			end
		end
		-- update the stored dialog
		yl_speak_up.speak_to[pname].dialog = new_dialog
		-- save it
		yl_speak_up.save_dialog(n_id, new_dialog)
		-- log the change
		yl_speak_up.log_change(pname, n_id, "Imported new dialog in .json format (complete).")
		return yl_speak_up.show_fs(player, "msg", {
				input_to = "yl_speak_up:export",
				formspec = "size[10,3]"..
					"label[0.5,1.0;Data successfully imported.]"..
					"button[3.5,2.0;2,0.9;back_from_error_msg;Back]"
				})
	end
end


yl_speak_up.get_fs_export = function(player, param)
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return
	end
	local n_id   = yl_speak_up.speak_to[pname].n_id
	-- generic dialogs are not part of the NPC
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(yl_speak_up.may_edit_npc(player, n_id))) then
		return ""
	end
	local text = ""
	if(not(minetest.check_player_privs(pname, {privs=true}))) then
		text = "You lack the \"privs\" priv that is required in order to import NPC data."
	end
	if(param and param == "import") then
		return table.concat({"size[20,20]label[4,0.5;IMPORT for NPC ",
			minetest.formspec_escape(n_id or "- ? -"),
			"dialog data in .json format]",
			"button[17.8,0.2;2.0,0.9;back_to_export;Back]",
			"button[3.6,17.2;6.0,0.9;really_import;Yes, I'm sure. Import it!]",
			"button[10.2,17.2;6.0,0.9;back_to_export;No. Go back, please.]",
			-- read-only
			"textarea[0.2,2;19.6,15;new_dialog_input;NEW dialog for ",
				minetest.formspec_escape(n_id or "- ? -"),
				":;",
				text,
				"]",
			"textarea[0.2,18.2;19.6,1.8;;;",
				"WARNING: This is highly experimental and requires the \"privs\" priv. "..
				"Use in singleplayer on a new NPC - but not on a live server!]",
		})
	end
	local content = ""
	local explanation = ""
	local b1 = "button[0.2,17.2;4.0,0.9;show_readable;Human readable]"..
			"tooltip[show_readable;Shows the raw dialog data format formatted diffrently so\n"..
				"that it is easier to read.]"
	local b2 = "button[5.0,17.2;4.0,0.9;show_export;Export in .json]"..
			"tooltip[show_export;Shows the raw dialog data format (.json).]"
	local b3 = "button[9.8,17.2;4.0,0.9;show_simple_dialogs;Simple dialogs]"..
			"tooltip[show_simple_dialogs;Show the dialog data structure in the format used by\n"..
				"the mod \"simple_dialogs\".]"
	local b4 = "button[14.6,17.2;4.0,0.9;show_ink_export;Ink language]"..
			"tooltip[show_ink_export;Export the dialog data structure to the\n"..
				"Ink markup language.]"
	-- include self.yl_speak_up (contains skin, animation, properties and the like)
	local obj = yl_speak_up.speak_to[pname].obj
	if(obj) then
		local entity = obj:get_luaentity()
		if(entity) then
			dialog.entity_yl_speak_up = entity.yl_speak_up
			-- these data values vary too much depending on mod used for the NPC
			if(entity.textures) then
				dialog.entity_yl_speak_up.entity_textures = entity.textures
			end
			if(entity.infotext) then
				dialog.entity_yl_speak_up.entity_infotext = entity.infotext
			end
		end
	end

	if(param and param == "show_readable") then
		b1 = "label[0.2,17.6;This is human readable format]"
		explanation = "This is like the raw dialog data format - except that it's written a bit "..
			"diffrent so that it is easier to read."
		content = minetest.write_json(dialog, true)
	elseif(param and param == "show_ink_export") then
		b4 = "label[14.6,17.6;Ink lanugage]"
		-- TODO
		explanation = "This is the format used by the \"Ink\" scripting language. "..
			"TODO: The export is not complete yet."
		content = yl_speak_up.export_to_ink_language(dialog, tostring(n_id).."_")
	elseif(param and param == "show_simple_dialogs") then
		b3 = "label[9.8,17.6;Simple dialogs format]"
		explanation = "This is the format used by the \"simple_dialogs\" mod. "..
			"It does not cover preconditions, actions, effects and other specialities of "..
			"this mod here. It only covers the raw dialogs. If a dialog line starts with "..
			"\":\", \">\" or \"=\", a \" \" is added before that letter because such a "..
			"line start would not be allowed in \"simple_dialogs\"."
		content = yl_speak_up.export_to_simple_dialogs_language(dialog, n_id)
	else
		b2 = "label[5.0,17.6;This is export in .json format]"
		explanation = "Mark the text in the above window with your mouse and paste it into "..
				"a local file on your disk. Save it as n_<id>.json (i.e. n_123.json) "..
				"in the folder containing your dialog data. Then the NPCs in your "..
				"local world can use this dialog."
				-- TODO: import?
		content = minetest.write_json(dialog, false)
	end
	return table.concat({"size[20,20]label[4,0.5;Export of NPC ",
		minetest.formspec_escape(n_id or "- ? -"),
		" dialog data in .json format]",
		"button[17.8,0.2;2.0,0.9;back;Back]",
		"button[15.4,0.2;2.0,0.9;import;Import]",
		"tooltip[import;WARNING: This is highly experimental and requires the \"privs\" priv.\n"..
			"Use in singleplayer on a new NPC - but not on a live server!]",
		b1, b2, b3, b4,
		-- background color for the textarea below
		"box[0.2,2;19.6,15;#AAAAAA]",
		-- read-only
		"textarea[0.2,2;19.6,15;;Current dialog of ",
		minetest.formspec_escape(n_id or "- ? -"),
		":;",
		minetest.formspec_escape(content),
		"]",
		"textarea[0.2,18.2;19.6,1.8;;;",
		explanation,
		"]",
		})
end


yl_speak_up.register_fs("export",
	yl_speak_up.input_export,
	yl_speak_up.get_fs_export,
	-- no special formspec required:
	nil
)

-- the formspec menu used for talking to the NPC can also used for
-- the trading formspec and similar things

-- the chat command npc_talk_style defined in register_once.lua
-- can be used to switch formspec style.
-- change the formspec style used in fs_decorated.lua;
--minetest.register_chatcommand( 'npc_talk_style', {
--	description = "This command sets your formspec version "..
--				"for the yl_speak_up NPC to value <version>.\n"..
--				"  Version 1: For very old clients. Not recommended.\n"..
--				"  Version 2: Adds extra scroll buttons. Perhaps you like this more.\n"..
--				"  Version 3: Default version.",
--	privs = {},
yl_speak_up.command_npc_talk_style = function(pname, param)
	-- set a default value
	if(not(yl_speak_up.fs_version[pname])) then
		yl_speak_up.fs_version[pname] = 3
	end
	if(param and param == "1") then
		yl_speak_up.fs_version[pname] = 1
	elseif(param and param == "2") then
		yl_speak_up.fs_version[pname] = 2
	elseif(param and param == "3") then
		yl_speak_up.fs_version[pname] = 3
	else
		minetest.chat_send_player(pname, "This command sets your formspec version "..
			"for the yl_speak_up NPC to value <version>.\n"..
			"  Version 1: For very old clients. Not recommended.\n"..
			"  Version 2: Adds extra scroll buttons.\n"..
			"  Version 3: Default (recommended) version.")
	end
	minetest.chat_send_player(pname, "Your formspec version for the yl_speak_up NPC "..
		"has been set to version "..tostring(yl_speak_up.fs_version[pname])..
		" for this session.")
end


-- helper function for yl_speak_up.show_fs_decorated
yl_speak_up.calculate_portrait = function(pname, n_id)

	local mesh = yl_speak_up.get_mesh(pname)
	-- which texture from the textures list are we talking about?
	-- this depends on the model!
	if(not(mesh)
	  or not(yl_speak_up.mesh_data[mesh])
	  or not(yl_speak_up.mesh_data[mesh].texture_index)) then
		return ""
	end
	local texture_index = yl_speak_up.mesh_data[mesh].texture_index
	local tex = yl_speak_up.speak_to[pname].textures
	if(not(tex) or not(tex[texture_index])) then
		return ""
	end
	return "[combine:8x8:-8,-8=" .. tex[texture_index] .. ":-40,-8=" .. tex[texture_index]
end


-- older formspecs (before v3) do not offer a scroll container and have to scroll manually;
-- we maintain a player-name-based counter in order to see if this line ought to be shown
yl_speak_up.old_fs_version_show_line = function(pname, anz_lines)
	-- the player is using a new enough version for scroll_container to work
	if(not(pname)) then
		return true
	end
	if(not(anz_lines) or anz_lines < 1) then
		anz_lines = 1
	end
	local max_number_of_buttons = yl_speak_up.max_number_of_buttons
	local start_index = yl_speak_up.speak_to[pname].option_index
	local counter = yl_speak_up.speak_to[pname].counter
	if(not(counter)) then
		counter = 1
	end
	yl_speak_up.speak_to[pname].counter = counter + anz_lines
	if counter < start_index or counter >= start_index + max_number_of_buttons then
		return false
	end
	return true
end


-- show an edit option in the main menu of the NPC;
-- helper function for yl_speak_up.fs_talkdialog(..)
-- and yl_speak_up.show_fs_decorated
-- (optional) anz_lines: trade offers take up more room
-- (optional) multi_line_content: for trade offers; draw them directly
yl_speak_up.add_edit_button_fs_talkdialog = function(formspec, h, button_name, tooltip, label,
						show_main_not_alternate, alternate_label, is_exit_button,
						pname, anz_lines, multi_line_content)
	if(not(anz_lines) or anz_lines < 1) then
		anz_lines = 1
	end
	-- do not show this button at all if there is no alternate text and the condition is false
	if(not(alternate_label) and not(show_main_not_alternate)) then
		return h
	end
	local button_dimensions = "0.5,"..(h+1)..";53.8,"..tostring(0.9*anz_lines)..";"
	local label_start_pos = "0.7"
	-- older formspecs (before v4) do not offer a scroll container and have to scroll manually
	if(pname) then
		if(not(yl_speak_up.old_fs_version_show_line(pname, anz_lines))) then
			return h
		end
		-- there has to be more room for the up and down arrows
		button_dimensions = "1.2,"..(h+1)..";52.3,"..tostring(0.9*anz_lines)..";"
		label_start_pos = "1.4"
	end
	h = h + anz_lines
	if(multi_line_content) then
		table.insert(formspec, "container[1.2,"..(h+1 - anz_lines).."]")
		table.insert(formspec, multi_line_content)
		table.insert(formspec, "container_end[]")
	elseif(show_main_not_alternate) then
		if(is_exit_button) then
			table.insert(formspec, "button_exit["..button_dimensions..tostring(button_name)..";]")
		else
			table.insert(formspec, "button["..button_dimensions..tostring(button_name)..";]")
		end
		table.insert(formspec, "tooltip["..tostring(button_name)..";"..tostring(tooltip).."]")
		table.insert(formspec, "label["..label_start_pos..","..(h+0.45)..";"..tostring(label).."]")
	else
		table.insert(formspec, "box["..button_dimensions.."#BBBBBB]")
		table.insert(formspec, "label["..label_start_pos..","..(h+0.45)..";"..
					tostring(alternate_label).."]")
	end
	return h
end


-- show a formspec element in the main menu of the NPC (with tooltip);
-- helper function for yl_speak_up.fs_talkdialog(..)
-- and yl_speak_up.show_fs_decorated
yl_speak_up.add_formspec_element_with_tooltip_if = function(formspec, element_type, position, element_name,
							    element_text, tooltip, condition)
	if(not(condition)) then
		return
	end
	table.insert(formspec, element_type.."["..position..";"..element_name..";"..element_text.."]")

	-- make sure the lines in the mouseover text don't get too long
	-- each paragraph has to be split seperately so that the old newlines are kept
	local paragraphs = string.split(tooltip, "\n", true, -1, false)
	for i, p in ipairs(paragraphs) do
		paragraphs[i] = minetest.wrap_text(paragraphs[i], 100, false)
	end
	tooltip = table.concat(paragraphs, "\n")
	table.insert(formspec, "tooltip["..tostring(element_name)..";"..tostring(tooltip).."]")
end


-- in formspec versions lower than 3, scrolling has to be handled diffrently;
-- this updates:
-- 	yl_speak_up.fs_version[pname]
-- 	yl_speak_up.speak_to[pname].counter
yl_speak_up.get_pname_for_old_fs = function(pname)
	-- depending on formspec version, diffrent formspec elements are available
	local fs_version = yl_speak_up.fs_version[pname]
	if(not(fs_version)) then
		local formspec_v = minetest.get_player_information(pname).formspec_version
		local protocol_v = minetest.get_player_information(pname).protocol_version

		if formspec_v >= 4 then
			fs_version = 3
		elseif formspec_v >= 2 then
			fs_version = 2
		else
			fs_version = 1
		end
		-- store which formspec version the player has
		yl_speak_up.fs_version[pname] = fs_version
	end
	if(fs_version <= 2) then
                -- old formspec versions need to remember somewhere extern how far the player scrolled
		yl_speak_up.speak_to[pname].counter = 1
                return pname
        end
	return nil
end



-- display the window with the text the NPC is saying
-- Note: In edit mode, and if there is a dialog selected, the necessary
--       elements for editing said text are done in the calling function.
yl_speak_up.show_fs_npc_text = function(pname, formspec, dialog, alternate_text, active_dialog, fs_version)
	if(alternate_text and active_dialog and active_dialog.d_text) then
		alternate_text = string.gsub(alternate_text, "%$TEXT%$", active_dialog.d_text)
	elseif(active_dialog and active_dialog.d_text) then
		alternate_text = active_dialog.d_text
	end
	-- replace $NPC_NAME$ etc.
	local t = minetest.formspec_escape(yl_speak_up.replace_vars_in_text(
						alternate_text, dialog, pname))
	-- t = "Visits to this dialog: "..tostring(active_dialog.visits).."\n"..t
	if(fs_version > 2) then
		yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
			"hypertext", "0.2,5;19.6,17.8", "d_text",
			"<normal>"..t.."\n</normal>",
			t:trim()..";#000000;#FFFFFF",
			true)
	else
		yl_speak_up.add_formspec_element_with_tooltip_if(formspec,
			"textarea", "0.2,5;19.6,17.8", "",
			";"..t.."\n",
			t:trim(),
			true)
	end
	return formspec
end



yl_speak_up.show_fs_decorated = function(pname, npc_text_already_printed, h,
					alternate_text,
					add_this_to_left_window,
					add_this_to_bottom_window,
					active_dialog,
					h)
	if(not(pname)) then
		return ""
	end
	-- which NPC is the player talking to?
	local n_id = yl_speak_up.speak_to[pname].n_id
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(n_id and dialog and not(dialog.n_npc)) then
		dialog.n_npc = n_id
	end
	if(n_id and dialog and not(dialog.n_description)) then
		dialog.n_description = "- no description -"
	end
        -- do we have all the necessary data?
        if(not(n_id) or not(dialog) or not(dialog.n_npc)) then
		return "size[6,2]"..
			"label[0.2,0.5;Ups! This NPC lacks ID or name.]"..
			"button_exit[2,1.5;1,0.9;exit;Exit]"
	end

	-- depending on formspec version, diffrent formspec elements are available
	local fs_version = yl_speak_up.fs_version[pname]

	local portrait = yl_speak_up.calculate_portrait(pname, n_id)

	local formspec = {}

	-- show who owns the NPC (and is thus more or less responsible for what it says)
	local owner_info = ""
	if(yl_speak_up.npc_owner[ n_id ]) then
		owner_info = "\n\n(owned by "..minetest.formspec_escape(yl_speak_up.npc_owner[ n_id ])..")"
	end

	formspec = {
            "size[58,33]",
            "position[0,0.45]",
            "anchor[0,0.45]",
            "no_prepend[]",
            "bgcolor[#00000000;false]",
            -- Container

            "container[2,0.75]",
            -- Background

            "background[0,0;20,23;yl_speak_up_bg_dialog.png;false]",
            "background[0,24;55.6,7.5;yl_speak_up_bg_dialog.png;false]",
            -- Frame Dialog

            "image[-0.25,-0.25;1,1;yl_speak_up_bg_dialog_tl.png]",
            "image[-0.25,22.25;1,1;yl_speak_up_bg_dialog_bl.png]",
            "image[19.25,-0.25;1,1;yl_speak_up_bg_dialog_tr.png]",
            "image[19.25,22.25;1,1;yl_speak_up_bg_dialog_br.png]",
            "image[-0.25,0.75;1,21.5;yl_speak_up_bg_dialog_hl.png]",
            "image[19.25,0.75;1,21.5;yl_speak_up_bg_dialog_hr.png]",
            "image[0.75,-0.25;18.5,1;yl_speak_up_bg_dialog_vt.png]",
            "image[0.75,22.25;18.5,1;yl_speak_up_bg_dialog_vb.png]",
            -- Frame Options

            "image[-0.25,23.75;1,1;yl_speak_up_bg_dialog_tl.png]",
            "image[-0.25,30.75;1,1;yl_speak_up_bg_dialog_bl.png]",
            "image[54.75,23.75;1,1;yl_speak_up_bg_dialog_tr.png]",
            "image[54.75,30.75;1,1;yl_speak_up_bg_dialog_br.png]",
            "image[-0.25,24.75;1,6;yl_speak_up_bg_dialog_hl.png]",
            "image[54.75,24.75;1,6;yl_speak_up_bg_dialog_hr.png]",
            "image[0.75,23.75;54,1;yl_speak_up_bg_dialog_vt.png]",
            "image[0.75,30.75;54,1;yl_speak_up_bg_dialog_vb.png]",

            "label[0.3,0.6;",
            minetest.formspec_escape(dialog.n_npc),
            "]",
            "label[0.3,1.8;",
            minetest.formspec_escape(dialog.n_description)..owner_info,
            "]",
            "image[15.5,0.5;4,4;",
            portrait,
            "]",
	}

	-- add those things that only exist in formspec_v >= 4
	if(fs_version > 2) then
		table.insert(formspec, "style_type[button;bgcolor=#a37e45]")
		table.insert(formspec, "style_type[button_exit;bgcolor=#a37e45]") -- Dialog
		table.insert(formspec, "style[button_start_edit_mode,show_log,add_option,"..
					"delete_this_empty_dialog,show_what_points_to_this_dialog,"..
					"make_first_option,turn_into_a_start_dialog,mute_npc,"..
					"un_mute_npc,button_end_edit_mode,show_inventory,order_follow,"..
					"button_edit_basics,"..
					"order_stand,order_wander,order_custom;"..
					"bgcolor=#FF4444;textcolor=white]")
		-- table.insert(formspec, "background[-1,-1;22,25;yl_speak_up_bg_dialog2.png;false]")
		-- table.insert(formspec, "background[-1,23;58,10;yl_speak_up_bg_dialog2.png;false]")
		-- table.insert(formspec, "style_type[button;bgcolor=#a37e45]")
	end

	-- display the window with the text the NPC is saying
	-- Note: In edit mode, and if there is a dialog selected, the necessary
	--       elements for editing said text are done in the calling function.
	if(not(npc_text_already_printed) or not(dialog) or not(dialog.n_dialogs)) then
		yl_speak_up.show_fs_npc_text(pname, formspec, dialog, alternate_text, active_dialog, fs_version)
	end

	-- add custom things (mostly for editing a dialog) to the window shown left
	table.insert(formspec, add_this_to_left_window)

	local pname_for_old_fs = nil

	-- is there any need to allow scrolling?
	local allow_scrolling = true
	-- in case of older formspec versions: it already does look pretty ugly; there
	-- is no point in checking there if we can scroll or not
	if(fs_version > 2 and h + 1 < yl_speak_up.max_number_of_buttons) then
		allow_scrolling = false
	end

	if(allow_scrolling and fs_version < 3) then
		table.insert(formspec, "style_type[button;bgcolor=#FFFFFF]")
		table.insert(formspec, "background[45,19.5;9.5,5;yl_speak_up_bg_dialog.png;false]")
		table.insert(formspec, "box[45.1,19.6;9.3,4.8;#BBBBBB]")
		table.insert(formspec, "image_button[45.5,20;4,4;gui_furnace_arrow_bg.png;button_down;Up]")
		table.insert(formspec, "image_button[50,20;4,4;gui_furnace_arrow_bg.png^[transformR180;button_up;Down]")
		table.insert(formspec, "style_type[button;bgcolor=#a37e45]")
	end

	if(allow_scrolling and fs_version > 2) then
		local max_scroll = math.ceil(h - yl_speak_up.max_number_of_buttons) + 1
--	        table.insert(formspec, "scrollbar[0.2,24.2;0.2,7;vertical;scr0;0]")
		table.insert(formspec, "scrollbaroptions[min=0;max=")
		table.insert(formspec, tostring(max_scroll*10))
		table.insert(formspec, ";thumbsize=")
		table.insert(formspec, tostring(math.ceil(
				yl_speak_up.max_number_of_buttons /
				(yl_speak_up.max_number_of_buttons + max_scroll)*max_scroll*10)))
		table.insert(formspec, ";smallstep=10")
		table.insert(formspec, ";largestep=")
		table.insert(formspec, tostring(yl_speak_up.max_number_of_buttons*10))
		table.insert(formspec, "]")
	        table.insert(formspec, "scrollbar[54.2,24.2;1.2,7.2;vertical;scr0;1]")
	        table.insert(formspec, "scroll_container[-0.2,24;54.2,7;scr0;vertical;0.1]")

	elseif(allow_scrolling) then
		if(fs_version < 2) then
			-- if the player has an older formspec version
			-- (the NPC itself is not relevant, and players reading the NPC logfile don't
			-- need this information)
			yl_speak_up.log_change(pname, nil,
				"User " .. pname .. " talked to NPC ID n_" .. n_id ..
				" with an old formspec version!", "info")
			table.insert(formspec,
					"box[0.3,20;19,2.6;red]"..
					"label[0.7,20.3;"..yl_speak_up.text_version_warning.."]")
-- TODO delete these obsolete buttons
--			-- The up and down buttons are microscopic. Offer some (still small)
--			-- additional text buttons so that players have a chance to hit them.
--			table.insert(formspec, "button[49,23.1;6,0.9;button_down;^ Scroll Up ^]")
--			table.insert(formspec, "button[49,31.5;6,0.9;button_up;v Scroll Down v]")
--			table.insert(formspec, "button[1,23.1;6,0.9;button_down;^ Scroll Up ^]")
--			table.insert(formspec, "button[1,31.5;6,0.9;button_up;v Scroll Down v]")
		end
		table.insert(formspec, "container[0,24]")
-- TODO delete these obsolete buttons
--		if(fs_version < 2) then
--			-- very small, ugly, and difficult to hit
--			table.insert(formspec, "button[0.1,0;1,0.9;button_down;^]")
--			table.insert(formspec, "button[0.1,7.0;1,0.9;button_up;v]")
--		else
--			-- somewhat larger and quite usable (v2 is pretty ok)
--			table.insert(formspec, "button[0.1,0;1,3;button_down;^\nU\np]")
--			table.insert(formspec, "button[0.1,3.2;1,4.5;button_up;D\no\nw\nn\nv]")
--			table.insert(formspec, "button[53.5,0;1,3;button_down;^\nU\np]")
--			table.insert(formspec, "button[53.5,3.2;1,4.5;button_up;D\no\nw\nn\nv]")
--		end
	else
		table.insert(formspec, "container[0,24]")
	end

	table.insert(formspec, add_this_to_bottom_window)

	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
		"button_exit",
		yl_speak_up.message_button_option_exit,
		yl_speak_up.message_button_option_exit,
		true, nil, true, pname_for_old_fs) -- button_exit

	if(allow_scrolling and fs_version > 2) then
		table.insert(formspec, "scroll_container_end[]")
	else
	        table.insert(formspec, "container_end[]")
	end
        table.insert(formspec, "container_end[]")
	return table.concat(formspec, "")
end


yl_speak_up.show_fs_simple_deco = function(size_x, size_y)
	local x_i = tostring(size_x - 1.5)  -- "18.5"
	local x_a = tostring(size_x - 0.75) -- "19.25"
	local y_i = tostring(size_y - 1.25) --1.5)  -- "21.5"
	local y_a = tostring(size_y - 0.5)  --0.75) -- "22.25"
	local x_L = tostring(size_x + 0.8)
	local y_L = tostring(size_y + 0.8)
	-- formspecs that are not very high look odd otherwise
	if(size_y < 6) then
		y_L = y_L - 0.8
	end
	return "size["..tostring(size_x)..","..tostring(size_y).."]"..
            "bgcolor[#00000000;false]"..
            "style_type[button;bgcolor=#a37e45]"..
            "style_type[button_exit;bgcolor=#a37e45]"..
            "background[0,0;"..tostring(size_x)..","..tostring(size_y+0.25)..
		";yl_speak_up_bg_dialog.png;false]"..
            "image[-0.25,-0.25;1,1;yl_speak_up_bg_dialog_tl.png]"..
            "image[-0.25,"..y_a..";1,1;yl_speak_up_bg_dialog_bl.png]"..
            "image["..x_a..",-0.25;1,1;yl_speak_up_bg_dialog_tr.png]"..
            "image["..x_a..","..y_a..";1,1;yl_speak_up_bg_dialog_br.png]"..
            "image[-0.25,0.5;1,"..y_L..";yl_speak_up_bg_dialog_hl.png]"..
            "image["..x_a..",0.5;1,"..y_L..";yl_speak_up_bg_dialog_hr.png]"..
            "image[0.5,-0.25;"..x_L..",1;yl_speak_up_bg_dialog_vt.png]"..
            "image[0.5,"..y_a..";"..x_L..",1;yl_speak_up_bg_dialog_vb.png]"
end

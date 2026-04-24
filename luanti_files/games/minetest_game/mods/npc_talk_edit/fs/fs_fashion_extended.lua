
-- inspired/derived from the wieldview mod in 3darmor
yl_speak_up.get_wield_texture = function(item)
	if(not(item) or not(minetest.registered_items[ item ])) then
		return "3d_armor_trans.png"
	end
	local def = minetest.registered_items[ item ]
	if(def.inventory_image ~= "") then
		return def.inventory_image
	elseif(def.tiles and type(def.tiles[1]) == "string" and def.tiles[1] ~= "") then
		return minetest.inventorycube(def.tiles[1])
	end
	return "3d_armor_trans.png"
end


yl_speak_up.fashion_wield_give_items_back = function(player, pname)
	-- move the item back to the player's inventory (if possible)
	local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
	local player_inv = player:get_inventory()
	local left_stack  = trade_inv:get_stack("wield", 1)
	local right_stack = trade_inv:get_stack("wield", 2)
	if(left_stack and not(left_stack:is_empty())
	  and player_inv:add_item("main", left_stack)) then
		trade_inv:set_stack("wield", 1, "")
	end
	if(right_stack and not(right_stack:is_empty())
	  and player_inv:add_item("main", right_stack)) then
		trade_inv:set_stack("wield", 2, "")
	end
end


-- set what the NPC shall wield and which cape to wear
yl_speak_up.input_fashion_extended = function(player, formname, fields)
        if formname ~= "yl_speak_up:fashion_extended" then
            return
        end

        local pname = player:get_player_name()
        local textures = yl_speak_up.speak_to[pname].textures

	local n_id = yl_speak_up.speak_to[pname].n_id

	-- is the player editing this npc? if not: abort
	if(not(yl_speak_up.edit_mode[pname])
	  or (yl_speak_up.edit_mode[pname] ~= n_id)) then
		return ""
	end

	-- catch ESC as well
	if(not(fields)
	  or (fields.quit or fields.button_cancel or fields.button_exit or fields.button_save)) then
		yl_speak_up.fashion_wield_give_items_back(player, pname)
		yl_speak_up.show_fs(player, "fashion")
		return

	elseif(fields.button_wield_left
	    or fields.button_wield_right) then
		local trade_inv = minetest.get_inventory({type="detached", name="yl_speak_up_player_"..pname})
		local player_inv = player:get_inventory()
		local left_stack  = trade_inv:get_stack("wield", 1)
		local right_stack = trade_inv:get_stack("wield", 2)
		if(left_stack and left_stack:get_name() and fields.button_wield_left) then
			textures[4] = yl_speak_up.get_wield_texture(left_stack:get_name())
			yl_speak_up.log_change(pname, n_id,
				"(fashion) sword changed to "..tostring(fields.set_sword)..".")
		end
		if(right_stack and right_stack:get_name() and fields.button_wield_right) then
			textures[3] = yl_speak_up.get_wield_texture(right_stack:get_name())
			yl_speak_up.log_change(pname, n_id,
				"(fashion) shield changed to "..tostring(fields.set_shield)..".")
		end
		yl_speak_up.fashion_wield_give_items_back(player, pname)

	-- only change cape if there really is a diffrent one selected
	elseif(fields.set_cape and fields.set_cape ~= textures[1]) then

		local mob_type = yl_speak_up.get_mob_type(pname)
		local capes = yl_speak_up.mob_capes[mob_type] or {}
		-- only set the cape if it is part of the list of allowed capes
		if(table.indexof(capes, fields.set_cape) ~= -1) then
			textures[1] = fields.set_cape
			yl_speak_up.log_change(pname, n_id,
				"(fashion) cape changed to "..tostring(fields.set_cape)..".")
		end
	end

	if(fields.button_wield_left or fields.button_wield_right or fields.set_cape or fields.button_sve) then
		yl_speak_up.fashion_wield_give_items_back(player, pname)
		yl_speak_up.mesh_update_textures(pname, textures)
		yl_speak_up.show_fs(player, "fashion_extended")
		return
	end
	yl_speak_up.show_fs(player, "fashion")
end


yl_speak_up.get_fs_fashion_extended = function(pname)
	-- which texture from the textures list are we talking about?
	-- this depends on the model!
	local mesh = yl_speak_up.get_mesh(pname)
	local texture_index = yl_speak_up.mesh_data[mesh].texture_index
	if(not(texture_index)) then
		texture_index = 1
	end

	local textures = yl_speak_up.speak_to[pname].textures
	local skin = (textures[texture_index] or "")

	-- which skins are available? this depends on mob_type
	local mob_type = yl_speak_up.get_mob_type(pname)
	local skins = yl_speak_up.mob_skins[mob_type] or {skin}
	local capes = yl_speak_up.mob_capes[mob_type] or {}
	local cape = "" -- TODO

	-- is this player editing this particular NPC? then rename the button
	if(not(yl_speak_up.edit_mode[pname])
	  or  yl_speak_up.edit_mode[pname] ~= yl_speak_up.speak_to[pname].n_id) then
		return "label[Error. Not in Edit mode!]"
	end

	-- make sure the cape can be unset again
	if(#capes < 1 or capes[1] ~= "") then
		table.insert(capes, 1, "")
	end
	local cape_list = table.concat(capes, ",")
	local cape_index = table.indexof(capes, cape)
	if(cape_index == -1) then
		cape_index = ""
	end

	local tmp_textures = textures
	if(texture_index ~= 1) then
		tmp_textures = yl_speak_up.textures2skin(textures)
	end
	local preview = yl_speak_up.skin_preview_3d(mesh, tmp_textures, "4.7,0.5;5,10", nil)

	local button_cancel = "Cancel"
	-- is this player editing this particular NPC? then rename the button
	if(   yl_speak_up.edit_mode[pname]
	  and yl_speak_up.edit_mode[pname] == yl_speak_up.speak_to[pname].n_id) then
		button_cancel = "Back"
	end
	local formspec = {
		"size[13.4,15]",
		"label[0.3,0.2;Skin: ",
			minetest.formspec_escape(skin),
			"]",
		"label[4.6,0.65;",
			yl_speak_up.speak_to[pname].n_id,
			"]",
		"label[6,0.65;",
			(yl_speak_up.speak_to[pname].n_npc or "- nameless -"),
			"]",
		"dropdown[9.1,0.2;4,0.75;set_cape;",
			cape_list, ";", cape_index, "]",
		"label[0.3,4.2;Right:]",
		"label[9.1,4.2;Left:]",
		"field_close_on_enter[set_sword;false]",
		"field_close_on_enter[set_shield;false]",
		"image[9.1,1;4,2;",
			textures[1] or "",
			"]", -- Cape
		"image[0.3,4.2;4,4;",
			textures[4] or "",
			"]", -- Sword
		"image[9.1,4.2;4,4;",
			textures[3] or "",
			"]", --textures[3],"]", -- Shield
		"tooltip[0.3,4.2;4,4;This is: ",
			minetest.formspec_escape(textures[4]),
			"]",
		"tooltip[9.1,4.2;4,4;This is: ",
			minetest.formspec_escape(textures[3]),
			"]",
		preview or "",
		"button[0.3,8.4;3,0.75;button_cancel;"..button_cancel.."]",
		"button[10.1,8.4;3,0.75;button_save;Save]",
		"list[current_player;main;1.8,10;8,4;]",
		-- set wielded items
		"label[0.3,9.7;Wield\nright:]",
		"label[12.0,9.7;Wield\nleft:]",
		"list[detached:yl_speak_up_player_"..tostring(pname)..";wield;0.3,10.5;1,1;]",
		"list[detached:yl_speak_up_player_"..tostring(pname)..";wield;12.0,10.5;1,1;1]",
		"button[0.3,11.7;1,0.6;button_wield_left;Set]",
		"button[12.0,11.7;1,0.6;button_wield_right;Set]",
		"tooltip[button_wield_left;Set and store what your NPC shall wield in its left hand.]",
		"tooltip[button_wield_right;Set and store what your NPC shall wield in its right hand.]",
	}
	return table.concat(formspec, "")
end


yl_speak_up.get_fs_fashion_extended_wrapper = function(player, param)
	local pname = player:get_player_name()
	return yl_speak_up.get_fs_fashion_extended(pname)
end

yl_speak_up.register_fs("fashion_extended",
	yl_speak_up.input_fashion_extended,
	yl_speak_up.get_fs_fashion_extended_wrapper,
	-- no special formspec required:
	nil
)

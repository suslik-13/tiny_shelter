-- ###
-- Fashion
-- ###

-- normal skins for NPC - without wielded items or capes etc.
yl_speak_up.input_fashion = function(player, formname, fields)
        if formname ~= "yl_speak_up:fashion" then
            return
        end

	local pname = player:get_player_name()
	local n_id = yl_speak_up.speak_to[pname].n_id

	-- is the player editing this npc? if not: abort
	if(not(yl_speak_up.edit_mode[pname])
	  or (yl_speak_up.edit_mode[pname] ~= n_id)) then
		return ""
	end

	-- catch ESC as well
	if(not(fields) or (fields.quit or fields.button_cancel or fields.button_exit)) then
		yl_speak_up.show_fs(player, "talk", {n_id = yl_speak_up.speak_to[pname].n_id,
						     d_id = yl_speak_up.speak_to[pname].d_id})
		return
	end

	-- which texture from the textures list are we talking about?
	-- this depends on the model!
	local mesh = yl_speak_up.get_mesh(pname)
	local texture_index = yl_speak_up.mesh_data[mesh].texture_index
	if(not(texture_index)) then
		texture_index = 1
	end

	-- show extra formspec with wielded item configuration and cape setup
	if(fields.button_config_wielded_items
	  and yl_speak_up.mesh_data[mesh].can_show_wielded_items) then
		yl_speak_up.show_fs(player, "fashion_extended")
		return
	end

	-- which skins are available? this depends on mob_type
	local mob_type = yl_speak_up.get_mob_type(pname)
	local skins = yl_speak_up.mob_skins[mob_type]


	local textures = yl_speak_up.speak_to[pname].textures or {}

	-- fallback if something went wrong (i.e. unkown NPC)
	local skin = (textures[texture_index] or "")
	if(not(skins)) then
		skins = {skin}
	end
	local skin_index = table.indexof(skins, skin)
	if(skin_index == -1) then
		skin_index = 1
	end
	local new_skin = skin
	-- switch back to the stored old skin
	if(fields.button_old_skin) then
		local old_texture = yl_speak_up.speak_to[pname].old_texture
		if(old_texture) then
			new_skin = old_texture
		end
	-- store the new skin
	elseif(fields.button_store_new_skin) then
		yl_speak_up.speak_to[pname].old_texture = skin
	-- show previous skin
	elseif(fields.button_prev_skin) then
		if(skin_index > 1) then
			new_skin = skins[skin_index - 1]
		else
			new_skin = skins[#skins]
		end
	-- show next skin
	elseif(fields.button_next_skin) then
		if(skin_index < #skins) then
			new_skin = skins[skin_index + 1]
		else
			new_skin = skins[1]
		end
	-- set directly via list
	elseif(fields.set_skin_normal) then
		local new_index = table.indexof(skins, fields.set_skin_normal)
		if(new_index ~= -1) then
			new_skin = skins[new_index]
		end
	end

	-- if there is a new skin to consider
	if(textures[texture_index] ~= new_skin) then
		textures[texture_index] = new_skin
		yl_speak_up.mesh_update_textures(pname, textures)
	end
	if(fields.set_animation
	  and yl_speak_up.mesh_data[mesh]
	  and yl_speak_up.mesh_data[mesh].animation
	  and yl_speak_up.mesh_data[mesh].animation[fields.set_animation]
	  and yl_speak_up.speak_to[pname]
	  and yl_speak_up.speak_to[pname].obj) then
		local obj = yl_speak_up.speak_to[pname].obj
		obj:set_animation(yl_speak_up.mesh_data[mesh].animation[fields.set_animation])
		-- store the animation so that it can be restored on reload
		local entity = obj:get_luaentity()
		if(entity) then
			entity.yl_speak_up.animation = yl_speak_up.mesh_data[mesh].animation[fields.set_animation]
		end
	end
	if(fields.button_old_skin or fields.button_store_new_skin) then
		yl_speak_up.speak_to[pname].old_texture = nil
		yl_speak_up.show_fs(player, "talk", {n_id = yl_speak_up.speak_to[pname].n_id,
						     d_id = yl_speak_up.speak_to[pname].d_id})
		return
	end
	yl_speak_up.show_fs(player, "fashion")
end


-- this only sets the *skin*, depending on the mesh of the NPC;
-- capes and wielded items are supported by an extended formspec for those
-- NPC that can handle them
yl_speak_up.get_fs_fashion = function(pname)
	-- which texture from the textures list are we talking about?
	-- this depends on the model!
	local mesh = yl_speak_up.get_mesh(pname)
	if(not(mesh) or not(yl_speak_up.mesh_data[mesh])) then
		return "size[9,2]label[0,0;Error: Mesh data missing.]"
	end
	local texture_index = yl_speak_up.mesh_data[mesh].texture_index
	if(not(texture_index)) then
		texture_index = 1
	end

	-- which skins are available? this depends on mob_type
	local mob_type = yl_speak_up.get_mob_type(pname)
	local skins = yl_speak_up.mob_skins[mob_type]

	local textures = yl_speak_up.speak_to[pname].textures
	local skin = ""
	if(textures and textures[texture_index]) then
		skin = (textures[texture_index] or "")
	end
	-- store the old texture so that we can go back to it
	local old_texture = yl_speak_up.speak_to[pname].old_texture
	if(not(old_texture)) then
		yl_speak_up.speak_to[pname].old_texture = skin
		old_texture = skin
	end
	-- fallback if something went wrong
	if(not(skins)) then
		skins = {old_texture}
	end

	local button_cancel = "Cancel"
	-- is this player editing this particular NPC? then rename the button
	if(   yl_speak_up.edit_mode[pname]
	  and yl_speak_up.edit_mode[pname] == yl_speak_up.speak_to[pname].n_id) then
		button_cancel = "Back"
	end

	local skin_list = table.concat(skins, ",")
	local skin_index = table.indexof(skins, skin)
	if(skin_index == -1) then
		skin_index = ""
	end

	local tmp_textures = textures
	if(texture_index ~= 1) then
		tmp_textures = yl_speak_up.textures2skin(textures)
	end
	local preview = yl_speak_up.skin_preview_3d(mesh, tmp_textures, "2,1;6,12", "8,1;6,12")
--	local preview = yl_speak_up.mesh_data[mesh].skin_preview(skin)

	local formspec = {
		"container[0.5,4.0]",
		"dropdown[0.75,14.1;16.25,1.5;set_skin_normal;",
			skin_list or "",
			";",
			tostring(skin_index) or "",
			"]",
		"label[0.75,13.6;The name of this skin is:]",

		"button[0.75,0.75;1.2,12;button_prev_skin;<]",
		"button[15.75,0.75;1.2,12;button_next_skin;>]",
		"tooltip[button_prev_skin;Select previous skin in list.]",
		"tooltip[button_next_skin;Select next skin in list.]",
		"tooltip[set_skin_normal;Select a skin from the list.]",
		preview,
		-- we add a special button for setting the skin in the player answer/reply window
	}
	if(yl_speak_up.mesh_data[mesh].animation
	  and yl_speak_up.speak_to[pname]
	  and yl_speak_up.speak_to[pname].obj) then
		local anim_list = {}
		for k, v in pairs(yl_speak_up.mesh_data[mesh].animation) do
			table.insert(anim_list, k)
		end
		table.sort(anim_list)
		-- which animation is the NPC currently running?
		local obj = yl_speak_up.speak_to[pname].obj
		local curr_anim = obj:get_animation(pname)
		local anim = ""
		-- does the current animation match any stored one?
		for k, v in pairs(yl_speak_up.mesh_data[mesh].animation) do
			if(v.x and v.y and curr_anim and curr_anim.x and curr_anim.y
			  and v.x == curr_anim.x and v.y == curr_anim.y) then
				anim = k
			end
		end
		local anim_index = table.indexof(anim_list, anim)
		if(anim_index == -1) then
			anim_index = "1"
		end
		table.insert(formspec, "label[0.75,16.4;Do the following animation:]")
		table.insert(formspec, "dropdown[0.75,16.9;16.25,1.5;set_animation;")
		table.insert(formspec, table.concat(anim_list, ','))
		table.insert(formspec, ";")
		table.insert(formspec, tostring(anim_index) or "")
		table.insert(formspec, "]")
	end
	table.insert(formspec, "container_end[]")

	local left_window = table.concat(formspec, "")
	formspec = {}
	local h = -0.8
	local button_text = "This shall be your new skin. Wear it proudly!"
	if(skin == old_texture) then
		button_text = "This is your old skin. It is fine. Keep it!"
	end
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"button_store_new_skin",
			"The NPC will wear the currently selected skin.",
			button_text,
			true, nil, nil, nil)
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"button_old_skin",
			"The NPC will wear the skin he wore before you started changing it.",
			"On a second throught - Keep your old skin. It was fine.",
			(skin ~= old_texture), nil, nil, nil)
	h = yl_speak_up.add_edit_button_fs_talkdialog(formspec, h,
			"button_config_wielded_items",
			"What shall the NPC wield, and which cape shall he wear?",
			"I'll tell you what you shall wield.",
			(yl_speak_up.mesh_data[mesh].can_show_wielded_items),
			"You don't know how to show wielded items. Thus, we can't configure them.",
			 nil, nil)
	return yl_speak_up.show_fs_decorated(pname, true, h,
					"",
					left_window,
					table.concat(formspec, ""),
					nil,
					h)
end

yl_speak_up.get_fs_fashion_wrapper = function(player, param)
	local pname = player:get_player_name()
	return yl_speak_up.get_fs_fashion(pname)
end


yl_speak_up.register_fs("fashion",
	yl_speak_up.input_fashion,
	yl_speak_up.get_fs_fashion_wrapper,
	-- no special formspec required:
	nil
)

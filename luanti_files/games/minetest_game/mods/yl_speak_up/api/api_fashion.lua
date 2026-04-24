

-- some meshes use more than one texture, and which texture is the main skin
-- texture can only be derived from the name of the mesh
yl_speak_up.get_mesh = function(pname)
	if(not(pname)) then
		return "error"
	end
	local obj = yl_speak_up.speak_to[pname].obj
	if(not(obj)) then
		return "error"
	end
	local entity = obj:get_luaentity()
	if(not(entity)) then
		return "error"
	end
	-- mobs_redo stores it extra; other mob mods may not
	if(not(entity.mesh) and entity.name
	  and minetest.registered_entities[entity.name]) then
		if(minetest.registered_entities[entity.name].initial_properties
		 and minetest.registered_entities[entity.name].initial_properties.mesh) then
			return minetest.registered_entities[entity.name].initial_properties.mesh
		end
		return minetest.registered_entities[entity.name].mesh
	end
	return entity.mesh
end


-- diffrent mobs (distinguished by self.name) may want to wear diffrent skins
-- even if they share the same model; find out which mob we're dealing with
yl_speak_up.get_mob_type = function(pname)
	if(not(pname)) then
		return "error"
	end
	local obj = yl_speak_up.speak_to[pname].obj
	if(not(obj)) then
		return "error"
	end
	local entity = obj:get_luaentity()
	if(not(entity)) then
		return "error"
	end
	return entity.name
end



-- this makes use of the "model" option of formspecs
yl_speak_up.skin_preview_3d = function(mesh, textures, where_front, where_back)
	local tstr = ""
	for i, t in ipairs(textures or {}) do
		tstr = tstr..minetest.formspec_escape(t)..","
	end
	local backside = ""
	if(where_back) then
		backside = ""..
		"model["..where_back..";skin_show_back;"..mesh..";"..tstr..";0,0;false;true;;]"
	end
	return	"model["..where_front..";skin_show_front;"..mesh..";"..tstr..";0,180;false;true;;]"..--"0,300;9]".. -- ;]"..
		backside
end


-- TODO: this function is obsolete now
-- this is a suitable version for most models/meshes that use normal player skins
-- (i.e. mobs_redo) with skins in either 64 x 32 or 64 x 64 MC skin format
yl_speak_up.skin_preview_normal = function(skin, with_backside)
	local backside = ""
	if(with_backside) then
		backside = ""..
		"image[8,0.7;2,2;[combine:8x8:-24,-8="..skin.."]"..  -- back head
		"image[7.85,0.55;2.3,2.3;[combine:8x8:-56,-8="..skin.."]".. -- head, beard
		"image[8,2.75;2,3;[combine:8x12:-32,-20="..skin..":-32,-36="..skin.."]"..  -- body back
		"image[8,5.75;1,3;[combine:4x12:-12,-20="..skin.."]"..  -- left leg back
		"image[8,5.75;1,3;[combine:4x12:-28,-52="..skin..":-12,-52="..skin.."]"..  -- r. leg back ov
		"image[9,5.75;1,3;[combine:4x12:-12,-20="..skin.."^[transformFX]"..  -- right leg back
		"image[9,5.75;1,3;[combine:4x12:-12,-36="..skin.."]"..  -- right leg back ov
		"image[7,2.75;1,3;[combine:4x12:-52,-20="..skin..":-40,-52="..skin..":-60,-52="..skin.."]"..  -- l. hand back ov
		"image[10,2.75;1,3;[combine:4x12:-52,-20="..skin.."^[transformFX]".. -- right hand back
		"image[10,2.75;1,3;[combine:4x12:-52,-20="..skin..":-52,-36="..skin.."]"  -- left hand back
	end
	return	"image[3,0.7;2,2;[combine:8x8:-8,-8="..skin.."]"..
		"image[2.85,0.55;2.3,2.3;[combine:8x8:-40,-8="..skin.."]".. -- head, beard
		"image[3,2.75;2,3;[combine:8x12:-20,-20="..skin..":-20,-36="..skin.."]".. -- body
		"image[3,5.75;1,3;[combine:4x12:-4,-20="..skin..":-4,-36="..skin.."]"..  -- left leg + ov
		"image[4,5.75;1,3;[combine:4x12:-4,-20="..skin.."^[transformFX]"..  -- right leg
		"image[4,5.75;1,3;[combine:4x12:-20,-52="..skin..":-4,-52="..skin.."]"..  -- right leg ov
		"image[2.0,2.75;1,3;[combine:4x12:-44,-20="..skin..":-44,-36="..skin.."]"..  -- left hand
		"image[5.0,2.75;1,3;[combine:4x12:-44,-20="..skin.."^[transformFX]"..  -- right hand
		"image[5.0,2.75;1,3;[combine:4x12:-36,-52="..skin..":-52,-52="..skin.."]"..  -- right hand ov
		backside

		--local legs_back = "[combine:4x12:-12,-20="..skins.skins[name]..".png"
end



yl_speak_up.cape2texture = function(t)
    if(not(t) or t=="") then
	t = "blank.png"
    end
    -- same texture mask as the shield
    return "yl_speak_up_mask_shield.png^[combine:32x64:56,20=" .. tostring(t)
end

yl_speak_up.shield2texture = function(t)
    if(not(t) or t=="") then
	t = "3d_armor_trans.png"
    end
    return "yl_speak_up_mask_shield.png^[combine:32x64:0,0=(" .. tostring(t) .. ")"
end

yl_speak_up.textures2skin = function(textures)
    local temp = {}
    -- Cape

    local cape = yl_speak_up.cape2texture(textures[1])

    -- Main

    local main = textures[2]

    -- left (Shield)

    local left = yl_speak_up.shield2texture(textures[3])

    -- right (Sword)

    local right = textures[4]

    temp = {cape, main, left, right}

    return temp
end


yl_speak_up.mesh_update_textures = function(pname, textures)
	-- actually make sure that the NPC updates its texture
	local obj = yl_speak_up.speak_to[pname].obj
	if(not(obj) or not(textures)) then
		return
	end
	-- store the textures without added masks for cape and shield:
	yl_speak_up.speak_to[pname].skins = textures
	local entity = obj:get_luaentity()
	if(entity) then
		entity.yl_speak_up.skin = textures
	end
	-- the skins with wielded items need some conversion,
	-- while simpler models may just apply the texture
	local mesh = yl_speak_up.get_mesh(pname)
	if(mesh and yl_speak_up.mesh_data[mesh].textures_to_skin) then
		textures = yl_speak_up.textures2skin(textures)
	end
	obj:set_properties({ textures = textures })
	-- scrolling through the diffrent skins updates the skin; avoid spam in the log
--	yl_speak_up.log_change(pname, n_id,
--		"(fashion) skin changed to "..tostring(new_skin)..".")
end


yl_speak_up.update_nametag = function(self)
    if(self.yl_speak_up.hide_nametag) then
        self.object:set_nametag_attributes({text=nil})
	return
    end
    if self.yl_speak_up.npc_name then
	-- the nametag is normal (cyan by default)
        if(self.yl_speak_up.talk) then
	    self.force_nametag_color = yl_speak_up.nametag_color_when_not_muted
            self.object:set_nametag_attributes({color=self.force_nametag_color, text=self.yl_speak_up.npc_name})
	-- the nametag has the addition "[muted]" and is magenta when muted
        else
	    self.force_nametag_color = yl_speak_up.nametag_color_when_muted
	    self.object:set_nametag_attributes({color=self.force_nametag_color, text=self.yl_speak_up.npc_name.." [muted]"})
        end
    end
end



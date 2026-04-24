-- Make the NPC talk (mobs_redo interface)

--###
-- Mob functions
--###

-- TODO: mob_table is currently unused
function yl_speak_up.init_mob_table()
    return false
end
-- -- TODO currently. mob_table doesn't really do anything
--    yl_speak_up.mob_table[self.yl_speak_up.id] = "yl_speak_up:test_npc"


-- this only makes sense if mobs_redo exists and is loaded
if(not(minetest.get_modpath("mobs"))
	or not(minetest.global_exists("mobs"))
	or not(mobs.mob_class)) then
   minetest.log("action","[MOD] yl_speak_up Info: mobs_redo mod not found. Not loading interface.")
   return
end


-- React to right-clicking a mobs_redo mob:
-- 	* capture the mob with a lasso or net (if appropriate)
-- 	* protect the mob with a protector
-- 	* if none of the above applies: actually talk to the mob
-- This is so often needed (but also mobs_redo specific!) that we provide
-- an extra easy-to-call function here.
function yl_speak_up.do_mobs_on_rightclick(self, clicker)
    --local item = clicker:get_wielded_item()
    local name = clicker:get_player_name()

	local n_id = "?"
	if(self and self.yl_speak_up and self.yl_speak_up.id) then
		n_id = "n_"..tostring(self.yl_speak_up.id)

		-- if someone other than the owner placed the mob, then we need to
		-- adjust the owner back from placer to real_owner
		if(self.yl_speak_up.real_owner and self.yl_speak_up.real_owner ~= self.owner) then
			self.owner = self.yl_speak_up.real_owner
		end
	end

	-- Take the mob only with net or lasso
	if self.owner and (self.owner == name or yl_speak_up.may_edit_npc(clicker, n_id)) then
		local pos = self.object:get_pos()
		self.yl_speak_up.last_pos = minetest.pos_to_string(pos, 0)
		-- the mob can be picked up by someone who can just *edit* it but is not *the* owner
		if(self.owner ~= name) then
			self.yl_speak_up.real_owner = self.owner
		end
		-- try to capture the mob
		local egg_stack = mobs:capture_mob(self, clicker, nil, 100, 100, true, nil)
		if(egg_stack and self.yl_speak_up) then
			minetest.log("action","[MOD] yl_speak_up "..
				" NPC n_"..tostring(self.yl_speak_up.id)..
				" named "..tostring(self.yl_speak_up.npc_name)..
				" (owned by "..tostring(self.owner)..
				") picked up by "..tostring(clicker:get_player_name())..
				" at pos "..minetest.pos_to_string(pos, 0)..".")

			-- players want to know *which* NPC will "hatch" from this egg;
			-- sadly there is no point in modifying egg_data as that has already
			-- been put into the inventory of the player and is just a copy now
			local player_inv = clicker:get_inventory()
			for i, v in ipairs(player_inv:get_list("main") or {}) do
				local m = v:get_meta()
				local d = minetest.deserialize(m:get_string("") or {})
				-- adjust the description text of the NPC in the inventory
				if(d and d.yl_speak_up and d.yl_speak_up.id) then
					local d2 = d.yl_speak_up
					local text = (d2.npc_name  or "- nameless -").. ", "..
						(d2.npc_description or "-").."\n"..
						"(n_"..tostring(d2.id)..", owned by "..
						tostring(d.owner).."),\n"..
						"picked up at "..tostring(d2.last_pos or "?").."."
					m:set_string("description", text)
					player_inv:set_stack("main", i, v)
				end
			end
			return
		end
	end

    -- protect npc with mobs:protector
    if mobs:protect(self, clicker) then
	if(self.yl_speak_up) then
		local pos = self.object:get_pos()
		minetest.log("action","[MOD] yl_speak_up "..
			" NPC n_"..tostring(self.yl_speak_up.id)..
			" named "..tostring(self.yl_speak_up.npc_name)..
			" (owned by "..tostring(self.owner)..
			") protected with protector by "..tostring(clicker:get_player_name())..
			" at pos "..minetest.pos_to_string(pos, 0)..".")
	end
        return
    end

    -- bring up the dialog options
    if clicker then
        yl_speak_up.talk(self, clicker)
        return
    end
end


function yl_speak_up.do_mobs_after_activate(self, staticdata, def, dtime)
    -- this scrolls far too much
--    yl_speak_up.log_change("-", "n_"..self.yl_speak_up.id,
--            "activated at "..minetest.pos_to_string(self.object:get_pos()), "action")

    -- we are not (yet?) responsible for this mob
    if(not(self.yl_speak_up)) then
	return true
    end

    if yl_speak_up.status == 2 then
        self.object:remove()
        return true
    end

    -- load the texture/skin of the NPC
    if self.yl_speak_up and self.yl_speak_up.skin then
        local tex = self.yl_speak_up.skin
	-- only use the cape as such:
	if(tex[1]) then
		local p = string.split(tex[1], "=")
		if(#p > 1) then
			tex[1] = p[#p]
		end
	end
	-- the shield:
	if(tex[3]) then
		local p = string.split(tex[3], "=")
		if(#p > 1) then
			tex[3] = p[#p]
			local start = 1
			local ende = string.len(tex[3])
			if(string.sub(tex[3], 1, 1)=="(") then
				start = 2
			end
			if(string.sub(tex[3], ende)==")") then
				ende = ende - 1
			end
			tex[3] = string.sub(tex[3], start, ende)
		end
	end
	-- store only the basic texture names without shield and text mask:
	self.yl_speak_up.skin = tex
	-- add back cape and shield mask:
	tex[1] = yl_speak_up.cape2texture(tex[1])
	tex[3] = yl_speak_up.shield2texture(tex[3])
        self.object:set_properties({textures = {tex[1], tex[2], tex[3], tex[4]}})
    end

    -- the NPC may have another animation (i.e. sitting)
    if self.yl_speak_up and self.yl_speak_up.animation then
        self.object:set_animation(self.yl_speak_up.animation)
    end

    -- add a more informative infotext
    if yl_speak_up.infotext then
        local i_text = ""
        if self.yl_speak_up.npc_name then
            i_text = i_text .. self.yl_speak_up.npc_name .. "\n"
        end
        if self.yl_speak_up.npc_description then
            i_text = i_text .. self.yl_speak_up.npc_description .. "\n"
        end
        i_text = i_text .. yl_speak_up.infotext
        self.object:set_properties({infotext = i_text})
    end

    -- set nametag (especially color)
    yl_speak_up.update_nametag(self)
end


-- prevent NPC from getting hurt by special nodes
-- This has another positive side-effect: update_tag doesn't get called constantly
if(not(yl_speak_up.orig_mobs_do_env_damage)) then
	yl_speak_up.orig_mobs_do_env_damage = mobs.mob_class.do_env_damage
end
mobs.mob_class.do_env_damage = function(self)
	-- we are only responsible for talking NPC
	if(not(self) or not(self.yl_speak_up)) then
		return yl_speak_up.orig_mobs_do_env_damage(self)
	end
	-- *no* env dammage for NPC
	return
end


-- we need to override this function from mobs_redo mod so that color
-- changes to the name tag color are possible
-- BUT: Only do this once. NOT at each reset!
if(not(yl_speak_up.orig_mobs_update_tag)) then
	yl_speak_up.orig_mobs_update_tag = mobs.mob_class.update_tag
end
-- update nametag and infotext
mobs.mob_class.update_tag = function(self, newname)

	-- we are only responsible for talking NPC
	if(not(self) or not(self.yl_speak_up)) then
		return yl_speak_up.orig_mobs_update_tag(self, newname)
	end

	local qua = 0
	local floor = math.floor
	local col = "#00FF00"
	local prop = self.object:get_properties()
	local hp_max = 0
	if(prop) then
		hp_max = prop.hp_max
	end
	if(not(hp_max)) then
		hp_max = self.hp_max
	end
	if(not(hp_max)) then
		hp_max = self.health
	end
	local qua = hp_max / 6

	if(self.force_nametag_color) then
		col = self.force_nametag_color
	elseif self.health <= qua then
		col = "#FF0000"
	elseif self.health <= (qua * 2) then
		col = "#FF7A00"
	elseif self.health <= (qua * 3) then
		col = "#FFB500"
	elseif self.health <= (qua * 4) then
		col = "#FFFF00"
	elseif self.health <= (qua * 5) then
		col = "#B4FF00"
	elseif self.health > (qua * 5) then
		col = "#00FF00"
	end


	local text = ""

	if self.horny == true then
		local HORNY_TIME = 30
		local HORNY_AGAIN_TIME = 60 * 5 -- 5 minutes

		text = "\nLoving: " .. (self.hornytimer - (HORNY_TIME + HORNY_AGAIN_TIME))
	elseif self.child == true then
		local CHILD_GROW_TIME = 60 * 20 -- 20 minutes
		text = "\nGrowing: " .. (self.hornytimer - CHILD_GROW_TIME)
	elseif self._breed_countdown then
		text = "\nBreeding: " .. self._breed_countdown
	end

	if self.protected then
		if self.protected == 2 then
			text = text .. "\nProtection: Level 2"
		else
			text = text .. "\nProtection: Level 1"
		end
	end

	local add_info = ""
	if(self.yl_speak_up and self.yl_speak_up.npc_name) then
		add_info = "\n"..tostring(self.yl_speak_up.npc_name)
		if(self.yl_speak_up.npc_description) then
			add_info = add_info..", "..tostring(self.yl_speak_up.npc_description)
		end
	end
	self.infotext = "Health: " .. self.health .. " / " .. hp_max
		.. add_info
		.. (self.owner == "" and "" or "\nOwner: " .. self.owner)
		.. text

	-- set changes
	self.object:set_properties({
		nametag = self.nametag,
		nametag_color = col,
		infotext = self.infotext
	})
end

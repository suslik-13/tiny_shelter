
--###
-- Init
--###

-- self (the npc as such) is rarely passed on to any functions; in order to be able to check if
-- the player really owns the npc, we need to have that data available;
-- format: yl_speak_up.npc_owner[ npc_id ] = owner_name
yl_speak_up.npc_owner = {}

-- store the current trade between player and npc in case it gets edited in the meantime
yl_speak_up.trade = {}

-- store what the player last entered in an text_input action
yl_speak_up.last_text_input = {}


--###
-- Debug
--###

yl_speak_up.debug = true


---###
-- general formpsec
---###
yl_speak_up.get_error_message = function()
    local formspec = {
        "size[13.4,8.5]",
        "bgcolor[#FF0000]",
        "label[0.2,0.35;Please save a NPC file first]",
        "button_exit[0.2,7.7;3,0.75;button_back;Back]"
    }

    return table.concat(formspec, "")
end


yl_speak_up.get_sorted_dialog_name_list = function(dialog)
	local liste = {}
	if(dialog and dialog.n_dialogs) then
		for k, v in pairs(dialog.n_dialogs) do
			-- this will be used for dropdown lists - so we use formspec_escape
			table.insert(liste, minetest.formspec_escape(v.d_name or k or "?"))
		end
		-- sort alphabethicly
		table.sort(liste)
	end
	return liste
end

---###
-- player related
---###

yl_speak_up.reset_vars_for_player = function(pname, reset_fs_version)
	yl_speak_up.speak_to[pname] = nil
	yl_speak_up.last_text_input[pname] = nil
	-- when just stopping editing: don't reset the fs_version
	if(reset_fs_version) then
		yl_speak_up.fs_version[pname] = nil
	end
end



---###
-- player and npc related
---###

-- identify multiple results that lead to target dialogs
yl_speak_up.check_for_disambigous_results = function(n_id, pname)
	local errors_found = false
	-- this is only checked when trying to edit this npc;
	-- let's stick to check the dialogs of this one without generic dialogs
	local dialog = yl_speak_up.load_dialog(n_id, false)
	-- nothing defined yet - nothing to repair
	if(not(dialog.n_dialogs)) then
		return
	end
	-- iterate over all dialogs
	for d_id, d in pairs(dialog.n_dialogs) do
		if(d_id and d and d.d_options) then
			-- iterate over all options
			for o_id, o in pairs(d.d_options) do
				if(o_id and o and o.o_results) then
					local dialog_results = {}
					-- iterate over all results
					for r_id, r in pairs(o.o_results) do
						if(r.r_type == "dialog") then
							table.insert(dialog_results, r_id)
						end
					end
					if(#dialog_results>1) then
						local msg = "ERROR: Dialog "..
							tostring(d_id)..", option "..tostring(o_id)..
							", has multiple results of type dialog: "..
							minetest.serialize(dialog_results)..". Please "..
							"let someone with npc_master priv fix that first!"
						yl_speak_up.log_change(pname, n_id, msg, "error")
						if(pname) then
							minetest.chat_send_player(pname, msg)
						end
						errors_found = true
					end
				end
			end
		end
	end
	return errors_found
end


-- returns true if someone is speaking to the NPC
yl_speak_up.npc_is_in_conversation = function(n_id)
	for name, data in pairs(yl_speak_up.speak_to) do
		if(data and data.n_id and data.n_id == n_id) then
			return true
		end
	end
	return false
end


-- returns a list of players that are in conversation with this NPC
yl_speak_up.npc_is_in_conversation_with = function(n_id)
	local liste = {}
	for name, data in pairs(yl_speak_up.speak_to) do
		if(data and data.n_id and data.n_id == n_id) then
			table.insert(liste, name)
		end
	end
	return liste
end


-- Make the NPC talk

-- assign n_ID
-- usually this happens when talking to the NPC for the first time;
-- but if you want to you can call this function earlier (on spawn)
-- so that logging of spawning with the ID is possible
yl_speak_up.initialize_npc = function(self)
	-- already configured?
	if(not(self) or (self.yl_speak_up and self.yl_speak_up.id)) then
		return self
	end

	local m_talk = yl_speak_up.talk_after_spawn or true
	local m_id = yl_speak_up.number_of_npcs + 1
	yl_speak_up.number_of_npcs = m_id
	yl_speak_up.modstorage:set_int("amount", m_id)

	self.yl_speak_up = {
		talk = m_talk,
		id = m_id,
		textures = self.textures
	}
	return self
end


function yl_speak_up.talk(self, clicker)

	if not clicker and not clicker:is_player() then
		return
	end
	if not self then
		return
	end

	local id_prefix = "n"
	-- we are not dealing with an NPC but with a position/block on the map
	if(self.is_block) then
		id_prefix = "p"
		local owner = "- unknown -"
		local talk_name = "- unknown -"
		if(self.pos and self.pos and self.pos.x) then
			local meta = minetest.get_meta(self.pos)
			if(meta) then
				owner = meta:get_string("owner") or ""
				talk_name = meta:get_string("talk_name") or ""
			end
		end
		self.yl_speak_up = {
			is_block = true,
			talk = true,
			id = minetest.pos_to_string(self.pos, 0),
			textures = {},
			owner = owner,
			npc_name = talk_name,
			object = nil, -- blocks don't have an object
		}
		-- TODO: remember somewhere that this block is relevant

	-- initialize the mob if necessary; this happens at the time of first talk, not at spawn time!
	elseif(not(self.yl_speak_up) or not(self.yl_speak_up.id)) then
		self = yl_speak_up.initialize_npc(self)
	end


    local npc_id = self.yl_speak_up.id
    local n_id = id_prefix.."_" .. npc_id

    -- remember whom the npc belongs to (as long as we still have self.owner available for easy access)
    yl_speak_up.npc_owner[ n_id ] = self.owner

    local pname = clicker:get_player_name()
    if not self.yl_speak_up or not self.yl_speak_up.talk or self.yl_speak_up.talk~=true then

	local was = "This NPC"
	if(id_prefix ~= "n") then
		was = "This block"
	end
	-- show a formspec to other players that this NPC is busy
        if(not(yl_speak_up.may_edit_npc(clicker, n_id))) then
             -- show a formspec so that the player knows that he may come back later
             yl_speak_up.show_fs(player, "msg", {input_to = "yl_spaek_up:ignore", formspec =
		"size[6,2]"..
		"label[1.2,0.0;"..minetest.formspec_escape((self.yl_speak_up.npc_name or was)..
			" [muted]").."]"..
		"label[0.2,0.5;Sorry! I'm currently busy learning new things.]"..
		"label[0.2,1.0;Please come back later.]"..
		"button_exit[2.5,1.5;1,0.9;ok;Ok]"})
             return
        end
        -- allow the owner to edit (and subsequently unmute) the npc
	minetest.chat_send_player(pname, was.." is muted. It will only talk to you.")
    end

    yl_speak_up.speak_to[pname] = {}
    yl_speak_up.speak_to[pname].n_id = n_id -- Memorize which player talks to which NPC
    yl_speak_up.speak_to[pname].textures = self.yl_speak_up.textures
    yl_speak_up.speak_to[pname].option_index = 1
    -- the object itself may be needed in load_dialog for adding generic dialogs
    yl_speak_up.speak_to[pname].obj = self.object
    -- this makes it a bit easier to access some values later on:
    yl_speak_up.speak_to[pname]._self = self
    -- Load the dialog and see what we can do with it
    -- this inculdes generic dialog parts;
    yl_speak_up.speak_to[pname].dialog = yl_speak_up.load_dialog(n_id, clicker)

    -- is this player explicitly allowed to edit this npc?
    if(yl_speak_up.speak_to[pname].dialog
      and yl_speak_up.speak_to[pname].dialog.n_may_edit
      and yl_speak_up.speak_to[pname].dialog.n_may_edit[pname]
      and minetest.check_player_privs(clicker, {npc_talk_owner=true})) then
	yl_speak_up.speak_to[pname].may_edit_this_npc = true
    end

    local dialog = yl_speak_up.speak_to[pname].dialog
    if(not(dialog.trades)) then
       dialog.trades = {}
    end

    -- create a detached inventory for the npc and load its inventory
    yl_speak_up.load_npc_inventory(id_prefix.."_"..tostring(self.yl_speak_up.id), false, dialog)


    -- some NPC may have reset the animation; at least set it to the desired
    -- value whenever we talk to the NPC
    if self.yl_speak_up and self.yl_speak_up.animation then
        self.object:set_animation(self.yl_speak_up.animation)
    end

    -- maintain a list of existing NPC, but do not force saving
    yl_speak_up.update_npc_data(self, dialog, false)

    yl_speak_up.show_fs(clicker, "talk", {n_id = n_id})
end


-- mute the npc; either via the appropriate staff or via talking to him
yl_speak_up.set_muted = function(p_name, obj, set_muted)
	if(not(obj)) then
		return
	end
	local luaentity = obj:get_luaentity()
	if(not(luaentity)) then
		return
	end
	local npc = luaentity.yl_speak_up.id
	local npc_name = luaentity.yl_speak_up.npc_name
	-- fallback
	if(not(npc_name)) then
		npc_name = npc
	end
	if(set_muted and luaentity.yl_speak_up.talk) then
		-- the npc is willing to talk
		luaentity.yl_speak_up.talk = false
		yl_speak_up.update_nametag(luaentity)

--		minetest.chat_send_player(p_name,"NPC with ID n_"..npc.." will shut up at pos "..
--			minetest.pos_to_string(obj:get_pos(),0).." on command of "..p_name)
		minetest.chat_send_player(p_name, "NPC n_"..tostring(npc).." is now muted and will "..
				"only talk to those who can edit the NPC.")
		yl_speak_up.log_change(p_name, "n_"..npc, "muted - NPC stops talking")
	elseif(not(set_muted) and not(luaentity.yl_speak_up.talk)) then
		-- mute the npc
		luaentity.yl_speak_up.talk = true
		yl_speak_up.update_nametag(luaentity)

		minetest.chat_send_player(p_name, "NPC n_"..tostring(npc).." is no longer muted and "..
				"will talk with any player who right-clicks the NPC.")
--		minetest.chat_send_player(p_name,"NPC with ID n_"..npc.." will resume speech at pos "..
--			minetest.pos_to_string(obj:get_pos(),0).." on command of "..p_name)
		yl_speak_up.log_change(p_name, "n_"..npc, "unmuted - NPC talks again")
	end
end


-- has the player the right privs?
-- this is used for the "I am your master" talk based configuration; *NOT* for the staffs!
yl_speak_up.may_edit_npc = function(player, n_id)
	if(not(player)) then
		return false
	end
	local pname = player:get_player_name()
	-- is the player allowed to edit this npc?
	return ((yl_speak_up.npc_owner[ n_id ] == pname
	  and minetest.check_player_privs(player, {npc_talk_owner=true}))
	  or minetest.check_player_privs(player, {npc_talk_master=true})
	  or minetest.check_player_privs(player, {npc_master=true})
	  or (yl_speak_up.speak_to[pname]
	  and yl_speak_up.speak_to[pname].may_edit_this_npc))
end


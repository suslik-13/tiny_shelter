pvp_control = {}

local S = minetest.get_translator("pvp_pad")
local war_pad_texture = "war_pad.png"
local peace_pad_texture = "peace_pad.png"
local intval = 0.15  --  Determins interval of pad checking
local visc = 4 --max 15, slows progress across pad to ensure detection.

-- Function to remove nearby mcl_bows:arrow_entity around a player
local function remove_nearby_arrows(player, radius)
    if not player or not player:is_player() then
        return
    end

    local pos = player:get_pos()
    local radius = radius or 5 -- default radius of 5 units

    -- Get all objects within the radius
    local objects = minetest.get_objects_inside_radius(pos, radius)
    for _, obj in ipairs(objects) do
        local luaentity = obj:get_luaentity()
        -- Check if the object is the specific arrow entity
        if luaentity and luaentity.name == "mcl_bows:arrow_entity" then
            obj:remove() -- Remove the arrow entity
        end
    end
end



-- Function to toggle PvP for a player
local function toggle_pvp(player)
    local pvp_setting = player:get_meta():get_string("pvp_enabled")

    if pvp_setting == "" or pvp_setting == "false" then
        pvp_on(player)
        --player:get_meta():set_string("pvp_enabled", "true")
        --minetest.chat_send_player(player:get_player_name(), "PvP is now enabled for you.")
    else
        pvp_off(player)
        --player:get_meta():set_string("pvp_enabled", "false")
        --minetest.chat_send_player(player:get_player_name(), "PvP is now disabled for you.")
    end
end

local function pvp_off(player)
        player:get_meta():set_string("pvp_enabled", "false")
        minetest.chat_send_player(player:get_player_name(), "PEACE mode for you.") 
		--local player = minetest.get_player_by_name(user)
		local color = {r = 0, g = 0, b = 255}
		player:set_nametag_attributes({color = color})
		player:set_attribute("nametag_color", minetest.serialize(color))
end   

local function pvp_on(player)
        player:get_meta():set_string("pvp_enabled", "true")
        minetest.chat_send_player(player:get_player_name(), "WAR mode for you.") 
		--local player = minetest.get_player_by_name(user)
		local color = {r = 255, g = 0, b = 0}
		player:set_nametag_attributes({color = color})
		player:set_attribute("nametag_color", minetest.serialize(color))
end 

-- Function to check if PvP is enabled for a player
local function is_pvp_enabled(player)
    local pvp_setting = player:get_meta():get_string("pvp_enabled")
    return pvp_setting ~= "false"
end

-- Registering the /toggle_pvp command
minetest.register_chatcommand("toggle_pvp", {
    description = "Toggle PvP on or off",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            toggle_pvp(player)
        end
    end,
})

-- Registering the /war command
minetest.register_chatcommand("war", {
    description = "PvP on",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            pvp_on(player)
        end
    end,
})

-- Registering the /peace command
minetest.register_chatcommand("peace", {
    description = "PvP off",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            pvp_off(player)
        end
    end,
})


-- Register the on punch player event
minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    -- Check if both player and hitter are valid and are players
    if not player or not hitter or not player:is_player() or not hitter:is_player() then
        return
    end

    local player_pvp_setting = player:get_meta():get_string("pvp_enabled")
    local hitter_pvp_setting = hitter:get_meta():get_string("pvp_enabled")

    -- Check if PvP is disabled for either player
    if player_pvp_setting == "false" or hitter_pvp_setting == "false" then
        if minetest.get_modpath("mcl_burning") then
            mcl_burning.extinguish(player)  -- Extinguish the player if they are on fire
        end
        return true  -- Cancel the punch event
    end
end)


-- Initialize PvP setting for each player as they join
minetest.register_on_joinplayer(function(player)
    -- Default to PvP off if not already set
local pvp_setting = player:get_meta():get_string("pvp_enabled")
    if pvp_setting == ""then
        pvp_off(player)
    end
    if pvp_setting == "false" then
        pvp_off(player)
    end
    if pvp_setting == "true" then
        pvp_on(player)
    end
end)

if minetest.get_modpath("mcl_inventory") then
        -- Override the damage handling function
        local original_damage_function = mcl_damage.run_modifiers
        mcl_damage.run_modifiers = function(obj, damage, reason)
            -- Check if obj and reason.source are valid and if the damage is caused by a projectile
            if obj and obj:is_player() and reason.source and reason.source:is_player() then
                -- Check PvP settings for both players
                if not is_pvp_enabled(obj) or not is_pvp_enabled(reason.source) then
                    remove_nearby_arrows(obj, 5)  -- Remove attached arrows to the player
                    mcl_hunger.stop_poison(obj) -- Stop poisoning the player
                    mcl_potions._reset_player_effects(obj) -- Remove all potion effects from the player
                    mcl_burning.extinguish(obj) -- Extinguish the player if they are on fire
                    return 0 -- No damage if PvP is disabled for either player
                end
            end

            -- Call the original damage function for all other cases
            return original_damage_function(obj, damage, reason)
        end

    minetest.log("action", "[PvP Mod] mcl_inventory modpath found. Registering PvP tab.")
    
    mcl_inventory.register_survival_inventory_tab({
        id = "pvp_control",
        description = "PvP Control",
        item_icon = "mcl_tools:sword_diamond",  -- Replace with an appropriate icon
        show_inventory = true,
        build = function(player)
            minetest.log("action", "[PvP Mod] Building PvP formspec for player " .. player:get_player_name())
            local pvp_setting = player:get_meta():get_string("pvp_enabled")
            local button_label = pvp_setting == "true" and "Disable PvP" or "Enable PvP"
            return "label[1,1;PvP Settings]" ..
                   "button[2,2;3,1;toggle_pvp;" .. button_label .. "]"
        end,
        handle = function(player, fields)
            minetest.log("action", "[PvP Mod] PvP tab pressed by" .. player:get_player_name())
            if fields.toggle_pvp then
                minetest.log("action", "[PvP Mod] PvP toggle button pressed by " .. player:get_player_name())
                toggle_pvp(player)
                mcl_inventory.update_inventory(player)  -- Update inventory to refresh the tab
            end
        end,
    })

    minetest.log("action", "[PvP Mod] PvP tab registered.")
else
    minetest.log("error", "[PvP Mod] mcl_inventory modpath not found. PvP tab not registered.")
end

--initialise pad node
minetest.register_node("pvp_control:war_pad", {
	tiles = {war_pad_texture, war_pad_texture .. "^[transformFY"},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
    liquid_range = 0, 
    liquidtype = "source",
    liquid_viscosity = visc,
	legacy_wallmounted = true,
	walkable = true,
	sunlight_propagates = true,
	description = S("PvP WAR pad, set PvP to ON"),
	inventory_image = war_pad_texture,
	wield_image = war_pad_texture,
	light_source = 5,
	groups = {snappy = 3},
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -6/16, 0.5}
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -6/16, 0.5}
	},
})
minetest.register_node("pvp_control:peace_pad", {
	tiles = {peace_pad_texture, peace_pad_texture .. "^[transformFY"},
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
    liquid_range = 0,  
    liquidtype = "source",
    liquid_viscosity = visc,
	legacy_wallmounted = true,
	walkable = true,
	sunlight_propagates = true,
	description = S("PvP PEACE pad, set PvP to OFF"),
	inventory_image = peace_pad_texture,
	wield_image = peace_pad_texture,
	light_source = 5,
	groups = {snappy = 3},
	node_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -6/16, 0.5}
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -6/16, 0.5}
	},

})

-- check pad, amend pvp meta if player above
minetest.register_abm({
	label = "WAR pad",
	nodenames = {"pvp_control:war_pad"},
	interval = intval,
	chance = 1,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)

		-- check objects on pad
		local objs = minetest.get_objects_inside_radius(pos, 1)

		if #objs == 0 then
			return
		end
        for n = 1, #objs do

			if objs[n]:is_player() then
				stepper = objs[n]

                pvp_on(stepper)
				
			end	
	    end
    end
})

-- check pad, amend pvp meta if player above
minetest.register_abm({
	label = "PEACE pad",
	nodenames = {"pvp_control:peace_pad"},
	interval = intval,
	chance = 1,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)

		-- check objects on pad
		local objs = minetest.get_objects_inside_radius(pos, 1)

		if #objs == 0 then
			return
		end
        for n = 1, #objs do

			if objs[n]:is_player() then
				stepper = objs[n]

                pvp_off(stepper)

			end

		end
	end
})

-- Ball Physics Registry
-- Configurable physics ball system for Luanti
local ball_physics = {}
-- Global registry for ball configurations
local ball_registry = {}

-- Default configuration template
local default_config = {
    -- Physics parameters
    physics = {
        mass = 5,
        friction = 0.5,
        gravity_force = 4,
        coefficient_of_restitution = 0.8,
        min_bounce_speed = 0.5,
        surface_resistance = {
            ground = 0.25,
            air = 0.05,
            default = 0.1
        },
        damping = {
            normal_factor = 0.001,
            increased_factor = 0.02,
            speed_threshold = 0.55
        },
        bounce_limits = {
            min = 1.5,
            max = 12
        },
        horizontal_damping = 0.6,
        roll_speed = 1.5,
        push_force = .5,
        punch_force = 10
    },
    
    -- Visual parameters
    visual = {
        mesh = "beachball1.gltf",
        textures = {"beachball.png"},
        visual_size = {x = 8.5, y = 8.5},
        collisionbox = {-0.6, -0.6, -0.6, 0.6, 0.6, 0.6},
        stepheight = 1
    },
    
    -- Sound parameters
    sounds = {
        bounce = "kick",
        water_splash = "kick",
        pickup = nil -- Optional pickup sound
    },
    
    -- Behavior parameters
    behavior = {
        can_be_picked_up = true,
        immortal = true,
        collide_with_objects = true,
        water_float = true,
        player_pushable = true
    },
    
    -- Item parameters
    item = {
        description = "Bouncy Ball",
        inventory_image = "ball_inv.png",
        stack_max = 1
    }
}

-- Utility function to deep copy tables
local function deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deep_copy(orig_key)] = deep_copy(orig_value)
        end
        setmetatable(copy, deep_copy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Utility function to merge configurations
local function merge_config(base, override)
    local result = deep_copy(base)
    
    local function merge_recursive(target, source)
        for key, value in pairs(source) do
            if type(value) == "table" and type(target[key]) == "table" then
                merge_recursive(target[key], value)
            else
                target[key] = value
            end
        end
    end
    
    if override then
        merge_recursive(result, override)
    end
    
    return result
end

-- Validation function for configuration
local function validate_config(config)
    local errors = {}
    
    -- Validate required fields
    if not config.physics then
        table.insert(errors, "Missing physics configuration")
    end
    
    if not config.visual then
        table.insert(errors, "Missing visual configuration")
    end
    
    if not config.visual.mesh then
        table.insert(errors, "Missing mesh file")
    end
    
    if not config.visual.textures or #config.visual.textures == 0 then
        table.insert(errors, "Missing textures")
    end
    
    -- Validate numeric ranges
    if config.physics.mass and config.physics.mass <= 0 then
        table.insert(errors, "Mass must be positive")
    end
    
    if config.physics.coefficient_of_restitution and 
       (config.physics.coefficient_of_restitution < 0 or config.physics.coefficient_of_restitution > 1) then
        table.insert(errors, "Coefficient of restitution must be between 0 and 1")
    end
    
    return #errors == 0, errors
end


-- API function to register a new ball type
function ball_physics.register_ball(name, config_override)
    if not name or name == "" then
        error("Ball name cannot be empty")
    end
    
    if ball_registry[name] then
        minetest.log("warning", "Ball type '" .. name .. "' is being overridden")
    end
    
    -- Merge with default configuration
    local config = merge_config(default_config, config_override)
    
    -- Validate configuration
    local valid, errors = validate_config(config)
    if not valid then
        error("Invalid ball configuration for '" .. name .. "': " .. table.concat(errors, ", "))
    end
    
    -- Store configuration
    ball_registry[name] = config
    
    -- Generate entity and craftitem names
    local entity_name = "ball_physics:" .. name
    local craftitem_name = "ball_physics:" .. name .. "_craftitem"
    
    -- Register the craftitem
    minetest.register_craftitem(craftitem_name, {
        description = config.item.description,
        inventory_image = config.item.inventory_image,
        stack_max = config.item.stack_max,
        on_place = function(itemstack, placer, pointed_thing)
            if pointed_thing.type == "node" then
                local pos = minetest.get_pointed_thing_position(pointed_thing)
                pos.y = pos.y + 2
                minetest.add_entity(pos, entity_name)
                itemstack:take_item()
                return itemstack
            end
        end,
    })
    
    -- Register the entity
    register_ball_entity(entity_name, config)
    
    minetest.log("info", "Registered ball type: " .. name)
    return entity_name, craftitem_name
end

-- API function to get ball configuration
function ball_physics.get_ball_config(name)
    return ball_registry[name] and deep_copy(ball_registry[name]) or nil
end

-- API function to list all registered balls
function ball_physics.list_balls()
    local balls = {}
    for name, _ in pairs(ball_registry) do
        table.insert(balls, name)
    end
    return balls
end

-- Helper function for collision bounce behavior
local function handle_collision_bounce(self, moveresult, pos, config)
    if not moveresult.collides then
        return
    end
    
    local velocity = self.object:get_velocity()
    local horizontal_speed = math.sqrt(velocity.x^2 + velocity.z^2)
    local total_speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
    
    -- Use configured physics parameters
    local ball_mass = config.physics.mass
    local coefficient_of_restitution = config.physics.coefficient_of_restitution
    local min_bounce_speed = config.physics.min_bounce_speed
    
    -- Check if ball has enough energy to bounce
    if total_speed < min_bounce_speed then
        return
    end
    
    -- Determine surface type and resistance
    local surface_resistance = config.physics.surface_resistance.default
    local is_on_ground = false
    
    -- Check if ball is touching ground (collision from below)
    if moveresult.touching_ground then
        is_on_ground = true
        surface_resistance = config.physics.surface_resistance.ground
    else
        -- In air collision (wall/ceiling)
        surface_resistance = config.physics.surface_resistance.air
    end
    
    -- Calculate bounce velocity based on physics
    local kinetic_energy = 0.5 * ball_mass * total_speed^2
    local energy_loss_factor = 1 - surface_resistance
    local remaining_energy = kinetic_energy * energy_loss_factor * coefficient_of_restitution^2
    
    -- Calculate new bounce speed from remaining energy
    local bounce_speed = math.sqrt(2 * remaining_energy / ball_mass)
    
    -- Apply directional bounce based on collision normal
    local bounce_velocity_y = bounce_speed
    
    -- For ground collisions, bounce primarily upward
    if is_on_ground then
        -- Preserve some horizontal momentum but reduce it
        local horizontal_damping = config.physics.horizontal_damping
        bounce_velocity_y = bounce_speed * 0.9 -- Most energy goes upward
        velocity.x = velocity.x * horizontal_damping
        velocity.z = velocity.z * horizontal_damping
    else
        -- For wall/ceiling collisions, distribute energy more evenly
        bounce_velocity_y = bounce_speed * 0.6
    end
    
    -- Apply minimum and maximum bounce limits
    bounce_velocity_y = math.max(bounce_velocity_y, config.physics.bounce_limits.min)
    bounce_velocity_y = math.min(bounce_velocity_y, config.physics.bounce_limits.max)
    
    -- Set the new velocity
    self.object:set_velocity({x = velocity.x, y = bounce_velocity_y, z = velocity.z})
    
    -- Play bounce sound if configured
    if config.sounds.bounce then
        minetest.sound_play(config.sounds.bounce, { pos = pos }, true)
    end
end

-- Helper function for physics application
local function apply_physics(self, dtime, config)
    local velocity = self.object:get_velocity()
    
    -- Apply gravity
    local gravity_force = config.physics.gravity_force
    velocity.y = velocity.y - gravity_force * dtime
    self.object:set_velocity(velocity)
    
    -- Apply damping (rolling friction)
    local horizontal_speed = math.sqrt(velocity.x^2 + velocity.z^2)
    local normal_damping_factor = config.physics.damping.normal_factor
    local speed_threshold = config.physics.damping.speed_threshold
    local increased_damping_factor = config.physics.damping.increased_factor
    
    local damping_factor = normal_damping_factor
    if horizontal_speed < speed_threshold then
        damping_factor = increased_damping_factor
    end
    
    velocity.x = velocity.x * (1 - damping_factor)
    velocity.z = velocity.z * (1 - damping_factor)
    self.object:set_velocity(velocity)
    
    -- Calculate rotation based on rolling motion
    -- The ball should rotate around an axis perpendicular to its direction of travel
    if horizontal_speed > 0.01 then
        -- Calculate the axis of rotation (perpendicular to velocity direction)
        -- For rolling, we rotate around the axis perpendicular to movement
        local rotation = self.object:get_rotation()
        local roll_speed = config.physics.roll_speed
        
        -- Rotation should be perpendicular to direction of travel
        -- If moving in +X, rotate around Z axis (rotation.z changes)
        -- If moving in +Z, rotate around -X axis (rotation.x changes)
        rotation.x = rotation.x - velocity.z * roll_speed * dtime
        rotation.z = rotation.z + velocity.x * roll_speed * dtime
        
        self.object:set_rotation(rotation)
    end
end

-- Helper function for water interaction
local function handle_water_interaction(self, config)
    if not config.behavior.water_float then
        return
    end
    
    local pos = self.object:get_pos()
    local node = minetest.get_node_or_nil({
        x = pos.x,
        y = pos.y + 0,
        z = pos.z
    })
    
    if node and minetest.get_item_group(node.name, "water") ~= 0 then
        self.object:set_velocity({
            x = 0,
            y = 1,
            z = 0
        })
        
        -- Play water splash sound if configured
        if config.sounds.water_splash then
            minetest.sound_play(config.sounds.water_splash, { pos = pos }, true)
        end
    end
end

-- Helper function for player pushing
local function handle_player_pushing(self, config)
    if not config.behavior.player_pushable then
        return
    end
    
    local pos = self.object:get_pos()
    local players_nearby = minetest.get_objects_inside_radius(pos, 2)
    for _, player in ipairs(players_nearby) do
        if player:is_player() then
            local player_dir = player:get_look_dir()
            local push_force = config.physics.push_force
            self.object:add_velocity({
                x = player_dir.x * push_force,
                y = player_dir.y * push_force,
                z = player_dir.z * push_force,
            })
        end
    end
end

-- Helper function for punch behavior
local function handle_punch(self, clicker, config)
    local player_dir = clicker:get_look_dir()
    local push_force = config.physics.punch_force
    self.object:add_velocity({
        x = player_dir.x * push_force,
        y = player_dir.y * push_force,
        z = player_dir.z * push_force,
    })
end

-- Helper function for right-click behavior
local function handle_rightclick(self, clicker, config, craftitem_name)
    if not config.behavior.can_be_picked_up then
        return
    end
    
    if clicker and clicker:is_player() then
        local inv = clicker:get_inventory()
        if inv:room_for_item("main", craftitem_name) then
            inv:add_item("main", craftitem_name)
            
            -- Play pickup sound if configured
            if config.sounds.pickup then
                minetest.sound_play(config.sounds.pickup, { pos = self.object:get_pos() }, true)
            end
            
            self.object:remove()
        else
            minetest.chat_send_player(clicker:get_player_name(), "Your inventory is full.")
        end
    end
end

-- Function to register ball entity with configuration
function register_ball_entity(entity_name, config)
    local craftitem_name = entity_name .. "_craftitem"
    
    minetest.register_entity(entity_name, {
        initial_properties = {
            physical = true,
            collide_with_objects = config.behavior.collide_with_objects,
            visual_size = config.visual.visual_size,
            collisionbox = config.visual.collisionbox,
            stepheight = config.visual.stepheight,
            visual = "mesh",
            mesh = config.visual.mesh,
            textures = config.visual.textures,
        },
        
        -- Store configuration in entity
        _config = config,
        
        on_activate = function(self, staticdata)
            self.object:set_properties({
                mass = config.physics.mass,
                friction = config.physics.friction,
            })
            
            if config.behavior.immortal then
                self.object:set_armor_groups({immortal = 1})
            end
        end,
        
        on_punch = function(self, clicker)
            handle_punch(self, clicker, config)
        end,
        
        on_rightclick = function(self, clicker)
            handle_rightclick(self, clicker, config, craftitem_name)
        end,
        
        on_step = function(self, dtime, moveresult)
            local pos = self.object:get_pos()
            
            -- Handle collision bouncing
            handle_collision_bounce(self, moveresult, pos, config)
            
            -- Apply physics
            apply_physics(self, dtime, config)
            
            -- Handle water interaction
            handle_water_interaction(self, config)
            
            -- Handle player pushing
            handle_player_pushing(self, config)
        end,
    })
end

-- Register the default rolling ball using the new API
ball_physics.register_ball("rolling_ball", {
    item = {
        description = "Bouncy Ball",
        inventory_image = "beachball.png"
    }
})

-- Example: Register additional ball types with different configurations
ball_physics.register_ball("super_bouncy_ball", {
    physics = {
        coefficient_of_restitution = 0.95,
        bounce_limits = {
            min = 3.0,
            max = 20
        }
    },
    item = {
        description = "Super Bouncy Ball",
        inventory_image = "red-radial.png"
    },
    sounds = {
        bounce = "kick",
        water_splash = "kick"
    },
    visual = {
        mesh = "ball.obj", 
        textures = {"red-radial.png"}, 
        visual_size = {x = 1, y = 1},
        collisionbox = {-.8, -.8, -.8, .8, .8, .8}
    },
})

ball_physics.register_ball("heavy_ball", {
    physics = {
        mass = 15,
        gravity_force = 1,
        coefficient_of_restitution = 0.4,
        damping = {
            normal_factor = 0.005,
            increased_factor = 0.05,
            speed_threshold = 0.3
        }
    },
    visual = {
        mesh = "beachball1.gltf",
        textures = {"beachball.png"},
        visual_size = {x = 17.5, y = 17.5},
        collisionbox = {-.8, -.8, -.8, .8, .8, .8}
    },
    item = {
        description = "Heavy Ball",
        inventory_image = "beachball.png"
    }
})

local modpath = minetest.get_modpath("ball_physics")

-- Register the soccer goal item (WIP)
minetest.register_node("ball_physics:soccer_goal", {
    description = "Soccer Goal",
    tiles = {"net.png"},
    use_texture_alpha = "clip",
    drawtype = "mesh",
    mesh = "soccerGoalPhysics.obj",
    paramtype = "light",
    paramtype2 = "facedir",
    sunlight_propagates = true,
    visual_scale = 1.0,
    visual_size = {x = 1.0, y = 1.0, z = 1.0},
    
    collision_box = {
        type = "fixed",
        fixed = {
            -- Main goal frame (hollow)
            {-1.0, -0.5, 1.9, -0.85, 2.5, 2.0},   -- Left post
            {0.85, -0.5, 1.9, 1.0, 2.5, 2.0},     -- Right post
            {-1.0, 2.35, 1.9, 1.0, 2.5, 2.0},     -- Crossbar
            
            -- Ground base for stability
            {-1.0, -0.5, 1.9, 1.0, -0.4, 2.0},    -- Base
            
            -- Back netting support (optional, adjust based on your mesh)
            {-1.0, -0.5, -0.1, -0.95, 2.5, 2.0},  -- Left back post
            {0.95, -0.5, -0.1, 1.0, 2.5, 2.0},    -- Right back post
        }
    },
    
    selection_box = {
        type = "fixed",
        fixed = {
            -- Main goal frame (hollow)
            {-1.0, -0.5, 1.9, -0.85, 2.5, 2.0},   -- Left post
            {0.85, -0.5, 1.9, 1.0, 2.5, 2.0},     -- Right post
            {-1.0, 2.35, 1.9, 1.0, 2.5, 2.0},     -- Crossbar
            
            -- Ground base for stability
            {-1.0, -0.5, 1.9, 1.0, -0.4, 2.0},    -- Base
            
            -- Back netting support (optional, adjust based on your mesh)
            {-1.0, -0.5, -0.1, -0.95, 2.5, 2.0},  -- Left back post
            {0.95, -0.5, -0.1, 1.0, 2.5, 2.0},    -- Right back post
        }
    },
    
    groups = {cracky = 3, oddly_breakable_by_hand = 1},
    
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then
            return itemstack
        end
        
        -- Get player's look direction for horizontal placement
        local placer_dir = placer:get_look_dir()
        local fdir = minetest.dir_to_facedir(placer_dir)
        
        -- Place the node with the calculated facedir
        return minetest.item_place(itemstack, placer, pointed_thing, fdir)
    end
})

print("[ball_physics] Soccer goal registered!")

-- Basic crafting recipes for the balls
-- Rolling Ball recipe - simple and cheap
minetest.register_craft({
    output = "ball_physics:rolling_ball_craftitem",
    recipe = {
        {"", "default:paper", ""},
        {"default:paper", "default:coal_lump", "default:paper"},
        {"", "default:paper", ""}
    }
})

-- Super Bouncy Ball recipe
minetest.register_craft({
    output = "ball_physics:super_bouncy_ball_craftitem",
    recipe = {
        {"", "default:mese_crystal_fragment", ""},
        {"default:mese_crystal_fragment", "default:diamond", "default:mese_crystal_fragment"},
        {"", "default:mese_crystal_fragment", ""}
    }
})

-- Heavy Ball recipe - uses heavy materials
minetest.register_craft({
    output = "ball_physics:heavy_ball_craftitem",
    recipe = {
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:obsidian", "default:steel_ingot"},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
    }
})

-- Alternative recipe for Rolling Ball using wool (if available)
minetest.register_craft({
    output = "ball_physics:rolling_ball_craftitem",
    recipe = {
        {"", "wool:white", ""},
        {"wool:white", "default:stick", "wool:white"},
        {"", "wool:white", ""}
    }
})

-- Soccer Goal crafting recipe
minetest.register_craft({
    output = "ball_physics:soccer_goal",
    recipe = {
        {"default:stick", "default:stick", "default:stick"},
        {"default:stick", "", "default:stick"},
        {"default:stick", "default:paper", "default:stick"}
    }
})

print("[ball_physics] Soccer goal registered!")

-- Basic crafting recipes for the balls
-- Rolling Ball recipe - simple and cheap
minetest.register_craft({
    output = "ball_physics:rolling_ball_craftitem",
    recipe = {
        {"", "mcl_core:paper", ""},
        {"mcl_core:paper", "mcl_core:coal_lump", "mcl_core:paper"},
        {"", "mcl_core:paper", ""}
    }
})

-- Super Bouncy Ball recipe - requires rubber/slime materials
minetest.register_craft({
    output = "ball_physics:super_bouncy_ball_craftitem",
    recipe = {
        {"", "mcl_mobitems:slimeball", ""},
        {"mcl_mobitems:slimeball", "mcl_core:diamond", "mcl_mobitems:slimeball"},
        {"", "mcl_mobitems:slimeball", ""}
    }
})

-- Heavy Ball recipe - uses heavy materials
minetest.register_craft({
    output = "ball_physics:heavy_ball_craftitem",
    recipe = {
        {"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"},
        {"mcl_core:iron_ingot", "mcl_core:obsidian", "mcl_core:iron_ingot"},
        {"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"}
    }
})

-- Soccer Goal crafting recipe
minetest.register_craft({
    output = "ball_physics:soccer_goal",
    recipe = {
        {"mcl_core:stick", "mcl_core:stick", "mcl_core:stick"},
        {"mcl_core:stick", "", "mcl_core:stick"},
        {"mcl_core:stick", "mcl_core:paper", "mcl_core:stick"}
    }
})

print("[ball_physics] Crafting recipes registered!")

-- Log sccessful initialization
minetest.log("info", "Balls API initialized with " .. #ball_physics.list_balls() .. " ball types")

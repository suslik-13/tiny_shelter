mobs_balrog = fmod.create()

mobs_balrog.settings.whip_tool_capabilities = {
	full_punch_interval = 1,
	max_drop_level = 3,
	damage_groups = {
		fleshy = mobs_balrog.settings.fleshy_damage,
		fire = mobs_balrog.settings.fire_damage,
	},
}

mobs_balrog.settings.fire_tool_capabilities = {
	full_punch_interval = 1,
	max_drop_level = 3,
	damage_groups = {
		fire = mobs_balrog.settings.fire_damage,
	},
}



balrog_not_died = true
-- Позиция для спавна балрога
local spawn_pos = {x = -61.0, y = -43.0, z = -319.0}

-- Интервал между спавнами в секундах
initial_spawn_interval = 1
spawn_after_kill_interval = 3600
half_hour_after_kill = 1800
twenty_minutes_after_half_hour = 1200
five_minutes = 300
spawn_interval = initial_spawn_interval

-- функция для проверки наличия мобов и удаления лишних
function check_and_remove_mobs()
  local pos = spawn_pos
  local mob_name = "mobs_balrog:balrog"
  local radius = 70	
  local objects = minetest.get_objects_inside_radius(pos, radius)
  local count = 0
  local target_mob = nil
  for _, obj in ipairs(objects) do
    if obj and obj:get_luaentity() and obj:get_luaentity().name == mob_name then
      count = count + 1
      if not target_mob then
        target_mob = obj
      else
        obj:remove()
      end
    end
  end
  return count, target_mob
end


-- Спавнит балрога на заданной позиции
local function spawn_balrog()
    local existing_balrog = minetest.get_objects_inside_radius(spawn_pos, 100)
    local found_balrog = false
    for _, obj in ipairs(existing_balrog) do
        if obj:get_luaentity() and obj:get_luaentity().name == "mobs_balrog:balrog" then	
            check_and_remove_mobs()
            found_balrog = true
            break
        end
    end
    
    if not found_balrog and balrog_not_died then
        minetest.add_entity(spawn_pos, "mobs_balrog:balrog")
    end	
end

-- Спавним первого балрога при запуске игры
minetest.after(0, spawn_balrog)

-- Спавним балрога периодически
minetest.register_globalstep(function(dtime)
    spawn_interval = spawn_interval - dtime
    if spawn_interval <= 0 then
        spawn_balrog()
        spawn_interval = initial_spawn_interval
    end
end)





mobs_balrog.dofile("api", "init")
mobs_balrog.dofile("entity")
mobs_balrog.dofile("spawn")
mobs_balrog.dofile("whip")

if mobs_balrog.settings.flame_node == "mobs_balrog:flame" then
	mobs_balrog.dofile("flame_node")
end

mobs_balrog.dofile("compat", "init")

mobs_balrog.dofile("aliases")

if mobs_balrog.settings.debug then
	mobs_balrog.dofile("debug")
end

-- Инициализация нового предмета "Розовый пельмень"
minetest.register_craftitem("pink_pelmen:pink_pelmen", {
    description = "Pink Pelmen",
    inventory_image = "pink_pelmen.png",
    wield_scale = { x = 2, y = 2, z = 1 },
    on_use = function(itemstack, user, pointed_thing)
        if not user then
            return
        end

        minetest.sound_play('x_obsidianmese_apple_eat', {
            pos = user:get_pos(),
            max_hear_distance = 32,
            gain = 0.5,
        })

        user:set_hp(20)
        itemstack:take_item()
        return itemstack
    end
})

-- Регистрация крафта для создания "Розового пельменя"
minetest.register_craft({
    output = "pink_pelmen:pink_pelmen",
    recipe = {
        {"group:food_flour", "dye:pink", "group:food_flour"},
        {"group:food_flour", "mobs:meatblock_raw", "group:food_flour"},
        {"group:food_flour", "group:food_flour", "group:food_flour"},
    },
})

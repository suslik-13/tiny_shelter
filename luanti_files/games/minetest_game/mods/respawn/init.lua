-- Функция для возрождения игрока
local function respawn_player(player)
    player:respawn()
    minetest.chat_send_player(player:get_player_name(), "You are respawned!")
end

-- Добавляем команду для возрождения игрока
minetest.register_chatcommand("respawn", {
    description = "Player respawn",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if player then
            respawn_player(player)
        end
    end,
})


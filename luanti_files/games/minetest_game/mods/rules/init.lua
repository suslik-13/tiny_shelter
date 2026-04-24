-- Сообщение с правилами
local rules_text = "\nPROTECTION BLOCK CRAFT CHANGED!\nNow use gold ingot instead of mese crystal.\n\nWelcome to tiny SHELTER! / Добро пожаловать на tiny SHELTER! \n\nSome rules that are important to follow for a comfortable game:\nНекоторые правила которые важно соблюдать для комфортной игры:\n1. Do not insult or bully / Не оскорблять и не устраивать травлю\n2. Do not spoil other people’s buildings, do not build on top of others / Не портить чужие постройки, не строить над другими\n3. PVP is disabled in protected areas / ПВП отключен на защищенных территориях\n4. Do not create traps using teleports / Не создавать ловушки с использованием телепортов\n5. Do not hack, do not exploit bugs, do not cheat / Не взламывать, не багоюзить, не читирить\n6. Do not talk about politics or adult topics / Не говорить о политике и на взрослые темы\n7. Our discord: https://discord.gg/JUFdNDWAcu - наш дискорд\n"

-- Функция для показа сообщения с правилами
local function showRules(player_name)
    player = minetest.get_player_by_name(player_name)
    if player:get_hp() > 0 then
        local formspec = "size[8,5]" ..
                     "textarea[0.3,0.5;7.5,4.5;rules_text;;" .. rules_text .. "]" ..
                     "button_exit[3.5,4.5;1,1;ok_button;ОК]"

        minetest.show_formspec(player_name, "rules:rules_form", formspec)    
    end
end
-- Регистрация специальной команды для показа правил
minetest.register_chatcommand("rules", {
    description = "Показать правила сервера",
    func = function(name)
        showRules(name)
    end,
})

-- Реакция на нажатие кнопки "ОК"
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "rules:rules_form" and fields.ok_button then
        return true
    end
end)

-- Функция, которая показывает правила при входе пользователя
minetest.register_on_joinplayer(function(player)
    showRules(player:get_player_name())
end)


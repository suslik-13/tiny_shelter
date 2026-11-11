-- Placeholders: {victim} = dead player's name, {killer} = player/mob name.
-- Substitution is done in a single pass, so digits or braces inside player
-- names are never treated as placeholders.

-- Fall damage
local fall = {
    '** {victim} hit the ground too hard **',
    '** {victim} jumped off a cliff **',
    '** {victim} forgot about fall damage **',
    "** {victim} fell and couldn't get back up **",
    '** {victim} believed they could fly **',
    '** {victim} took the express elevator down **',
    '** {victim} discovered gravity the hard way **',
    '** {victim} tested the ground. The ground won **',
    '** {victim} forgot to pack a parachute **',
    '** {victim} left a {victim}-shaped dent in the ground **',
    '** {victim} tried a triple backflip. Landed zero of them **',
    '** {victim} skipped the stairs. All of them **',
    '** {victim} missed the water bucket clutch **',
    '** {victim} mistook the edge for a shortcut **',
    '** {victim} was too eager to reach bedrock **',
    "** {victim}'s knees have filed a formal complaint **",
    '** {victim} found out how deep that hole really was **',
    '** {victim} attempted a speedrun to the ground floor **',
    '** {victim} learned that Newton was right **',
    '** {victim} stepped off the tower to "take a shortcut home" **',
    '** {victim} fell for it. Literally **',
    '** {victim} rolled a natural 1 on Acrobatics **',
    '** {victim} wanted to feel the wind one last time **',
    '** {victim} hugged the floor a bit too passionately **',
}

-- Burning in fire
local burn = {
    '** {victim} burned to a crisp **',
    '** {victim} got a little too warm **',
    '** {victim} got too close to the camp fire **',
    '** {victim} got nuked **',
    '** {victim} became a well-done steak **',
    '** {victim} tried to roast marshmallows without a stick **',
    '** {victim} is now available as charcoal **',
    '** {victim} found out fire is not a decorative block **',
    '** {victim} warmed their hands. And everything else **',
    '** {victim} was cooked medium rare **',
    '** {victim} played with fire. Mom was right **',
    '** {victim} tried to put out the fire with their face **',
    '** {victim} turned into a very short-lived torch **',
    '** {victim} became the barbecue **',
    '** {victim} was hot. Briefly **',
    '** {victim} asked for extra crispy **',
    '** {victim} discovered the forbidden sauna **',
    '** {victim} believed they were fireproof. They were not **',
    '** {victim} set a new personal heat record **',
    '** {victim} burned all bridges. And themselves **',
    '** {victim} went up in smoke **',
    '** {victim} is now smoked meat **',
    '** {victim} tried to hug a campfire **',
    '** {victim} lit up the night. Permanently **',
}

-- Drowning
local drown = {
    '** {victim} drowned **',
    '** {victim} ran out of air **',
    '** {victim} tried to impersonate an anchor **',
    "** {victim} forgot they weren't a fish **",
    '** {victim} forgot how breathing works **',
    '** {victim} held their breath for a new world record. Fatally **',
    '** {victim} went looking for Atlantis **',
    '** {victim} is now sleeping with the fishes **',
    '** {victim} tried to breathe water. 0/10, would not recommend **',
    '** {victim} never finished their swimming lessons **',
    '** {victim} swam a little too deep for that one shipwreck **',
    '** {victim} mistook the bubble bar for a decoration **',
    '** {victim} became fish food **',
    '** {victim} took a very long bath **',
    '** {victim} went diving without a helmet **',
    '** {victim} drank the whole ocean. Almost **',
    '** {victim} tried to grow gills by willpower **',
    '** {victim} sank like a stone, because they were holding one **',
    '** {victim} did not find the surface in time **',
    '** {victim} tried to count all the fish **',
    '** {victim} swam with full iron armor on **',
    '** {victim} has been promoted to submarine **',
    '** {victim} went for a swim. The swim went for {victim} **',
    '** {victim} found the bottom of the lake **',
}

-- Burning in lava
local lava = {
    '** {victim} thought lava was cool **',
    '** {victim} tried to swim in lava **',
    '** {victim} melted in lava **',
    '** {victim} fell whilst trying to reach that last diamond **',
    '** {victim} took a hot bath. Very hot **',
    '** {victim} mistook lava for orange juice **',
    '** {victim} dug straight down. Classic **',
    '** {victim} and all their loot are now part of the lava lake **',
    '** {victim} tried to collect lava without a bucket **',
    '** {victim} became a smelting ingredient **',
    '** {victim} went to check if lava is really that hot. It is **',
    '** {victim} turned into obsidian (not really, but it looked like it) **',
    '** {victim} tried to surf a lava wave **',
    '** {victim} wanted a magma tan **',
    '** {victim} fell into the planet\'s core. Partially **',
    '** {victim} upgraded the lava lake with fresh meat **',
    '** {victim} heard that the lava floor is good for the skin **',
    '** {victim} played "the floor is lava" for real **',
    '** {victim} poured lava, but forgot where **',
    '** {victim} melted faster than ice cream in summer **',
    '** {victim} tried to fuel a furnace with themselves **',
    '** {victim} bravely mined the block holding back the lava **',
    "** {victim}'s diamond pickaxe will be remembered **",
    '** {victim} just wanted to see the glowing orange stuff up close **',
}

-- Killed by other player
local pvp = {
    '** {victim} was slain by {killer} **',
    '** {victim} was killed by {killer} **',
    '** {victim} was put to the sword by {killer} **',
    '** {victim} lost a PVP battle to {killer} **',
    '** {victim} got schooled by {killer} **',
    '** {victim} brought fists to a {killer} fight **',
    '** {victim} said "come at me" and {killer} did **',
    '** {victim} was unfriended by {killer}. Violently **',
    '** {killer} sent {victim} back to spawn **',
    '** {victim} was rearranged by {killer} **',
    '** {victim} became the latest entry in {killer}\'s diary **',
    '** {victim} lost an argument with {killer} **',
    '** {killer} taught {victim} a valuable lesson **',
    '** {victim} and {killer} had an epic duel. {killer} won this time **',
    '** {victim} trusted {killer}. Big mistake **',
    '** {victim} was given a free respawn by {killer} **',
    '** {killer} pressed the "delete {victim}" button **',
    '** {victim} tried to trade with {killer}. {killer} declined **',
    '** {victim} looked at {killer} funny **',
    '** {victim} has been yeeted by {killer} **',
    '** {killer} turned {victim} into a loot pinata **',
    '** {victim} lagged. {killer} did not **',
    '** {victim} said "gg ez" too early. {killer} disagreed **',
    "** {victim} will need a moment to think about what {killer} did **",
}

-- Killed by mob
local mob = {
    '** {victim} was slain by {killer} **',
    '** {victim} was killed by {killer} **',
    "** {victim} got on {killer}'s last nerve **",
    '** {victim} forgot to feed {killer} **',
    '** {victim} tried to pet {killer} **',
    '** {victim} became a snack for {killer} **',
    '** {victim} lost a staring contest to {killer} **',
    '** {victim} was hugged a little too hard by {killer} **',
    '** {victim} underestimated {killer} **',
    '** {victim} asked {killer} for directions **',
    '** {victim} tried to tame {killer} with bare hands **',
    '** {killer} did not like {victim}\'s haircut **',
    '** {victim} wanted to make friends with {killer}. {killer} did not **',
    '** {victim} was ambushed by a sneaky {killer} **',
    '** {killer} added {victim} to its collection **',
    '** {victim} tried to negotiate with {killer} **',
    '** {victim} provoked {killer}. Bad idea **',
    '** {victim} stepped on {killer}\'s tail **',
    '** {victim} was mistaken for dinner by {killer} **',
    '** {killer} wins this round against {victim} **',
    '** {victim} turned their back on {killer} **',
    '** {victim} was clearly the side quest for {killer} **',
    '** {victim} found out what {killer} drops. The hard way **',
    '** {victim} hoped {killer} was passive **',
}

-- Everything else
local other = {
    '** {victim} died **',
    '** {victim} gave up on life **',
    '** {victim} passed out - permanently **',
    '** {victim} did something fatal **',
    '** {victim} has left the game. Of life **',
    '** {victim} pressed the wrong button **',
    '** {victim} died of mysterious causes **',
    '** {victim} ran out of hit points and excuses **',
    '** {victim} has respawned in the cosmic queue **',
    '** {victim} forgot to eat, sleep and survive **',
    '** {victim} died. Nobody knows why. Not even {victim} **',
    '** {victim} took a quick trip to the respawn point **',
    '** {victim} took an unscheduled nap. Forever-ish **',
    '** {victim} became an ex-player (until respawn) **',
    '** {victim} died doing what they loved: adventuring **',
    '** {victim} has been garbage collected **',
    '** {victim} divided by zero **',
    '** {victim} encountered an unhandled exception **',
    '** {victim} read the terms and conditions **',
    '** {victim} angered the RNG gods **',
    '** {victim} got 404: health not found **',
    '** {victim} lost to the game mechanics **',
    '** {victim} will be back in a moment, stronger than ever **',
    "** {victim} is now a very sad pile of loot **",
}

-- Human-readable name of a killer object (player or entity)
local function get_killer_name(killer)
    if killer:is_player() then
        return killer:get_player_name()
    end

    local ent = killer:get_luaentity()
    if not ent then
        return 'something'
    end

    -- Mobs with a custom nametag
    if type(ent.nametag) == 'string' and ent.nametag ~= '' then
        return ent.nametag
    end

    -- "mymod:enemy_boss" -> "enemy boss"
    local entity_name = ent.name or 'something'
    entity_name = entity_name:gsub('^[^:]*:', '')
    entity_name = entity_name:gsub('_', ' ')
    return entity_name
end

local function send_death_message(cause, victim, killer)
    local meta = victim:get_meta()
    local show_death_messages = meta:get_string('show_death_messages')

    if show_death_messages == '' or show_death_messages == 'yes' then
        local values = {
            victim = victim:get_player_name(),
            killer = killer and get_killer_name(killer) or 'something',
        }

        local template = cause[math.random(#cause)]
        -- Function replacement: one pass, no "%" pattern issues in names
        local death_message = template:gsub('{(%a+)}', function(key)
            return values[key]
        end)

        minetest.chat_send_all(minetest.colorize("red", death_message))
    end
end

minetest.register_on_dieplayer(function(player, reason)
    if reason.object then
        if reason.object:is_player() then
            -- Player was killed by player
            send_death_message(pvp, player, reason.object)

        else
            -- Player was killed by mob
            send_death_message(mob, player, reason.object)

        end
    else
        if reason.type == 'fall' then
            -- Player was killed by fall damage
            send_death_message(fall, player)

        elseif reason.type == 'drown' then
            -- Player drowned
            send_death_message(drown, player)

        elseif reason.type == 'node_damage' and reason.node then
            if string.match(reason.node, 'lava') then
                -- Player burned in lava
                send_death_message(lava, player)

            elseif string.match(reason.node, 'fire') then
                -- Player burned in fire
                send_death_message(burn, player)

            else
                -- Reason not detected, send general death message
                send_death_message(other, player)
            end
        else
            send_death_message(other, player)
        end
    end
end)

minetest.register_chatcommand('toggle_death_messages', {
    description = 'Toggles death messages appearing in chat when you die',
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, 'You must be online to use this command'
        end

        local meta = player:get_meta()
        local show_death_messages = meta:get_string('show_death_messages')

        if show_death_messages == '' or show_death_messages == 'yes' then
            -- Turn death messages off
            meta:set_string('show_death_messages', 'no')
            minetest.chat_send_player(name, minetest.colorize('green', 'You will no longer send death messages'))
            minetest.log('action', name .. ' disabled their death messages')

        else
            -- Turn death messages on
            meta:set_string('show_death_messages', 'yes')
            minetest.chat_send_player(name, minetest.colorize('green', 'You will now send death messages'))
            minetest.log('action', name .. ' enabled their death messages')
        end
    end
})

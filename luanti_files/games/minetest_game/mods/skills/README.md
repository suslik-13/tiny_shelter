# Skills

This Minetest library allows you to create skills, such as a super-high jump, a damaging aura, or passive stat boosts. These skills can be used to enhance gameplay or add new features to your mod.

<a name="registering"></a>

## Registering a skill
To register a skill, you can use the skills.register_skill(internal_name, def) function. The internal_name argument is the name you will use to refer to the skill in your code, and should be formatted as "unique_prefix:skill_name" (where the unique prefix could be the name of your mod, for example). The def argument is a definition table that contains various properties that define the behavior and appearance of the skill and can cotain the following properties:
- **name** (string): the skill's name;
- **description** (string): the skill's description;
- **cooldown** (number): in seconds. It's the minimum amount of time to wait in order to cast the skill again;
- **cast(self, args)**: it contains the skill's logic. It'll return false if the player is offline or the cooldown has not finished. The self parameter is a table containing [properties of the skill](#final_skill_table);
- **loop_params** (table): if this is defined, the skill will be looped. To cast a looped skill you need to use the `start(args)` function instead of `cast`. The `start` function simply calls the `cast` function at a rate of `cast_rate` seconds  (if cast_rate is defined, otherwise the skill's logic will never be executed);
    - **cast_rate** (number): in seconds. The rate at which the skill will be casted. Assigning 0 will loop it as fast as it can;
    - **duration** (number): in seconds. The amount of time after which the skill will stop;
- **passive** (boolean): false by default. If true the skill will start (calling the `on_start` callback) automatically once the player has unlocked it. It can be stopped calling `stop()` or [`disable()`](#final_skill_table) (both of which will call the `on_stop` callback) and restarted calling `start()` or [`enable()`](#other_functions) (both of which will call the `on_start` callback);
- **blocks_other_skills** (boolean): false by default. Whether this skills has to disable all of the other skills while used;
- **can_be_blocked_by_other_skills** (boolean): true by default. Whether this skill will be disabled by other blocking skills (you may want to use this for a passive skill that just increases health, for example);
- **physics** (table): this table can contain any [physics property](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7069)'s field and must contain an `operation` field having one of the following values: `add`, `sub`, `multiply`, `divide` (e.g. {operation = "add", speed = 1} will add 1 to the player's speed).  
- **sounds** (table; every sound is declared this way: `{name = "sound_name"[, to_player = true, object = true, other sound parameters/SoundSpec properties...]}`. If `to_player` or `object` are set to true their value will become the player's name:
    - **cast** (table): a sound that is reproduced every time the `cast` function is called;
    - **start** (table): a sound that is reproduced when the skill starts;
    - **stop** (table): a sound that is reproduced when the    skill stops;
    - **bgm** (table): a looped sound that is reproduced while the skill is being used;
- **hud** (`{{name = "hud_name", hud definition...}, ...}`): a list of hud elements that appear while the skill is being used. They are stored in the `data._hud` table (`{"hud_name" = hud_id}`);
- **attachments** (table):
    - **particles** (`{ParticleSpawner1, ...}`): a list of particle spawners that are created when the skill starts and destroyed when it stops. They're stored in the `data._particles` table and are always attached to the player - it's useful if you want to have something like a particles trail;
    - **entities** (`{{pos = {...}, name = "Entity1" [, bone = "bone", rotation = {...}, forced_visible = false]}, ...}`): a list of entities that are attacched to the player as long as the skill is being used. The staticdata passed to the entity's `on_activate` callback is the player name and it's automatically stored in the entity's `pl_name` property;
- **celestial_vault** (table) if one of these is defined, while the skill is being casted the celestial vault will change:
    - **sky** (table): [accepted parameters](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7134);
    - **moon** (table): [accepted parameters](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7215);
    - **sun** (table): [accepted parameters](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7199);
    - **stars** (table): [accepted parameters](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7229);
    - **clouds** (table): [accepted parameters](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7248);
- **on_start(args)**: this is called when `start` is called and `args` is the same value you pass to the latter;
- **on_stop()**: this is called when `stop` is called;
- **data** (table): this allows you to define custom properties for each player. These properties are stored in the mod storage and will not be reset when the server shuts down unless you change the type of one of them in the registration table. Be careful to avoid using names for these properties that start with an underscore (_);
- **... any other properties you may need**: you can also define your own properties, just make sure that they don't exist already and remember that this are shared by all players.

Here some examples of how to register a skill:
<details>
<summary>click to expand...</summary>

```lua
skills.register_skill("example_mod:counter", {
    name = "Counter",
    description = "Counts. You can use it every 2s.",
    sounds = {
        cast = {name = "ding", pitch = 2}
    },
    cooldown = 2,
    data = {
        counter = 0
    },
    cast = function(self)
        self.data.counter = self.data.counter + 1
        print(self.pl_name .. " is counting: " .. self.data.counter)
    end
})
```

```lua
skills.register_skill("example_mod:heal_over_time", {
    name = "Heal Over Time",
    description = "Restores a heart every 3 seconds for 30 seconds.",
    loop_params = {
        cast_rate = 3,
        duration = 30
    },
    sounds = {
        cast = {name = "heart_added"},
        bgm = {name = "angelic_music"}
    },
    cast = function(self)
        local player = self.player
        player:set_hp(player:get_hp() + 2)
    end
})
```

```lua
skills.register_skill("example_mod:boost_physics", {
    name = "Boost Physics",
    description = "Multiplies the speed and the gravity x1.5 for 3 seconds.",
    loop_params = {
        duration = 3
    },
    sounds = {
        start = {name = "speed_up"},
        stop = {name = "speed_down"}
    },
    physics = {
        operation = "multiply",
        speed = 1.5,
        gravity = 1.5
    }
})
```

```lua
skills.register_skill("example_mod:set_speed", {
    name = "Set Speed",
    description = "Sets speed to 3.",
    passive = true,
    data = {
        original_speed = {}
    },
    on_start = function(self)
        local player = self.player
        self.data.original_speed = player:get_physics_override().speed

        player:set_physics_override({speed = 3})
    end,
    on_stop = function(self)
        self.player:set_physics_override({speed = self.data.original_speed})
    end
})
```
</details>


### Skill based on other skills
A skill based on another skill is a modified version that retains some of the original skill's properties, while keeping others the same. You can register one by using `skills.register_skill_based_on("example_mod:original_skill_name", "example_mod:variant_skill_name", def)`. The definition table allows you to override any properties of the original skill that you want to change in the new skill (any non-specified properties will be inherited from the original). If you want to override one of the properties with a `nil` value just set it to `"@@nil"`.

Here's an example:
<details>
<summary>click to expand...</summary>

```lua
skills.register_skill_based_on("fbrawl:acid_spray", "fbrawl:confetti_spray", {
	name = "Confetti Spray",
	attachments = {
		particles = {{ texture = { name = "fbrawl_confetti_particle.png" } }}
	},
	data = {
		damage_multiplier = 3.5,
	},
	cooldown = 10,
    nodes_to_corrode = "@@nil", -- we don't want our confetti spray to corrode things
	loop_params = {
		duration = 2.5
	}
})
```
</details>


## Assigning a skill
To unlock or remove a skill from a player just use `skills.unlock_skill/remove_skill(pl_name, skill_name)` function. You can also use the shorter form:
```lua
local pl_name = "giov4"
pl_name:unlock_skill("example_mod:counter")
pl_name:remove_skill("example_mod:counter")
```

## Using a skill
To use a player's skill you can use the short method or the long one: for the short one use `pl_name:cast_skill/start_skill/stop_skill("skill_name"[, args])` (if the player can't use it, because they didn't unlock it, these will return false); 

for the long one, you first have to get the player's skill table, using `skills.get_skill(pl_name, "skill_name")` or `pl_name:get_skill("skill_name")` (as before, if the player can't use it, it'll return false).

<a name="final_skill_table"></a>

The function will return the player's skill table, composed of the [definition properties](#registering) + the following new properties:
- **disable()**: to disable the skill: when disabled the `cast` and `start` functions won't work;
- **enable()**: to enable the skill;
- **data._enabled** (boolean): true if the skill is enabled;
- **internal_name** (string): the name used to refer to the skill in the code; 
- **cooldown_timer** (number): the time left until the end of the cooldown;
- **is_active** (boolean): true if the skill is active;
- **pl_name**: the name of the player using this skill;
- **player**: the ObjectRef of the player using this skill.

Once you have it, just call `skill_table:cast([args])` or `skill_table:start([args])` to cast the skill. To stop it use `skill_table:stop()`.


## Utils function

### Skills
- **skills.register_on_unlock(function(skill_table), [prefix])**: this is called everytime a player unlocks a skill having the specified prefix; if the prefix isn't specified the function will be called everytime a player unlocks a skill;
- **skills.disable/enable_skill(pl_name, skill_name) / pl_name:enable/disable_skill(skill_name)**: short methods to enable or disable a skill; 
- **skills.get_skill_def(skill_name)**: returns the skill's definition table;
- **skills.does_skill_exist(skill_name)**: to check if a skill exists (not case-sensitive);
- **skills.get_registered_skills([prefix])**: returns the registered skills; if a prefix is specified, only the skills having that prefix will be listed (`{"prefix1:skill1" = {def}}`); 
- **skills.get_unlocked_skills(pl_name, [prefix]) / pl_name:get_unlocked_skills(prefix)**: returns the unlocked skills; if a prefix is specified, only the skills having that prefix will be listed (`{"prefix1:skill1" = {def}}`); 
- **skills.has_skill(pl_name, skill_name) / pl_name:has_skill(skill_name)**: returns true if the player has the skill.

### Player
- **skills.add/sub/multiply/divide_physics(pl_name, property, value) / pl_name:add/sub/multiply/divide_physics(property, value)**: add/subtract/multiply/divide `value` from the `property` [physics property](https://github.com/minetest/minetest/blob/stable-5/doc/lua_api.txt#L7069) (e.g. pl_name:add_physics("speed", 1));

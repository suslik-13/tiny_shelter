--[[
    Log Spikes — adds log spikes to Minetest
    Copyright © 2021‒2023, Silver Sandstone <@SilverSandstone@craftodon.social>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
]]


--- Public API functions.
-- @module api


local S = logspikes.S;


logspikes.spike_mapping = {};


logspikes.SELECTION_BOX = {type = 'fixed', fixed = {}};
for i = 0, 7 do
    local x = 8 - i;
    local y = i * 2 - 8;
    local box = {-x / 16, y       / 16, -x / 16,
                  x / 16, (y + 2) / 16,  x / 16};
    table.insert(logspikes.SELECTION_BOX.fixed, box);
end;

logspikes.COLLISION_BOX =
{
    type = 'fixed';
    fixed = {-4/16, -8/16, -4/16,
              4/16,  0/16,  4/16};
};

logspikes.PLANTLIKE_SELECTION_BOX =
{
    type = 'fixed';
    fixed = {-2.5/16, -8/16, -2.5/16,
              2.5/16,  4/16,  2.5/16};
};

logspikes.PLANTLIKE_COLLISION_BOX =
{
    type = 'fixed';
    fixed = {-2.5/16, -8/16, -2.5/16,
              2.5/16,  0/16,  2.5/16};
};


logspikes.DESCRIPTION = S'A tree trunk sharpened to a spike, which hurts players and mobs on contact.';
if minetest.get_modpath('mesecons') then
    logspikes.DESCRIPTION = logspikes.DESCRIPTION .. '\n' .. S'Extend with a piston for extra damage.';
end;


--- Updates items in a table.
-- @param tbl [table] The table to update.
-- @param ... [table] Properties to set.
-- @return    [table] The original table.
local function update(tbl, ...)
    for __, updates in ipairs{...} do
        for k, v in pairs(updates) do
             tbl[k] = v;
        end;
    end;
    return tbl;
end;


--- Escapes a texture to be used with [combine.
-- @param texture [string] The texture to escape.
-- @return        [string] An escaped texture.
local function escape_texture(texture)
    return string.gsub(texture, '[\\^:]', function(char) return '\\' .. char; end);
end;


--- Combines the tiles of a log into a texture sheet suitable for a log spike.
-- @param top    [string]     The log's top texture.
-- @param bottom [string|nil] The log's bottom texture.
-- @param side   [string]     The log's side texture.
-- @return       [string]     A stitched texture.
function logspikes.make_spike_texture(top, bottom, side)
    local tile_size = logspikes.settings.texture_size; -- To support HD textures.
    local result = {string.format('[combine:%dx%d', tile_size * 2, tile_size * 2)};

    local function _add(x, y, tile)
        if type(tile) == 'table' then
            tile = tile.name or tile.image;
        end;
        tile = string.format('(%s)^[resize:%dx%d', tile, tile_size, tile_size);
        tile = escape_texture(tile);
        table.insert(result, string.format(':%d,%d=%s', x * tile_size, y * tile_size, tile));
    end;

    if not side then
        side = bottom;
        bottom = top;
    end;

    _add(0, 0, top);
    _add(1, 0, bottom or top);
    _add(0, 1, side or top);

    return table.concat(result);
end;


--- Stabs objects at the specified position.
-- @param pos       [vector] The position to stab at.
-- @param direction [vector] The direction to stab in, as a unit vector.
-- @param node      [Node]   The spike node.
function logspikes.stab(pos, direction, node)
    local def = minetest.registered_items[node.name] or {};
    local tool_capabilities = def._stab_capabilities or def.tool_capabilities or {};
    local victims = minetest.get_objects_inside_radius(vector.add(pos, vector.multiply(direction, 0.5)), 1.0);
    for __, victim in ipairs(victims) do
        victim:punch(victim, 1.0, tool_capabilities, direction);
    end;
end;


--- Registers a log spike variant.
-- @param name     [string]       The namespaced ID of the spike node to register.
-- @param log      [string|table] The definition table or namespaced ID of the log node to make the spike out of.
-- @param override [table|nil]    An optional table of extra data for the spike node definition.
-- @return         [boolean]      true if the spike node was successfully registered.
function logspikes.register_log_spike(name, log, override)
    local log_name;
    local log_def;
    if type(log) == 'string' then
        log_name = log;
        log_def = minetest.registered_nodes[log];
        if not log_def then
            return false;
        end;
    else
        log_def = log;
        log_name = log_def.name;
    end;
    log_name = minetest.registered_aliases[log_name] or log_name;

    override = override or {};

    if logspikes.spike_mapping[log_name] then
        -- There's already a spike associated with this log — just alias to the existing name.
        minetest.register_alias(name, logspikes.spike_mapping[log_name]);
        return false;
    end;

    local sword_def = minetest.registered_items['default:sword_wood']
                   or minetest.registered_items['mcl_tools:sword_wood']
                   or minetest.registered_items['hades_core:sword_wood']
                   or minetest.registered_items['rp_default:spear_wood']
                   or minetest.registered_items['spears:spear_stone'] or {};

    local log_description = log_def.short_description or (log_def.description or log_name):split('\n')[1];

    -- Register node:
    local def =
    {
        description         = S('@1 Spike', log_description);
        drawtype            = 'mesh';
        mesh                = 'logspikes_spike.obj';
        selection_box       = logspikes.SELECTION_BOX;
        collision_box       = logspikes.COLLISION_BOX;
        tiles               = {logspikes.make_spike_texture(log_def.tiles[1], log_def.tiles[2], log_def.tiles[3])};
        use_texture_alpha   = log_def.use_texture_alpha or 'clip';
        walkable            = true;
        groups              = {logspike = 1, fall_damage_add_percent = 50};
        damage_per_second   = logspikes.settings.damage_per_second;
        paramtype           = 'light';
        paramtype2          = 'wallmounted';
        sounds              = log_def.sounds;
        light_source        = log_def.light_source;
        is_ground_content   = false;
        _stab_capabilities  = sword_def.tool_capabilities;
        _mcl_hardness       = log_def._mcl_hardness;
        _doc_items_longdesc = logspikes.DESCRIPTION;
        mesecon =
        {
            on_mvps_move =
            function(moved_pos, moved_node, old_pos, meta)
                local direction = vector.subtract(moved_pos, old_pos);
                logspikes.stab(moved_pos, direction, moved_node);
            end;
        };
    };

    if log_def.drawtype == 'plantlike' then
        def.mesh = 'logspikes_spike_plantlike.obj';
        def.tiles = log_def.tiles;
        def.selection_box = logspikes.PLANTLIKE_SELECTION_BOX;
        def.collision_box = logspikes.PLANTLIKE_COLLISION_BOX;
        def.sunlight_propagates = true;
    end;

    local groups = update(def.groups, log_def.groups, override.groups or {});
    update(def, override);
    def.groups = groups;
    minetest.register_node(name, def);
    logspikes.spike_mapping[log_name] = name;

    -- Register crafting recipe:
    minetest.register_craft(
    {
        output = name .. ' 7';
        recipe =
        {
            {'',       log_name, ''},
            {log_name, log_name, log_name},
            {log_name, log_name, log_name},
        };
    });

    -- Register crafting recipe for Repixture:
    if minetest.get_modpath('rp_crafting') then
        crafting.register_craft(
        {
            output = name;
            items  = {log_name};
        });
    end;

    -- Stripped Trees:
    if minetest.get_modpath('stripped_tree') then
        local stripped_name = log_name:gsub(':', ':stripped_');
        local stripped_def = minetest.registered_nodes[stripped_name];
        if stripped_def then
            logspikes.register_log_spike(name .. '_stripped', stripped_name);
        end;
    end;

    return true;
end;

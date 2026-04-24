last_login_signs = {}

local S = core.get_translator("last_login_signs")

last_login_signs.active_signs = {}

-- API
------

local function is_last_login_sign(nodename)
  return core.registered_nodes[nodename] and
         core.registered_nodes[nodename].groups.last_login_signs
end

function last_login_signs.rightclick_sign(pos, node, player)
  if not is_last_login_sign(node.name) then return end
  if not signs_lib.can_modify(pos, player) then return end
  local meta = core.get_meta(pos)
  local player_names = core.deserialize(meta:get("last_login_signs:players"), true) or {}
  if player:is_player() then
    player_names[player:get_player_name()] = true
    meta:set_string("last_login_signs:players", core.serialize(player_names))
    last_login_signs.update_sign(pos, node)
  end
end

function last_login_signs.after_place_node(pos, ...)
    signs_lib.after_place_node(pos, ...)
    local meta = core.get_meta(pos)
    signs_lib.update_sign(pos, {text = "Right click\nto add yourself\nto the list"})
    last_login_signs.active_signs[pos] = true
end

function last_login_signs.register_sign(name, def)
  -- We're going to mutate the definition table, so let's copy it in case it's
  -- a shared table, like signs_lib.standard_wood_groups.
  -- This is extremely important and WILL cause damage if not done, and it's
  -- not just hipothetical: all sign of an Asuna world got overwritten before
  -- this line was added.
  def = table.copy(def)
  if not def.groups then def.groups = {} end
  def.groups.last_login_signs = 1
  def.on_rightclick = def.on_rightclick or last_login_signs.rightclick_sign
  def.after_place_node = def.after_place_node or last_login_signs.after_place_node
  signs_lib.register_sign(name, def)
end

function last_login_signs.update_sign(pos, node)
  if not is_last_login_sign(node.name) then return end
  local meta = core.get_meta(pos)
  local player_names = core.deserialize(meta:get_string("last_login_signs:players"), true)
  local text = ""
  if player_names and next(player_names) then
    local auth_handler = core.get_auth_handler()
    for player_name,_ in pairs(player_names) do
      local online_status
      if core.get_player_by_name(player_name) then
        online_status = "#2" .. "online"
      else
        local pauth = auth_handler.get_auth(player_name)
        if pauth and pauth.last_login and pauth.last_login ~= -1 then
          online_status = "#4" .. os.date("!%Y-%m-%d %H:%M:%S", pauth.last_login)
        else
          online_status = "#4" .. "unknown"
        end
      end
      text = text .. player_name .. ": " .. online_status .. "\n"
    end
  else
    text = "Right click\nto add yourself\nto the list"
  end
  signs_lib.update_sign(pos, {text = text})
end

-- Implementation
-----------------

core.register_lbm {
  label = "Update Last Login Signs",
  name = "last_login_signs:update",
  nodenames = {"group:last_login_signs"},
  run_at_every_load = true,
  action = function(pos, node)
    last_login_signs.active_signs[pos] = true
    last_login_signs.update_sign(pos, node)
  end,
}

local function update_all_active_signs()
  for pos,_ in pairs(last_login_signs.active_signs) do
    local node = core.get_node_or_nil(pos)
    if node then
      last_login_signs.update_sign(pos, node)
    else
      last_login_signs.active_signs[pos] = nil
    end
  end
end

-- FIXME This is O(signs*players). We should store active signs by player, so we don't have
-- to iterate over all of them.
core.register_on_joinplayer(update_all_active_signs)
-- NOTE: the on_leaveplayer callback gets called before the player actually gets
-- removed from the online players list, so we use after() to delay the update
-- after the leave is complete.
core.register_on_leaveplayer(function() core.after(0, update_all_active_signs) end)

-- Standard signs
-----------------

last_login_signs.register_sign("last_login_signs:sign_wall_wood", {
  description = S("Wooden Last Login Wall Sign"),
  inventory_image = "signs_lib_sign_wall_wooden_inv.png^last_login_signs_sign_wall_inv_overlay.png",
  tiles = {
    "signs_lib_sign_wall_wooden.png^last_login_signs_sign_wall_overlay.png",
    "signs_lib_sign_wall_wooden_edges.png",
    -- items 3 - 5 are not set, so signs_lib will use its standard pole
    -- mount, hanging, and yard sign stick textures.
  },
  groups = signs_lib.standard_wood_groups,
  sounds = signs_lib.standard_wood_sign_sounds,
  entity_info = "standard",
  allow_hanging = true,
  allow_widefont = true,
  allow_onpole = true,
  allow_onpole_horizontal = true,
  allow_yard = true,
  use_texture_alpha = "clip",
})

last_login_signs.register_sign("last_login_signs:sign_wall_steel", {
  description = S("Steel Last Login Wall Sign"),
  inventory_image = "signs_lib_sign_wall_steel_inv.png^last_login_signs_sign_wall_inv_overlay.png",
  tiles = {
    "signs_lib_sign_wall_steel.png^last_login_signs_sign_wall_overlay.png",
    "signs_lib_sign_wall_steel_edges.png",
    nil, -- not set, so it'll use the standard pole mount texture
    nil, -- not set, so it'll use the standard hanging chains texture
    "default_steel_block.png" -- for the yard sign's stick
  },
  groups = signs_lib.standard_steel_groups,
  sounds = signs_lib.standard_steel_sign_sounds,
  locked = true,
  entity_info = "standard",
  allow_hanging = true,
  allow_widefont = true,
  allow_onpole = true,
  allow_onpole_horizontal = true,
  allow_yard = true,
  use_texture_alpha = "clip",
})

if default then
  core.register_craft({
    output = "last_login_signs:sign_wall_wood",
    recipe = {
      {"default:steel_ingot"     },
      {"default:sign_wall_wood"},
    }
  })
  core.register_craft({
    output = "last_login_signs:sign_wall_steel",
    recipe = {
      {"default:steel_ingot"     },
      {"default:sign_wall_steel"},
    }
  })
end

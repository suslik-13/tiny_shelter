-- Copyright (C) 2026 Blockhead
-- SPDX-License-Identifier: BSD-3-Clause
local use_radar = core.settings:get_bool("yesmap.radar", true)

function map.update_hud_flags(player)
    player:hud_set_flags({
        minimap = true,
        minimap_radar = use_radar,
    })
end

-- Experience tab on the atl_server_statistics leaderboard (spec section 10):
-- the experience is mirrored into that mod's storage so offline players are
-- ranked too; cb_xp's storage stays the source of truth. The tab comes first,
-- so /leaderboard opens on it.
local X = cb_xp
local A = rawget(_G, "atl_server_statistics")
if not (A and A.statistics and A.mod_storage) then
	return
end
local STAT = "Experience"
table.insert(A.statistics, 1, STAT)

local function mirror(name)
	A.mod_storage:set_int(name .. "_" .. STAT, X.get(name))
end

X.register_on_change(mirror)
core.register_on_joinplayer(function(player)
	mirror(player:get_player_name())
end)

local base = A.create_base_formspec
function A.create_base_formspec(...)
	return (base(...):gsub("leaderboard_tabs;", "leaderboard_tabs;" .. STAT .. ", ", 1))
end

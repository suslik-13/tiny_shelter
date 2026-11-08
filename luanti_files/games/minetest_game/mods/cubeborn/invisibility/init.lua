-- mobs_redo asks a mod named "invisibility" whether a player can be seen
-- (mobs/api.lua, an optional dependency). cb_core's invisibility effect
-- fills `hidden`; with no dependencies of its own this mod loads before
-- mobs_redo, so every mobs_redo mob of the servers ignores invisible players.
invisibility = { hidden = {}, }

function invisibility.is_visible(name)
	return not invisibility.hidden[name]
end

-- Bad Omen (spec cycle 2, 6): a player who kills a pillager captain gets one
-- level more, up to V, for 100 minutes. Captains of raid waves give none, or
-- every won raid would start the next one at once.
local S = cb_raids.S
local E = cb_core.effects
local O = { MAX = 5, TIME = 6000, }
cb_raids.omen = O

function O.killed_captain(ent)
	local cause = ent.cause_of_death
	local p = cause and cause.type == "punch" and cause.puncher
	if not (ent._captain and not ent._raid and p and p.is_player and p:is_player()) then
		return false
	end
	local level = math.min(O.MAX, (E.get(p, "bad_omen") or 0) + 1)
	E.clear(p, "bad_omen")
	E.apply(p, "bad_omen", level, O.TIME)
	local name = p:get_player_name()
	core.sound_play("cb_raids_bad_omen", { to_player = name, }, true)
	core.chat_send_player(name, core.colorize("#c0a0ff",
		S("Bad Omen @1: the illagers will raid the next village with villagers you enter within 100 minutes.", level)))
	return true
end

core.register_on_mods_loaded(function()
	local def = core.registered_entities["cb_mobs_illager:pillager"]
	local on_die = def and def.on_die
	if def then
		def.on_die = function(self, pos)
			O.killed_captain(self)
			if on_die then
				return on_die(self, pos)
			end
		end
	end
end)

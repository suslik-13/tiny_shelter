-- Equivalents: Cubeborn reuses a block or item the server already has instead
-- of registering a duplicate. The last candidate is Cubeborn's own node.
local entries = {}

function cb_core.register_equiv(key, candidates)
	assert(type(candidates) == "table" and #candidates > 0, "register_equiv needs candidates: " .. key)
	entries[key] = candidates
end

function cb_core.has_external(key)
	local candidates = assert(entries[key], "unknown equivalent: " .. key)
	for i = 1, #candidates - 1 do
		if core.registered_items[candidates[i]] then
			return true
		end
	end
	return false
end

function cb_core.equiv(key)
	local candidates = assert(entries[key], "unknown equivalent: " .. key)
	for _, name in ipairs(candidates) do
		if core.registered_items[name] then
			return name
		end
	end
	error("no registered item for equivalent: " .. key)
end

cb_core.register_equiv("obsidian", { "default:obsidian", })

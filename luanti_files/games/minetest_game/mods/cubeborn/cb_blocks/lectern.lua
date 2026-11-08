-- Lectern (spec cycle 3, 4): holds one written book; right-click reads it.
-- Taking it back is for whoever may build here (the area's owner, or anyone
-- outside protection). The book lives in node meta (cb_book).
local NAME = "cb_blocks:lectern"
if not cb_blocks.registered[NAME] then
	return
end
local S = cb_blocks.S
local L = { BOOK = "default:book_written", }
cb_blocks.lectern = L
local FORM = "cb_blocks:lectern_"

function L.book(pos)
	return ItemStack(core.get_meta(pos):get_string("cb_book"))
end

function L.put(pos, stack)
	if stack:get_name() ~= L.BOOK or not L.book(pos):is_empty() then
		return false
	end
	local one = ItemStack(stack)
	one:set_count(1)
	local meta = core.get_meta(pos)
	meta:set_string("cb_book", one:to_string())
	local title = one:get_meta():get_string("title")
	meta:set_string("infotext", title ~= "" and S("Lectern: @1", title) or S("Lectern"))
	return true
end

function L.can_take(pos, name)
	return not core.is_protected(pos, name)
end

function L.take(pos, name)
	local book = L.book(pos)
	if book:is_empty() or not L.can_take(pos, name) then
		return nil
	end
	local meta = core.get_meta(pos)
	meta:set_string("cb_book", "")
	meta:set_string("infotext", "")
	return book
end

function L.formspec(pos, name)
	local m = L.book(pos):get_meta()
	local fs = "size[8,8]label[0.2,0;" .. core.formspec_escape(m:get_string("title")) .. "]"
		.. "textarea[0.5,0.7;7.5,7;;;" .. core.formspec_escape(m:get_string("text")) .. "]"
	if L.can_take(pos, name) then
		fs = fs .. "button_exit[3,7.3;2,0.8;take;" .. core.formspec_escape(S("Take")) .. "]"
	end
	return fs
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #FORM) ~= FORM then
		return
	end
	local pos = core.string_to_pos(formname:sub(#FORM + 1))
	if pos and fields.take and core.get_node(pos).name == NAME and vector.distance(player:get_pos(), pos) <= 10 then
		local book = L.take(pos, player:get_player_name())
		if book then
			local left = player:get_inventory():add_item("main", book)
			if not left:is_empty() then
				core.add_item(vector.offset(pos, 0, 1, 0), left)
			end
		end
	end
	return true
end)

core.override_item(NAME, {
	on_rightclick = function(pos, _, clicker, itemstack)
		if not clicker then
			return itemstack
		end
		local name = clicker:get_player_name()
		if L.book(pos):is_empty() then
			if itemstack:get_name() == L.BOOK and not core.is_protected(pos, name) and L.put(pos, itemstack) then
				itemstack:take_item()
			elseif itemstack:get_name() == L.BOOK then
				core.record_protection_violation(pos, name)
			end
			return itemstack
		end
		core.show_formspec(name, FORM .. core.pos_to_string(pos), L.formspec(pos, name))
		return itemstack
	end,
	on_destruct = function(pos)
		local book = L.book(pos)
		if not book:is_empty() then
			core.add_item(vector.offset(pos, 0, 0.5, 0), book)
		end
	end,
})

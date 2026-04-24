
--###
--Load and Save
--###

local function save_path(n_id)
    return yl_speak_up.worldpath .. yl_speak_up.path .. DIR_DELIM .. n_id .. ".json"
end

-- we can't really log changes here in this function because we don't know *what* has been changed
yl_speak_up.save_dialog = function(n_id, dialog)
    if type(n_id) ~= "string" or type(dialog) ~= "table" then
        return false
    end
    local p = save_path(n_id)
    -- save some data (in particular usage of quest variables)
    yl_speak_up.update_stored_npc_data(n_id, dialog)
    -- make sure we never store any automaticly added generic dialogs
    dialog = yl_speak_up.strip_generic_dialogs(dialog)
    -- never store d_dynamic dialogs
    if(dialog.n_dialogs and dialog.n_dialogs["d_dynamic"]) then
        dialog.n_dialogs["d_dynamic"] = nil
    end
    local content = minetest.write_json(dialog)
    return minetest.safe_file_write(p, content)
end


-- if a player is supplied: include generic dialogs
yl_speak_up.load_dialog = function(n_id, player) -- returns the saved dialog
    local p = save_path(n_id)

    -- note: add_generic_dialogs will also add an empty d_dynamic dialog
    local file, err = io.open(p, "r")
    if err then
	return yl_speak_up.add_generic_dialogs({}, n_id, player)
    end
    io.input(file)
    local content = io.read()
    local dialog = minetest.parse_json(content)
    io.close(file)

    if type(dialog) ~= "table" then
        dialog = {}
    end

    return yl_speak_up.add_generic_dialogs(dialog, n_id, player)
end

-- this deletes the dialog with id d_id from the npc n_id's dialogs;
-- it loads the dialogs from the npc's savefile, deletes dialog d_id,
-- and then saves the dialogs back to the npc's savefile in order to
-- keep things consistent
yl_speak_up.delete_dialog = function(n_id, d_id)
    if d_id == yl_speak_up.text_new_dialog_id then
        return false
    end -- We don't delete "New dialog"

    local dialog = yl_speak_up.load_dialog(n_id, false)

    dialog.n_dialogs[d_id] = nil

    yl_speak_up.save_dialog(n_id, dialog)
end



-- used by staff and input_inital_config
yl_speak_up.fields_to_dialog = function(pname, fields)
    local n_id = yl_speak_up.speak_to[pname].n_id
    local dialog = yl_speak_up.load_dialog(n_id, false)
    local save_d_id = ""

    if next(dialog) == nil then -- No file found. Let's create the basic values
        dialog = {}
        dialog.n_dialogs = {}
    end

    if dialog.n_dialogs == nil or next(dialog.n_dialogs) == nil then --No dialogs found. Let's make a table
        dialog.n_dialogs = {}
    end

    if fields.d_text ~= "" then -- If there is dialog text, then save new or old dialog
        if fields.d_id == yl_speak_up.text_new_dialog_id then --New dialog --
            -- Find highest d_id and increase by 1
            save_d_id = "d_" .. yl_speak_up.find_next_id(dialog.n_dialogs)

            -- Initialize empty dialog
            dialog.n_dialogs[save_d_id] = {}
        else -- Already existing dialog
            save_d_id = fields.d_id
        end
        -- Change dialog
        dialog.n_dialogs[save_d_id].d_id = save_d_id
        dialog.n_dialogs[save_d_id].d_type = "text"
        dialog.n_dialogs[save_d_id].d_text = fields.d_text
        dialog.n_dialogs[save_d_id].d_sort = fields.d_sort
    end

    --Context
    yl_speak_up.speak_to[pname].d_id = save_d_id

    -- Just in case the NPC vlaues where changed or set
    dialog.n_id = n_id
    dialog.n_description = fields.n_description
    dialog.n_npc = fields.n_npc

    dialog.npc_owner = fields.npc_owner

    return dialog
end


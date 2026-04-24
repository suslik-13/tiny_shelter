local create_formspec = dofile(minetest.get_modpath("server_logs") .. "/formspec.lua")
local ie = minetest.request_insecure_environment()

if not ie then
  error("Please add server_logs to trusted_mods in your minetest.conf file for it to work")
end

-- Register 'logs' privilege
minetest.register_privilege("logs", {
    description = "Allows viewing server logs",
    give_to_singleplayer = false,
})

local function show_logs(name, start_line, search_term)
    if not minetest.check_player_privs(name, {logs = true}) then
        minetest.chat_send_player(name, "Insufficient privileges!")
        return
    end

    -- get the log file path from the settings, default to /var/log/minetest/minetest.log if it's not set
    local log_file_path = minetest.settings:get("server_logs.log_file") or "/var/log/minetest/minetest.log"

    local f
    local content = ""
    if search_term then
        -- shell escape the search term to prevent injection attacks
        search_term = search_term:gsub('([%(%)%.%%%+%-%*%?%[%^%$])', '%%%1')
        f = ie.io.popen("grep " .. search_term .. " " .. log_file_path)
    else
        f = ie.io.popen("tail -n +" .. start_line .. " " .. log_file_path)
        minetest.log(start_line)
        minetest.log(log_file_path)
    end

    if f then
        for i = 1, 100 do
            local line = f:read("*l")
            if line then
                content = content .. line .. "\n"
            else
                break
            end
        end
        f:close()
        minetest.show_formspec(name, "server_logs:logs", create_formspec(content, search_term, start_line))
    else
        minetest.chat_send_player(name, "Could not open log file!")
    end
end

minetest.register_chatcommand("logs", {
    description = "Show server logs",
    privs = {logs = true},
    func = function(name)
        show_logs(name, 1)
    end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "server_logs:logs" then
        if fields.search then
            show_logs(player:get_player_name(), 1, fields.search_term)
        elseif fields.load_more then
            show_logs(player:get_player_name(), tonumber(fields.start_line) + 100)
        end
    end
end)

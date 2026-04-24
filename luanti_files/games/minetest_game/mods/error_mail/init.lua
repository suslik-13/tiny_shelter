-- error_mail/init.lua
-- Send mail to the admin with error traceback
-- Copyright (C) 2024  1F616EMO
-- SPDX-License-Identifier: LGPL-3.0-or-later

local WP = minetest.get_worldpath()
local err_path = WP .. DIR_DELIM .. "error_mail_contents.txt"

-- Check for unsent mails
do
    local mail_file = io.open(err_path)
    if mail_file then
        local content = mail_file:read("*a")
        mail_file:close()
        mail_file = nil -- luacheck: ignore
        os.remove(err_path)

        -- mail calls auth function so move it into globalstep
        minetest.after(0, function()
            local admin = minetest.settings:get("name")
            local success, error = mail.send({
                from = "Error Mail System",
                to = admin,
                subject = "Error traceback",
                body = content
            })
            if success then
                minetest.log("action", "Sent error traceback to " .. admin)
            else
                minetest.log("error", "Failed to send mail file to " .. admin .. ": " .. error)
            end
        end)
    end
end

local old_error_handler = minetest.error_handler
function minetest.error_handler(...) -- luacheck: ignore
    local msg = old_error_handler(...)
    local mail_file = io.open(err_path, "w")
    if mail_file then
        local mail_msg =
            "This error happened on " .. os.date('%Y-%m-%d at %H:%M:%S') .. ".\n\n" ..
            msg
        mail_file:write(mail_msg)
        mail_file:close()
        mail_file = nil -- luacheck: ignore
        minetest.log("action", "Error traceback saved to " .. err_path)
    else
        -- Remove to remove duplication in case sth strange happens
        os.remove(err_path)
        minetest.log("error", "Failed to save error traceback to " .. err_path)
    end
    return msg
end

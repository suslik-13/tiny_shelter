return function(content, search_term, start_line)
    search_term = search_term or ""
    start_line = start_line or 1
    return "size[12,8]" ..
        "field[0.5,0.5;11,1;search_term;Search;" .. minetest.formspec_escape(search_term) .. "]" ..
        "textarea[0.5,6.5;0,0;start_line;;" .. start_line .. "]" ..
        "button[10.5,0;1.5,1;search;Search]" ..
        "textarea[0.5,1.5;11.5,6;logs;Server Logs;" .. minetest.formspec_escape(content) .. "]" ..
        "button[4,7;4,1;load_more;Load More]" ..
        "button_exit[9,7;2.5,1;exit;Exit]"
end

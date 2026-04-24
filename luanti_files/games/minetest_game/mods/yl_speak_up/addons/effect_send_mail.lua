
-- requires mail.send from the mail mod

-- NPC can send out mails in order to sum up a quest state or complex step
-- - or just to inform their owner that they ran out of stock
-- There is also a similar action defined in another file. The action
-- allows the player that talks to the NPC to enter his/her own mailtext.
-- The *effect* here requires that the text has been configured in advance.

-- define the custom effect named "send_mail"
local effect_send_mail = {
	-- this information is necessary for allowing to add this as an effect to an option 
	description = "Send a preconfigured mail via the mail_mod mod for quest state etc.",
	-- define the parameters that can be set when the action is added
	param1_text = "To:",
	param1_desc = "Who shall receive this mail? Default: $PLAYER_NAME$."..
			"\nNote: Leave fields empty for the default values."..
			"\nNote: All parameters allow to use the usual replacements like $NPC_NAME$,"..
			"\n\t$OWNER_NAME$, $PLAYER_NAME$, $VAR name_of_your_var$, $PROP name_of_prop$.",
	-- the "From:" field will always be the name of the owner of the NPC
--	param2_text = "From:",
--	param2_desc = "Who shall be listed as the sender of this mail?\n"..
--			"The player talking to the NPC might be best as it makes answering easier.\n"..
--			"Default: $PLAYER_NAME$. Also allowed: $OWNER_NAME$.",
	param3_text = "cc:",
	param3_desc = "(optional) Whom to send a carbon copy to?"..
			"\nThis is useful if multiple players may edit this NPC."..
			"\nIt is also possible to send a copy to $PLAYER_NAME$.",
	param4_text = "bcc:",
	param4_desc = "(optional) Who gets set in the bcc?",
	param5_text = "Subject:",
	param5_desc = "The subject of the mail. Ought to give the player information\n"..
			"which NPC sent this mail and why.\n"..
			"Default: \"$NPC_NAME$ has a message from $OWNER_NAME$\"",
	param6_text = "Mail text:",
	param6_desc = "The actual text of the mail. Use the usual replacements to make the mail\n"..
			"meaningful! You may want to use $VAR name_of_your_var$.\n"..
			"Note: Use \\n to create a newline!",
}



-- the actual implementation of the function - run when the effect is executed
effect_send_mail.code = function(player, n_id, r)
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return fields
	end
	local dialog = yl_speak_up.speak_to[pname].dialog

	-- prepare data/parameters for the mail we want to send
	-- $PLAYER_NAME$, $OWNER_NAME$, $NPC_NAME$, $VAR *$ $PROP *$ are allowed replacements!
	local mail_to      = yl_speak_up.replace_vars_in_text(r.r_param1, dialog, pname)
	local mail_from    = yl_speak_up.replace_vars_in_text(r.r_param2, dialog, pname)
	local mail_cc      = yl_speak_up.replace_vars_in_text(r.r_param3, dialog, pname)
	local mail_bcc     = yl_speak_up.replace_vars_in_text(r.r_param4, dialog, pname)
	local mail_subject = yl_speak_up.replace_vars_in_text(r.r_param5, dialog, pname)
	local mail_text    = yl_speak_up.replace_vars_in_text(r.r_param6, dialog, pname)
	-- this is in reverse of the actions: the mail is usually sent to the player the
	-- NPC is talking with - e.g. as a reminder of a quest status
	if(not(mail_to) or mail_to == "") then
		mail_to = pname
	end
	-- the mail always originates from the owner of the NPC
	mail_from = dialog.npc_owner
	if(not(mail_cc) or mail_cc == "") then
		mail_cc = nil
	end
	if(not(mail_bcc) or mail_bcc == "") then
		mail_bcc = nil
	end
	if(not(mail_subject) or mail_subject == "") then
		mail_subject = (dialog.n_npc or "- ? -").." has a message from "..(dialog.npc_owner or "- ? -")
	end
	-- actually send the mail via the mail_mod mod
	local success, error_msg = mail.send({
		from    = mail_from,
		to      = mail_to,
		cc      = mail_cc,
		bcc     = mail_bcc,
		subject = mail_subject,
		body    = "Message from "..tostring(dialog.n_npc or "- ? -")..":\n\n"..
				table.concat(string.split(mail_text or "- no message -", "\\n"), "\n")
	})
	return success
end


if(minetest.global_exists("mail")
  and type(mail) == "table"
  and type(mail.send) == "function") then
	-- only add this effect if the mail mod and the mail.send function exist
	yl_speak_up.custom_functions_r_[ "send_mail" ] = effect_send_mail
end

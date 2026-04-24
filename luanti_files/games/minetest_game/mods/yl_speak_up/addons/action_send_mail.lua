-- requires mail.send from the mail mod

-- sending a mail allows to give feedback - and for players to ask the NPC owner to add more texts
-- and let the NPC answer to further questions

-- define the custom action named "send_mail"
local action_send_mail = {
	-- this information is necessary for allowing to add this as an action to an option 
	description = "Send a mail via the mail_mod mod for feedback/ideas/etc.",
	-- define the parameters that can be set when the action is added
	param1_text = "To:",
	param1_desc = "Who shall receive this mail? Default: $OWNER_NAME$."..
			"\nNote: Leave fields empty for the default values."..
			"\nNote: All parameters allow to use the usual replacements like $NPC_NAME$,"..
			"\n\t$OWNER_NAME$, $PLAYER_NAME$, $VAR name_of_your_var$, $PROP name_of_prop$.",
	param2_text = "From:",
	param2_desc = "Who shall be listed as the sender of this mail?\n"..
			"The player talking to the NPC might be best as it makes answering easier.\n"..
			"Default: $PLAYER_NAME$. Also allowed: $OWNER_NAME$.",
	param3_text = "cc:",
	param3_desc = "(optional) Whom to send a carbon copy to?"..
			"\nThis is useful if multiple players may edit this NPC."..
			"\nIt is also possible to send a copy to $PLAYER_NAME$.",
	param4_text = "bcc:",
	param4_desc = "(optional) Who gets set in the bcc?",
	param5_text = "Subject:",
	param5_desc = "The subject of the mail. The player talking to the NPC\n"..
			"will provide the actual text for the body of the mail.\n"..
			"Default: \"$NPC_NAME$: regarding $PLAYER_NAME$\"",
}


-- this function will show a formspec whenever our custom action "send_mail" is executed
--yl_speak_up.custom_functions_a_[ "send_mail" ].code = function(player, n_id, a)
action_send_mail.code = function(player, n_id, a)
	local pname = player:get_player_name()
	-- sending the mail can either succeed or fail; pdata.tmp_mail_* variables store the result
	local pdata = yl_speak_up.speak_to[pname]
	-- just the normal dialog data from the NPC (contains name of the NPC and owner)
	local dialog = yl_speak_up.speak_to[pname].dialog
	local npc_name = "- (this NPC) -"
	local owner_name = "- (his owner) -"
	if(dialog) then
		-- the NPC is the one "forwarding" the message (so that the receiver will know
		-- *which* NPC was talked to)
		npc_name   = minetest.formspec_escape(dialog.n_npc or "- ? -")
		-- usually the owner is the receiver
		owner_name = minetest.formspec_escape(a.a_param1 or dialog.npc_owner or "- ? ")
	end

	-- the mail was already sent successful; we still return once to this formspec so that
	-- the player gets this information and can finish the action successfully
	if(pdata and pdata.tmp_mail_to and pdata.tmp_mail_success) then
		local mail_to = minetest.formspec_escape(pdata.tmp_mail_to or "?")
		-- unset temporary variables that are no longer needed
		pdata.tmp_mail_success = nil
		pdata.tmp_mail_error = nil
		pdata.tmp_mail_to = nil
		return table.concat({
			"size[20,3]label[0.2,0.7;",
			npc_name,
			" has sent a mail containing your text to ",
			mail_to,
			" and awaits further instructions."..
			"\nPlease be patient and wait for a reply. This may take some time as ",
			mail_to,
			" has to receive, read and answer the mail.]",
			-- offer a button to finally complete the action successfully
			"button[4,2;6.8,0.9;finished_action;Ok. I'll wait.]",
		}, "")

	-- we tried to send the mail - and an error occoured
	elseif(pdata and pdata.tmp_mail_to and pdata.tmp_mail_error) then
		local mail_to = minetest.formspec_escape(pdata.tmp_mail_to or "?")
		local error_msg = minetest.formspec_escape(pdata.tmp_mail_error or "?")
		-- unset temporary variables that are no longer needed
		pdata.tmp_mail_success = nil
		pdata.tmp_mail_error = nil
		pdata.tmp_mail_to = nil
		return table.concat({
			"size[20,8]label[0.2,0.7;",
			npc_name,
			" FAILED to sent a mail containing your text to ",
			mail_to,
			" in order to get help!]",
			"textarea[0.2,1.8;19.6,5;;The following error(s) occourd:;",
			error_msg,
			"]",
			-- the action can no longer be completed successfully; best to back to talk
			"button[7,7.0;6.0,0.9;back_to_talk;Back to talk]",
		}, "")
	end

	-- the mail has not been sent yet; show the normal formspec asking for text input
	return table.concat({"size[20,8.5]label[4,0.7;Send a message to ",
			npc_name,
			"]",
		"button[17.8,0.2;2.0,0.9;back_to_talk;Back]",
		"label[0.2,7.0;Note: ",
			npc_name,
			" will send a mail to ",
			minetest.formspec_escape(a.a_param1 or dialog.npc_owner or "- ? "),
			", requesting instructions how to respond. This may take a while.]",
		"button[3.6,7.5;6.0,0.9;back_to_talk;Abort and go back]",
		"button[10.2,7.5;6.0,0.9;send_mail;Send this message]",
		-- read-only
		"textarea[0.2,1.8;19.6,5;message_text;Write your message for ",
			npc_name,
			" here, and then click on \"Send this message\":;",
			"",
			"]",
	})
end


-- whenever our formspec above for the custom action "send_mail" received input (player clicked
-- on a button), this function is called
action_send_mail.code_input_handler = function(player, n_id, a, formname, fields)
	local pname = player:get_player_name()
	if(not(pname) or not(yl_speak_up.speak_to[pname])) then
		return fields
	end
	-- sending was aborted or there was no text to send
	if(  not(fields.message_text) or fields.message_text == ""
	  or not(fields.send_mail)    or fields.send_mail    == "") then
		return fields
	end
	local dialog = yl_speak_up.speak_to[pname].dialog

	-- prepare data/parameters for the mail we want to send
	-- $PLAYER_NAME$, $OWNER_NAME$, $NPC_NAME$, $VAR *$ $PROP *$ are allowed replacements!!
	local mail_to      = yl_speak_up.replace_vars_in_text(a.a_param1, dialog, pname)
	local mail_from    = yl_speak_up.replace_vars_in_text(a.a_param2, dialog, pname)
	local mail_cc      = yl_speak_up.replace_vars_in_text(a.a_param3, dialog, pname)
	local mail_bcc     = yl_speak_up.replace_vars_in_text(a.a_param4, dialog, pname)
	local mail_subject = yl_speak_up.replace_vars_in_text(a.a_param5, dialog, pname)
	if(not(mail_to) or mail_to == "") then
		mail_to = dialog.npc_owner
	end
	-- make sure the sender is not forged; we allow EITHER the name of the owner of the NPC
	-- OR the name of the player currently talking to the npc
	if(not(mail_from) or mail_from == "" or mail_from ~= dialog.npc_owner) then
		mail_from = pname
	end
	if(not(mail_cc) or mail_cc == "") then
		mail_cc = nil
	end
	if(not(mail_bcc) or mail_bcc == "") then
		mail_bcc = nil
	end
	if(not(mail_subject) or mail_subject == "") then
		mail_subject = (dialog.n_npc or "- ? -")..": regarding "..pname
	end
	-- actually send the mail via the mail_mod mod
	local success, error_msg = mail.send({
		from    = mail_from,
		to      = mail_to,
		cc      = mail_cc,
		bcc     = mail_bcc,
		subject = mail_subject,
		body    = "Dear "..tostring(dialog.npc_owner)..",\n\n"..tostring(pname)..
			" asked me something I don't know the answer to. Hope you can help? "..
			"This is the request:\n\n"..
			tostring(fields.message_text or "- no message -")
	})
	-- Sending this mail was either successful or not. We want to display this to the player.
	-- Therefore, we set fields.back_from_error_msg. This tells the calling function that it
	-- needs to display the formspec generated by the function
	-- 	yl_speak_up.custom_functions_a_[ "send_mail" ].code
	-- again.
	fields.back_from_error_msg = true
	-- The function displaying the formspec needs to know that it has to display the result
	-- of sending the mail now. We need to store these variables somewhere.
	local pdata = yl_speak_up.speak_to[pname]
	pdata.tmp_mail_success = success
	pdata.tmp_mail_error = error_msg
	pdata.tmp_mail_to = mail_to
	-- the function has to return fields
	return fields
end


if(minetest.global_exists("mail")
  and type(mail) == "table"
  and type(mail.send) == "function") then
	-- only add this action if the mail mod and the mail.send function exist
	yl_speak_up.custom_functions_a_[ "send_mail" ] = action_send_mail
end

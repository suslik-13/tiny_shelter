
-- This is a quick way to generate a simple d_dynamic dialog with
-- displayed text  new_text  and options/answers from the table
-- (list) answers.
-- The strings  topics  are added as parameters to the dialog options.
-- TODO: do the common replacements like $PLAYER_NAME$, $NPC_NAME$ etc?
yl_speak_up.generate_next_dynamic_dialog_simple = function(
			player, n_id, d_id, alternate_text, recursion_depth,
			new_text, answers, topics,
			back_option_o_id, back_option_target_dialog)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog)) then
		return
	end
	local dyn_dialog = dialog.n_dialogs["d_dynamic"]
	if(not(dyn_dialog)) then
		return
	end
	-- which dialog did the player come from?
	local prev_d_id = yl_speak_up.speak_to[pname].d_id
	-- the dialog d_dynamic is modified directly; we do not return anything
	-- set the new text:
	dialog.n_dialogs["d_dynamic"].d_text = new_text
	-- add all the answers:
	dialog.n_dialogs["d_dynamic"].d_options = {}
	if(not(topics)) then
		topics = {}
	end
	for i, text in ipairs(answers) do
		local future_o_id = "o_" .. tostring(i)
		-- add the dialog option as such:
		dialog.n_dialogs["d_dynamic"].d_options[future_o_id] = {
			o_id = future_o_id,
			o_hide_when_prerequisites_not_met = "false",
			o_grey_when_prerequisites_not_met = "false",
			o_sort = i,
			o_text_when_prerequisites_not_met = "",
			o_text_when_prerequisites_met = (text or ""),
			-- some additional information to make it easier to
			-- react to a selected answer:
			tmp_topic = topics[i],
		}

		-- create a fitting dialog result automaticly:
		-- give this new dialog a dialog result that leads back to this dialog
		-- (this can be changed later on if needed):
		local future_r_id = "r_1"
                -- actually store the new result
		dialog.n_dialogs["d_dynamic"].d_options[future_o_id].o_results = {}
		dialog.n_dialogs["d_dynamic"].d_options[future_o_id].o_results[future_r_id] = {
			r_id = future_r_id,
			r_type = "dialog",
			r_value = "d_dynamic"}
	end
	-- go back to back_option_target_dialog:
	if(back_option_o_id
	    and dialog.n_dialogs["d_dynamic"].d_options[back_option_o_id]) then
		dialog.n_dialogs["d_dynamic"].d_options[back_option_o_id].o_results["r_1"].r_value = 
								back_option_target_dialog
	end
end


-- the dialog will be modified for this player only:
-- (pass on all the known parameters in case they're relevant):
-- 	called from yl_speak_up.get_fs_talkdialog(..):
yl_speak_up.generate_next_dynamic_dialog = function(player, n_id, d_id, alternate_text, recursion_depth)
	if(not(player)) then
		return
	end
	local pname = player:get_player_name()
	if(not(yl_speak_up.speak_to[pname])) then
		return
	end
	local dialog = yl_speak_up.speak_to[pname].dialog
	if(not(dialog.n_dialogs["d_dynamic"])) then
		dialog.n_dialogs["d_dynamic"] = {}
	end
	-- which dialog did the player come from?
	local prev_d_id = yl_speak_up.speak_to[pname].d_id
	local selected_o_id = yl_speak_up.speak_to[pname].selected_o_id
	-- the text the NPC shall say:
	local prev_answer = "- unknown -"
	local tmp_topic = "- none -"
	if(dialog.n_dialogs[prev_d_id]
	  and dialog.n_dialogs[prev_d_id].d_options
	  and dialog.n_dialogs[prev_d_id].d_options[selected_o_id]
	  and dialog.n_dialogs[prev_d_id].d_options[selected_o_id].o_text_when_prerequisites_met) then
		prev_answer = dialog.n_dialogs[prev_d_id].d_options[selected_o_id].o_text_when_prerequisites_met
		tmp_topic   = dialog.n_dialogs[prev_d_id].d_options[selected_o_id].tmp_topic
	end
	-- pname is the name of the player; d_id is "d_dynamic"
	local new_text = "Hello $PLAYER_NAME$,\n".. -- also: pname
			"you're talking to me, $NPC_NAME$, who has the NPC ID "..tostring(n_id)..".\n"..
			"Previous dialog: "..tostring(prev_d_id)..".\n"..
			"Selected option: "..tostring(selected_o_id).." with the text:\n"..
			"\t\""..tostring(prev_answer).."\".\n"..
			"We have shared "..tostring(dialog.n_dialogs["d_dynamic"].tmp_count or 0)..
				" such continous dynamic dialogs this time.\n"
	-- the answers/options the player can choose from:
	local answers = {"$GOOD_DAY$! My name is $PLAYER_NAME$.",
			"Can I help you, $NPC_NAME$?",
			"What is your name? I'm called $PLAYER_NAME$.", "Who is your employer?",
			"What are you doing here?", "Help me, please!", "This is just a test.",
			"That's too boring. Let's talk normal again!"}
	-- store a topic for each answer so that the NPC can reply accordingly:
	local topics = {"my_name", "help_offered", "your_name", "your_employer", "your_job",
			"help_me", "test", "back"}
	-- react to the previously selected topic (usually you'd want a diffrent new_text,
	-- answers and topics based on what the player last selected; this here is just for
	-- demonstration):
	if(tmp_topic     == "my_name") then
		new_text = new_text.."Pleased to meet you, $PLAYER_NAME$!"
	elseif(tmp_topic == "help_offered") then
		new_text = new_text.."Thanks! But I don't need any help right now."
	elseif(tmp_topic == "your_name") then
		new_text = new_text.."Thank you for asking for my name! It is $NPC_NAME$."
	elseif(tmp_topic == "your_employer") then
		new_text = new_text.."I work for $OWNER_NAME$."
	elseif(tmp_topic == "your_job") then
		new_text = new_text.."My job is to answer questions from adventurers like yourself."
	elseif(tmp_topic == "help_me") then
		new_text = new_text.."I'm afraid I'm unable to help you."
	elseif(tmp_topic == "test") then
		new_text = new_text.."Your test was successful. We're talking."
	else
		new_text = new_text.."Feel free to talk to me! Just choose an answer or question."
	end
	-- With this answer/option, the player can leave the d_dynamic dialog and return..
	local back_option_o_id = "o_"..tostring(#answers)
	-- ..back to dialog d_1 (usually the start dialog):
	local back_option_target_dialog = "d_1"
	-- store some additional values:
	if(d_id ~= "d_dynamic" or not(dialog.n_dialogs["d_dynamic"].tmp_count)) then
		dialog.n_dialogs["d_dynamic"].tmp_count = 0
	end
	dialog.n_dialogs["d_dynamic"].tmp_count = dialog.n_dialogs["d_dynamic"].tmp_count + 1
	-- actually update the d_dynamic dialog
	return yl_speak_up.generate_next_dynamic_dialog_simple(
			player, n_id, d_id, alternate_text, recursion_depth,
			new_text, answers, topics, back_option_o_id, back_option_target_dialog)
end

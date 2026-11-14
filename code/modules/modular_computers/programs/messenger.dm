/// Every imprinted messenger, keyed by reference
GLOBAL_LIST_EMPTY(pda_messengers)

/proc/add_messenger(datum/computer_file/program/messenger/messenger)
	if(!istype(messenger))
		return
	var/obj/item/modular_computer/device = messenger.computer
	if(!device?.saved_identification || !device.saved_job)
		return
	GLOB.pda_messengers[REF(messenger)] = messenger

/proc/remove_messenger(datum/computer_file/program/messenger/messenger)
	GLOB.pda_messengers -= REF(messenger)

/proc/cmp_messenger_name_asc(datum/computer_file/program/messenger/a, datum/computer_file/program/messenger/b)
	return sorttext(b.computer.saved_identification, a.computer.saved_identification)

/proc/cmp_messenger_job_asc(datum/computer_file/program/messenger/a, datum/computer_file/program/messenger/b)
	return sorttext(b.computer.saved_job, a.computer.saved_job) || cmp_messenger_name_asc(a, b)

/// A conversation with one other messenger
/datum/pda_chat
	var/cached_name = "Unknown"
	var/cached_job = "Unknown"
	var/datum/weakref/recipient
	var/list/datum/pda_message/messages = list()
	var/visible_in_recents = FALSE
	var/can_reply = TRUE
	var/message_draft = ""
	var/unread_messages = 0

/datum/pda_chat/New(datum/computer_file/program/messenger/recipient)
	src.recipient = WEAKREF(recipient)
	can_reply = !isnull(recipient)

/datum/pda_chat/proc/add_message(datum/pda_message/message, show_in_recents = TRUE)
	messages += message
	if(show_in_recents)
		visible_in_recents = TRUE
	return message

/datum/pda_chat/proc/get_recipient_messenger()
	var/datum/computer_file/program/messenger/messenger = recipient?.resolve()
	if(istype(messenger) && (REF(messenger) in GLOB.pda_messengers))
		cached_name = messenger.computer.saved_identification
		cached_job = messenger.computer.saved_job
		return messenger
	can_reply = FALSE

/datum/pda_chat/proc/get_ui_data()
	var/datum/computer_file/program/messenger/messenger = get_recipient_messenger()
	var/list/data = list()
	data["ref"] = REF(src)
	data["recipient"] = list(
		"name" = cached_name,
		"job" = cached_job,
		"ref" = messenger ? REF(messenger) : null,
	)
	var/list/messages_data = list()
	for(var/datum/pda_message/message as anything in messages)
		messages_data += list(message.get_ui_data())
	data["messages"] = messages_data
	data["message_draft"] = message_draft
	data["visible"] = visible_in_recents
	data["can_reply"] = can_reply
	data["unread_messages"] = unread_messages
	return data

/datum/pda_message
	var/message
	var/outgoing
	var/timestamp

/datum/pda_message/New(message, outgoing, timestamp)
	src.message = message
	src.outgoing = outgoing
	src.timestamp = timestamp

/datum/pda_message/proc/get_ui_data()
	return list(
		"message" = message,
		"outgoing" = outgoing,
		"everyone" = FALSE,
		"timestamp" = timestamp,
	)

/datum/computer_file/program/messenger
	filename = "messenger"
	filedesc = "Direct Messenger"
	extended_desc = "This program allows direct communication with other modular devices."
	program_flags = PROGRAM_HEADER
	tgui_id = "NtosMessenger"
	program_icon = "comment-alt"
	program_open_overlay = "command"
	alert_able = TRUE

	var/invisible = FALSE
	COOLDOWN_DECLARE(last_text)
	/// Chats keyed by chat reference
	var/list/saved_chats = list()
	/// Chat or messenger reference currently open, null on the contacts screen
	var/viewing_messages_of
	var/sort_by_job = TRUE
	var/sending_and_receiving = TRUE

/datum/computer_file/program/messenger/Destroy(force)
	remove_messenger(src)
	QDEL_LIST_ASSOC_VAL(saved_chats)
	return ..()

/datum/computer_file/program/messenger/on_imprint()
	add_messenger(src)

/datum/computer_file/program/messenger/proc/get_messengers()
	var/list/messengers = list()
	for(var/ref in GLOB.pda_messengers)
		var/datum/computer_file/program/messenger/messenger = GLOB.pda_messengers[ref]
		if(!istype(messenger) || !istype(messenger.computer) || messenger == src || messenger.invisible)
			continue
		messengers += messenger
	messengers = sortTim(messengers, sort_by_job ? GLOBAL_PROC_REF(cmp_messenger_job_asc) : GLOBAL_PROC_REF(cmp_messenger_name_asc))

	var/list/dictionary = list()
	for(var/datum/computer_file/program/messenger/messenger as anything in messengers)
		var/ref = REF(messenger)
		dictionary[ref] = list(
			"name" = messenger.computer.saved_identification,
			"job" = messenger.computer.saved_job,
			"ref" = ref,
		)
	return dictionary

/datum/computer_file/program/messenger/proc/get_chat_with(datum/computer_file/program/messenger/other)
	for(var/chat_ref in saved_chats)
		var/datum/pda_chat/chat = saved_chats[chat_ref]
		if(chat.recipient?.resolve() == other)
			return chat
	var/datum/pda_chat/new_chat = new(other)
	saved_chats[REF(new_chat)] = new_chat
	return new_chat

/datum/computer_file/program/messenger/proc/send_message(mob/living/sender, message, datum/computer_file/program/messenger/recipient)
	if(!sending_and_receiving)
		to_chat(sender, SPAN_NOTICE("ERROR: This device has sending disabled."))
		return FALSE
	if(!COOLDOWN_FINISHED(src, last_text))
		return FALSE
	if(!istype(recipient) || !(REF(recipient) in GLOB.pda_messengers))
		to_chat(sender, SPAN_NOTICE("ERROR: Recipient no longer exists."))
		return FALSE
	if(!recipient.sending_and_receiving)
		to_chat(sender, SPAN_NOTICE("ERROR: Recipient is not accepting messages."))
		return FALSE

	message = strip_html(message, MAX_PDA_MESSAGE_LEN)
	if(!message)
		return FALSE

	COOLDOWN_START(src, last_text, 1 SECONDS)
	var/timestamp = worldtime2text(PDA_MESSAGE_TIMESTAMP_FORMAT)

	var/datum/pda_chat/sent_chat = get_chat_with(recipient)
	sent_chat.add_message(new /datum/pda_message(message, TRUE, timestamp))
	sent_chat.message_draft = ""

	var/datum/pda_chat/received_chat = recipient.get_chat_with(src)
	received_chat.add_message(new /datum/pda_message(message, FALSE, timestamp))
	if(recipient.viewing_messages_of != REF(received_chat))
		received_chat.unread_messages++
	recipient.computer.alert_call(recipient, "Message from <b>[computer.saved_identification] ([computer.saved_job])</b>: [message] <a href='byond://?src=[REF(recipient.computer)];pda_reply=[REF(received_chat)]'>(Reply)</a>")

	log_say("PDA: [key_name(sender)] to [recipient.computer.saved_identification] ([recipient.computer.saved_job]): [message]")
	SStgui.update_uis(recipient.computer)
	return sent_chat

/// Marks the chat that was being viewed as read and drops it if nothing was ever said in it
/datum/computer_file/program/messenger/proc/leave_chat(previous_ref, next_ref)
	if(!previous_ref || previous_ref == next_ref || !(previous_ref in saved_chats))
		return
	var/datum/pda_chat/previous_chat = saved_chats[previous_ref]
	previous_chat.unread_messages = 0
	if(!length(previous_chat.messages))
		qdel(previous_chat)
		saved_chats -= previous_ref

/datum/computer_file/program/messenger/ui_data(mob/user)
	var/list/data = list()
	if(computer.saved_identification && computer.saved_job)
		data["owner"] = list("name" = computer.saved_identification, "job" = computer.saved_job)
	var/list/chats = list()
	for(var/chat_ref in saved_chats)
		var/datum/pda_chat/chat = saved_chats[chat_ref]
		chats[chat_ref] = chat.get_ui_data()
	data["saved_chats"] = chats
	data["messengers"] = get_messengers()
	data["sort_by_job"] = sort_by_job
	data["alert_silenced"] = alert_silenced
	data["alert_able"] = alert_able
	data["sending_and_receiving"] = sending_and_receiving
	data["open_chat"] = viewing_messages_of
	return data

/datum/computer_file/program/messenger/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/mob/user = ui.user
	switch(action)
		if("PDA_toggleAlerts")
			alert_silenced = !alert_silenced
			return TRUE

		if("PDA_toggleSendingAndReceiving")
			sending_and_receiving = !sending_and_receiving
			return TRUE

		if("PDA_changeSortStyle")
			sort_by_job = !sort_by_job
			return TRUE

		if("PDA_viewMessages")
			var/target = params["ref"]
			if(target && !(target in saved_chats) && (target in GLOB.pda_messengers))
				var/datum/pda_chat/new_chat = get_chat_with(GLOB.pda_messengers[target])
				target = REF(new_chat)
			leave_chat(viewing_messages_of, target)
			viewing_messages_of = (target in saved_chats) ? target : null
			if(viewing_messages_of)
				var/datum/pda_chat/chat = saved_chats[viewing_messages_of]
				if(length(chat.messages))
					chat.visible_in_recents = TRUE
			return TRUE

		if("PDA_closeMessages")
			var/target = params["ref"]
			if(!(target in saved_chats))
				return FALSE
			var/datum/pda_chat/chat = saved_chats[target]
			chat.visible_in_recents = FALSE
			if(viewing_messages_of == target)
				viewing_messages_of = null
			return TRUE

		if("PDA_clearMessages")
			var/chat_ref = params["ref"]
			if(chat_ref in saved_chats)
				qdel(saved_chats[chat_ref])
				saved_chats -= chat_ref
			viewing_messages_of = null
			return TRUE

		if("PDA_saveMessageDraft")
			var/target_chat_ref = params["ref"]
			if(!(target_chat_ref in saved_chats))
				return FALSE
			var/datum/pda_chat/chat = saved_chats[target_chat_ref]
			chat.message_draft = params["message"]
			return TRUE

		if("PDA_clearUnreads")
			var/target_chat_ref = params["ref"]
			if(!(target_chat_ref in saved_chats))
				return FALSE
			var/datum/pda_chat/chat = saved_chats[target_chat_ref]
			chat.unread_messages = 0
			return TRUE

		if("PDA_sendMessage")
			var/target_ref = params["ref"]
			var/datum/computer_file/program/messenger/recipient
			if(target_ref in saved_chats)
				var/datum/pda_chat/target_chat = saved_chats[target_ref]
				recipient = target_chat.get_recipient_messenger()
			else if(target_ref in GLOB.pda_messengers)
				recipient = GLOB.pda_messengers[target_ref]

			var/datum/pda_chat/sent_chat = send_message(user, params["message"], recipient)
			if(!sent_chat)
				return FALSE
			if(!(viewing_messages_of in saved_chats))
				viewing_messages_of = REF(sent_chat)
			return TRUE

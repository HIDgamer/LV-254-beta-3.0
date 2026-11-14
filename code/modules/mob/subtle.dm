/mob/verb/subtle_verb(message as text)
	set name = "Subtle"
	set category = "IC"

	message = trim(strip_html(message, MAX_EMOTE_LEN))
	if(!length(message) || !client?.attempt_talking(message))
		return
	subtle_emote(message)

/// An emote only people next to the user can see
/mob/proc/subtle_emote(message)
	if(stat != CONSCIOUS)
		to_chat(src, SPAN_WARNING("You can't do that right now."))
		return
	var/formatted_message = SPAN_EMOTE("<b>[get_paygrade()][src]</b> [message]")
	var/list/recipients = list()
	for(var/mob/viewer in view(1, src))
		recipients += viewer
		viewer.show_message(formatted_message)
	log_emote("[name]/[key] (subtle): [message]")
	for(var/mob/ghost as anything in GLOB.dead_mob_list)
		if(!ghost.client || isnewplayer(ghost) || (ghost in recipients))
			continue
		if(ghost.client.prefs.toggles_chat & CHAT_GHOSTSIGHT)
			ghost.show_message(SPAN_EMOTE("<b>[get_paygrade()][src]</b> (subtle) [message]"))

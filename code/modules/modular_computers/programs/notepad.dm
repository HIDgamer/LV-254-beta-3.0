/datum/computer_file/program/notepad
	filename = "notepad"
	filedesc = "Notepad"
	extended_desc = "Jot down your work-safe thoughts and what not."
	tgui_id = "NtosNotepad"
	program_icon = "book"
	program_open_overlay = "generic"

	var/written_note = ""
	COOLDOWN_DECLARE(last_print)

/datum/computer_file/program/notepad/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("UpdateNote")
			written_note = copytext(params["newnote"], 1, 4096)
			return TRUE
		if("PrintNote")
			print_note(ui.user)
			return TRUE

/datum/computer_file/program/notepad/ui_data(mob/user)
	var/list/data = list()
	data["note"] = written_note
	data["can_print"] = computer.can_print_notes
	return data

/datum/computer_file/program/notepad/proc/print_note(mob/user)
	if(!computer.can_print_notes || !length(written_note))
		return
	if(!COOLDOWN_FINISHED(src, last_print))
		to_chat(user, SPAN_WARNING("\The [computer] is still printing."))
		return
	COOLDOWN_START(src, last_print, 10 SECONDS)
	playsound(computer, 'sound/machines/terminal_processing.ogg', 25, TRUE)
	var/obj/item/paper/page = new(get_turf(computer))
	page.name = "Note from [computer.saved_identification || "Unknown"]"
	page.info = "<b>[computer.saved_identification] ([computer.saved_job])</b> <i>[worldtime2text()]</i><hr>[replacetext(strip_html(written_note, 4096), "\n", "<br>")]"
	page.update_icon()
	user?.put_in_hands(page)
	to_chat(user, SPAN_NOTICE("\The [computer] prints a page."))

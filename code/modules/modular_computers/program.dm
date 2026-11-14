/datum/computer_file
	var/filename = "NewFile"
	var/filetype = "XXX"
	var/obj/item/modular_computer/computer

/datum/computer_file/Destroy()
	computer = null
	return ..()

/// Software running on a modular computer
/datum/computer_file/program
	filetype = "PRG"
	filename = "UnknownProgram"
	/// User-friendly name of this program
	var/filedesc = "Unknown Program"
	var/extended_desc = "N/A"
	var/program_flags = NONE
	/// Font Awesome icon shown in the computer's main menu
	var/program_icon = "window-maximize-o"
	/// Screen overlay shown on the computer while this program is open
	var/program_open_overlay = "generic"
	/// Name of the tgui interface
	var/tgui_id
	var/alert_able = FALSE
	var/alert_silenced = FALSE
	var/alert_pending = FALSE
	var/always_update_ui = FALSE
	/// Accesses needed to run the program, any one will do
	var/list/run_access = list()

/datum/computer_file/program/tgui_interact(mob/user, datum/tgui/ui)
	return

/datum/computer_file/program/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	return

/datum/computer_file/program/proc/can_run(mob/user, loud = FALSE)
	if(!length(run_access))
		return TRUE

	var/list/found_access = computer?.get_computer_access()
	if(!length(found_access))
		if(loud && user)
			to_chat(user, SPAN_DANGER("\The [computer] flashes an \"RFID Error - Unable to scan ID\" warning."))
		return FALSE

	for(var/singular_access in run_access)
		if(singular_access in found_access)
			return TRUE

	if(loud && user)
		to_chat(user, SPAN_DANGER("\The [computer] flashes an \"Access Denied\" warning."))
	return FALSE

/datum/computer_file/program/proc/on_install()
	return

/datum/computer_file/program/proc/on_imprint()
	return

/datum/computer_file/program/proc/on_start(mob/living/user)
	return can_run(user, loud = TRUE)

/datum/computer_file/program/proc/kill_program(mob/user)
	if(src == computer.active_program)
		computer.active_program = null
		computer.update_icon()
		if(!QDELETED(computer) && computer.enabled)
			INVOKE_ASYNC(computer, TYPE_PROC_REF(/obj/item/modular_computer, update_open_uis), user)
	computer.idle_threads -= src
	return TRUE

/// Sends the program to the background, header programs are closed instead
/datum/computer_file/program/proc/background_program(mob/user)
	if(program_flags & PROGRAM_HEADER)
		return kill_program(user)

	computer.idle_threads += src
	computer.active_program = null
	computer.update_icon()
	if(user)
		INVOKE_ASYNC(computer, TYPE_PROC_REF(/obj/item/modular_computer, update_open_uis), user)
	return TRUE

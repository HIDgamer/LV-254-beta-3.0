/// Opens the crew tracker for the computer it is installed on
/datum/computer_file/program/lifeline
	filename = "lifeline"
	filedesc = "Lifeline"
	extended_desc = "Tracks crew members whose suit sensors are set to maximum."
	program_icon = "heartbeat"
	program_open_overlay = "radarntos"

	var/datum/radar/lifeline/radar

/datum/computer_file/program/lifeline/on_install()
	radar = new(computer, FACTION_MARINE)

/datum/computer_file/program/lifeline/Destroy()
	QDEL_NULL(radar)
	return ..()

/datum/computer_file/program/lifeline/on_start(mob/living/user)
	. = ..()
	if(!.)
		return
	radar.tgui_interact(user)
	return FALSE

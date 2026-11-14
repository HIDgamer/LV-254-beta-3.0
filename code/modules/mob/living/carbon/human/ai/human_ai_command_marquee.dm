/// Turns drag selection on or off, one drag across the map selects every AI human inside the box
/datum/npc_command_console/proc/toggle_marquee_mode(mob/user)
	if(!owner)
		return
	if(marquee_active)
		end_marquee()
		to_chat(user, SPAN_NOTICE("Marquee select disabled."))
		return
	RegisterSignal(owner, COMSIG_MOB_MOUSEDOWN, PROC_REF(on_marquee_mousedown))
	RegisterSignal(owner, COMSIG_MOB_MOUSEDRAG, PROC_REF(on_marquee_mousedrag))
	RegisterSignal(owner, COMSIG_MOB_MOUSEUP, PROC_REF(on_marquee_mouseup))
	marquee_active = TRUE
	to_chat(user, SPAN_NOTICE("Marquee select enabled, drag across the map to box-select. It switches off after one drag."))

/datum/npc_command_console/proc/end_marquee()
	if(owner)
		UnregisterSignal(owner, list(COMSIG_MOB_MOUSEDOWN, COMSIG_MOB_MOUSEDRAG, COMSIG_MOB_MOUSEUP))
	clear_marquee_highlight()
	marquee_start_turf = null
	marquee_active = FALSE

/datum/npc_command_console/proc/clear_marquee_highlight()
	for(var/turf/highlighted as anything in marquee_highlighted_turfs)
		highlighted.color = null
	marquee_highlighted_turfs = null

/datum/npc_command_console/proc/on_marquee_mousedown(mob/source, atom/A, turf/T, skin_ctl, params)
	SIGNAL_HANDLER
	if(T)
		marquee_start_turf = T

/datum/npc_command_console/proc/on_marquee_mousedrag(mob/source, atom/src_obj, atom/over_obj, turf/src_loc, turf/over_loc, src_ctl, over_ctl, params)
	SIGNAL_HANDLER
	if(!marquee_start_turf || !over_loc || marquee_start_turf.z != over_loc.z)
		return
	clear_marquee_highlight()
	marquee_highlighted_turfs = list()
	for(var/turf/candidate in block(marquee_start_turf, over_loc))
		candidate.color = "#66ff6640"
		marquee_highlighted_turfs += candidate

/datum/npc_command_console/proc/on_marquee_mouseup(mob/source, atom/A, turf/T, skin_ctl, params)
	SIGNAL_HANDLER
	var/turf/start = marquee_start_turf
	end_marquee()
	if(!start || !T || start.z != T.z)
		return
	select_box(start, T)
	to_chat(source, SPAN_NOTICE("Selected [length(selection.selected)] AI humans."))

/// Selects every AI human standing in the box between the two turfs
/datum/npc_command_console/proc/select_box(turf/first, turf/second)
	var/count = 0
	for(var/turf/candidate in block(first, second))
		for(var/mob/living/carbon/human/human in candidate)
			if(selection.select(human))
				count++
	sync_click_intercept()
	refresh()
	return count

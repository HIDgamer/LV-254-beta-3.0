/// Admin controlled measures that cut server load at the cost of some polish
SUBSYSTEM_DEF(lag_switch)
	name = "Lag Switch"
	flags = SS_NO_FIRE

	var/list/measures = new /list(MEASURES_AMOUNT)
	/// Connected clients at which every measure switches on by itself, 0 means never
	var/trigger_pop = 0
	var/auto_triggered = FALSE

/datum/controller/subsystem/lag_switch/Initialize()
	for(var/index in 1 to MEASURES_AMOUNT)
		measures[index] = FALSE
	trigger_pop = CONFIG_GET(number/auto_lag_switch_pop)
	return SS_INIT_SUCCESS

/datum/controller/subsystem/lag_switch/proc/get_measure_name(measure)
	switch(measure)
		if(DISABLE_FOOTSTEPS)
			return "Footstep sounds"
		if(DISABLE_TALK_SOUNDS)
			return "Talk sounds"
		if(DISABLE_LANGCHAT)
			return "Chat text over speakers"

/datum/controller/subsystem/lag_switch/proc/set_measure(measure, state)
	if(measure < 1 || measure > MEASURES_AMOUNT || !!measures[measure] == !!state)
		return FALSE
	measures[measure] = !!state
	to_chat(world, SPAN_BOLDANNOUNCE("[get_measure_name(measure)] have been [state ? "disabled" : "re-enabled"] for performance concerns."))
	return TRUE

/datum/controller/subsystem/lag_switch/proc/set_all_measures(state)
	for(var/index in 1 to MEASURES_AMOUNT)
		set_measure(index, state)

/// Switches every measure on once the connected clients reach the configured population
/datum/controller/subsystem/lag_switch/proc/client_connected()
	if(!trigger_pop || auto_triggered || length(GLOB.clients) < trigger_pop)
		return
	auto_triggered = TRUE
	message_admins("Lag Switch population threshold reached, lag mitigation measures are being switched on.")
	set_all_measures(TRUE)

/datum/admins/proc/lag_switch()
	set name = "Lag Switch"
	set category = "Server"
	set desc = "Turns server load reducing measures on or off."

	var/list/choices = list("Switch everything on" = 0, "Switch everything off" = 0)
	for(var/index in 1 to MEASURES_AMOUNT)
		choices["[SSlag_switch.get_measure_name(index)]: [SSlag_switch.measures[index] ? "off" : "on"]"] = index
	var/choice = tgui_input_list(usr, "Pick a measure to toggle", "Lag Switch", choices)
	if(!choice)
		return
	switch(choice)
		if("Switch everything on")
			SSlag_switch.set_all_measures(TRUE)
		if("Switch everything off")
			SSlag_switch.set_all_measures(FALSE)
		else
			var/measure = choices[choice]
			SSlag_switch.set_measure(measure, !SSlag_switch.measures[measure])
	message_admins("[key_name_admin(usr)] used the lag switch: [choice].")

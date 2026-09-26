/datum/action/human_action/synth_bracer/tactical_map
	name = "View Tactical Map"
	action_icon_state = "minimap"

	var/datum/tacmap/tacmap
	var/minimap_type = MINIMAP_FLAG_USCM
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/tactical_map/New()
	. = ..()
	tacmap = new(src, minimap_type)

/datum/action/human_action/synth_bracer/tactical_map/Destroy()
	QDEL_NULL(tacmap)
	return ..()

/datum/action/human_action/synth_bracer/tactical_map/action_activate()
	..()
	if(COOLDOWN_FINISHED(synth_bracer, sound_cooldown))
		COOLDOWN_START(synth_bracer, sound_cooldown, 5 SECONDS)
		playsound(synth_bracer, 'sound/machines/terminal_processing.ogg', 35, TRUE)
	tacmap.tgui_interact(usr)

/// Chip action for the live tactical map upgrade.
/// Toggles the live tactical map (same feed as the CO tablet) with drawing tools.
/datum/action/human_action/synth_bracer/live_tactical_map
	name = "Toggle Live Tactical Map"
	action_icon_state = "minimap"
	handles_cooldown = TRUE
	handles_charge_cost = TRUE
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/live_tactical_map/can_use_action()
	if(!synth_bracer.live_tacmap)
		to_chat(synth, SPAN_WARNING("Live tactical map module not installed."))
		return FALSE
	if(!synth.client)
		return FALSE
	return ..()

/datum/action/human_action/synth_bracer/live_tactical_map/form_call(obj/item/clothing/gloves/synth/bracer, mob/user)
	if(!user.client)
		return
	var/datum/tacmap/live_tacmap = bracer.live_tacmap
	if(!live_tacmap)
		return
	var/datum/tgui/open_ui = SStgui.get_open_ui(user, live_tacmap)
	if(open_ui)
		open_ui.close()
		to_chat(user, SPAN_NOTICE("You close the live tactical map."))
	else
		live_tacmap.tgui_interact(user)
		to_chat(user, SPAN_NOTICE("You open the live tactical map."))

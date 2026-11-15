/// Starts holding the target at gunpoint with the gun in the active hand
/mob/living/carbon/human/proc/hold_up(mob/living/carbon/human/target)
	var/obj/item/weapon/gun/weapon = get_active_hand()
	if(!istype(weapon) || !istype(target) || target == src || target.stat == DEAD || is_mob_incapacitated())
		return
	if(GetComponent(/datum/component/gunpoint))
		to_chat(src, SPAN_WARNING("You are already holding someone at gunpoint."))
		return
	if(get_dist(src, target) > 5 || !can_see(src, target, 5))
		to_chat(src, SPAN_WARNING("You need a clear view of [target] to hold them up."))
		return
	AddComponent(/datum/component/gunpoint, target, weapon)

/mob/living/carbon/human/proc/lower_aim()
	var/datum/component/gunpoint/aim = GetComponent(/datum/component/gunpoint)
	if(aim)
		qdel(aim)

/// Picks which actions of someone held at gunpoint make this human mag dump
/mob/living/carbon/human/proc/choose_gunpoint_triggers()
	var/list/options = list(
		"Moving" = GUNPOINT_TRIGGER_MOVE,
		"Drawing or using items" = GUNPOINT_TRIGGER_ITEMS,
		"Using the radio" = GUNPOINT_TRIGGER_COMMS,
	)
	var/list/labels = list()
	for(var/option in options)
		labels["[option]: [(gunpoint_triggers & options[option]) ? "on" : "off"]"] = options[option]
	var/picked = tgui_input_list(src, "Which actions of someone you hold at gunpoint make you open fire? Fire from their own gun always does.", "Gunpoint Triggers", labels)
	if(!picked)
		return
	gunpoint_triggers ^= labels[picked]
	to_chat(src, SPAN_NOTICE("Gunpoint triggers are now: [gunpoint_triggers & GUNPOINT_TRIGGER_MOVE ? "moving " : ""][gunpoint_triggers & GUNPOINT_TRIGGER_ITEMS ? "items " : ""][gunpoint_triggers & GUNPOINT_TRIGGER_COMMS ? "radio " : ""]. They apply the next time you hold someone up."))

/mob/living/carbon/human/verb/gunpoint_triggers_verb()
	set name = "Gunpoint Triggers"
	set category = "IC"

	choose_gunpoint_triggers()

/mob/living/carbon/human/verb/hold_up_verb()
	set name = "Hold Up"
	set category = "IC"

	hold_up_prompt()

/// Asks who in sight to hold at gunpoint with the gun in the active hand
/mob/living/carbon/human/proc/hold_up_prompt()
	if(!istype(get_active_hand(), /obj/item/weapon/gun))
		to_chat(src, SPAN_WARNING("You need a gun in your active hand to hold someone up."))
		return
	var/list/targets = list()
	for(var/mob/living/carbon/human/candidate in view(5, src))
		if(candidate == src || candidate.stat == DEAD)
			continue
		var/label = "[candidate.name]"
		var/duplicate = 1
		while(targets[label])
			duplicate++
			label = "[candidate.name] #[duplicate]"
		targets[label] = candidate
	if(!length(targets))
		to_chat(src, SPAN_WARNING("There is nobody nearby to hold up."))
		return
	var/picked = tgui_input_list(src, "Who do you hold at gunpoint?", "Hold Up", targets)
	if(!picked || !targets[picked])
		return
	hold_up(targets[picked])

/mob/living/carbon/human/verb/lower_aim_verb()
	set name = "Lower Aim"
	set category = "IC"

	if(!GetComponent(/datum/component/gunpoint))
		to_chat(src, SPAN_WARNING("You are not holding anyone at gunpoint."))
		return
	lower_aim()

/// The button on the HUD for the Hold Up verb, pressed again while someone is held it lowers the aim
/datum/action/human_action/hold_up
	name = "Hold Up"
	action_icon_state = "spotter_target"

/datum/action/human_action/hold_up/action_activate()
	. = ..()
	var/mob/living/carbon/human/holder = owner
	if(!istype(holder))
		return
	if(holder.GetComponent(/datum/component/gunpoint))
		holder.lower_aim()
		return
	holder.hold_up_prompt()

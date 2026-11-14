GLOBAL_LIST_INIT(human_ai_intent_names, list(
	"idle", "alert", "investigate", "engage", "advance", "hold", "fallback", "broken", "ordered"
))

/datum/human_ai_brain/proc/intent_name()
	return GLOB.human_ai_intent_names[intent] || "unknown"

/// Shows the intent over the head while AI debugging is on, clears it when it goes off
/datum/human_ai_brain/proc/update_debug_text()
	if(GLOB.ai_debug_pathing)
		body.maptext_width = 96
		body.maptext_x = -32
		body.maptext_y = 32
		body.maptext = MAPTEXT("[intent_name()] t[tier]")
		debug_text_shown = TRUE
	else if(debug_text_shown)
		body.maptext = null
		debug_text_shown = FALSE

/datum/human_ai_brain/proc/describe()
	var/list/lines = list()
	lines += "<b>[body]</b> ([body.type]) at [body.x],[body.y],[body.z]"
	lines += "personality [personality.id], intent [intent_name()], tier [tier], stress [stress]"
	lines += "target [get_target() || "none"], waypoint [waypoint ? "[waypoint.x],[waypoint.y]" : "none"]"
	lines += "thinks [think_count], errors [error_total]"
	lines += "<hr>"
	for(var/index in length(decision_log) to 1 step -1)
		lines += decision_log[index]
	return lines.Join("<br>")

/client/proc/debug_view_human_ai()
	set category = "Debug"
	set name = "View Human AI"

	var/mob/living/carbon/human/target = tgui_input_list(src, "Which AI human?", "View Human AI", GLOB.ai_human_list)
	if(!target?.ai_brain)
		return
	usr << browse(target.ai_brain.describe(), "window=hai_[REF(target)];size=520x420")

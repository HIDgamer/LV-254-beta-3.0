/// Whether the other faction is one this brain's faction fights on sight
/datum/human_ai_brain/proc/faction_is_enemy(other_faction)
	switch(aggression)
		if(HAI_AGGRO_OTHERS)
			return TRUE
		if(HAI_AGGRO_NONE)
			return FALSE
	if(enemy_factions)
		return !!(other_faction in enemy_factions)
	return human_ai_faction_relation(body.faction, other_faction) == HAI_REL_HOSTILE

/client/proc/debug_set_human_ai_hostility()
	set category = "Debug"
	set name = "Set Human AI Hostility"

	var/mob/living/carbon/human/target = tgui_input_list(src, "Which AI human?", "Set Human AI Hostility", GLOB.ai_human_list)
	if(!target?.ai_brain)
		return
	var/choice = tgui_input_list(src, "Who does it fight?", "Set Human AI Hostility", list("Enemy factions only", "Every human of another faction", "No humans"))
	if(!choice)
		return
	switch(choice)
		if("Enemy factions only")
			target.ai_brain.aggression = HAI_AGGRO_FACTIONS
		if("Every human of another faction")
			target.ai_brain.aggression = HAI_AGGRO_OTHERS
		if("No humans")
			target.ai_brain.aggression = HAI_AGGRO_NONE
	target.ai_brain.log_decision("hostility set to [choice]")
	message_admins("[key_name_admin(src)] set the hostility of [target] to [choice].")

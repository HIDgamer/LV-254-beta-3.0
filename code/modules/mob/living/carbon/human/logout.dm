/mob/living/carbon/human/Logout()
	..()
	if(species)
		species.handle_logout_special(src)
	if(was_human_ai_spawned && !ai_brain)
		reattach_human_ai_on_disconnect(src)
	return

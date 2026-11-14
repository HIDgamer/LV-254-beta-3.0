/// Hold-to-sprint: faster steps that drain a regenerating energy pool

/// Brief puff of dust at a sprinter's feet
/obj/effect/sprint_dust
	icon = 'icons/effects/sprint_dust.dmi'
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/sprint_dust/proc/appear(state, direction, turf/location, duration)
	if(!location)
		return
	if(state == "sprint_cloud")
		dir = SOUTH
	else
		dir = direction
	forceMove(location)
	flick(state, src)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom/movable, moveToNullspace)), duration)

/mob/living/carbon/human/proc/get_sprint_energy()
	var/regen_start = max(sprint_energy_time, sprint_rest_until)
	if(world.time > regen_start)
		sprint_energy = min(SPRINT_ENERGY_MAX, sprint_energy + (world.time - regen_start) * SPRINT_ENERGY_REGEN)
		sprint_energy_time = world.time
	return sprint_energy

/mob/living/carbon/human/proc/can_sprint()
	if(stat != CONSCIOUS || body_position == LYING_DOWN || buckled || pulling || legcuffed || isyautja(src))
		return FALSE
	if(m_intent != MOVE_INTENT_RUN)
		return FALSE
	return get_sprint_energy() >= (sprint_exhausted ? SPRINT_RESUME_ENERGY : 1)

/mob/living/carbon/human/proc/start_sprint()
	if(sprinting)
		return
	if(!can_sprint())
		if(sprint_exhausted && stat == CONSCIOUS)
			to_chat(src, SPAN_WARNING(issynth(src) ? "You are overheating too much to sprint." : "You're too out of breath to sprint."))
		return
	sprint_exhausted = FALSE
	sprinting = TRUE
	sprint_streak = 0
	recalculate_move_delay = TRUE

/mob/living/carbon/human/proc/stop_sprint()
	if(!sprinting)
		return
	sprinting = FALSE
	recalculate_move_delay = TRUE
	if(sprint_streak >= SPRINT_SUSTAINED_TILES)
		sprint_dust?.appear("sprint_cloud_small", dir, get_turf(src), 0.4 SECONDS)
	sprint_streak = 0
	sprint_dir = 0

/// Ends the sprint when the human can no longer keep it up, called before every step
/mob/living/carbon/human/proc/validate_sprint()
	if(!sprinting)
		return
	if(!can_sprint())
		stop_sprint()

/// Called after every step taken while sprinting
/mob/living/carbon/human/proc/on_sprint_step(direction)
	if(!sprint_dust)
		sprint_dust = new
	if(!sprint_dir)
		sprint_dust.appear("sprint_cloud", direction, get_turf(src), 0.6 SECONDS)
	else if(direction & turn(sprint_dir, 180))
		sprint_dust.appear("sprint_cloud_tiny", direction, get_turf(src), 0.3 SECONDS)
		sprint_streak = 0
	sprint_dir = direction
	sprint_streak++
	var/energy = get_sprint_energy() - SPRINT_ENERGY_COST
	sprint_energy = max(energy, 0)
	sprint_energy_time = world.time
	sprint_rest_until = world.time + SPRINT_REGEN_DELAY
	if(energy > 0)
		return
	sprint_exhausted = TRUE
	stop_sprint()
	if(issynth(src))
		to_chat(src, SPAN_WARNING("You are overheating!"))
		return
	to_chat(src, SPAN_WARNING("You're out of breath!"))
	emote("gasp")

/datum/keybinding/human/sprint
	hotkey_keys = list("Shift")
	classic_keys = list("Shift")
	name = "sprint"
	full_name = "Sprint"
	description = "Hold to run faster until you run out of energy"
	keybind_signal = COMSIG_KB_HUMAN_SPRINT_DOWN

/datum/keybinding/human/sprint/can_use(client/user)
	return ishuman(user.mob)

/datum/keybinding/human/sprint/down(client/user)
	. = ..()
	if(.)
		return
	var/mob/living/carbon/human/human = user.mob
	human.start_sprint()
	return TRUE

/datum/keybinding/human/sprint/up(client/user)
	. = ..()
	if(.)
		return
	var/mob/living/carbon/human/human = user.mob
	human.stop_sprint()

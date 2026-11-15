/**
 * Mounted machineguns. A unit with an enemy in sight goes to a machinegun nest close by that nobody is on and has ammo in it, takes its hands off its own weapon,
 * mans the gun and fires it in bursts at the enemy, and lets go of it when there is nothing left to shoot at, the ammo is gone or things go badly.
 */

/// The mounted gun the body is manning right now, null when it is on none
/datum/human_ai_brain/proc/manned_emplacement()
	RETURN_TYPE(/obj/structure/machinery/m56d_hmg)
	var/obj/structure/machinery/m56d_hmg/gun = body.interactee
	if(istype(gun) && gun.operator == body && !QDELETED(gun))
		return gun
	return null

/// Where a man stands to man the gun: behind it
/datum/human_ai_brain/proc/emplacement_mount_turf(obj/structure/machinery/m56d_hmg/gun)
	return get_step(gun, turn(gun.dir, 180))

/// Whether the gun is a nest a unit can man: it has ammo, nobody on it, a free place to stand and has not been put out of action
/datum/human_ai_brain/proc/emplacement_usable(obj/structure/machinery/m56d_hmg/gun)
	if(QDELETED(gun) || gun.operator || gun.rounds <= 0 || gun.safety || gun.z != body.z)
		return FALSE
	if(gun.health <= gun.health_max * HAI_EMPLACEMENT_MIN_HEALTH)
		return FALSE
	var/turf/stand = emplacement_mount_turf(gun)
	if(!stand || stand.density || is_blocked_turf(stand))
		return FALSE
	for(var/mob/living/occupant in stand)
		if(occupant != body)
			return FALSE
	return TRUE

/// Whether a gun that cannot be turned could fire at the place, the ones that rotate with their gunner cover everything
/datum/human_ai_brain/proc/emplacement_covers(obj/structure/machinery/m56d_hmg/gun, atom/there)
	if(istype(gun, /obj/structure/machinery/m56d_hmg/auto))
		return TRUE
	var/turf/gun_turf = get_turf(gun)
	var/turf/aim_turf = get_turf(there)
	if(!gun_turf || !aim_turf || gun_turf == aim_turf)
		return FALSE
	var/difference = abs(Get_Angle(gun_turf, aim_turf) - dir2angle(gun.dir))
	if(difference > 180)
		difference = 360 - difference
	return difference <= gun.shoot_degree

/// The nearest nest worth going to, looked for every little while
/datum/human_ai_brain/proc/find_emplacement()
	RETURN_TYPE(/obj/structure/machinery/m56d_hmg)
	var/obj/structure/machinery/m56d_hmg/kept = emplacement_ref?.resolve()
	if(world.time < next_emplacement_scan)
		return (kept && emplacement_usable(kept)) ? kept : null
	next_emplacement_scan = world.time + HAI_EMPLACEMENT_SCAN_GAP
	emplacement_ref = null
	var/mob/living/target = get_target()
	var/obj/structure/machinery/m56d_hmg/best
	var/best_distance = INFINITY
	for(var/obj/structure/machinery/m56d_hmg/gun in range(HAI_EMPLACEMENT_RANGE, body))
		var/distance = get_dist(body, gun)
		if(distance >= best_distance || !emplacement_usable(gun))
			continue
		if(target && !emplacement_covers(gun, target))
			continue
		best = gun
		best_distance = distance
	emplacement_ref = best ? WEAKREF(best) : null
	return best

/// Whether the brain is in a state to go and man a gun
/datum/human_ai_brain/proc/emplacement_duty_ok()
	if(is_civilian() || role?.passive || role?.maintains || surrendered || broken_kind || roe == HAI_ROE_WEAPONS_HOLD || current_order?.hard)
		return FALSE
	if(body.is_mob_incapacitated() || body.body_position != STANDING_UP || body.buckled)
		return FALSE
	if(is_acting() || world.time < hands_busy_until || reload_phase != HAI_RELOAD_NONE || suppressed())
		return FALSE
	if(!ishuman(body) || !body.allow_gun_usage)
		return FALSE
	return TRUE

/// Frees both hands for the handles, whatever is in them goes into storage or on the floor where it can be picked up again
/datum/human_ai_brain/proc/free_hands_for_mount()
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun && (gun.flags_item & WIELDED))
		gun.unwield(body)
	for(var/obj/item/held in list(body.get_active_hand(), body.get_inactive_hand()))
		if(!clear_hand(held))
			return FALSE
	return !body.get_active_hand() && !body.get_inactive_hand()

/// Fires a burst at the target from the mounted gun
/datum/human_ai_brain/proc/emplacement_burst(obj/structure/machinery/m56d_hmg/gun, mob/living/victim)
	emplacement_burst_until = world.time + HAI_EMPLACEMENT_BURST_TIME
	for(var/shot in 1 to HAI_EMPLACEMENT_BURST)
		if(QDELETED(src) || QDELETED(body) || QDELETED(gun) || QDELETED(victim) || victim.stat == DEAD || manned_emplacement() != gun || stopped)
			break
		gun.set_target(victim)
		var/before = gun.rounds
		gun.try_fire()
		if(gun.rounds < before)
			emplacement_shots += before - gun.rounds
		sleep(max(1, gun.fire_delay))
	emplacement_burst_until = 0
	if(!QDELETED(gun))
		gun.set_target(null)

/// Goes to a nest and mans it when there is an enemy in sight that the gun can shoot at
/datum/human_ai_action/man_emplacement
	id = "man_emplacement"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/man_emplacement/get_weight(datum/human_ai_brain/brain)
	if(brain.manned_emplacement() || !brain.emplacement_duty_ok())
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || world.time > brain.target_seen_time + HAI_EMPLACEMENT_TARGET_AGE || get_dist(brain.body, target) <= HAI_EMPLACEMENT_MIN_ENEMY)
		return 0
	return brain.find_emplacement() ? 74 : 0

/datum/human_ai_action/man_emplacement/trigger(datum/human_ai_brain/brain)
	var/obj/structure/machinery/m56d_hmg/gun = brain.find_emplacement()
	if(!gun)
		return FALSE
	var/turf/stand = brain.emplacement_mount_turf(gun)
	if(brain.body.loc != stand)
		if(brain.move_to(stand, 0, TRUE))
			return TRUE
		brain.next_emplacement_scan = world.time + HAI_EMPLACEMENT_SCAN_GAP
		brain.emplacement_ref = null
		return FALSE
	brain.cancel_reload("manning")
	if(!brain.free_hands_for_mount())
		brain.emplacement_ref = null
		return FALSE
	brain.body.setDir(gun.dir)
	gun.try_mount_gun(brain.body)
	if(brain.manned_emplacement() != gun)
		brain.log_decision("could not man [gun]")
		brain.emplacement_ref = null
		brain.next_emplacement_scan = world.time + HAI_EMPLACEMENT_SCAN_GAP * 3
		return FALSE
	brain.emplacements_manned++
	brain.emplacement_idle_since = world.time
	brain.log_decision("manned [gun]")
	return TRUE

/// Fires the mounted gun at the enemy in sight
/datum/human_ai_action/fire_emplacement
	id = "fire_emplacement"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/fire_emplacement/get_weight(datum/human_ai_brain/brain)
	var/obj/structure/machinery/m56d_hmg/gun = brain.manned_emplacement()
	if(!gun || world.time < brain.emplacement_burst_until || brain.broken_kind || brain.roe == HAI_ROE_WEAPONS_HOLD)
		return 0
	var/mob/living/target = brain.get_target()
	if(!target || world.time > brain.target_seen_time + 20 || !brain.emplacement_covers(gun, target))
		return 0
	if(brain.wall_in_line(target) || brain.friendly_in_lane(target, 1))
		return 0
	return 125

/datum/human_ai_action/fire_emplacement/trigger(datum/human_ai_brain/brain)
	var/obj/structure/machinery/m56d_hmg/gun = brain.manned_emplacement()
	var/mob/living/target = brain.get_target()
	if(!gun || !target)
		return FALSE
	brain.emplacement_idle_since = world.time
	gun.set_target(target)
	if(istype(gun, /obj/structure/machinery/m56d_hmg/auto))
		var/obj/structure/machinery/m56d_hmg/auto/heavy = gun
		heavy.rotate_to(brain.body, target)
	INVOKE_ASYNC(brain, TYPE_PROC_REF(/datum/human_ai_brain, emplacement_burst), gun, target)
	return TRUE

/// Lets go of the gun when there is nothing to shoot at, nothing to shoot with or nothing to be gained by staying
/datum/human_ai_action/leave_emplacement
	id = "leave_emplacement"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/leave_emplacement/get_weight(datum/human_ai_brain/brain)
	var/obj/structure/machinery/m56d_hmg/gun = brain.manned_emplacement()
	if(!gun)
		return 0
	if(world.time < brain.emplacement_burst_until)
		return 0
	if(gun.rounds <= 0 || gun.health <= gun.health_max * HAI_EMPLACEMENT_MIN_HEALTH || brain.broken_kind || brain.surrendered)
		return 130
	var/mob/living/target = brain.get_target()
	if(target && world.time <= brain.target_seen_time + HAI_EMPLACEMENT_TARGET_AGE && brain.emplacement_covers(gun, target))
		return 0
	return (world.time > brain.emplacement_idle_since + HAI_EMPLACEMENT_IDLE) ? 130 : 0

/datum/human_ai_action/leave_emplacement/trigger(datum/human_ai_brain/brain)
	var/obj/structure/machinery/m56d_hmg/gun = brain.manned_emplacement()
	if(!gun)
		return FALSE
	brain.body.unset_interaction()
	brain.log_decision("let go of [gun]")
	brain.next_emplacement_scan = world.time + HAI_EMPLACEMENT_SCAN_GAP
	return TRUE

/// Stays on the gun between two bursts, so that nothing else sends the body off it
/datum/human_ai_action/hold_emplacement
	id = "hold_emplacement"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/hold_emplacement/get_weight(datum/human_ai_brain/brain)
	return brain.manned_emplacement() ? 100 : 0

/datum/human_ai_action/hold_emplacement/trigger(datum/human_ai_brain/brain)
	var/obj/structure/machinery/m56d_hmg/gun = brain.manned_emplacement()
	if(!gun)
		return FALSE
	brain.body.setDir(gun.dir)
	return TRUE

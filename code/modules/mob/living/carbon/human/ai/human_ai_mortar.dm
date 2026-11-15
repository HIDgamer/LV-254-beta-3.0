/**
 * Mortar crews. A man who carries mortar shells and has a mortar close by listens to what the rest of his side is looking at: when somebody has an enemy in
 * sight that is far enough from the gun and from anyone on the side, he walks to the mortar, dials in the enemy's coordinates and drops a few shells there,
 * then waits a while before he takes another fire mission. The spotter does not have to do anything but see the enemy.
 */

/datum/human_ai_role/mortar
	id = "mortar"
	name = "Mortar crew"

/datum/human_ai_role/mortar/equip_skills(mob/living/carbon/human/body)
	if(!body.skills)
		body.skills = new /datum/skills()
	if(body.skills.get_skill_level(SKILL_ENGINEER) < SKILL_ENGINEER_NOVICE)
		body.skills.set_skill(SKILL_ENGINEER, SKILL_ENGINEER_NOVICE)

/// A mortar shell the body carries, null when it has none
/datum/human_ai_brain/proc/find_mortar_shell()
	RETURN_TYPE(/obj/item/mortar_shell)
	for(var/obj/item/mortar_shell/shell in body.get_contents())
		return shell
	return null

/// The nearest mortar that is set up and ready, null when there is none
/datum/human_ai_brain/proc/find_mortar()
	RETURN_TYPE(/obj/structure/mortar)
	var/obj/structure/mortar/kept = mortar_ref?.resolve()
	if(world.time < next_mortar_scan)
		return (kept && !QDELETED(kept)) ? kept : null
	next_mortar_scan = world.time + HAI_MORTAR_SCAN_GAP
	mortar_ref = null
	var/obj/structure/mortar/best
	var/best_distance = INFINITY
	for(var/obj/structure/mortar/candidate in range(HAI_MORTAR_RANGE, body))
		if(QDELETED(candidate) || candidate.ship_side || candidate.lase_mode || candidate.z != body.z)
			continue
		var/distance = get_dist(body, candidate)
		if(distance < best_distance)
			best = candidate
			best_distance = distance
	mortar_ref = best ? WEAKREF(best) : null
	return best

/**
 * The turf of an enemy somebody on the same side is looking at that the gun can be dialed on: not too close to the gun and in its reach, and with nobody who
 * is not an enemy near enough to be hit by a shell that lands off the mark. Null when there is nothing to fire at.
 */
/datum/human_ai_brain/proc/find_fire_mission(obj/structure/mortar/mortar)
	RETURN_TYPE(/turf)
	var/turf/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/mate as anything in GLOB.ai_human_list)
		if(QDELETED(mate) || mate == body || !mate.ai_brain || mate.faction != body.faction || mate.z != mortar.z)
			continue
		var/datum/human_ai_brain/spotter = mate.ai_brain
		var/mob/living/enemy = spotter.get_target()
		if(!enemy || QDELETED(enemy) || enemy.stat == DEAD || world.time > spotter.target_seen_time + HAI_MORTAR_SPOT_AGE)
			continue
		var/turf/there = get_turf(enemy)
		if(!there || there.z != mortar.z)
			continue
		var/distance = get_dist(mortar, there)
		if(distance < HAI_MORTAR_MIN_DISTANCE || distance > mortar.max_range || distance >= best_distance)
			continue
		var/turf/shell_turf = there
		var/area/impact_area = get_area(shell_turf)
		if(!impact_area || CEILING_IS_PROTECTED(impact_area.ceiling, CEILING_PROTECTION_TIER_2))
			continue
		var/safe = TRUE
		for(var/mob/living/bystander in range(HAI_MORTAR_SAFE_RADIUS, there))
			if(bystander != body && is_protected(bystander))
				safe = FALSE
				break
		if(!safe)
			continue
		best = there
		best_distance = distance
	return best

/// Dials the mortar in on the turf, which takes the time it takes a person
/datum/human_ai_brain/proc/aim_mortar(obj/structure/mortar/mortar, turf/where)
	if(QDELETED(mortar) || QDELETED(body) || !where)
		acting_until = 0
		return
	body.face_atom(mortar)
	mortar.handle_target(body, obfuscate_x(where.x), obfuscate_y(where.y), obfuscate_z(where.z))
	acting_until = 0
	if(mortar.targ_x == where.x && mortar.targ_y == where.y && mortar.targ_z == where.z)
		log_decision("dialed the mortar in on [where.x],[where.y]")
	else
		mortar_mission = null
		next_mortar_mission = world.time + HAI_MORTAR_COOLDOWN

/// Loads a shell, which sets the mortar off
/datum/human_ai_brain/proc/load_mortar(obj/structure/mortar/mortar, obj/item/mortar_shell/shell)
	if(QDELETED(mortar) || QDELETED(body) || QDELETED(shell))
		acting_until = 0
		return
	body.face_atom(mortar)
	if(hand_item(shell))
		mortar.attackby(shell, body)
	acting_until = 0
	if(shell.loc == mortar)
		mortar_shells_fired++
		mortar_mission_shells--
		log_decision("fired a shell at [mortar.targ_x],[mortar.targ_y]")
	else
		mortar_mission = null
		next_mortar_mission = world.time + HAI_MORTAR_COOLDOWN

/// Whether the body has the training and the shells to serve a mortar and is free to do it
/datum/human_ai_brain/proc/mortar_duty_ok()
	if(is_civilian() || surrendered || broken_kind || roe == HAI_ROE_WEAPONS_HOLD || current_order?.hard || world.time < next_mortar_mission)
		return FALSE
	if(!skillcheck(body, SKILL_ENGINEER, SKILL_ENGINEER_NOVICE))
		return FALSE
	if(body.is_mob_incapacitated() || body.body_position != STANDING_UP || is_acting() || world.time < hands_busy_until || suppressed())
		return FALSE
	var/mob/living/target = get_target()
	if(target && world.time <= target_seen_time + 40 && get_dist(body, target) <= HAI_MORTAR_SELF_DEFENSE)
		return FALSE
	return !!find_mortar_shell()

/// A crewman serves the mortar: finds an enemy somebody has spotted, walks to the gun, dials it in and fires a few shells
/datum/human_ai_action/serve_mortar
	id = "serve_mortar"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/serve_mortar/get_weight(datum/human_ai_brain/brain)
	if(!brain.mortar_duty_ok())
		return 0
	var/obj/structure/mortar/mortar = brain.find_mortar()
	if(!mortar || mortar.busy)
		return 0
	if(brain.mortar_mission)
		return (brain.mortar_mission_shells > 0 && !mortar.firing) ? 68 : 0
	return brain.find_fire_mission(mortar) ? 68 : 0

/datum/human_ai_action/serve_mortar/trigger(datum/human_ai_brain/brain)
	var/obj/structure/mortar/mortar = brain.find_mortar()
	if(!mortar)
		return FALSE
	if(!brain.mortar_mission)
		var/turf/where = brain.find_fire_mission(mortar)
		if(!where)
			return FALSE
		brain.mortar_mission = where
		brain.mortar_mission_shells = min(HAI_MORTAR_SHELLS, brain.count_mortar_shells())
		brain.log_decision("fire mission at [where.x],[where.y]")
	if(get_dist(brain.body, mortar) > 1)
		if(brain.move_to(get_turf(mortar), 1, FALSE))
			return TRUE
		brain.mortar_mission = null
		brain.next_mortar_mission = world.time + HAI_MORTAR_COOLDOWN
		return FALSE
	if(brain.mortar_mission_shells <= 0)
		brain.mortar_mission = null
		brain.next_mortar_mission = world.time + HAI_MORTAR_COOLDOWN
		return FALSE
	var/turf/where = brain.mortar_mission
	if(mortar.targ_x != where.x || mortar.targ_y != where.y || mortar.targ_z != where.z)
		brain.acting_until = world.time + 6 SECONDS
		INVOKE_ASYNC(brain, TYPE_PROC_REF(/datum/human_ai_brain, aim_mortar), mortar, where)
		return TRUE
	var/obj/item/mortar_shell/shell = brain.find_mortar_shell()
	if(!shell)
		brain.mortar_mission = null
		brain.next_mortar_mission = world.time + HAI_MORTAR_COOLDOWN
		return FALSE
	brain.acting_until = world.time + 4 SECONDS
	INVOKE_ASYNC(brain, TYPE_PROC_REF(/datum/human_ai_brain, load_mortar), mortar, shell)
	return TRUE

/// How many shells the body carries
/datum/human_ai_brain/proc/count_mortar_shells()
	var/count = 0
	for(var/obj/item/mortar_shell/shell in body.get_contents())
		count++
	return count

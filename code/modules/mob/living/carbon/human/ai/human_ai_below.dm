/**
 * Enemies on another level. Nothing that is shot crosses from one level to the next, but a gap in the floor shows what is below it and whatever is dropped through
 * it lands there. A unit that sees an enemy through a gap calls it out, drops a grenade through the gap onto it when it has one and no friend is near the spot, and
 * otherwise goes after it by whatever ladder or stair leads down.
 */

/// The first enemy standing under a gap in the floor of the level the body is on, within sight, null when there is none. Sets below_gap and below_turf to where it is.
/datum/human_ai_brain/proc/find_enemy_below(turf/here)
	RETURN_TYPE(/mob/living)
	if(!SSmapping.get_turf_below(here))
		return null
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/turf/open_space/gap in view(HAI_BELOW_RANGE, body))
		var/distance = get_dist(here, gap)
		if(distance >= best_distance)
			continue
		var/turf/floor = SSmapping.get_turf_below(gap)
		while(istype(floor, /turf/open_space))
			floor = SSmapping.get_turf_below(floor)
		if(!floor)
			continue
		for(var/mob/living/candidate in floor)
			if(candidate.stat == DEAD || get_disposition(candidate) < HAI_DISP_HOSTILE)
				continue
			if(!clarity_of(candidate, floor, distance))
				continue
			best = candidate
			best_distance = distance
			below_gap = gap
			below_turf = floor
			break
	return best

/// Looks through the gaps in the floor now and then, and calls out what is seen below the first time it is
/datum/human_ai_brain/proc/scan_below(turf/here)
	if(world.time < next_below_scan)
		return
	next_below_scan = world.time + HAI_BELOW_SCAN_GAP
	var/mob/living/enemy = find_enemy_below(here)
	if(!enemy)
		return
	if(world.time > below_seen_time + HAI_BELOW_MEMORY)
		log_decision("[enemy] is below, seen through the gap at [below_gap.x],[below_gap.y]")
		express(HAI_EXPR_CONTACT, "below")
		below_hunt_until = 0
	below_ref = WEAKREF(enemy)
	below_seen_time = world.time

/// The enemy seen below lately, null when there is none to speak of
/datum/human_ai_brain/proc/get_enemy_below(fresh = HAI_BELOW_MEMORY)
	RETURN_TYPE(/mob/living)
	var/mob/living/enemy = below_ref?.resolve()
	if(!enemy || QDELETED(enemy) || enemy.stat == DEAD || world.time > below_seen_time + fresh)
		return null
	return enemy

/// Whether a grenade dropped through the gap spares everyone it should and has a clear way there
/datum/human_ai_brain/proc/plunge_is_safe(mob/living/enemy)
	var/turf/here = get_turf(body)
	if(!below_gap || !below_turf || !istype(below_gap, /turf/open_space) || get_dist(here, below_gap) < HAI_BELOW_GRENADE_MIN)
		return FALSE
	for(var/mob/living/bystander in view(HAI_BELOW_SAFE_RADIUS, below_turf))
		if(bystander != enemy && is_protected(bystander))
			return FALSE
	// A thrown grenade stops at the first wall or body in its way
	for(var/turf/line_turf in get_line(here, below_gap))
		if(line_turf == below_gap || line_turf == here)
			continue
		if(line_turf.density || line_turf.opacity)
			return FALSE
		for(var/mob/living/in_flight in line_turf)
			if(is_protected(in_flight))
				return FALSE
	return TRUE

/// Whether the body can and should drop a grenade on the enemy below
/datum/human_ai_brain/proc/plunge_ready()
	var/mob/living/enemy = get_enemy_below(HAI_BELOW_FRESH)
	if(!enemy || is_civilian() || surrendered || broken_kind || roe == HAI_ROE_WEAPONS_HOLD)
		return FALSE
	if(world.time < next_grenade_time || world.time < grenade_blocked_until || world.time < hands_busy_until || is_acting() || reload_phase != HAI_RELOAD_NONE)
		return FALSE
	// Somebody on this level comes first
	if(get_target() && world.time <= target_seen_time + 20)
		return FALSE
	if(!find_grenade(HAI_GRENADE_LETHAL))
		return FALSE
	return plunge_is_safe(enemy)

/// A unit that sees an enemy through a gap in the floor drops a grenade through it
/datum/human_ai_action/drop_grenade_below
	id = "drop_grenade_below"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_INVESTIGATE, HAI_INTENT_ENGAGE, HAI_INTENT_ADVANCE, HAI_INTENT_HOLD)

/datum/human_ai_action/drop_grenade_below/get_weight(datum/human_ai_brain/brain)
	return brain.plunge_ready() ? 74 : 0

/datum/human_ai_action/drop_grenade_below/trigger(datum/human_ai_brain/brain)
	var/obj/item/explosive/grenade/grenade = brain.find_grenade(HAI_GRENADE_LETHAL)
	if(!grenade || !brain.below_gap)
		return FALSE
	if(brain.throw_grenade(grenade, brain.below_gap, FALSE))
		brain.plunges++
		return TRUE
	return FALSE

/// A unit with nothing to drop that has seen an enemy below goes after it, by the ladder or the stair that leads down
/datum/human_ai_action/hunt_below
	id = "hunt_below"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT)

/datum/human_ai_action/hunt_below/get_weight(datum/human_ai_brain/brain)
	if(!brain.get_enemy_below() || !brain.below_turf || world.time < brain.below_blocked_until)
		return 0
	if(brain.is_civilian() || brain.role?.passive || brain.role?.maintains || brain.surrendered || brain.broken_kind || brain.leash_center || brain.ride_ref)
		return 0
	if(brain.roe == HAI_ROE_WEAPONS_HOLD || brain.get_target() || brain.is_acting() || brain.current_order?.hard)
		return 0
	// A grenade that can be dropped is dropped first
	if(brain.plunge_ready())
		return 0
	return 30

/datum/human_ai_action/hunt_below/trigger(datum/human_ai_brain/brain)
	if(!brain.below_hunt_until)
		brain.below_hunt_until = world.time + HAI_BELOW_HUNT_TIME
	if(world.time > brain.below_hunt_until)
		brain.below_ref = null
		brain.below_hunt_until = 0
		brain.below_blocked_until = world.time + HAI_BELOW_HUNT_TIME
		return FALSE
	if(brain.move_to(brain.below_turf, 2, FALSE))
		return TRUE
	brain.log_decision("no way down after the enemy below")
	brain.below_ref = null
	brain.below_hunt_until = 0
	brain.below_blocked_until = world.time + HAI_BELOW_HUNT_TIME
	return FALSE

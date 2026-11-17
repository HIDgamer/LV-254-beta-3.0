/**
 * The cloak of a scout. A unit that wears an optical camouflage cloak puts it on the way a scout would: to get away when it is hurt or pinned down with an enemy
 * near, to close in on an enemy that is still far off without being seen, and to go unseen along a patrol or an order. It takes it off again when there is nothing
 * left to hide from. A sniper, or anyone who has settled in a place and means to stay, hides in it or in a ghillie suit and waits.
 */

/// The cloak the body wears on its back, null when it wears none
/datum/human_ai_brain/proc/worn_cloak()
	RETURN_TYPE(/obj/item/storage/backpack/marine/satchel/scout_cloak)
	var/obj/item/storage/backpack/marine/satchel/scout_cloak/cloak = body.back
	return istype(cloak) ? cloak : null

/// Whether the wearer knows how to work the cloak, it refuses anyone else
/datum/human_ai_brain/proc/can_use_cloak()
	return skillcheck(body, SKILL_SPEC_WEAPONS, SKILL_SPEC_ALL) || body.skills?.get_skill_level(SKILL_SPEC_WEAPONS) == SKILL_SPEC_SCOUT

/// Whether the body has not moved for the time
/datum/human_ai_brain/proc/still_for(time)
	return world.time >= body.l_move_time + time

/// Whether the body is hurt badly enough to want out of a fight
/datum/human_ai_brain/proc/hurt_badly()
	return body.health < body.maxHealth * HAI_CLOAK_ESCAPE_HEALTH

/**
 * Why the cloak should be on now, null when it should not: "escape" when the body is hurt, pinned down or falling back with an enemy near, "ambush" when an enemy
 * is still far off and the body means to close in, "settled" when it has found its place and stays there, and "patrol" when it walks a patrol or an order and
 * has nobody in sight.
 */
/datum/human_ai_brain/proc/cloak_reason()
	var/mob/living/target = get_target()
	if(target && world.time <= target_seen_time + 4 SECONDS)
		if(hurt_badly() || suppressed() || intent == HAI_INTENT_FALLBACK)
			return "escape"
		if(role?.id != "sniper" && get_dist(body, target) >= HAI_CLOAK_AMBUSH_RANGE && !role?.passive && !role?.ambush)
			return "ambush"
		return null
	if(is_settled() || (role?.nests && still_for(HAI_CAMO_STILL)))
		return "settled"
	if(current_order?.status == HAI_ORDER_ACTIVE && (current_order.id == "patrol" || current_order.id == "move"))
		return "patrol"
	if(waypoint)
		return "patrol"
	return null

/// Puts the cloak on or takes it off, true when it is as wanted afterwards
/datum/human_ai_brain/proc/switch_cloak(obj/item/storage/backpack/marine/satchel/scout_cloak/cloak, on)
	if(QDELETED(cloak) || cloak.camo_active == on)
		return cloak?.camo_active == on
	cloak.try_camouflage(body)
	if(cloak.camo_active != on)
		// A cloak that will not go on is left alone for a while
		next_cloak_time = world.time + HAI_CLOAK_GAP * 3
		return FALSE
	cloak_uses++
	log_decision("[on ? "put on" : "took off"] [cloak.name]")
	return TRUE

/// A scout in a cloak puts it on to get away, to close in, to hold a place or to move unseen, and takes it off when it is done with it
/datum/human_ai_action/use_cloak
	id = "use_cloak"
	conflicts = NONE

/datum/human_ai_action/use_cloak/get_weight(datum/human_ai_brain/brain)
	var/obj/item/storage/backpack/marine/satchel/scout_cloak/cloak = brain.worn_cloak()
	if(!cloak || world.time < brain.next_cloak_time || brain.is_civilian() || brain.surrendered || brain.broken_kind || !brain.can_use_cloak())
		return 0
	if(cloak.cloak_cooldown && cloak.cloak_cooldown > world.time)
		return 0
	if(cloak.camo_active)
		var/active_reason = brain.cloak_reason()
		// Already out of sight, a unit that is hurt or pinned down with the enemy near still gets away from him
		if(active_reason == "escape" && world.time >= brain.next_slip_time && brain.current_order?.id != "fall_back" && brain.body.body_position == STANDING_UP)
			return 96
		if(active_reason || brain.in_contact())
			brain.cloak_idle_since = 0
			return 0
		if(!brain.cloak_idle_since)
			brain.cloak_idle_since = world.time
		return (world.time >= brain.cloak_idle_since + HAI_CLOAK_IDLE) ? 22 : 0
	brain.cloak_idle_since = 0
	if(brain.body.body_position != STANDING_UP || brain.is_acting())
		return 0
	var/reason = brain.cloak_reason()
	if(!reason)
		return 0
	// Getting away from a fight comes before whatever else the unit is doing
	return reason == "escape" ? 96 : 58

/datum/human_ai_action/use_cloak/trigger(datum/human_ai_brain/brain)
	var/obj/item/storage/backpack/marine/satchel/scout_cloak/cloak = brain.worn_cloak()
	if(!cloak)
		return FALSE
	brain.next_cloak_time = world.time + HAI_CLOAK_GAP
	if(cloak.camo_active)
		brain.cloak_idle_since = 0
		if(brain.cloak_reason() == "escape")
			brain.next_slip_time = world.time + HAI_CLOAK_GAP * 2
			return brain.slip_away()
		return brain.switch_cloak(cloak, FALSE)
	var/reason = brain.cloak_reason()
	if(!brain.switch_cloak(cloak, TRUE))
		return FALSE
	brain.log_decision("cloaked to [reason]")
	if(reason == "escape")
		brain.slip_away()
	return TRUE

/// Falls back away from the enemy it is in contact with, unseen
/datum/human_ai_brain/proc/slip_away()
	var/mob/living/target = get_target()
	if(!target || current_order?.id == "fall_back")
		return FALSE
	var/turf/away = retreat_turf(get_turf(target))
	if(!away)
		return FALSE
	var/datum/npc_order/fall_back/retreat = new
	retreat.target_turf = away
	retreat.internal = TRUE
	retreat.issuer = "its own cloak"
	return give_order(retreat)

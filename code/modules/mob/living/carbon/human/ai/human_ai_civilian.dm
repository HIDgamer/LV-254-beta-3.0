/// Whether the turf is under a roof worth hiding beneath
/proc/human_ai_indoors(turf/spot)
	var/area/room = spot?.loc
	return room && room.ceiling != CEILING_NONE && room.ceiling != CEILING_GLASS

/datum/human_ai_brain/proc/is_civilian()
	return role?.id == "civilian"

/datum/human_ai_brain/proc/civilian_alarm()
	return world.time < panic_until

/// Gunfire, blasts, monsters or being shot at send a civilian looking for a roof
/datum/human_ai_brain/proc/panic()
	if(!is_civilian())
		return
	if(!civilian_alarm())
		log_decision("panicking")
	panic_until = world.time + HAI_PANIC_TIME

/// Turfs on the lines between known enemies and the armed friends who would shoot at them
/datum/human_ai_brain/proc/fire_lane_turfs()
	var/list/lanes = list()
	var/list/armed_friends = list()
	for(var/mob/living/carbon/human/friend in view(HAI_SHELTER_RADIUS + 4, body))
		if(friend != body && friend.stat != DEAD && get_disposition(friend) <= HAI_DISP_FRIEND && istype(friend.get_active_hand(), /obj/item/weapon/gun))
			armed_friends += friend
	if(!length(armed_friends))
		return lanes
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(!contact.last_turf || (!contact.visible && contact.confidence < 0.4))
			continue
		for(var/mob/living/carbon/human/friend as anything in armed_friends)
			for(var/turf/lane_turf in get_line(contact.last_turf, friend))
				lanes[lane_turf] = TRUE
	return lanes

/// The roofed turf close by that is farthest from the danger and out of the line of fire
/datum/human_ai_brain/proc/find_shelter()
	var/turf/here = get_turf(body)
	var/turf/threat = threat_turf()
	var/list/lanes = fire_lane_turfs()
	var/turf/best
	var/best_score = -INFINITY
	for(var/turf/open/candidate in range(HAI_SHELTER_RADIUS, here))
		if(!human_ai_indoors(candidate) || !cover_turf_usable(candidate))
			continue
		var/score = -get_dist(here, candidate)
		if(threat)
			score += min(get_dist(candidate, threat), 14) * 0.5
		if(lanes[candidate])
			score -= 20
		if(score > best_score)
			best_score = score
			best = candidate
	return best

/// Already under a roof, well away from the danger and clear of the fire lanes
/datum/human_ai_brain/proc/sheltered_here()
	var/turf/here = get_turf(body)
	if(!human_ai_indoors(here))
		return FALSE
	var/turf/threat = threat_turf()
	if(threat && get_dist(here, threat) < HAI_SHELTER_SAFE_DISTANCE)
		return FALSE
	return !fire_lane_turfs()[here]

/// The nearest friend with a gun in hand, someone worth sticking close to
/datum/human_ai_brain/proc/armed_friend()
	var/mob/living/carbon/human/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/friend in view(HAI_SHELTER_RADIUS + 4, body))
		if(friend == body || friend.stat == DEAD || get_disposition(friend) > HAI_DISP_FRIEND || !istype(friend.get_active_hand(), /obj/item/weapon/gun))
			continue
		var/distance = get_dist(body, friend)
		if(distance < best_distance)
			best_distance = distance
			best = friend
	return best

/// Someone with a gun turned on the body
/datum/human_ai_brain/proc/aimed_at_by()
	for(var/mob/living/carbon/human/other in view(HAI_HANDS_UP_RANGE, body))
		if(other == body || other.stat == DEAD || get_disposition(other) <= HAI_DISP_FRIEND)
			continue
		if(threatened_by(other))
			return other
	return null

/// Runs for a roof when there is danger about, follows an armed friend when there is none, and stays put once under cover
/datum/human_ai_action/civilian_shelter
	id = "civilian_shelter"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_INVESTIGATE, HAI_INTENT_ENGAGE)

/datum/human_ai_action/civilian_shelter/get_weight(datum/human_ai_brain/brain)
	if(!brain.is_civilian() || !brain.civilian_alarm() || brain.broken_kind || brain.surrendered || brain.current_order?.hard)
		return 0
	return 90

/datum/human_ai_action/civilian_shelter/trigger(datum/human_ai_brain/brain)
	if(brain.sheltered_here())
		if(!brain.sheltered)
			brain.sheltered = TRUE
			brain.times_sheltered++
			brain.log_decision("sheltering")
		if(prob(6))
			brain.express(HAI_EXPR_FEAR, null, "tremble")
		brain.shelter_goal = null
		return FALSE
	brain.sheltered = FALSE
	if((!brain.shelter_goal || world.time >= brain.next_shelter_search) && SShuman_ai.take_cover_budget())
		brain.next_shelter_search = world.time + HAI_SHELTER_SEARCH_INTERVAL
		brain.shelter_goal = brain.find_shelter()
	if(brain.shelter_goal)
		if(brain.move_to(brain.shelter_goal, 0, TRUE))
			return TRUE
		brain.shelter_goal = null
		return FALSE
	var/mob/living/carbon/human/guardian = brain.armed_friend()
	if(guardian)
		if(get_dist(brain.body, guardian) > 3)
			brain.followed_armed++
			return brain.follow_leader(guardian, 0)
		return FALSE
	var/turf/threat = brain.threat_turf()
	if(threat)
		var/turf/away = brain.retreat_turf(threat, 12)
		if(away)
			return brain.move_to(away, 1, TRUE)
	return FALSE

/// Hands up for anyone pointing a gun at a civilian who is not brave enough to do anything else
/datum/human_ai_action/hands_up
	id = "hands_up"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_INVESTIGATE, HAI_INTENT_ENGAGE)

/datum/human_ai_action/hands_up/get_weight(datum/human_ai_brain/brain)
	if(!brain.is_civilian() || brain.surrendered || brain.personality.trait("courage") > 50)
		return 0
	return brain.aimed_at_by() ? 96 : 0

/datum/human_ai_action/hands_up/trigger(datum/human_ai_brain/brain)
	brain.begin_surrender()
	brain.surrender_until = world.time + HAI_HANDS_UP_TIME
	brain.hands_up_count++
	brain.express(HAI_EXPR_SURRENDER)
	return TRUE

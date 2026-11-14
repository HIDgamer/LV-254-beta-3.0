/datum/human_ai_action/scan
	id = "scan"

/datum/human_ai_action/scan/get_weight(datum/human_ai_brain/brain)
	return world.time >= brain.next_scan_time ? 100 : 0

/datum/human_ai_action/scan/trigger(datum/human_ai_brain/brain)
	brain.next_scan_time = world.time + ((brain.tier <= HAI_TIER_ENGAGED) ? HAI_SCAN_ENGAGED_INTERVAL : 2)
	brain.perceive()
	brain.refresh_intent()
	return FALSE

/datum/human_ai_action/investigate
	id = "investigate"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_INVESTIGATE)

/datum/human_ai_action/investigate/get_weight(datum/human_ai_brain/brain)
	return brain.investigate_turf ? 35 : 0

/datum/human_ai_action/investigate/trigger(datum/human_ai_brain/brain)
	return brain.investigate_step()

/datum/human_ai_action/go_to_waypoint
	id = "go_to_waypoint"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED)

/datum/human_ai_action/go_to_waypoint/get_weight(datum/human_ai_brain/brain)
	return brain.waypoint ? 20 : 0

/datum/human_ai_action/go_to_waypoint/trigger(datum/human_ai_brain/brain)
	if(brain.move_to(brain.waypoint, HAI_ARRIVE_DISTANCE, brain.waypoint_sprint))
		return TRUE
	brain.log_decision(brain.move_state == HAI_MOVE_ARRIVED ? "reached waypoint" : "waypoint unreachable")
	brain.waypoint = null
	return FALSE

/datum/human_ai_action/follow
	id = "follow"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED)

/datum/human_ai_action/follow/get_weight(datum/human_ai_brain/brain)
	return brain.follow_ref ? 15 : 0

/datum/human_ai_action/follow/trigger(datum/human_ai_brain/brain)
	var/atom/movable/leader = brain.get_follow_target()
	if(!leader || QDELETED(leader))
		brain.set_follow(null)
		return FALSE
	return brain.follow_leader(leader, brain.follow_slot)

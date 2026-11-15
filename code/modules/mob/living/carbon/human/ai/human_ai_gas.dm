/// Every smoke cloud and every flame that exists, kept by their own Initialize and Destroy so a brain looking for hazards does not have to search the map
GLOBAL_LIST_EMPTY(live_smoke_clouds)
GLOBAL_LIST_EMPTY(live_flamer_fires)

/// Clouds a gas mask keeps out of the lungs
GLOBAL_LIST_INIT(human_ai_mask_gases, typecacheof(list(
	/obj/effect/particle_effect/smoke/bad,
	/obj/effect/particle_effect/smoke/sleepy,
	/obj/effect/particle_effect/smoke/teargas,
	/obj/effect/particle_effect/smoke/mustard,
	/obj/effect/particle_effect/smoke/chlorine,
	/obj/effect/particle_effect/smoke/toxic,
	/obj/effect/particle_effect/smoke/cn20,
)))

/// Clouds that burn or poison whoever stands in them, whatever is worn
GLOBAL_LIST_INIT(human_ai_burning_gases, typecacheof(list(
	/obj/effect/particle_effect/smoke/phosphorus,
	/obj/effect/particle_effect/smoke/xeno_burn,
	/obj/effect/particle_effect/smoke/xeno_weak,
	/obj/effect/particle_effect/smoke/xeno_weak_fire,
)))

/// Turfs whose fire or gas was reported to the native pathfinder lately, so a cloud of thirty tiles is not reported thirty times by every brain around it
GLOBAL_LIST_EMPTY(human_ai_hazard_marks)

/// Whether what the body wears keeps nerve gas, tear gas and the like out of its lungs
/datum/human_ai_brain/proc/gas_protected()
	var/obj/item/mask = body.wear_mask
	if(mask && (mask.flags_inventory & BLOCKGASEFFECT))
		return TRUE
	if(body.head && (body.head.flags_inventory & BLOCKGASEFFECT))
		return TRUE
	return body.internal && mask && (mask.flags_inventory & ALLOWINTERNALS)

/// Whether the cloud would hurt the body where it is
/datum/human_ai_brain/proc/gas_hurts(obj/effect/particle_effect/smoke/gas)
	if(QDELETED(gas))
		return FALSE
	if(is_type_in_typecache(gas, GLOB.human_ai_burning_gases))
		return TRUE
	if(!is_type_in_typecache(gas, GLOB.human_ai_mask_gases))
		return FALSE
	return !issynth(body) && !gas_protected()

/// The first cloud on the turf that would hurt the body, null when there is none
/datum/human_ai_brain/proc/harmful_gas_on(turf/where)
	RETURN_TYPE(/obj/effect/particle_effect/smoke)
	for(var/obj/effect/particle_effect/smoke/gas in where)
		if(gas_hurts(gas))
			return gas
	return null

/// What the next step would walk into: flames, or a cloud that would hurt. Null when the turf is clean
/datum/human_ai_brain/proc/find_hazard_on(turf/where)
	RETURN_TYPE(/obj)
	var/obj/flamer_fire/fire = locate() in where
	if(fire)
		return fire
	return harmful_gas_on(where)

/// A mask that keeps gas out that is on the body somewhere other than its face, null when it carries none
/datum/human_ai_brain/proc/find_gas_mask()
	RETURN_TYPE(/obj/item/clothing/mask)
	for(var/obj/item/clothing/mask/candidate in body.get_contents())
		if(candidate == body.wear_mask || (candidate.flags_item & (NODROP|ITEM_ABSTRACT)))
			continue
		if(candidate.flags_inventory & BLOCKGASEFFECT)
			return candidate
	return null

/// Puts a gas mask on, whatever was on the face goes into storage or on the ground. True when it is on
/datum/human_ai_brain/proc/put_on_gas_mask(obj/item/clothing/mask/mask)
	if(QDELETED(mask))
		return FALSE
	var/obj/item/worn = body.wear_mask
	if(worn)
		if(worn.flags_item & NODROP)
			return FALSE
		if(!stow_item(worn) && worn.loc == body)
			body.drop_inv_item_on_ground(worn)
	take_out_of_holder(mask)
	if(!body.equip_to_slot_if_possible(mask, WEAR_FACE))
		return FALSE
	hands_busy_until = world.time + HAI_GAS_MASK_TIME
	gas_masks++
	log_decision("put on [mask]")
	return TRUE

/**
 * Looks around for clouds and flames now and then: a cloud in sight that would hurt puts the brain on its guard, and everything that would hurt
 * is reported to the native pathfinder so that routes bend around it, for every brain.
 */
/datum/human_ai_brain/proc/scan_hazards(turf/here)
	gas_alert = FALSE
	if(!length(GLOB.live_smoke_clouds) && !length(GLOB.live_flamer_fires))
		return
	for(var/obj/effect/particle_effect/smoke/gas as anything in GLOB.live_smoke_clouds)
		if(gas.z != here.z || get_dist(here, gas) > HAI_GAS_WARN_RANGE || !gas_hurts(gas))
			continue
		if(!is_type_in_typecache(gas, GLOB.human_ai_burning_gases))
			gas_alert = TRUE
		report_hazard(get_turf(gas))
	for(var/obj/flamer_fire/fire as anything in GLOB.live_flamer_fires)
		if(fire.z != here.z || get_dist(here, fire) > HAI_GAS_WARN_RANGE)
			continue
		report_hazard(get_turf(fire))

/// Tells the native pathfinder that the turf is not worth walking through for a while
/datum/human_ai_brain/proc/report_hazard(turf/hazard)
	if(!SSxeno_pathfinding?.available || !xeno_pathfind_profiles_available())
		return
	var/last_told = GLOB.human_ai_hazard_marks[hazard]
	if(last_told && world.time < last_told + HAI_HAZARD_REPORT_GAP)
		return
	if(length(GLOB.human_ai_hazard_marks) > 400)
		for(var/turf/old as anything in GLOB.human_ai_hazard_marks)
			if(world.time >= GLOB.human_ai_hazard_marks[old] + HAI_HAZARD_REPORT_GAP)
				GLOB.human_ai_hazard_marks -= old
	GLOB.human_ai_hazard_marks[hazard] = world.time
	rust_xeno_pathfind_danger("[hazard.z],[hazard.x],[hazard.y],[HAI_HAZARD_PATH_DANGER],1")

/**
 * Fire is never walked into on purpose and a cloud only by a brain in a hurry or one that has waited it out. A brain with a choice looks for
 * another way a couple of times, then lets the hazard burn out or blow away for a while. One with nothing that makes crossing worth it, a walk
 * for the sake of walking, gives the step up once the wait is over. True while the brain is dealing with it and the step must not be taken.
 */
/datum/human_ai_brain/proc/handle_hazard_ahead(obj/hazard, turf/next_turf)
	if(body.on_fire || find_hazard_on(get_turf(body)))
		return FALSE // Already in it, the way out is forward
	var/is_fire = istype(hazard, /obj/flamer_fire)
	if(!is_fire && in_a_hurry())
		return FALSE
	if(hazard_detours < HAI_WIRE_DETOURS)
		hazard_detours++
		last_progress_time = world.time
		prefer_other_way(next_turf, "would rather go round [hazard]")
		return TRUE
	if(hazard_waits < (is_fire ? HAI_FIRE_WAITS : HAI_GAS_WAITS))
		hazard_waits++
		last_progress_time = world.time // Waiting for it to go is not being stuck
		next_step_time = world.time + HAI_HAZARD_WAIT_TIME
		return TRUE
	if(current_order || follow_ref || (intent in list(HAI_INTENT_ENGAGE, HAI_INTENT_ADVANCE, HAI_INTENT_FALLBACK)))
		return FALSE
	remember_blocked(next_turf, "no reason to cross [hazard]", HAI_DETOUR_MEMORY)
	return TRUE

/// A brain with a mask in its pack puts it on when a cloud that would hurt it is close, and keeps it on after
/datum/human_ai_action/mask_up
	id = "mask_up"
	conflicts = HAI_LIMB_HANDS

/datum/human_ai_action/mask_up/get_weight(datum/human_ai_brain/brain)
	if(!brain.gas_alert || brain.gas_protected() || world.time < brain.hands_busy_until || brain.broken_kind)
		return 0
	return brain.find_gas_mask() ? 118 : 0

/datum/human_ai_action/mask_up/trigger(datum/human_ai_brain/brain)
	var/obj/item/clothing/mask/mask = brain.find_gas_mask()
	if(!mask)
		return FALSE
	brain.cancel_reload("gas")
	return brain.put_on_gas_mask(mask)

/**
 * Walling up what a held area opens onto. An engineer holding an area, with nothing to shoot at, builds a metal barricade on the inside of every window and
 * door the enemy could come through, as long as it has the sheets for it and the barricade would not seal the unit in. With no sheets it breaks up furniture
 * for them, tables, racks and chairs, which each give a sheet of metal.
 */

/// The building sheets in the pack, of any amount
/datum/human_ai_brain/proc/find_any_sheets()
	RETURN_TYPE(/obj/item/stack/sheet/metal)
	for(var/obj/item/stack/sheet/metal/sheets in body.get_contents())
		return sheets
	return null

/// The way into the area a barricade would close: the barricade's turf and the way it faces, as list(turf, direction), null when every opening is dealt with
/datum/human_ai_brain/proc/find_opening()
	if(!leash_center)
		return null
	if(opening_cache && world.time < opening_cache_until)
		var/list/kept = opening_cache
		if(!(kept[1] in skipped_openings) && !(locate(/obj/structure/barricade) in kept[1]))
			return kept
	opening_cache = null
	opening_cache_until = world.time + HAI_OPENING_CACHE
	var/best_distance = INFINITY
	var/list/best
	for(var/turf/candidate in range(leash_radius + 1, leash_center))
		if(candidate in skipped_openings)
			continue
		var/obj/structure/opening = null
		for(var/obj/structure/window/glass in candidate)
			if(glass.density)
				opening = glass
				break
		if(!opening)
			for(var/obj/structure/machinery/door/airlock/door in candidate)
				opening = door
				break
		if(!opening)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/inside = get_step(candidate, direction)
			if(!inside || inside.density || !istype(inside, /turf/open) || !inside_leash(inside))
				continue
			if(locate(/obj/structure/barricade) in inside)
				continue
			var/blocked = FALSE
			for(var/obj/thing in inside)
				if(thing.density && !(thing.flags_atom & ON_BORDER))
					blocked = TRUE
					break
			if(blocked)
				continue
			// The side of the opening that is toward the middle of the area is the inside
			var/turf/far_side = get_step(candidate, turn(direction, 180))
			if(far_side && get_dist(far_side, leash_center) < get_dist(inside, leash_center))
				continue
			var/distance = get_dist(body, inside)
			if(distance < best_distance)
				best_distance = distance
				best = list(inside, get_dir(inside, candidate))
	opening_cache = best
	return best

/// A table, rack or chair close by that nobody uses and that is worth breaking up for the metal, null when there is none
/datum/human_ai_brain/proc/find_scrap()
	RETURN_TYPE(/obj/structure)
	var/obj/structure/kept = scrap_ref?.resolve()
	if(kept && !QDELETED(kept) && get_dist(body, kept) <= HAI_SCRAP_RANGE)
		return kept
	scrap_ref = null
	var/obj/structure/best
	var/best_distance = INFINITY
	for(var/obj/structure/candidate in range(HAI_SCRAP_RANGE, body))
		if(!istype(candidate, /obj/structure/surface/table) && !istype(candidate, /obj/structure/surface/rack) && !istype(candidate, /obj/structure/bed/chair))
			continue
		if(QDELETED(candidate) || (candidate in skipped_scrap))
			continue
		if(leash_center && !inside_leash(get_turf(candidate)))
			continue
		var/turf/where = get_turf(candidate)
		var/occupied = FALSE
		for(var/mob/living/someone in where)
			occupied = TRUE
			break
		if(occupied)
			continue
		var/distance = get_dist(body, candidate)
		if(distance < best_distance)
			best_distance = distance
			best = candidate
	scrap_ref = best ? WEAKREF(best) : null
	return best

/// Breaks the furniture up and picks the metal off the floor into the stack it carries, or into a new one
/datum/human_ai_brain/proc/scrap_structure(obj/structure/furniture)
	var/turf/where = get_turf(furniture)
	if(QDELETED(furniture) || QDELETED(body) || stopped)
		acting_until = 0
		return
	body.face_atom(furniture)
	body.visible_message(SPAN_WARNING("[body] starts breaking up [furniture]."), SPAN_NOTICE("You start breaking up [furniture]."))
	playsound(furniture, 'sound/items/Ratchet.ogg', 25, TRUE)
	var/start = get_turf(body)
	var/finish = world.time + HAI_SCRAP_TIME
	while(world.time < finish)
		sleep(10)
		if(QDELETED(body) || QDELETED(furniture) || stopped || body.stat != CONSCIOUS || body.is_mob_incapacitated() || get_turf(body) != start || get_target())
			acting_until = 0
			return
	furniture.deconstruct(FALSE)
	scrapped++
	// Whatever the piece leaves behind, it is worth a sheet
	if(!(locate(/obj/item/stack/sheet/metal) in where))
		new /obj/item/stack/sheet/metal(where)
	for(var/obj/item/stack/sheet/metal/loose in where)
		var/obj/item/stack/sheet/metal/mine = find_any_sheets()
		if(mine && mine != loose)
			mine.add(loose.amount)
			qdel(loose)
		else if(!stow_item(loose))
			body.put_in_hands(loose, FALSE)
	log_decision("broke up [furniture.name] for metal")
	acting_until = 0

/// An engineer holding an area walls up its windows and doors, from the sheets it has or from furniture it breaks up
/datum/human_ai_action/fortify_openings
	id = "fortify_openings"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_HOLD)

/datum/human_ai_action/fortify_openings/get_weight(datum/human_ai_brain/brain)
	if(!brain.leash_center || !brain.role?.supports_order("fortify") || world.time < brain.next_fortify_time)
		return 0
	if(brain.get_target() || brain.suppressed() || brain.is_acting() || brain.surrendered || brain.broken_kind || brain.current_order?.hard)
		return 0
	if(brain.body.is_mob_incapacitated() || world.time < brain.hands_busy_until || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	if(brain.openings_walled >= HAI_OPENINGS_MAX)
		return 0
	return brain.find_opening() ? 57 : 0

/datum/human_ai_action/fortify_openings/trigger(datum/human_ai_brain/brain)
	var/list/opening = brain.find_opening()
	if(!opening)
		return FALSE
	var/turf/spot = opening[1]
	var/facing = opening[2]
	var/obj/item/stack/sheet/metal/sheets = brain.find_building_stack()
	if(!sheets)
		var/obj/structure/furniture = brain.find_scrap()
		if(!furniture)
			brain.next_fortify_time = world.time + HAI_FORTIFY_RETRY
			return FALSE
		if(get_dist(brain.body, furniture) > 1)
			if(brain.move_to(get_turf(furniture), 1, FALSE))
				return TRUE
			LAZYADD(brain.skipped_scrap, furniture)
			brain.scrap_ref = null
			return FALSE
		brain.acting_until = world.time + HAI_SCRAP_TIME + 5 SECONDS
		INVOKE_ASYNC(brain, TYPE_PROC_REF(/datum/human_ai_brain, scrap_structure), furniture)
		return TRUE
	var/turf/stand = get_step(spot, turn(facing, 180))
	if(!stand || stand.density)
		LAZYADD(brain.skipped_openings, spot)
		brain.opening_cache = null
		return FALSE
	if(brain.body.loc != stand)
		if(brain.move_to(stand, 0, FALSE))
			return TRUE
		LAZYADD(brain.skipped_openings, spot)
		brain.opening_cache = null
		return FALSE
	if(!brain.room_left_after(spot))
		LAZYADD(brain.skipped_openings, spot)
		brain.opening_cache = null
		brain.log_decision("left the opening at [spot.x],[spot.y] alone, it would seal the way back")
		return FALSE
	brain.body.face_atom(spot)
	brain.acting_until = world.time + HAI_BUILD_TIME
	brain.openings_walled++
	brain.opening_cache = null
	addtimer(CALLBACK(brain, TYPE_PROC_REF(/datum/human_ai_brain, build_barricade), spot, facing, sheets), HAI_BUILD_TIME)
	return TRUE

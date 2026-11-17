/**
 * Smartgunners. A smartgun is not picked up and fired like a rifle. It wants a trained man in a harness, its servo arm locked to his side and its recoil compensation
 * on before it can be fired easily, a battery with some charge in it, and its feed cover shut. Reloading it means opening the cover, taking the empty drum out, putting a
 * full one in and closing the cover again. A smartgunner does all of that the way a player would, with the arm and the stabilizer off while there is nothing to shoot at,
 * which is also what it takes to put the gun away, and swaps the battery when it runs low.
 */

/// The smartgun the body holds, null when it holds another gun or none
/datum/human_ai_brain/proc/held_smartgun()
	RETURN_TYPE(/obj/item/weapon/gun/smartgun)
	var/obj/item/weapon/gun/smartgun/gun = peek_gun()
	return istype(gun) ? gun : null

/// Whether the body is trained and harnessed to use the gun, without which nothing else it asks for is of any use
/datum/human_ai_brain/proc/smartgun_fit(obj/item/weapon/gun/smartgun/gun)
	if(!skillcheckexplicit(body, SKILL_SPEC_WEAPONS, SKILL_SPEC_SMARTGUN) && !skillcheckexplicit(body, SKILL_SPEC_WEAPONS, SKILL_SPEC_ALL))
		return FALSE
	if(gun.requires_harness && (!body.wear_suit || !(body.wear_suit.flags_inventory & SMARTGUN_HARNESS)))
		return FALSE
	return TRUE

/// How much charge is left in the gun's battery, 0 to 1, and 1 for a gun that has no use for one
/datum/human_ai_brain/proc/smartgun_charge(obj/item/weapon/gun/smartgun/gun)
	if(!gun.requires_battery || !gun.requires_power)
		return 1
	var/obj/item/cell/cell = gun.battery?.power_cell
	if(!cell || cell.maxcharge <= 0)
		return 0
	return cell.charge / cell.maxcharge

/// The best battery the body carries that is not the one in the gun and has charge in it, null when it has none
/datum/human_ai_brain/proc/find_spare_battery(obj/item/weapon/gun/smartgun/gun)
	RETURN_TYPE(/obj/item/heavygun_battery)
	var/obj/item/heavygun_battery/best
	for(var/obj/item/heavygun_battery/cell in body.get_contents())
		if(cell == gun.battery || cell.loc == gun || !cell.power_cell || cell.power_cell.charge <= 0)
			continue
		if(!best || cell.power_cell.charge > best.power_cell.charge)
			best = cell
	return best

/// Whether the smartgun is no use to the body: it is not fit to use it, or the battery is dead and there is no other
/datum/human_ai_brain/proc/smartgun_unusable(obj/item/weapon/gun/smartgun/gun)
	if(!smartgun_fit(gun))
		return TRUE
	return smartgun_charge(gun) <= 0 && !find_spare_battery(gun)

/// Whether the body is in a state to fight, which is when it has the arm and the stabilizer on for the gun
/datum/human_ai_brain/proc/smartgun_alert()
	if(in_contact())
		return TRUE
	return intent == HAI_INTENT_ENGAGE || intent == HAI_INTENT_ALERT || intent == HAI_INTENT_INVESTIGATE || intent == HAI_INTENT_ADVANCE

/**
 * The next thing the gun wants done before it is fired or put away, null when there is nothing: the feed cover shut, a fresh battery, and with an enemy about the servo arm and the
 * stabilizer on, or off once the fight is a while behind.
 */
/datum/human_ai_brain/proc/smartgun_job(obj/item/weapon/gun/smartgun/gun)
	if(!smartgun_fit(gun))
		return null
	if(gun.cover_open && reload_phase == HAI_RELOAD_NONE)
		return "close_cover"
	if(smartgun_charge(gun) < HAI_SG_LOW_BATTERY && find_spare_battery(gun))
		return "swap_battery"
	if(smartgun_alert())
		if(!gun.armbrace)
			return "arm_on"
		if(!gun.recoil_compensation)
			return "stabilizer_on"
	else if(world.time >= last_shot_time + HAI_SG_STAND_DOWN)
		if(gun.recoil_compensation)
			return "stabilizer_off"
		if(gun.armbrace)
			return "arm_off"
	return null

/// Does the job, true when it was done
/datum/human_ai_brain/proc/smartgun_work(obj/item/weapon/gun/smartgun/gun, job)
	hands_busy_until = world.time + HAI_SG_TOGGLE_TIME
	switch(job)
		if("close_cover")
			return smartgun_cover(gun, FALSE)
		if("swap_battery")
			var/obj/item/heavygun_battery/cell = find_spare_battery(gun)
			if(!cell)
				return FALSE
			if(gun.flags_item & WIELDED)
				gun.unwield(body)
			take_out_of_holder(cell)
			if(!body.put_in_hands(cell, FALSE))
				cell.forceMove(body.loc)
				return FALSE
			var/obj/item/heavygun_battery/old = gun.battery
			gun.attackby(cell, body)
			if(gun.battery != cell)
				stow_item(cell)
				return FALSE
			if(old && !QDELETED(old))
				stow_item(old)
			sg_battery_swaps++
			log_decision("put a fresh battery in [gun.name]")
			return TRUE
		if("arm_on")
			gun.toggle_armbrace(body)
			return gun.armbrace
		if("arm_off")
			gun.toggle_armbrace(body)
			return !gun.armbrace
		if("stabilizer_on", "stabilizer_off")
			gun.toggle_recoil_compensation(body)
			return gun.recoil_compensation == (job == "stabilizer_on")
	return FALSE

/// Takes the arm and the stabilizer off the gun, which a smartgun has to have for it to be put away, the arm locks it to the hand
/datum/human_ai_brain/proc/smartgun_release(obj/item/weapon/gun/smartgun/gun)
	if(gun.armbrace)
		gun.toggle_armbrace(body)
	if(gun.recoil_compensation)
		gun.toggle_recoil_compensation(body)
	hands_busy_until = max(hands_busy_until, world.time + HAI_SG_TOGGLE_TIME)

/// Opens or closes the feed cover the way anyone does, by alt-click, with the other hand freed when both are full. True when it is as wanted afterwards
/datum/human_ai_brain/proc/smartgun_cover(obj/item/weapon/gun/smartgun/gun, open)
	if(gun.cover_open == open)
		return TRUE
	// Both hands are the gun's while it is held in both, so it is let go of with one first, it comes back up when it is fired
	if(gun.flags_item & WIELDED)
		gun.unwield(body)
	for(var/attempt in 1 to 2)
		gun.clicked(body, list(ALT_CLICK = TRUE))
		if(gun.cover_open == open)
			return TRUE
		var/obj/item/other = (gun == body.get_active_hand()) ? body.get_inactive_hand() : body.get_active_hand()
		if(!other || !clear_hand(other))
			break
	return gun.cover_open == open

/// The gun is serviced before anything else is done with it: the cover shut, the battery full, the arm and the stabilizer as the fight needs them
/datum/human_ai_action/service_smartgun
	id = "service_smartgun"
	conflicts = HAI_LIMB_HANDS

/datum/human_ai_action/service_smartgun/get_weight(datum/human_ai_brain/brain)
	var/obj/item/weapon/gun/smartgun/gun = brain.held_smartgun()
	if(!gun || brain.is_acting() || world.time < brain.hands_busy_until || world.time < brain.next_service_time || brain.is_civilian())
		return 0
	if(brain.reload_phase != HAI_RELOAD_NONE || brain.body.body_position != STANDING_UP)
		return 0
	return brain.smartgun_job(gun) ? 97 : 0

/datum/human_ai_action/service_smartgun/trigger(datum/human_ai_brain/brain)
	var/obj/item/weapon/gun/smartgun/gun = brain.held_smartgun()
	var/job = gun ? brain.smartgun_job(gun) : null
	if(!job)
		return FALSE
	brain.next_service_time = world.time + HAI_SG_TOGGLE_TIME
	if(brain.smartgun_work(gun, job))
		brain.sg_services++
		brain.log_decision("smartgun: [job]")
		return TRUE
	// Whatever would not work is left alone for a while, and the gun is given up on if it cannot be served at all
	brain.next_service_time = world.time + HAI_SG_RETRY
	return FALSE

/// A drum in the gun is swapped by opening the cover, taking the empty one out and putting a full one in, and closing the cover, which takes the time each of them does
/datum/human_ai_brain/proc/smartgun_reload_step(obj/item/weapon/gun/smartgun/gun, datum/human_ai_gun_appraisal/appraisal)
	switch(reload_phase)
		if(HAI_RELOAD_OPEN)
			if(!smartgun_cover(gun, TRUE))
				cancel_reload("the cover would not open")
				return FALSE
			var/obj/item/ammo_magazine/spare = reload_item_ref?.resolve()
			reload_phase = HAI_RELOAD_SWAP
			reload_until = world.time + max(spare?.reload_delay, HAI_RELOAD_MIN_TIME)
			return TRUE
		if(HAI_RELOAD_SWAP)
			var/swapped = finish_swap(gun, appraisal)
			// The cover is shut again whether or not the drum went in, a gun left open cannot be fired
			reload_phase = HAI_RELOAD_CLOSE
			reload_until = world.time + HAI_SG_COVER_TIME
			reload_gun_ref = WEAKREF(gun)
			reload_start_loc = body.loc
			if(!swapped)
				log_decision("the drum of [gun.name] would not go in")
			return TRUE
		if(HAI_RELOAD_CLOSE)
			smartgun_cover(gun, FALSE)
			reload_phase = HAI_RELOAD_NONE
			reload_gun_ref = null
			reload_item_ref = null
			reload_start_loc = null
			forget_spare_check()
			return FALSE
	return FALSE

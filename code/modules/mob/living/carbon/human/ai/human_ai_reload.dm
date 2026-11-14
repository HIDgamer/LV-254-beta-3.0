/// Rounds the gun can still shoot, chambered and stored
/datum/human_ai_brain/proc/gun_rounds(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	var/rounds = gun.in_chamber ? 1 : 0
	if(appraisal.feed == HAI_FEED_GRENADE)
		var/obj/item/weapon/gun/launcher/grenade/launcher = gun
		if(launcher.cylinder)
			rounds += length(launcher.cylinder.contents)
	else if(gun.current_mag)
		rounds += max(gun.current_mag.current_rounds, 0)
	else if(appraisal.feed == HAI_FEED_NONE)
		rounds = max(rounds, 1)
	return rounds

/// Rounds the gun holds when full, zero when that is not known
/datum/human_ai_brain/proc/gun_capacity(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(appraisal.feed == HAI_FEED_GRENADE)
		var/obj/item/weapon/gun/launcher/grenade/launcher = gun
		return launcher.internal_slots
	if(gun.current_mag)
		return gun.current_mag.max_rounds
	return 0

/// Where the gun stands, as one of the HAI_WEAPON defines
/datum/human_ai_brain/proc/weapon_state(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(gun_rounds(gun) <= 0)
		return HAI_WEAPON_EMPTY
	if(gun.flags_gun_features & GUN_TRIGGER_SAFETY)
		return HAI_WEAPON_SAFE
	if((appraisal.break_action || appraisal.cylinder) && gun.current_mag && !gun.current_mag.chamber_closed)
		return HAI_WEAPON_OPEN
	if(appraisal.cycle == HAI_CYCLE_MANUAL && !gun.in_chamber)
		return HAI_WEAPON_CYCLE
	return HAI_WEAPON_READY

/// Every item the body carries that could be ammunition for the gun, best first
/datum/human_ai_brain/proc/find_spare_ammo(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(appraisal.feed == HAI_FEED_NONE || appraisal.feed == HAI_FEED_GRENADE)
		return null
	var/obj/item/ammo_magazine/best
	for(var/obj/item/ammo_magazine/candidate in body.get_contents())
		if(candidate.current_rounds <= 0 || candidate == gun.current_mag || candidate.loc == gun)
			continue
		if(!ammo_fits_gun(candidate, gun, appraisal))
			continue
		if(!best || candidate.current_rounds > best.current_rounds)
			best = candidate
	return best

/datum/human_ai_brain/proc/ammo_fits_gun(obj/item/ammo_magazine/candidate, obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal)
	switch(appraisal.feed)
		if(HAI_FEED_MAGAZINE)
			if(candidate.flags_magazine & (AMMUNITION_HANDFUL|AMMUNITION_HANDFUL_BOX))
				return FALSE
			return istype(gun, candidate.gun_type) || (candidate.type in gun.accepted_ammo)
		if(HAI_FEED_INTERNAL)
			if(!gun.current_mag || candidate.flags_magazine & AMMUNITION_HANDFUL_BOX)
				return FALSE
			if(appraisal.cylinder && !(candidate.flags_magazine & AMMUNITION_HANDFUL) && gun.current_mag.gun_type != candidate.gun_type)
				return FALSE
			return candidate.caliber == gun.current_mag.caliber
		if(HAI_FEED_ROCKET, HAI_FEED_TANK)
			return istype(gun, candidate.gun_type)
	return FALSE

/// True when the body can reload the gun from what it carries, checked at most every few seconds
/datum/human_ai_brain/proc/has_spare_ammo(obj/item/weapon/gun/gun)
	if(world.time < spare_check_time && spare_check_gun_ref?.resolve() == gun)
		return spare_check_result
	spare_check_time = world.time + HAI_SPARE_CHECK_INTERVAL
	spare_check_gun_ref = WEAKREF(gun)
	spare_check_result = !!find_spare_ammo(gun)
	return spare_check_result

/datum/human_ai_brain/proc/forget_spare_check()
	spare_check_time = 0

/// The gun is out of what it needs and the body has nothing to feed it
/datum/human_ai_brain/proc/gun_is_dry(obj/item/weapon/gun/gun)
	var/state = weapon_state(gun)
	if(state != HAI_WEAPON_EMPTY)
		return FALSE
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(appraisal.feed == HAI_FEED_NONE)
		return FALSE
	return !has_spare_ammo(gun)

/// Moves an item into the first storage that takes it, otherwise it stays where it is
/datum/human_ai_brain/proc/stow_item(obj/item/item)
	if(QDELETED(item))
		return FALSE
	for(var/obj/item/storage/holder in body.get_contents())
		if(holder.loc != body && !istype(holder.loc, /obj/item/clothing))
			continue
		if(holder.can_be_inserted(item, body, TRUE))
			if(istype(item.loc, /obj/item/storage))
				var/obj/item/storage/old_holder = item.loc
				old_holder.remove_from_storage(item, body.loc)
			else if(item.loc == body)
				body.drop_inv_item_to_loc(item, body.loc)
			return holder.handle_item_insertion(item, TRUE, body)
	return FALSE

/// Frees the hand an item is in, into storage when it fits and otherwise at the feet
/datum/human_ai_brain/proc/clear_hand(obj/item/item)
	if(!item || (item.flags_item & (NODROP|ITEM_ABSTRACT)))
		return FALSE
	if(!stow_item(item) && item.loc == body)
		body.drop_inv_item_on_ground(item)
	return item.loc != body

/// Takes an item out of the storage or hand it is in so it can be handed to a gun
/datum/human_ai_brain/proc/take_out_of_holder(obj/item/item)
	if(istype(item.loc, /obj/item/storage))
		var/obj/item/storage/holder = item.loc
		holder.remove_from_storage(item, body.loc)
	else if(item.loc == body)
		body.drop_inv_item_to_loc(item, body.loc)

/// Starts, runs and finishes a reload, true while the body is busy with it
/datum/human_ai_brain/proc/reload_step(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(reload_phase != HAI_RELOAD_NONE && (reload_gun_ref?.resolve() != gun || body.loc != reload_start_loc || (gun.flags_gun_features & GUN_BURST_FIRING)))
		cancel_reload("interrupted")
	if(reload_phase == HAI_RELOAD_NONE)
		if(!begin_reload(gun, appraisal))
			return FALSE
	if(world.time < reload_until)
		return TRUE
	switch(reload_phase)
		if(HAI_RELOAD_SWAP)
			finish_swap(gun, appraisal)
			return FALSE
		if(HAI_RELOAD_OPEN)
			open_for_loading(gun, appraisal)
			reload_phase = HAI_RELOAD_LOAD
			reload_until = world.time + HAI_RELOAD_ROUND_TIME
			return TRUE
		if(HAI_RELOAD_LOAD)
			if(load_one_round(gun, appraisal))
				reload_until = world.time + HAI_RELOAD_ROUND_TIME
				return TRUE
			reload_phase = HAI_RELOAD_CLOSE
			reload_until = world.time + HAI_RELOAD_ROUND_TIME
			return TRUE
		if(HAI_RELOAD_CLOSE)
			close_after_loading(gun, appraisal)
			reload_phase = HAI_RELOAD_NONE
			forget_spare_check()
			return FALSE
	return FALSE

/datum/human_ai_brain/proc/begin_reload(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal)
	var/obj/item/ammo_magazine/spare = find_spare_ammo(gun)
	if(!spare && !appraisal.break_action && !appraisal.cylinder)
		return FALSE
	if(!spare)
		return FALSE
	reload_gun_ref = WEAKREF(gun)
	reload_item_ref = WEAKREF(spare)
	reload_start_loc = body.loc
	reload_rounds_loaded = 0
	if(appraisal.feed == HAI_FEED_INTERNAL)
		reload_phase = HAI_RELOAD_OPEN
		reload_until = world.time + 1
	else
		reload_phase = HAI_RELOAD_SWAP
		reload_until = world.time + max(spare.reload_delay, HAI_RELOAD_MIN_TIME)
	log_decision("reloading [gun.name] with [spare.name]")
	if(!(squad && express(HAI_EXPR_COVER_ME)))
		express(HAI_EXPR_RELOAD)
	return TRUE

/datum/human_ai_brain/proc/cancel_reload(reason)
	if(reload_phase != HAI_RELOAD_NONE)
		log_decision("reload cancelled ([reason])")
	reload_phase = HAI_RELOAD_NONE
	reload_gun_ref = null
	reload_item_ref = null
	reload_start_loc = null
	forget_spare_check()

/// Swaps the magazine, tank or rocket in one go once the reload time has passed
/datum/human_ai_brain/proc/finish_swap(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal)
	var/obj/item/ammo_magazine/spare = reload_item_ref?.resolve()
	reload_phase = HAI_RELOAD_NONE
	reload_gun_ref = null
	reload_item_ref = null
	reload_start_loc = null
	forget_spare_check()
	if(QDELETED(spare) || spare.current_rounds <= 0 || !ammo_fits_gun(spare, gun, appraisal))
		return FALSE
	var/obj/item/ammo_magazine/old = gun.current_mag
	if(old && !QDELETED(old) && old.loc == gun && appraisal.feed != HAI_FEED_ROCKET)
		var/keep = old.current_rounds > 0
		gun.unload(body, TRUE, TRUE)
		if(keep && !QDELETED(old))
			stow_item(old)
	take_out_of_holder(spare)
	gun.reload(null, spare)
	if(gun.current_mag != spare)
		log_decision("reload of [gun.name] failed")
		spare.forceMove(body.loc)
		return FALSE
	reload_count++
	return TRUE

/// Double barrels break open and revolvers swing the cylinder out before they take rounds
/datum/human_ai_brain/proc/open_for_loading(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal)
	if(!gun.current_mag)
		return
	if(appraisal.break_action && gun.current_mag.chamber_closed)
		gun.unique_action(body)
	else if(appraisal.cylinder && gun.current_mag.chamber_closed)
		gun.unload(body)

/// Puts one round or loader from the best source into the gun, false when it is full or nothing is left
/datum/human_ai_brain/proc/load_one_round(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal)
	if(!gun.current_mag || gun.current_mag.current_rounds >= gun.current_mag.max_rounds)
		return FALSE
	var/obj/item/ammo_magazine/source = reload_item_ref?.resolve()
	if(QDELETED(source) || source.current_rounds <= 0 || !ammo_fits_gun(source, gun, appraisal))
		source = find_spare_ammo(gun)
		reload_item_ref = source ? WEAKREF(source) : null
	if(!source)
		return FALSE
	var/before = gun.current_mag.current_rounds
	gun.reload(body, source)
	if(gun.current_mag.current_rounds <= before)
		return FALSE
	reload_rounds_loaded++
	return TRUE

/datum/human_ai_brain/proc/close_after_loading(obj/item/weapon/gun/gun, datum/human_ai_gun_appraisal/appraisal)
	reload_gun_ref = null
	reload_item_ref = null
	reload_start_loc = null
	if(!gun.current_mag)
		return
	if(appraisal.break_action && !gun.current_mag.chamber_closed)
		gun.unique_action(body)
	else if(appraisal.cylinder && !gun.current_mag.chamber_closed)
		gun.unload(body)
	if(reload_rounds_loaded)
		reload_count++
	reload_rounds_loaded = 0

/// Takes the safety off, or lights the pilot light of a flamer
/datum/human_ai_brain/proc/release_safety(obj/item/weapon/gun/gun)
	gun.flags_gun_features &= ~GUN_TRIGGER_SAFETY
	gun.gun_safety_handle(body)
	gun.update_icon()

/// Pumps, levers or bolts the next round in when the gun needs it, true when it acted
/datum/human_ai_brain/proc/cycle_step(obj/item/weapon/gun/gun)
	if(world.time < next_cycle_time)
		return TRUE
	next_cycle_time = world.time + HAI_CYCLE_TIME
	gun.unique_action(body)
	return TRUE

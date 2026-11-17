/// The gun in the active hand, or the one in the other hand when the active hand has none, without swapping
/datum/human_ai_brain/proc/peek_gun()
	var/obj/item/weapon/gun/gun = body.get_active_hand()
	if(istype(gun))
		return gun
	gun = body.get_inactive_hand()
	if(istype(gun))
		return gun
	return null

/// True when the target is close enough to hit with the hands
/datum/human_ai_brain/proc/target_adjacent()
	var/mob/living/target = get_target()
	return target && get_dist(body, target) <= 1 && body.Adjacent(target)

/// A gun that should not be the one in use right now
/datum/human_ai_brain/proc/gun_unusable(obj/item/weapon/gun/gun)
	if(world.time < gun_blocked_until)
		return TRUE
	if(gun_is_dry(gun))
		return TRUE
	// An empty gun is not reloaded with the enemy on top of the unit, another gun is taken up instead
	if(weapon_state(gun) == HAI_WEAPON_EMPTY && target_adjacent())
		return TRUE
	if(lethal_forbidden() && !gun_is_nonlethal(gun))
		return TRUE
	// An empty gun that takes longer to load than another takes to bring up is not reloaded with the enemy in sight, the other one is fired meanwhile
	if(weapon_state(gun) == HAI_WEAPON_EMPTY && in_contact() && sidearm_beats_reload(gun))
		return TRUE
	// A smartgun that its man is not trained for, has no harness for or has no power for is only a weight to carry
	if(istype(gun, /obj/item/weapon/gun/smartgun) && smartgun_unusable(gun))
		return TRUE
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(target_adjacent() && (appraisal.family == HAI_GUN_SNIPER || appraisal.area_effect))
		return TRUE
	return FALSE

/// Another gun on the body that is better to use than the given one, in the hands or holstered
/datum/human_ai_brain/proc/find_other_gun(obj/item/weapon/gun/current)
	if(world.time < other_gun_check_time && other_gun_check_for_ref?.resolve() == current)
		return other_gun_ref?.resolve()
	other_gun_check_time = world.time + HAI_SPARE_CHECK_INTERVAL
	other_gun_check_for_ref = WEAKREF(current)
	var/obj/item/weapon/gun/best
	var/best_score = 0
	for(var/obj/item/weapon/gun/candidate in body.get_contents())
		if(candidate == current)
			continue
		var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(candidate)
		if(appraisal.feed == HAI_FEED_NONE || (lethal_forbidden() && !gun_is_nonlethal(candidate)))
			continue
		var/score = 0
		if(weapon_state(candidate) != HAI_WEAPON_EMPTY)
			score = 100
		else if(has_spare_ammo(candidate))
			score = 50
		if(!score)
			continue
		if(target_adjacent() && (appraisal.family == HAI_GUN_SNIPER || appraisal.area_effect))
			score -= 60
		// Of the guns that work the stronger one is the one to take
		score += appraisal.power * 2
		if(candidate.loc == body)
			score += 5
		if(score > best_score)
			best_score = score
			best = candidate
	other_gun_ref = best ? WEAKREF(best) : null
	return best

/// Puts the other gun in hand, drawing it from its holster when it is not in a hand already
/datum/human_ai_brain/proc/switch_to(obj/item/weapon/gun/other)
	var/obj/item/weapon/gun/current = peek_gun()
	if(istype(current, /obj/item/weapon/gun/smartgun) && current != other)
		smartgun_release(current)
	if(current && (current.flags_item & WIELDED))
		current.unwield(body)
	if(other == body.get_inactive_hand())
		body.swap_hand()
	else if(other == body.get_active_hand())
		return TRUE
	else
		if(current && current == body.get_active_hand() && body.get_inactive_hand())
			return FALSE
		take_out_of_holder(other)
		if(!body.put_in_hands(other, FALSE))
			other.forceMove(body.loc)
			return FALSE
		if(other == body.get_inactive_hand())
			body.swap_hand()
	forget_spare_check()
	other_gun_check_time = 0
	weapon_switches++
	log_decision("switched to [other.name]")
	return TRUE

/// A two handed gun in a hand that is not holding it with both yet, and a free hand to do it with
/datum/human_ai_brain/proc/needs_wield(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	return appraisal.two_handed && !(gun.flags_item & WIELDED) && gun == body.get_active_hand() && !body.get_inactive_hand()

/// Whether a reload now, between fights, is worth the time
/datum/human_ai_brain/proc/wants_tactical_reload(obj/item/weapon/gun/gun)
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	if(appraisal.feed == HAI_FEED_NONE || appraisal.feed == HAI_FEED_GRENADE || appraisal.cylinder || appraisal.break_action)
		return FALSE
	var/capacity = gun_capacity(gun)
	if(capacity <= 0)
		return FALSE
	var/rounds = gun_rounds(gun)
	var/threshold = (appraisal.feed == HAI_FEED_INTERNAL) ? 0.6 : HAI_TACTICAL_RELOAD_FRACTION
	if(rounds >= capacity * threshold)
		return FALSE
	return has_spare_ammo(gun)

/// Whether an enemy was in sight in the last few seconds
/datum/human_ai_brain/proc/in_contact()
	return get_target() && world.time <= target_seen_time + HAI_CONTACT_COOLDOWN

/// Deciseconds it takes to get the gun loaded from what the body carries, nothing to it when it holds rounds already and for ever when there is nothing to load it with
/datum/human_ai_brain/proc/reload_cost(obj/item/weapon/gun/gun)
	if(weapon_state(gun) != HAI_WEAPON_EMPTY)
		return 0
	var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(gun)
	var/obj/item/ammo_magazine/spare = find_spare_ammo(gun)
	if(!spare)
		return INFINITY
	if(appraisal.feed == HAI_FEED_INTERNAL || appraisal.cylinder || appraisal.break_action)
		var/missing = max(min(gun_capacity(gun) - gun_rounds(gun), spare.current_rounds), 1)
		return missing * HAI_RELOAD_ROUND_TIME + HAI_CYCLE_TIME
	return max(spare.reload_delay, HAI_RELOAD_MIN_TIME)

/// Whether another gun the body has is loaded and can be brought up faster than this empty one can be loaded
/datum/human_ai_brain/proc/sidearm_beats_reload(obj/item/weapon/gun/gun)
	// Out of a fight there is time to load it
	if(!in_contact())
		return FALSE
	var/obj/item/weapon/gun/other = find_other_gun(gun)
	if(!other || weapon_state(other) == HAI_WEAPON_EMPTY)
		return FALSE
	return reload_cost(gun) > HAI_SWITCH_COOLDOWN

/// The strongest gun the body has that works, loaded or with something to load it with, null when it has none
/datum/human_ai_brain/proc/strongest_gun()
	RETURN_TYPE(/obj/item/weapon/gun)
	var/obj/item/weapon/gun/best
	var/best_score = -1
	for(var/obj/item/weapon/gun/candidate in body.get_contents())
		var/datum/human_ai_gun_appraisal/appraisal = get_human_ai_gun_appraisal(candidate)
		if(appraisal.feed == HAI_FEED_NONE || (lethal_forbidden() && !gun_is_nonlethal(candidate)))
			continue
		var/loaded = weapon_state(candidate) != HAI_WEAPON_EMPTY
		if(!loaded && !has_spare_ammo(candidate))
			continue
		var/score = appraisal.power * 10 + (loaded ? 5 : 0)
		if(score > best_score)
			best_score = score
			best = candidate
	return best

/// The best thing to hit with that the body carries, a blade or a club and not a gun
/datum/human_ai_brain/proc/find_melee_weapon()
	var/obj/item/best
	for(var/obj/item/weapon/candidate in body.get_contents())
		if(istype(candidate, /obj/item/weapon/gun) || candidate.force < HAI_MELEE_MIN_FORCE || (candidate.flags_item & (NODROP|ITEM_ABSTRACT)))
			continue
		if(lethal_forbidden() && !istype(candidate, /obj/item/weapon/baton))
			continue
		if(!best || candidate.force > best.force || (role?.id == "security" && istype(candidate, /obj/item/weapon/baton)))
			best = candidate
	return best

/// True when a melee weapon is in the active hand
/datum/human_ai_brain/proc/holding_melee_weapon()
	var/obj/item/held = body.get_active_hand()
	return held && !istype(held, /obj/item/weapon/gun) && held.force >= HAI_MELEE_MIN_FORCE && (!lethal_forbidden() || istype(held, /obj/item/weapon/baton))

/// Puts the weapon in the active hand, putting the gun aside in the other hand
/datum/human_ai_brain/proc/draw_melee_weapon(obj/item/weapon)
	var/obj/item/weapon/gun/gun = peek_gun()
	if(gun && (gun.flags_item & WIELDED))
		gun.unwield(body)
	if(weapon == body.get_active_hand())
		return TRUE
	if(weapon == body.get_inactive_hand())
		body.swap_hand()
		return TRUE
	if(body.get_active_hand() && body.get_inactive_hand() && !clear_hand(body.get_inactive_hand()))
		return FALSE
	take_out_of_holder(weapon)
	if(!body.put_in_hands(weapon, FALSE))
		weapon.forceMove(body.loc)
		return FALSE
	if(weapon == body.get_inactive_hand())
		body.swap_hand()
	melee_draws++
	log_decision("drew [weapon.name]")
	return TRUE

/// Pushes the target away to make room
/datum/human_ai_brain/proc/shove_target(mob/living/target)
	if(world.time < next_shove_time || world.time <= body.next_move)
		return FALSE
	next_shove_time = world.time + HAI_SHOVE_COOLDOWN
	body.face_atom(target)
	body.next_move = world.time
	if(body.a_intent != INTENT_DISARM)
		body.a_intent_change(INTENT_DISARM)
	body.UnarmedAttack(target, 1, list())
	shoves++
	return TRUE

/datum/human_ai_action/shove
	id = "shove"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/shove/get_weight(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	if(!target || world.time < brain.next_shove_time || get_dist(brain.body, target) > 1 || !brain.body.Adjacent(target))
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(gun && brain.gun_can_shoot_now(gun))
		return 0
	return 55

/datum/human_ai_action/shove/trigger(datum/human_ai_brain/brain)
	var/mob/living/target = brain.get_target()
	return target ? brain.shove_target(target) : FALSE

/// Drawing a blade when the gun is no use and something is in reach
/datum/human_ai_action/draw_melee
	id = "draw_melee"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/draw_melee/get_weight(datum/human_ai_brain/brain)
	if(brain.is_acting() || !brain.target_adjacent() || brain.holding_melee_weapon() || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(gun && !brain.gun_unusable(gun))
		return 0
	if(gun && brain.find_other_gun(gun))
		return 0
	return brain.find_melee_weapon() ? 70 : 0

/datum/human_ai_action/draw_melee/trigger(datum/human_ai_brain/brain)
	var/obj/item/weapon = brain.find_melee_weapon()
	return weapon ? brain.draw_melee_weapon(weapon) : FALSE

/// Rolling to put out flames takes over everything else
/datum/human_ai_action/react_to_fire
	id = "react_to_fire"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS

/datum/human_ai_action/react_to_fire/get_weight(datum/human_ai_brain/brain)
	return brain.body.on_fire ? 120 : 0

/datum/human_ai_action/react_to_fire/trigger(datum/human_ai_brain/brain)
	if(world.time < brain.next_resist_time)
		return TRUE
	brain.next_resist_time = world.time + HAI_RESIST_FIRE_INTERVAL
	brain.cancel_reload("on fire")
	brain.body.resist_fire()
	brain.fire_rolls++
	brain.add_stress(5)
	return TRUE

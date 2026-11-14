/mob/living/carbon/human/refresh_derived_movespeed()
	. = ..()

	set_movespeed_modifier(MOVESPEED_ID_SPECIES, MOVESPEED_STAGE_ADD, species.slowdown, update = FALSE)

	// Limb break/loss slowdown
	// Wheelchairs depend on different limbs than walking, which is...cute
	var/shoe_delay = 0
	var/limb_delay = 0
	var/list/limb_names
	if(istype(buckled, /obj/structure/bed/chair/wheelchair))
		limb_names = list("l_hand","r_hand","l_arm","r_arm","chest","groin","head")
	else
		if(shoes)
			shoe_delay = shoes.slowdown
		limb_names = list("l_foot","r_foot","l_leg","r_leg","chest","groin","head")
	for(var/organ_name in limb_names)
		var/obj/limb/E = get_limb(organ_name)
		if(!E || !E.is_usable())
			limb_delay += MOVE_REDUCTION_LIMB_DESTROYED
		if(!E)
			continue
		// Splinted limbs are not as punishing
		if(E.status & LIMB_SPLINTED)
			limb_delay += MOVE_REDUCTION_LIMB_SPLINTED
		else if(E.status & LIMB_BROKEN)
			limb_delay += MOVE_REDUCTION_LIMB_BROKEN
	set_movespeed_modifier(MOVESPEED_ID_SHOES, MOVESPEED_STAGE_ADD, shoe_delay, update = FALSE)
	set_movespeed_modifier(MOVESPEED_ID_LIMBS, MOVESPEED_STAGE_ADD, limb_delay, update = FALSE)

	set_movespeed_modifier(MOVESPEED_ID_PAIN, MOVESPEED_STAGE_REDUCIBLE, max(pain.pain_slowdown, stamina.stamina_slowdown), update = FALSE) // Get the highest slowdown and apply that

	var/hungry = (500 - nutrition)/5 // So overeat would be 100 and default level would be 80
	//Level where a yellow food pip shows up, aka hunger level 3 at 250 nutrition and under. Goes from a slowdown of 1 all the way to 2 for total starvation
	set_movespeed_modifier(MOVESPEED_ID_HUNGER, MOVESPEED_STAGE_REDUCIBLE, hungry >= 50 ? hungry/50 : 0, update = FALSE)

	//Equipment slowdowns
	var/wear_slowdown_reduction = 0
	var/uniform_delay = 0
	var/suit_delay = 0
	if(w_uniform)
		uniform_delay = w_uniform.slowdown
		wear_slowdown_reduction += w_uniform.movement_compensation
	if(wear_suit)
		suit_delay = wear_suit.slowdown
		wear_slowdown_reduction += wear_suit.movement_compensation
	set_movespeed_modifier(MOVESPEED_ID_UNIFORM, MOVESPEED_STAGE_REDUCIBLE, uniform_delay, update = FALSE)
	set_movespeed_modifier(MOVESPEED_ID_SUIT, MOVESPEED_STAGE_REDUCIBLE, suit_delay, update = FALSE)

	set_movespeed_modifier(MOVESPEED_ID_REAGENTS, MOVESPEED_STAGE_REDUCIBLE, reagent_move_delay_modifier, update = FALSE) //Muscle-stimulating property

	//Major slowdown if you're freezing
	set_movespeed_modifier(MOVESPEED_ID_COLD, MOVESPEED_STAGE_REDUCIBLE, (bodytemperature < species.cold_level_1 && !isyautja(src)) ? 2 : 0, update = FALSE)

	var/temporary_delay = 0
	if(temporary_slowdown)
		temporary_slowdown = max(temporary_slowdown - 1, 0)
		temporary_delay = 2 //Temporary slowdown slows hard
	set_movespeed_modifier(MOVESPEED_ID_TEMPORARY, MOVESPEED_STAGE_REDUCIBLE, temporary_delay, update = FALSE)

	set_movespeed_modifier(MOVESPEED_ID_SHIELD, MOVESPEED_STAGE_REDUCIBLE, shield_slowdown, update = FALSE)

	var/gun_delay = 0
	if(isgun(get_active_hand()))
		var/obj/item/weapon/gun/G = get_active_hand() //If wielding, it will ALWAYS be on the active hand
		gun_delay = max(0, G.slowdown - wear_slowdown_reduction)
	set_movespeed_modifier(MOVESPEED_ID_HELD_GUN, MOVESPEED_STAGE_POST, gun_delay, update = FALSE)

	var/status_delay = 0
	if(superslowed)
		status_delay = HUMAN_SUPERSLOWED_AMOUNT
	else if(slowed)
		status_delay = HUMAN_SLOWED_AMOUNT
	set_movespeed_modifier(MOVESPEED_ID_SLOWED, MOVESPEED_STAGE_FINAL, status_delay, update = FALSE)
	set_movespeed_modifier(MOVESPEED_ID_CONFIG, MOVESPEED_STAGE_FINAL, CONFIG_GET(number/human_delay), update = FALSE)

/mob/living/carbon/human/movement_delay()
	recalculate_move_delay = FALSE

	if(interactee)// moving stops any kind of interaction
		if(!(SEND_SIGNAL(src, COMSIG_HUMAN_MOVEMENT_CANCEL_INTERACTION) & COMPONENT_HUMAN_MOVEMENT_KEEP_USING))
			unset_interaction()

	if(length(embedded_items) > 0)
		handle_embedded_objects() //Moving with objects stuck in you can cause bad times.

	. = ..()

	//Compile reducible tally and send it to total tally. Cannot go more than 1 units faster from the reducible tally!
	. += max(MOVESPEED_REDUCIBLE_CAP, movespeed_total(MOVESPEED_STAGE_REDUCIBLE))
	. += movespeed_total(MOVESPEED_STAGE_POST)

	if(mobility_aura && . >= 1.5)
		. = max(. - (0.1 + 0.1 * mobility_aura), 1.5)

	. += movespeed_total(MOVESPEED_STAGE_FINAL)
	var/list/movedata = list("move_delay" = .)
	SEND_SIGNAL(src, COMSIG_HUMAN_POST_MOVE_DELAY, movedata)
	move_delay = movedata["move_delay"]

/mob/living/carbon/human/yautja/refresh_derived_movespeed()
	. = ..()
	var/status_delay = 0
	if(superslowed)
		status_delay = YAUTJA_SUPERSLOWED_AMOUNT
	else if(slowed)
		status_delay = YAUTJA_SLOWED_AMOUNT
	set_movespeed_modifier(MOVESPEED_ID_SPECIES_SLOWED, MOVESPEED_STAGE_FINAL, status_delay, update = FALSE)

/mob/living/carbon/human/Process_Spacemove(check_drift = 0)
	//Can we act
	if(is_mob_restrained())
		return 0

// if(!check_drift && J.allow_thrust(0.01, src))
// return 1

	//If no working jetpack then use the other checks
	if(..())
		return 1
	return 0


/mob/living/carbon/human/Process_Spaceslipping(prob_slip = 5)
	//If knocked out we might just hit it and stop.  This makes it possible to get dead bodies and such.

	if(species.flags & NO_SLIP)
		return

	if(stat)
		prob_slip = 0 // Changing this to zero to make it line up with the comment, and also, make more sense.

	//Do we have magboots or such on if so no slip
	if(istype(shoes, /obj/item/clothing/shoes/magboots) && (shoes.flags_inventory & NOSLIPPING))
		prob_slip = 0

	//Check hands and mod slip
	if(!l_hand)
		prob_slip -= 2
	else if(l_hand.w_class <= SIZE_SMALL) prob_slip--
	if (!r_hand) prob_slip -= 2
	else if(r_hand.w_class <= SIZE_SMALL) prob_slip--

	prob_slip = floor(prob_slip)
	return(prob_slip)

/// Updates [TRAIT_FLOORED] based on whether the mob has appropriate limbs to stand or not
/mob/living/carbon/human/proc/update_leg_status()
	if((has_limb("r_foot") && has_limb("r_leg")) || (has_limb("l_foot") && has_limb("l_leg")))
		REMOVE_TRAIT(src, TRAIT_FLOORED, BODY_TRAIT)
	else
		ADD_TRAIT(src, TRAIT_FLOORED, BODY_TRAIT)

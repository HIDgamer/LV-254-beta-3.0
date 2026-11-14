/// Abstract items standing in for the user's hand, spawned by emotes
/obj/item/hand_item
	icon = 'icons/obj/weapons/hand.dmi'
	icon_state = "latexballoon"
	item_state = "nothing"
	flags_item = NOBLUDGEON|DELONDROP|ITEM_ABSTRACT
	w_class = SIZE_HUGE
	force = 0
	throwforce = 0

/obj/item/hand_item/slapper
	name = "slapper"
	desc = "This is how real men fight."
	var/table_smacks_left = 3

/obj/item/hand_item/slapper/attack(mob/living/slapped, mob/living/user)
	user.animation_attack_on(slapped)
	if(user.zone_selected in list("head", "eyes", "mouth"))
		if(user == slapped)
			user.visible_message(SPAN_NOTICE("[user] facepalms!"), SPAN_NOTICE("You facepalm."), null, 4)
		else if(slapped.sleeping || slapped.stat == UNCONSCIOUS)
			user.visible_message(SPAN_NOTICE("[user] slaps [slapped] in the face, trying to wake [slapped.p_them()] up!"), SPAN_NOTICE("You slap [slapped] in the face, trying to wake [slapped.p_them()] up!"), null, 4)
			slapped.AdjustSleeping(-10)
		else
			user.visible_message(SPAN_DANGER("[user] slaps [slapped] in the face!"), SPAN_NOTICE("You slap [slapped] in the face!"), null, 4)
	else
		user.visible_message(SPAN_DANGER("[user] slaps [slapped]!"), SPAN_NOTICE("You slap [slapped]!"), null, 4)
	playsound(slapped, 'sound/weapons/slap.ogg', 50, TRUE, vol_cat = VOLUME_SFX)
	return ATTACKBY_HINT_NO_AFTERATTACK|ATTACKBY_HINT_UPDATE_NEXT_MOVE

/obj/item/hand_item/slapper/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	if(!proximity_flag || !istype(target, /obj/structure/surface/table))
		return FALSE
	if(islist(click_parameters) && click_parameters["right"] && table_smacks_left == initial(table_smacks_left))
		slam_table(target, user)
	else
		slap_table(target, user)
	return TRUE

/obj/item/hand_item/slapper/proc/slap_table(obj/structure/surface/table/table, mob/living/user)
	user.animation_attack_on(table)
	playsound(get_turf(table), 'sound/effects/tableslam.ogg', 40, TRUE)
	user.visible_message(SPAN_NOTICE("[user] slaps [user.p_their()] hand on [table]."), SPAN_NOTICE("You slap your hand on [table]."), null, 4)
	table_smacks_left--
	if(table_smacks_left <= 0)
		qdel(src)

/obj/item/hand_item/slapper/proc/slam_table(obj/structure/surface/table/table, mob/living/user)
	user.animation_attack_on(table)
	playsound(get_turf(table), 'sound/effects/tableslam.ogg', 110, TRUE)
	user.visible_message(SPAN_DANGER("<b>[user] slams [user.p_their()] fist down on [table]!</b>"), SPAN_DANGER("<b>You slam your fist down on [table]!</b>"))
	qdel(src)

/obj/item/hand_item/kisser
	name = "kiss"
	desc = "I want you all to know, everyone and anyone, to seal it with a kiss."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "heart"

/obj/item/hand_item/kisser/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	var/turf/user_turf = get_turf(user)
	if(!user_turf || target == user)
		return FALSE

	user.visible_message("<b>[user]</b> blows a kiss at [target]!", SPAN_NOTICE("You blow a kiss at [target]!"))
	var/obj/projectile/kiss = new(user_turf, create_cause_data("kiss", user))
	kiss.generate_bullet(GLOB.ammo_list[/datum/ammo/kiss])
	kiss.permutated += user
	kiss.fire_at(target, user, user, kiss.ammo.max_range, kiss.ammo.shell_speed)
	qdel(src)
	return TRUE

/datum/ammo/kiss
	name = "kiss"
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "heart"
	sound_hit = 'sound/effects/kiss.ogg'
	damage = 0
	max_range = 10
	shell_speed = AMMO_SPEED_TIER_2
	flags_ammo_behavior = AMMO_IGNORE_ARMOR|AMMO_IGNORE_COVER

/datum/ammo/kiss/on_hit_mob(mob/M, obj/projectile/P, mob/user)
	playsound(get_turf(M), 'sound/effects/kiss.ogg', 100, TRUE)
	M.visible_message(SPAN_NOTICE("[M] is hit by a kiss!"), SPAN_NOTICE("You're hit by a kiss!"), null, 4)

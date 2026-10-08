/obj/vehicle/souto
	name = "\improper ATV"
	icon_state = "soutomobile"
	desc = "Almost, but not quite, the best ride in the universe."
	move_delay = 2 //The speed of a fed but shoeless pajamarine, or a bit slower than a heavy-armor marine.
	buckling_y = 4
	layer = ABOVE_LYING_MOB_LAYER //Allows it to drive over people, but is below the driver.
	//Sound to play when moving
	var/movement_sound = 'sound/vehicles/jeep_driving.ogg'
	//Cooldown for next sound to play
	var/move_next_sound_play = 0

/obj/vehicle/souto/Initialize()
	. = ..()
	var/image/I = new(icon = 'icons/obj/vehicles/vehicles.dmi', icon_state = "soutomobile_overlay", layer = ABOVE_MOB_LAYER) //over mobs
	overlays += I

/obj/vehicle/souto/manual_unbuckle(mob/user)
	if(buckled_mob && buckled_mob != user)
		if(do_after(user, 20, INTERRUPT_ALL, BUSY_ICON_GENERIC))
			..()
	else ..()

/obj/vehicle/souto/relaymove(mob/user, direction)
	if(user.is_mob_incapacitated())
		return
	if(world.time > l_move_time + move_delay)
		. = step(src, direction)
		if(movement_sound && world.time > move_next_sound_play)
			playsound(src, movement_sound, vol = 20, sound_range = 30)
			move_next_sound_play = world.time + 15
/obj/vehicle/souto/super
	name = "\improper Soutomobile"
	desc = "The best ride in the universe, for the one-and-only Souto Man!"
	health = 1000
	locked = FALSE
	unacidable = TRUE
	explo_proof = TRUE

/obj/vehicle/souto/super/explode()
	for(var/mob/M as anything in viewers(7, src))
		M.show_message("Somehow, [src] still looks as bright and shiny as a new can of Souto Classic.", SHOW_MESSAGE_VISIBLE)
	health = initial(health) //Souto Man never dies, and neither does his bike.

/obj/vehicle/souto/super/buckle_mob(mob/M, mob/user)
	if(!locked) //Vehicle is unlocked until first being mounted, since the Soutomobile is faction-locked and otherwise Souto Man cannot automatically buckle in on spawn as his equipment is spawned before his ID.
		locked = TRUE
	else if(M == user && M.faction != FACTION_SOUTO && locked == TRUE) //Are you a cool enough dude to drive this bike? Nah, nobody's THAT cool.
		to_chat(user, SPAN_WARNING("Somehow, as you take hold of the handlebars, [src] manages to glare at you. You back off. We didn't sign up for haunted motorbikes, man."))
		return
	..()

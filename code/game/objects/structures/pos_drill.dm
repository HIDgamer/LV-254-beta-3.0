/obj/structure/prop/pos_drill
	name = "mining drill"
	desc = "An old mining drill, seemingly used for mining. And possibly drilling."
	icon = 'icons/obj/structures/props/industrial/drill.dmi'
	icon_state = "drill"
	bound_height = 96
	var/on = FALSE//if this is set to on by default, the drill will start on, doi
	var/drill_cycle = 0
	var/break_chance = 25

/obj/structure/prop/pos_drill/attackby(obj/item/W, mob/user)
	. = ..()
	if(isxeno(user))
		return
	else if (ishuman(user) && HAS_TRAIT(W, TRAIT_TOOL_WRENCH))
		on = !on
		visible_message("You wrench the controls of \the [src]. The drill jumps to life." , "[user] wrenches the controls of \the [src]. The drill jumps to life.")

		update()

/obj/structure/prop/pos_drill/proc/update()
	drill_cycle++
	icon_state = "thumper[on ? "-on" : ""]"
	if(on)
		set_light(3)
		playsound(src, 'sound/machines/turbine_on.ogg')
		var/current_cycle = drill_cycle
		spawn(20 SECONDS)
			drill_door(current_cycle)
	else
		set_light(0)
		playsound(src, 'sound/machines/turbine_off.ogg')
	return

/obj/structure/prop/pos_drill/proc/drill_door(expected_cycle)
	if(!src || !on || drill_cycle != expected_cycle)
		return
	var/turf/target_turf = get_step(src, dir)
	if(!target_turf)
		return
	var/obj/structure/machinery/door/target_door = locate() in target_turf
	if(target_door)
		target_door.deconstruct(disassembled = FALSE)
		playsound(loc, 'sound/effects/metal_shatter.ogg', 40, 1)
		on = FALSE
		update()


/obj/structure/prop/pos_drill/Initialize()
	. = ..()
	update()

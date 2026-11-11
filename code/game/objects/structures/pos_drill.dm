/obj/structure/prop/pos_drill
	name = "thermal drill"
	desc = "An old mining drill, seemingly used for mining. And possibly drilling."
	icon = 'icons/obj/structures/props/industrial/drill.dmi'
	icon_state = "drill"
	bound_height = 96
	var/on = FALSE//if this is set to on by default, the drill will start on, doi
	var/drill_cycle = 0
	var/drill_time = 0
	var/break_chance = 5 //percent chance to break every cycle
	var/work_progress = 0

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
		var/turf/target_turf = get_step(src, dir)
		if(target_turf)
			var/obj/structure/machinery/door/target_door = locate() in target_turf
			if(target_door)
				drill_time = min(target_door.health * 10, 360 SECONDS)
		set_light(3)
		playsound(src, 'sound/machines/turbine_on.ogg')
		var/current_cycle = drill_cycle
		spawn(min(1 SECONDS, max(1, drill_time - work_progress)))
			drill_door(current_cycle)
	else
		set_light(0)
		playsound(src, 'sound/machines/turbine_off.ogg')
	return

/obj/structure/prop/pos_drill/proc/emit_sparks(amount = 3)
	var/datum/effect_system/spark_spread/sparks = new /datum/effect_system/spark_spread
	sparks.set_up(amount, TRUE, src)
	sparks.start()
	return

/obj/structure/prop/pos_drill/proc/drill_door(expected_cycle)
	if(!src || !on || drill_cycle != expected_cycle)
		return
	var/seconds_left = max(0, round((drill_time - work_progress) / 1 SECONDS))
	visible_message("[src] beeps: [seconds_left/100] seconds remaining.")
	work_progress = min(drill_time, work_progress + 1 SECONDS)
	if(prob(break_chance))
		emit_sparks(3)
		playsound(src, 'sound/machines/terminal_shutdown.ogg', 60, FALSE)
		playsound(src, 'sound/machines/buzz-sigh.ogg', 60, FALSE)
		on = FALSE
		update()
		return
	if(work_progress < drill_time)
		var/current_cycle = drill_cycle
		spawn(min(1 SECONDS, max(1, drill_time - work_progress)))
			drill_door(current_cycle)
		return
	var/turf/target_turf = get_step(src, dir)
	if(!target_turf)
		return
	var/obj/structure/machinery/door/target_door = locate() in target_turf
	if(target_door)
		target_door.deconstruct(disassembled = FALSE)
		playsound(loc, 'sound/effects/metal_shatter.ogg', 40, 1)
		new /obj/item/thermal_drill(get_turf(src))
		qdel(src)


/obj/structure/prop/pos_drill/Initialize()
	. = ..()
	update()


/obj/item/thermal_drill
	icon = 'icons/obj/structures/machinery/defenses/sentry.dmi'
	icon_state = "Normal uac_sentry_handheld"


/obj/item/thermal_drill/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(!proximity_flag || !istype(target, /obj/structure/machinery/door))
		return
	if(alert(user, "Do you want to deploy the thermal drill?", "Deploy Thermal Drill", "Yes", "No") != "Yes")
		return

	var/deploy_dir = get_dir(user, target)
	var/turf/deploy_turf = get_step(get_turf(target), turn(deploy_dir, 180))
	if(!deploy_turf)
		return

	var/obj/structure/prop/pos_drill/drill = new(deploy_turf)
	drill.dir = deploy_dir
	user.drop_held_item()
	qdel(src)


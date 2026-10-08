/obj/vehicle/multitile/van/jeep
	name = "M48 Utility Vehicle"
	desc = "An Armat designed light utility vehicle based around providing more protection and upgradeability compared to older jeeps."

	layer = ABOVE_XENO_LAYER
	vehicle_flags = VEHICLE_CLASS_LIGHT
	vehicle_pen_armor = VEHICLE_ARMOR_LIGHT_ARMOR
	flatbed = FALSE

	icon = 'icons/obj/vehicles/jeep.dmi'
	icon_state = "jeep"
	pixel_x = -16
	pixel_y = -16

	bound_width = 64
	bound_height = 64

	bound_x = 0
	bound_y = 0

	interior_map = /datum/map_template/interior/jeep
	entrances = list(
		"left" = list(2, 0),
		"right" = list(-1, 0),
		"left_rear" = list(2, 1),
		"right_rear" = list(-1, 1),
		"rear" = list(0, 2)
	)

	movement_sound = 'sound/vehicles/jeep_driving.ogg'
	honk_sound = 'sound/vehicles/honk_4_light.ogg'
	passengers_slots = 7
	xenos_slots = 4

	misc_multipliers = list(
		"move" = 0.75, // fucking annoying how this is the only way to modify speed
		"accuracy" = 1,
		"cooldown" = 1
	)

	luminosity = 5

	health = 500

	move_max_momentum = 3
	move_turn_momentum_loss_factor = 1

	hardpoints_allowed = list(
		/obj/item/hardpoint/support/jeep/jeep_wheels,
		/obj/item/hardpoint/support/jeep/jeep_turret
	)

// Flatbed Version
/obj/vehicle/multitile/van/jeep/flatbed
	desc = "An Armat designed light utility vehicle based around providing more protection and upgradeability compared to older jeeps, this one is configured with a flatbed to store pallets."
	icon_state = "jeep_bed"
	interior_map = /datum/map_template/interior/jeep_bed
	flatbed = TRUE

	max_stored_cargo = 1

	hardpoints_allowed = list(
		/obj/item/hardpoint/support/jeep/jeep_wheels,
		/obj/item/hardpoint/support/jeep/jeep_turret
	)

// Medical Version
/obj/vehicle/multitile/van/jeep/medical
	desc = "An Armat designed light utility vehicle based around providing more protection and upgradeability compared to older jeeps, this one has been retrofitted into an ambulance."
	icon_state = "jeep_med"
	interior_map = /datum/map_template/interior/jeep_med

	hardpoints_allowed = list(
		/obj/item/hardpoint/support/jeep/jeep_wheels
	)

// Command Version
/obj/vehicle/multitile/van/jeep/command
	desc = "An Armat designed light utility vehicle based around providing more protection and upgradeability compared to older jeeps, this one is configured with a sensor tower instead of a hardpoint."

	icon_state = "jeep_cmd"
	interior_map = /datum/map_template/interior/jeep_cmd

	hardpoints_allowed = list(
		/obj/item/hardpoint/support/jeep/jeep_wheels
	)

// Police Version
/obj/vehicle/multitile/van/jeep/police
	desc = "An Armat designed light utility vehicle based around providing more protection and upgradeability compared to older jeeps, this one is used by military police units."

	icon_state = "jeep_mp"
	interior_map = /datum/map_template/interior/jeep_mp
	passengers_slots = 10

	hardpoints_allowed = list(
		/obj/item/hardpoint/support/jeep/jeep_wheels,
		/obj/item/hardpoint/support/jeep/jeep_turret
	)

// Boring procs

/obj/vehicle/multitile/van/jeep/Initialize()
	. = ..()

	var/turf/gotten_turf = get_turf(src)
	if(gotten_turf && gotten_turf.z)
		SSminimaps.add_marker(src, gotten_turf.z, MINIMAP_FLAG_USCM, "apc", 'icons/ui_icons/map_blips_large.dmi')

/obj/vehicle/multitile/van/jeep/load_hardpoints()
	add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)

/obj/vehicle/multitile/van/jeep/medical/load_hardpoints()
	return

/obj/vehicle/multitile/van/jeep/command/load_hardpoints()
	return

/obj/vehicle/multitile/van/jeep/add_seated_verbs(mob/living/M, seat)
	if(!M.client)
		return
	add_verb(M.client, list(
		/obj/vehicle/multitile/proc/get_status_info,
		/obj/vehicle/multitile/proc/open_controls_guide
	))
	if(seat == VEHICLE_DRIVER)
		add_verb(M.client, list(
			/obj/vehicle/multitile/proc/toggle_door_lock,
			/obj/vehicle/multitile/proc/activate_horn,
			/obj/vehicle/multitile/proc/name_vehicle
		))
	else if(seat == VEHICLE_GUNNER)
		add_verb(M.client, list(
			/obj/vehicle/multitile/proc/switch_hardpoint,
			/obj/vehicle/multitile/proc/cycle_hardpoint,
			/obj/vehicle/multitile/proc/name_vehicle
		))

/obj/vehicle/multitile/van/jeep/remove_seated_verbs(mob/living/M, seat)
	if(!M.client)
		return
	remove_verb(M.client, list(
		/obj/vehicle/multitile/proc/get_status_info,
		/obj/vehicle/multitile/proc/open_controls_guide,
	))
	SStgui.close_user_uis(M, src)
	if(seat == VEHICLE_DRIVER)
		remove_verb(M.client, list(
			/obj/vehicle/multitile/proc/toggle_door_lock,
			/obj/vehicle/multitile/proc/activate_horn,
			/obj/vehicle/multitile/proc/name_vehicle,
		))
	else if(seat == VEHICLE_GUNNER)
		remove_verb(M.client, list(
			/obj/vehicle/multitile/proc/switch_hardpoint,
			/obj/vehicle/multitile/proc/cycle_hardpoint,
			/obj/vehicle/multitile/proc/name_vehicle,
		))

/obj/vehicle/multitile/van/jeep/relaymove(mob/user, direction)
	if(user == seats[VEHICLE_DRIVER])
		return ..()

	if(user != seats[VEHICLE_GUNNER])
		return FALSE

	var/obj/item/hardpoint/support/jeep/jeep_turret/T = null
	for(var/obj/item/hardpoint/support/jeep/jeep_turret/TT in hardpoints)
		T = TT
		break
	if(!T)
		return FALSE

	if(direction == GLOB.reverse_dir[T.dir] || direction == T.dir)
		return FALSE

	T.user_rotation(user, turning_angle(T.dir, direction))
	update_icon()

	return TRUE

/* ------------------
PRESETS SPAWNERS
-------------------*/

/obj/effect/vehicle_spawner/jeep
	name = "Jeep Spawner"
	icon = 'icons/obj/vehicles/jeep.dmi'
	icon_state = "jeep"
	pixel_x = -16
	pixel_y = -16

/obj/effect/vehicle_spawner/jeep/Initialize()
	. = ..()
	spawn_vehicle()
	qdel(src)

//PRESET: no hardpoints
/obj/effect/vehicle_spawner/jeep/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	JEEP.update_icon()

//PRESET: wheels installed
/obj/effect/vehicle_spawner/jeep/plain/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default hardpoints, destroyed (this one spawns on VASRS elevator for VCs)
/obj/effect/vehicle_spawner/jeep/decrepit/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	load_damage(JEEP)
	JEEP.update_icon()

/obj/effect/vehicle_spawner/jeep/decrepit/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default M56
/obj/effect/vehicle_spawner/jeep/m56/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/m56)
		break

//PRESET: default M2C
/obj/effect/vehicle_spawner/jeep/m2C/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/m56/hmg)
		break

//PRESET: default Flamer
/obj/effect/vehicle_spawner/jeep/flamer/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/small_flamer)
		break

//PRESET: default TOW
/obj/effect/vehicle_spawner/jeep/missile/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/towlauncher)
		break

//PRESET: default GL
/obj/effect/vehicle_spawner/jeep/grenade/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/grenade_launcher)
		break

/obj/effect/vehicle_spawner/jeep/load_hardpoints(obj/vehicle/multitile/van/jeep/V)
	return

/obj/effect/vehicle_spawner/jeep/broken/spawn_vehicle()
	var/obj/vehicle/multitile/van/JEEP = ..()
	load_damage(JEEP)
	JEEP.update_icon()

/* ------------------
FLAT BED
-------------------*/

/obj/effect/vehicle_spawner/jeep/flatbed
	name = "Flatbed Jeep Spawner"
	icon = 'icons/obj/vehicles/jeep.dmi'
	icon_state = "jeep_bed"
	pixel_x = -16
	pixel_y = -16

/obj/effect/vehicle_spawner/jeep/flatbed/Initialize()
	. = ..()
	spawn_vehicle()
	qdel(src)

//PRESET: no hardpoints
/obj/effect/vehicle_spawner/jeep/flatbed/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/flatbed/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	JEEP.update_icon()

//PRESET: wheels installed
/obj/effect/vehicle_spawner/jeep/flatbed/plain/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default hardpoints, destroyed (this one spawns on VASRS elevator for VCs)
/obj/effect/vehicle_spawner/jeep/flatbed/decrepit/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/flatbed/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	load_damage(JEEP)
	JEEP.update_icon()

/obj/effect/vehicle_spawner/jeep/flatbed/decrepit/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default M56
/obj/effect/vehicle_spawner/jeep/flatbed/m56/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/m56)
		break

//PRESET: default M2C
/obj/effect/vehicle_spawner/jeep/flatbed/m2C/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/m56/hmg)
		break

//PRESET: default Flamer
/obj/effect/vehicle_spawner/jeep/flatbed/flamer/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/small_flamer)
		break

//PRESET: default TOW
/obj/effect/vehicle_spawner/jeep/flatbed/missile/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/towlauncher)
		break

//PRESET: default GL
/obj/effect/vehicle_spawner/jeep/flatbed/grenade/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/grenade_launcher)
		break

/obj/effect/vehicle_spawner/jeep/flatbed/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	return

/obj/effect/vehicle_spawner/jeep/flatbed/broken/spawn_vehicle()
	var/obj/vehicle/multitile/van/flatbed/JEEP = ..()
	load_damage(JEEP)
	JEEP.update_icon()

/* ------------------
MEDICAL
-------------------*/

/obj/effect/vehicle_spawner/jeep/medical
	name = "Medical Jeep Spawner"
	icon = 'icons/obj/vehicles/jeep.dmi'
	icon_state = "jeep_med"
	pixel_x = -16
	pixel_y = -16

/obj/effect/vehicle_spawner/jeep/medical/Initialize()
	. = ..()
	spawn_vehicle()
	qdel(src)

//PRESET: no hardpoints
/obj/effect/vehicle_spawner/jeep/medical/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/medical/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	JEEP.update_icon()

//PRESET: wheels installed
/obj/effect/vehicle_spawner/jeep/medical/plain/load_hardpoints(obj/vehicle/multitile/van/jeep/medical/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default hardpoints, destroyed (this one spawns on VASRS elevator for VCs)
/obj/effect/vehicle_spawner/jeep/medical/decrepit/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/medical/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	load_damage(JEEP)
	JEEP.update_icon()

/obj/effect/vehicle_spawner/jeep/medical/decrepit/load_hardpoints(obj/vehicle/multitile/van/jeep/medical/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

/obj/effect/vehicle_spawner/jeep/medical/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	return

/obj/effect/vehicle_spawner/jeep/medical/broken/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/medical/JEEP = ..()
	load_damage(JEEP)
	JEEP.update_icon()

/* ------------------
COMMAND
-------------------*/

/obj/effect/vehicle_spawner/jeep/command
	name = "Command Jeep Spawner"
	icon = 'icons/obj/vehicles/jeep.dmi'
	icon_state = "jeep_cmd"
	pixel_x = -16
	pixel_y = -16

/obj/effect/vehicle_spawner/jeep/command/Initialize()
	. = ..()
	spawn_vehicle()
	qdel(src)

//PRESET: no hardpoints
/obj/effect/vehicle_spawner/jeep/command/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/command/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	JEEP.update_icon()

//PRESET: wheels installed
/obj/effect/vehicle_spawner/jeep/command/plain/load_hardpoints(obj/vehicle/multitile/van/jeep/command/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default hardpoints, destroyed (this one spawns on VASRS elevator for VCs)
/obj/effect/vehicle_spawner/jeep/command/decrepit/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/command/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	load_damage(JEEP)
	JEEP.update_icon()

/obj/effect/vehicle_spawner/jeep/command/decrepit/load_hardpoints(obj/vehicle/multitile/van/jeep/command/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

/obj/effect/vehicle_spawner/jeep/command/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	return

/obj/effect/vehicle_spawner/jeep/command/broken/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/command/JEEP = ..()
	load_damage(JEEP)
	JEEP.update_icon()

/* ------------------
MILITARY POLICE
-------------------*/

/obj/effect/vehicle_spawner/jeep/police
	name = "Military Police Jeep Spawner"
	icon = 'icons/obj/vehicles/jeep.dmi'
	icon_state = "jeep_mp"
	pixel_x = -16
	pixel_y = -16

/obj/effect/vehicle_spawner/jeep/police/Initialize()
	. = ..()
	spawn_vehicle()
	qdel(src)

//PRESET: no hardpoints
/obj/effect/vehicle_spawner/jeep/police/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/police/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	JEEP.update_icon()

//PRESET: wheels installed
/obj/effect/vehicle_spawner/jeep/police/plain/load_hardpoints(obj/vehicle/multitile/van/jeep/police/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default hardpoints, destroyed (this one spawns on VASRS elevator for VCs)
/obj/effect/vehicle_spawner/jeep/police/decrepit/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/police/JEEP = new (loc)

	load_misc(JEEP)
	load_hardpoints(JEEP)
	handle_direction(JEEP)
	load_damage(JEEP)
	JEEP.update_icon()

/obj/effect/vehicle_spawner/jeep/police/decrepit/load_hardpoints(obj/vehicle/multitile/van/jeep/police/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

//PRESET: default R10T GL
/obj/effect/vehicle_spawner/jeep/police/riot/load_hardpoints(obj/vehicle/multitile/van/jeep/police/V)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_turret)
	V.add_hardpoint(new /obj/item/hardpoint/support/jeep/jeep_wheels)

	for(var/obj/item/hardpoint/support/jeep/jeep_turret/LT in V.hardpoints)
		LT.add_hardpoint(new /obj/item/hardpoint/primary/jeep/grenade_launcher/riot)
		break

/obj/effect/vehicle_spawner/jeep/police/load_hardpoints(obj/vehicle/multitile/van/jeep/flatbed/V)
	return

/obj/effect/vehicle_spawner/jeep/police/broken/spawn_vehicle()
	var/obj/vehicle/multitile/van/jeep/police/JEEP = ..()
	load_damage(JEEP)
	JEEP.update_icon()

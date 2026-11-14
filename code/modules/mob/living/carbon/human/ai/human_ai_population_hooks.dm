/// Every optional content hook by id, all of them off until an admin switches one on
GLOBAL_LIST_INIT(npc_population_hooks, init_npc_population_hooks())

/proc/init_npc_population_hooks()
	var/list/found = list()
	for(var/hook_type in subtypesof(/datum/npc_population_hook))
		var/datum/npc_population_hook/hook = new hook_type
		if(!hook.id)
			qdel(hook)
			continue
		found[hook.id] = hook
	return found

/// Content for one kind of round that puts AI humans where the map profile does not: it only runs while switched on and while the round suits it
/datum/npc_population_hook
	var/id
	var/name
	var/desc
	var/enabled = FALSE
	/// Runs whatever the round is, for admins who want it somewhere odd
	var/forced = FALSE
	var/list/group_types = list()
	var/list/datum/npc_population_group/groups = list()

/datum/npc_population_hook/New()
	for(var/group_type in group_types)
		groups += new group_type

/datum/npc_population_hook/Destroy()
	QDEL_LIST(groups)
	return ..()

/// Switches the hook on or off and does whatever that needs
/datum/npc_population_hook/proc/set_enabled(on)
	enabled = !!on
	on_toggle(enabled)

/datum/npc_population_hook/proc/on_toggle(on)
	return

/// Whether the round suits the hook
/datum/npc_population_hook/proc/suits_round()
	return TRUE

/datum/npc_population_hook/proc/active()
	return enabled && (forced || suits_round())

/datum/npc_population_hook/proc/validate()
	RETURN_TYPE(/list)
	var/list/problems = list()
	for(var/datum/npc_population_group/group as anything in groups)
		problems += group.validate()
	return problems

/// Marines on the ship's own decks keeping order: military police in the brig and the hallways
/datum/npc_population_hook/ship_security
	id = "ship_security"
	name = "Ship security"
	desc = "Military police on duty in the brig and the hallways of the ship."
	group_types = list(/datum/npc_population_group/hook/ship_police)

/datum/npc_population_hook/ship_security/suits_round()
	return !!GLOB.areas_by_type[/area/almayer/shipboard/brig/lobby]

/datum/npc_population_group/hook/ship_police
	id = "hook_ship_police"
	name = "Ship military police"
	presets = list(/datum/equipment_preset/uscm_ship/uscm_police/mp = 1)
	personalities = list("professional" = 3, "veteran" = 1)
	roles = list("security" = 1)
	size_min = 2
	size_max = 4
	squad_size = 2
	zones = list(/area/almayer/shipboard/brig/lobby = 2, /area/almayer/shipboard/brig/starboard_hallway = 1, /area/almayer/shipboard/brig/cic_hallway = 1)
	behavior = HAI_POP_GUARD
	marine_attitude = "friendly"

/// Marines defending the outpost of Whiskey Outpost alongside the players
/datum/npc_population_hook/whiskey_defenders
	id = "whiskey_defenders"
	name = "Whiskey Outpost defenders"
	desc = "Marines that hold the bunkers of Whiskey Outpost with the players."
	group_types = list(/datum/npc_population_group/hook/outpost_riflemen, /datum/npc_population_group/hook/outpost_support)

/datum/npc_population_hook/whiskey_defenders/suits_round()
	return !!Check_WO()

/datum/npc_population_group/hook/outpost_riflemen
	id = "hook_outpost_riflemen"
	name = "Outpost riflemen"
	presets = list(/datum/equipment_preset/uscm/private_equipped = 1)
	personalities = list("veteran" = 2, "professional" = 2, "guardian" = 1)
	roles = list("rifleman" = 4, "machinegunner" = 1, "grenadier" = 1)
	size_min = 4
	size_max = 12
	size_per_player = 0.1
	squad_size = 4
	zones = list(/area/whiskey_outpost/inside/bunker = 2, /area/whiskey_outpost/inside/bunker/bunker/front = 2, /area/whiskey_outpost/inside/engineering = 1)
	behavior = HAI_POP_GUARD
	marine_attitude = "friendly"

/datum/npc_population_group/hook/outpost_support
	id = "hook_outpost_support"
	name = "Outpost medics and engineers"
	presets = list(/datum/equipment_preset/uscm/medic = 1, /datum/equipment_preset/uscm/engineer = 1)
	personalities = list("cautious" = 2, "professional" = 1)
	roles = list("medic" = 1, "engineer" = 1)
	size_min = 2
	size_max = 5
	size_per_player = 0.05
	zones = list(/area/whiskey_outpost/inside/hospital = 2, /area/whiskey_outpost/inside/engineering = 1, /area/whiskey_outpost/inside/living = 1)
	behavior = HAI_POP_LOITER
	marine_attitude = "friendly"

/// Marines that make up the numbers when few players have joined a drop
/datum/npc_population_hook/low_pop_fill
	id = "low_pop_fill"
	name = "Low population marine fill"
	desc = "AI marines near the landing zone after the first drop, fewer the more marine players there are."
	group_types = list(/datum/npc_population_group/hook/fill_team)

/datum/npc_population_hook/low_pop_fill/suits_round()
	return !!SSticker.mode?.active_lz

/datum/npc_population_group/hook/fill_team
	id = "hook_fill_team"
	name = "Marine fill team"
	presets = list(/datum/equipment_preset/uscm/private_equipped = 4, /datum/equipment_preset/uscm/medic = 1, /datum/equipment_preset/uscm/engineer = 1)
	personalities = list("professional" = 2, "veteran" = 1, "neutral" = 1)
	roles = list("rifleman" = 4, "medic" = 1, "engineer" = 1)
	size_min = 0
	allow_empty = TRUE
	dynamic_zone = TRUE
	size_max = 12
	squad_size = 4
	timing = HAI_POP_ON_LANDING
	behavior = HAI_POP_GUARD
	marine_attitude = "friendly"
	leave_landmarks = FALSE
	/// Marine players below which the group makes up the difference
	var/full_strength = 24

/datum/npc_population_group/hook/fill_team/target_size()
	var/marines = get_active_player_count(TRUE, TRUE, TRUE, FACTION_MARINE)
	return clamp(full_strength - marines, 0, size_max)

/// The ground within a few tiles of the primary landing zone
/datum/npc_population_group/hook/fill_team/get_zone_turfs()
	if(zone_turfs)
		return zone_turfs
	zone_turfs = list()
	var/turf/landing = get_active_lz_turf()
	if(!landing)
		return zone_turfs
	var/list/usable = list()
	for(var/turf/open/candidate in range(8, landing))
		if(is_valid_admin_spawn_turf(candidate) && !istype(candidate, /turf/open/space))
			usable += candidate
	if(length(usable))
		zone_turfs["landing"] = usable
	return zone_turfs

/// Feral humans that the hive counts as its own, for rounds where the hive is played by the AI
/datum/npc_population_hook/hive_allies
	id = "hive_allies"
	name = "PvE hive allies"
	desc = "A cell of CLF fanatics on the ground that the AI hive leaves alone and that fight the marines."
	group_types = list(/datum/npc_population_group/hook/hive_cell)
	/// The hive that was made to accept the fanatics, to put back when the hook goes off
	var/hive_number

/datum/npc_population_hook/hive_allies/suits_round()
	return istype(SSticker.mode, /datum/game_mode/colonialmarines/pve_hive)

/datum/npc_population_hook/hive_allies/on_toggle(on)
	ally_hive(on)

/datum/npc_population_hook/hive_allies/proc/ally_hive(on)
	var/datum/hive_status/hive = GLOB.hive_datum[hive_number || XENO_HIVE_NORMAL]
	if(!hive)
		return
	if(on)
		hive.allies[FACTION_CLF] = TRUE
		hive_number = hive.hivenumber
	else
		hive.allies -= FACTION_CLF

/datum/npc_population_group/hook/hive_cell
	id = "hook_hive_cell"
	name = "Hive-aligned CLF cell"
	faction = FACTION_CLF
	presets = list(/datum/equipment_preset/survivor/clf = 1)
	personalities = list("zealot" = 3, "reckless" = 1)
	roles = list("rifleman" = 3, "medic" = 1)
	size_min = 3
	size_max = 6
	size_per_player = 0.05
	squad_size = 3
	dynamic_zone = TRUE
	timing = HAI_POP_ON_LANDING
	behavior = HAI_POP_PATROL
	marine_attitude = "hostile"
	leave_landmarks = FALSE

/// The ground around the hive's own spawn points
/datum/npc_population_group/hook/hive_cell/get_zone_turfs()
	if(zone_turfs)
		return zone_turfs
	zone_turfs = list()
	var/list/usable = list()
	for(var/obj/effect/landmark/xeno_spawn/spawn_point as anything in GLOB.xeno_spawns)
		for(var/turf/open/candidate in range(6, get_turf(spawn_point)))
			if(is_valid_admin_spawn_turf(candidate) && !istype(candidate, /turf/open/space))
				usable += candidate
	if(length(usable))
		zone_turfs["hive"] = usable
	return zone_turfs

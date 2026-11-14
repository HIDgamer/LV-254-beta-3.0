/// Every shipped population profile must be sound on its own terms
/datum/unit_test/human_ai_population_profiles

/datum/unit_test/human_ai_population_profiles/Run()
	TEST_ASSERT(GLOB.npc_population_profiles["LV-624"], "LV-624 has no population profile")
	for(var/map_name in GLOB.npc_population_profiles)
		var/datum/npc_population_profile/profile = GLOB.npc_population_profiles[map_name]
		TEST_ASSERT(length(profile.groups) >= 3, "[map_name] has fewer than three groups")
		var/list/problems = profile.validate()
		TEST_ASSERT(!length(problems), "[map_name] has problems: [problems.Join(" | ")]")

	var/datum/npc_population_group/bad = allocate(/datum/npc_population_group)
	bad.id = "bad"
	bad.presets = list(/obj/item = 1)
	bad.personalities = list("nonsense" = 1)
	bad.roles = list("nonsense" = 1)
	bad.zones = list(/obj = 1)
	bad.size_min = 0
	bad.faction = "no such faction"
	bad.marine_attitude = "devoted"
	bad.behavior = "dance"
	bad.timing = 9
	var/list/found = bad.validate()
	TEST_ASSERT(length(found) >= 9, "A thoroughly broken group only produced [length(found)] problems: [found.Join(" | ")]")

/// The director places groups where it is told, keeps off players and landmarks, obeys its caps and switches and keeps a group topped up
/datum/unit_test/human_ai_population_director
	var/datum/npc_population_profile/saved_profile
	var/saved_enabled
	var/saved_max_total
	var/list/made_landmarks = list()

/datum/unit_test/human_ai_population_director/Destroy()
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	director.clear_all()
	director.profile = saved_profile
	director.enabled = saved_enabled
	director.landed = FALSE
	director.corpse_times.Cut()
	SShuman_ai.max_total = saved_max_total
	GLOB.npc_population_extra_watchers.Cut()
	QDEL_LIST(made_landmarks)
	return ..()

/datum/unit_test/human_ai_population_director/proc/make_group(group_id, list/turfs, size)
	var/datum/npc_population_group/group = allocate(/datum/npc_population_group)
	group.id = group_id
	group.name = "Test [group_id]"
	group.presets = list(/datum/equipment_preset/survivor/civilian = 1)
	group.personalities = list("skittish" = 1)
	group.roles = list("civilian" = 1)
	group.size_min = size
	group.size_max = size
	group.fixed_turfs = turfs
	return group

/datum/unit_test/human_ai_population_director/Run()
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	saved_profile = director.profile
	saved_enabled = director.enabled
	saved_max_total = SShuman_ai.max_total
	var/list/rows = list("################################################################")
	for(var/row in 1 to 6)
		rows += "#..............................................................#"
	rows += "################################################################"
	var/datum/human_ai_arena/yard = new(rows, run_loc_floor_bottom_left)
	var/datum/npc_population_profile/profile = allocate(/datum/npc_population_profile)
	director.profile = profile
	director.enabled = TRUE
	director.reset_groups()

	var/mob/living/carbon/human/watcher = allocate(/mob/living/carbon/human, locate(yard.origin_x + 2, yard.origin_y + 3, yard.z))
	GLOB.npc_population_extra_watchers += watcher
	for(var/turf/where as anything in yard.floors)
		if(where.x >= yard.origin_x + 20 && where.x <= yard.origin_x + 45)
			made_landmarks += new /obj/effect/landmark/survivor_spawner(where)

	var/datum/npc_population_group/patrol = make_group("patrol", yard.floors, 6)
	patrol.squad_size = 3
	patrol.behavior = HAI_POP_PATROL
	patrol.wound_min = 10
	patrol.wound_max = 20
	profile.groups += patrol
	TEST_ASSERT_EQUAL(director.run_groups(), 6, "The first run did not place the group")
	TEST_ASSERT_EQUAL(patrol.alive_count(), 6, "The group is not at its size")
	TEST_ASSERT(patrol.placed, "The group was not marked as placed")
	var/list/spots = list()
	var/leaders = 0
	for(var/mob/living/carbon/human/member as anything in patrol.alive_members())
		TEST_ASSERT(!(member.loc in spots), "Two humans were put on one turf")
		spots += member.loc
		TEST_ASSERT(get_dist(member, watcher) >= HAI_POP_MIN_PLAYER_DISTANCE, "A human was put [get_dist(member, watcher)] tiles from a player")
		TEST_ASSERT(!(locate(/obj/effect/landmark/survivor_spawner) in member.loc), "A human was put on a survivor landmark")
		TEST_ASSERT(member.health < member.maxHealth, "A wounded group member is unhurt")
		TEST_ASSERT(member.ai_grace_until > world.time, "No grace period against the hive")
		TEST_ASSERT_EQUAL(member.ai_brain.role?.id, "civilian", "The role did not come from the group")
		TEST_ASSERT_EQUAL(member.ai_brain.personality.id, "skittish", "The personality did not come from the group")
		if(member.ai_brain.squad?.leader == member.ai_brain)
			leaders++
			TEST_ASSERT_EQUAL(member.ai_brain.current_order?.id, "patrol", "A squad leader was not sent on patrol")
	TEST_ASSERT_EQUAL(leaders, 2, "The group should have made two squads of three")
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "A placed group placed more")

	var/datum/npc_population_group/guards = make_group("guards", yard.floors, 3)
	guards.behavior = HAI_POP_GUARD
	guards.enabled = FALSE
	profile.groups += guards
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "A disabled group was placed")
	director.enabled = FALSE
	guards.enabled = TRUE
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "The master switch did not stop the director")
	director.enabled = TRUE
	SShuman_ai.max_total = length(SShuman_ai.brains) + 2
	TEST_ASSERT_EQUAL(director.run_groups(), 2, "The population cap did not hold the group to two")
	SShuman_ai.max_total = saved_max_total
	TEST_ASSERT_EQUAL(director.run_groups(), 1, "The rest of the group was not placed once there was room")
	for(var/mob/living/carbon/human/guard as anything in guards.alive_members())
		TEST_ASSERT_EQUAL(guard.ai_brain.current_order?.id, "guard", "A guard has no post")

	var/datum/npc_population_group/trickle = make_group("trickle", yard.floors, 3)
	trickle.timing = HAI_POP_TRICKLE
	profile.groups += trickle
	for(var/round in 1 to 3)
		trickle.next_spawn = 0
		TEST_ASSERT_EQUAL(director.run_groups(), 1, "The trickle group did not add one human on pass [round]")
	TEST_ASSERT_EQUAL(trickle.alive_count(), 3, "The trickle group is not at its size")
	trickle.next_spawn = 0
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "A full trickle group placed more")
	var/mob/living/carbon/human/casualty = pick(trickle.alive_members())
	casualty.stat = DEAD
	trickle.next_spawn = 0
	TEST_ASSERT_EQUAL(director.run_groups(), 1, "The trickle group did not replace its dead")
	TEST_ASSERT_EQUAL(trickle.alive_count(), 3, "The trickle group was not topped up")
	TEST_ASSERT(director.run_groups() == 0, "The trickle gap was ignored")

	var/datum/npc_population_group/late = make_group("late", yard.floors, 2)
	late.timing = HAI_POP_ON_LANDING
	profile.groups += late
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "A landing group was placed before the landing")
	director.landed = TRUE
	TEST_ASSERT_EQUAL(director.run_groups(), 2, "A landing group was not placed after the landing")

	var/datum/npc_population_group/event = make_group("event", yard.floors, 2)
	event.timing = HAI_POP_ON_EVENT
	profile.groups += event
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "An event group was placed by itself")
	TEST_ASSERT_EQUAL(director.populate_now(event), 2, "An event group was not placed when asked")

	var/mob/living/carbon/human/body = pick(patrol.alive_members())
	body.stat = DEAD
	director.run_groups()
	TEST_ASSERT(director.corpse_times[REF(body)], "The dead human was not noted")
	director.corpse_times[REF(body)] = world.time - HAI_POP_CORPSE_TIME - 1
	var/mob/living/carbon/human/onlooker = allocate(/mob/living/carbon/human, get_step(body, EAST))
	director.clear_corpses(list(onlooker))
	TEST_ASSERT(!QDELETED(body), "A body somebody could see was cleared")
	director.clear_corpses(list())
	TEST_ASSERT(QDELETED(body), "A body nobody could see was not cleared")

	var/removed = director.clear_all()
	TEST_ASSERT(removed >= 8, "Clearing the population removed only [removed]")
	TEST_ASSERT_EQUAL(patrol.spawned_total, 0, "The groups were not reset")

/// The director on the real loaded map, the health check, and the panel tab
/datum/unit_test/human_ai_population_map
	var/datum/npc_population_profile/saved_profile
	var/saved_enabled

/datum/unit_test/human_ai_population_map/Destroy()
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	director.clear_all()
	director.profile = saved_profile
	director.enabled = saved_enabled
	return ..()

/datum/unit_test/human_ai_population_map/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	saved_profile = director.profile
	saved_enabled = director.enabled
	var/datum/npc_population_profile/profile = director.find_profile()
	TEST_ASSERT_NOTNULL(profile, "The loaded map has no population profile")
	TEST_ASSERT_EQUAL(profile.map_name, "LV-624", "The test world is not LV-624, the live check needs it")
	director.profile = profile
	director.enabled = TRUE
	director.reset_groups()

	var/list/report = director.check_health(profile)
	TEST_ASSERT(!length(report), "The health check found problems on the real map: [report.Join(" | ")]")

	var/total_target = 0
	for(var/datum/npc_population_group/group as anything in profile.groups)
		total_target += group.target_size()
	for(var/pass in 1 to 10)
		director.run_groups()
	var/placed = 0
	for(var/datum/npc_population_group/group as anything in profile.groups)
		TEST_ASSERT_EQUAL(group.alive_count(), group.target_size(), "[group.id] has [group.alive_count()] of [group.target_size()] humans")
		placed += group.alive_count()
		var/list/spots = list()
		for(var/mob/living/carbon/human/member as anything in group.alive_members())
			var/area/place = get_area(member)
			TEST_ASSERT(place.type in group.zones, "[group.id] has a human in [place.type], not one of its zones")
			TEST_ASSERT(!(member.loc in spots), "[group.id] stacked two humans on a turf")
			spots += member.loc
			TEST_ASSERT_EQUAL(member.ai_brain.error_total, 0, "A placed human's brain threw errors")
			if(group.marine_attitude == "hostile")
				TEST_ASSERT(FACTION_MARINE in member.ai_brain.enemy_factions, "A hostile group does not fight marines")
	TEST_ASSERT_EQUAL(placed, total_target, "Placed [placed] humans, the profile asked for [total_target]")

	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human)
	var/datum/npc_command_console/console = new(admin)
	console.access_override = TRUE
	console.handle_action(admin, "set_tab", list("tab" = "population"))
	var/list/data = console.ui_data(admin)["population"]
	TEST_ASSERT_EQUAL(data["profile"], "LV-624", "The population tab shows the wrong profile")
	TEST_ASSERT_EQUAL(length(data["groups"]), length(profile.groups), "The population tab lists the wrong groups")
	console.handle_action(admin, "set_group_enabled", list("group" = "lv_goons", "enabled" = FALSE))
	TEST_ASSERT(!profile.get_group("lv_goons").enabled, "The group switch did not work")
	console.handle_action(admin, "set_group_enabled", list("group" = "lv_goons", "enabled" = TRUE))
	console.handle_action(admin, "set_population_enabled", list("enabled" = FALSE))
	TEST_ASSERT(!director.enabled, "The director switch did not work")
	console.handle_action(admin, "clear_population", list())
	TEST_ASSERT_EQUAL(profile.get_group("lv_clf").spawned_total, 0, "Clearing did not reset the groups")
	console.handle_action(admin, "set_population_enabled", list("enabled" = TRUE))
	console.handle_action(admin, "populate_group", list("group" = "lv_clf"))
	TEST_ASSERT(profile.get_group("lv_clf").alive_count() >= 2, "The panel could not place a group")
	qdel(console)

	var/datum/npc_population_group/missing = allocate(/datum/npc_population_group)
	missing.id = "elsewhere"
	missing.presets = list(/datum/equipment_preset/survivor/civilian = 1)
	missing.zones = list(/area/desert_dam/interior/lab_northeast = 1)
	var/datum/npc_population_profile/foreign = allocate(/datum/npc_population_profile)
	foreign.groups += missing
	var/list/foreign_report = director.check_health(foreign)
	TEST_ASSERT(findtext(foreign_report.Join(" "), "is not on this map"), "A zone from another map was not reported: [foreign_report.Join(" | ")]")

/// The optional hooks start off, run only while the round suits them or an admin forces them, and add the gear the roles need
/datum/unit_test/human_ai_population_hooks
	var/datum/npc_population_profile/saved_profile
	var/saved_enabled
	var/list/saved_hooks = list()

/datum/unit_test/human_ai_population_hooks/Destroy()
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	director.clear_all()
	director.profile = saved_profile
	director.enabled = saved_enabled
	director.round_over_done = FALSE
	SShuman_ai.paused = FALSE
	for(var/hook_id in saved_hooks)
		var/datum/npc_population_hook/hook = GLOB.npc_population_hooks[hook_id]
		hook.set_enabled(saved_hooks[hook_id])
		hook.forced = FALSE
	return ..()

/datum/unit_test/human_ai_population_hooks/Run()
	var/datum/controller/subsystem/human_ai_population/director = SShuman_ai_population
	saved_profile = director.profile
	saved_enabled = director.enabled
	for(var/hook_id in GLOB.npc_population_hooks)
		var/datum/npc_population_hook/hook = GLOB.npc_population_hooks[hook_id]
		saved_hooks[hook_id] = hook.enabled
		TEST_ASSERT(!hook.enabled, "The hook [hook_id] is on by default")
		TEST_ASSERT(!length(hook.validate()), "The hook [hook_id] has problems: [hook.validate().Join(" | ")]")
	TEST_ASSERT_EQUAL(length(GLOB.npc_population_hooks), 4, "The four hooks are not all there")

	director.profile = null
	director.enabled = TRUE
	director.reset_groups()
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "The director placed humans with every hook off")
	TEST_ASSERT_EQUAL(length(director.all_groups(TRUE)), 0, "A hook group was active with every hook off")

	var/datum/npc_population_hook/whiskey = GLOB.npc_population_hooks["whiskey_defenders"]
	whiskey.set_enabled(TRUE)
	TEST_ASSERT(!whiskey.active(), "The Whiskey Outpost hook ran in another round")
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "The Whiskey Outpost hook placed humans in another round")
	whiskey.forced = TRUE
	TEST_ASSERT(whiskey.active(), "Forcing the hook did not make it run")
	TEST_ASSERT_EQUAL(director.run_groups(), 0, "A forced hook with no ground to stand on placed humans")
	whiskey.set_enabled(FALSE)
	whiskey.forced = FALSE

	var/datum/npc_population_hook/fill = GLOB.npc_population_hooks["low_pop_fill"]
	var/datum/npc_population_group/hook/fill_team/team = fill.groups[1]
	TEST_ASSERT_EQUAL(team.target_size(), team.size_max, "With no marine players the fill team is not at full size")

	var/datum/npc_population_hook/allies = GLOB.npc_population_hooks["hive_allies"]
	var/datum/hive_status/hive = GLOB.hive_datum[XENO_HIVE_NORMAL]
	var/allied_before = hive.allies[FACTION_CLF]
	allies.set_enabled(TRUE)
	TEST_ASSERT(hive.faction_is_ally(FACTION_CLF, TRUE), "The hive does not accept the fanatics")
	allies.set_enabled(FALSE)
	TEST_ASSERT(!hive.allies[FACTION_CLF], "The hive still accepts the fanatics")
	if(allied_before)
		hive.allies[FACTION_CLF] = allied_before

	var/datum/npc_population_hook/police = GLOB.npc_population_hooks["ship_security"]
	TEST_ASSERT(police.suits_round(), "The test world has no ship brig")
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human)
	var/datum/npc_command_console/console = new(admin)
	console.access_override = TRUE
	console.handle_action(admin, "set_hook_enabled", list("hook" = "ship_security", "enabled" = TRUE))
	TEST_ASSERT(police.enabled, "The panel could not switch the hook on")
	TEST_ASSERT_EQUAL(director.run_groups(), 2, "The ship security hook did not place its two police")
	var/datum/npc_population_group/patrol = police.groups[1]
	for(var/mob/living/carbon/human/cop as anything in patrol.alive_members())
		TEST_ASSERT_EQUAL(cop.ai_brain.role?.id, "security", "A ship police officer has the wrong role")
		TEST_ASSERT_NOTNULL(cop.ai_brain.find_cuffs(), "A ship police officer has no cuffs")
		TEST_ASSERT_NOTNULL(cop.ai_brain.find_baton(), "A ship police officer has no baton")
		TEST_ASSERT(istype(get_area(cop), /area/almayer/shipboard/brig), "A ship police officer is not in the brig")
	console.handle_action(admin, "set_tab", list("tab" = "population"))
	var/list/hook_rows = console.ui_data(admin)["population"]["hooks"]
	TEST_ASSERT_EQUAL(length(hook_rows), 4, "The population tab does not list the hooks")
	console.handle_action(admin, "set_hook_forced", list("hook" = "whiskey_defenders", "forced" = TRUE))
	TEST_ASSERT(whiskey.forced, "The panel could not force the hook")
	whiskey.forced = FALSE
	console.handle_action(admin, "set_hook_enabled", list("hook" = "ship_security", "enabled" = FALSE))
	TEST_ASSERT(!police.enabled, "The panel could not switch the hook off")
	qdel(console)
	director.clear_all()

	var/datum/npc_population_group/kit_group = allocate(/datum/npc_population_group)
	kit_group.id = "kits"
	kit_group.presets = list(/datum/equipment_preset/uscm/private_equipped = 1)
	kit_group.roles = list("medic" = 1)
	kit_group.fixed_turfs = list(get_turf(admin))
	var/mob/living/carbon/human/medic = kit_group.spawn_member(get_turf(admin))
	TEST_ASSERT_NOTNULL(medic, "The kit test human was not made")
	var/list/supplies = medic.ai_brain.medical_supplies()
	TEST_ASSERT(length(supplies[HAI_MED_BANDAGE]) && length(supplies[HAI_MED_SALVE]) && length(supplies[HAI_MED_SPLINT]), "The medic was not given all three kinds of supply")
	qdel(medic)

	director.round_over()
	TEST_ASSERT(SShuman_ai.paused, "The round end did not stop the AI")

/// A roofed area for the civilians to hide in
/area/human_ai_test_shelter
	name = "Test shelter"
	ceiling = CEILING_METAL

/// A colonist with a nervous nature and no gun
/datum/unit_test/proc/make_civilian(turf/where, personality = "skittish")
	var/mob/living/carbon/human/colonist = make_soldier(where, FACTION_COLONIST, FALSE, personality)
	if(!colonist)
		return null
	colonist.ai_brain.set_role("civilian")
	return colonist

/// Civilians run for a roof, stay put once under it, put their hands up for a gun, follow an armed friend when there is no roof and keep out of the fire lanes
/datum/unit_test/human_ai_civilians
	var/datum/human_ai_brain/civilian
	var/turf/hall_spot

/datum/unit_test/human_ai_civilians/proc/under_roof()
	return human_ai_indoors(get_turf(civilian.body))

/datum/unit_test/human_ai_civilians/proc/hands_up()
	return civilian.surrendered

/datum/unit_test/human_ai_civilians/proc/near_friend(mob/living/carbon/human/friend, distance)
	return get_dist(civilian.body, friend) <= distance

/datum/unit_test/human_ai_civilians/proc/calm()
	return !civilian.civilian_alarm()

/datum/unit_test/human_ai_civilians/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/town = new(list(
		"##############################",
		"#..................#.........#",
		"#..................#.........#",
		"#..................D.........#",
		"#..................#.........#",
		"#..................#.........#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/area/human_ai_test_shelter/roof = new
	for(var/x_offset in 20 to 28)
		for(var/y_offset in 1 to 5)
			roof.contents += locate(town.origin_x + x_offset, town.origin_y + y_offset, town.z)
	var/obj/structure/machinery/door/airlock/entrance = town.first_door("D")
	entrance.open(TRUE)
	sleep(2 SECONDS)
	var/mob/living/carbon/human/colonist = make_civilian(locate(town.origin_x + 10, town.origin_y + 3, town.z))
	TEST_ASSERT_NOTNULL(colonist, "The colonist took no brain")
	civilian = colonist.ai_brain
	TEST_ASSERT_EQUAL(civilian.roe, HAI_ROE_WEAPONS_HOLD, "Colonists do not hold fire")
	TEST_ASSERT(!under_roof(), "The colonist starts under a roof")
	var/turf/monster_turf = locate(town.origin_x + 4, town.origin_y + 3, town.z)
	var/mob/living/carbon/xenomorph/drone/monster = make_target_dummy(monster_turf)
	var/start_distance = get_dist(colonist, monster)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(under_roof)), 25), "The colonist never took shelter, it is at [colonist.x],[colonist.y]: [civilian.decision_log.Join(" | ")]")
	TEST_ASSERT(get_dist(colonist, monster) > start_distance, "The colonist ran toward the monster")
	sleep(4 SECONDS)
	TEST_ASSERT(civilian.sheltered, "The colonist is not sheltering: [civilian.decision_log.Join(" | ")]")
	var/turf/hiding_place = get_turf(colonist)
	sleep(5 SECONDS)
	TEST_ASSERT(get_turf(colonist) == hiding_place, "The colonist left its shelter while the monster was about")
	TEST_ASSERT_EQUAL(civilian.shots_fired, 0, "A colonist fired")
	qdel(monster)
	civilian.contacts = list()
	civilian.set_target(null)
	civilian.panic_until = world.time + 3 SECONDS
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(calm)), 8), "The colonist never calmed down")
	detach_human_ai(colonist)

	var/mob/living/carbon/human/hostage = make_civilian(locate(town.origin_x + 10, town.origin_y + 3, town.z))
	civilian = hostage.ai_brain
	var/mob/living/carbon/human/raider = make_soldier(locate(town.origin_x + 14, town.origin_y + 3, town.z), FACTION_CLF, TRUE)
	raider.setDir(WEST)
	raider.ai_brain.aggression = HAI_AGGRO_NONE
	raider.ai_brain.next_idle_time = world.time + 10 MINUTES
	raider.ai_brain.roe = HAI_ROE_WEAPONS_HOLD
	SSspatial_grid.track(raider, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hands_up)), 12), "The colonist did not put its hands up for a gun turned on it: [civilian.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(civilian.hands_up_count, 1, "The hands went up [civilian.hands_up_count] times")
	raider.drop_held_items()
	detach_human_ai(hostage)
	detach_human_ai(raider)
	release_roof(roof)

	var/datum/human_ai_arena/field = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/lost = make_civilian(locate(field.origin_x + 16, field.origin_y + 2, field.z))
	civilian = lost.ai_brain
	var/mob/living/carbon/human/rifleman = make_soldier(locate(field.origin_x + 6, field.origin_y + 2, field.z), FACTION_MARINE, TRUE)
	var/mob/living/carbon/xenomorph/drone/hunter = make_target_dummy(locate(field.origin_x + 24, field.origin_y + 2, field.z))
	civilian.panic()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(near_friend), rifleman, 4), 25), "With no roof to hide under the colonist did not stick close to the armed marine, it is at [lost.x],[lost.y]: [civilian.decision_log.Join(" | ")]")
	TEST_ASSERT(civilian.followed_armed >= 1, "The following was not counted")
	qdel(hunter)
	detach_human_ai(lost)
	detach_human_ai(rifleman)
	release_roof(roof)

	var/datum/human_ai_arena/lanes = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/area/human_ai_test_shelter/south_roof = new
	var/area/human_ai_test_shelter/north_roof = new
	for(var/x_offset in 12 to 16)
		for(var/y_offset in 1 to 2)
			south_roof.contents += locate(lanes.origin_x + x_offset, lanes.origin_y + y_offset, lanes.z)
		for(var/y_offset in 4 to 5)
			north_roof.contents += locate(lanes.origin_x + x_offset, lanes.origin_y + y_offset, lanes.z)
	var/mob/living/carbon/human/runner_man = make_civilian(locate(lanes.origin_x + 12, lanes.origin_y + 3, lanes.z))
	civilian = runner_man.ai_brain
	var/mob/living/carbon/human/shooter = make_soldier(locate(lanes.origin_x + 6, lanes.origin_y + 2, lanes.z), FACTION_MARINE, TRUE)
	var/mob/living/carbon/xenomorph/drone/attacker = make_target_dummy(locate(lanes.origin_x + 20, lanes.origin_y + 2, lanes.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(civilian_sees), attacker), 8), "The colonist never saw the monster")
	var/list/lane = civilian.fire_lane_turfs()
	TEST_ASSERT(lane[locate(lanes.origin_x + 14, lanes.origin_y + 2, lanes.z)], "A turf between the marine and the monster is not in the fire lane")
	TEST_ASSERT(!lane[locate(lanes.origin_x + 14, lanes.origin_y + 5, lanes.z)], "A turf far from the line of fire is in the fire lane")
	var/turf/chosen = civilian.find_shelter()
	TEST_ASSERT_NOTNULL(chosen, "The colonist found no shelter")
	TEST_ASSERT(!lane[chosen], "The colonist picked shelter in the line of fire")
	TEST_ASSERT(chosen.y != lanes.origin_y + 2, "The colonist picked the row the marine is shooting along")
	TEST_ASSERT_EQUAL(civilian.error_total, 0, "The colonist's brain threw errors")
	qdel(attacker)
	detach_human_ai(runner_man)
	detach_human_ai(shooter)
	release_roof(south_roof)
	release_roof(north_roof)

/datum/unit_test/human_ai_civilians/proc/release_roof(area/human_ai_test_shelter/roof)
	var/area/plain = get_area(run_loc_floor_bottom_left)
	for(var/turf/roofed as anything in roof.contents.Copy())
		plain.contents += roofed

/datum/unit_test/human_ai_civilians/proc/civilian_sees(mob/living/carbon/xenomorph/drone/monster)
	return !!civilian.get_contact(monster)

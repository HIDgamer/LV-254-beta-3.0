/// An enemy seen through a gap in the floor gets a grenade dropped on it, and a unit with nothing to drop goes down after it by the ladder
/datum/unit_test/human_ai_enemy_below
	var/mob/living/carbon/human/walker
	var/mob/living/carbon/xenomorph/drone/dummy
	var/datum/space_level/upper_level
	var/list/old_traits

/datum/unit_test/human_ai_enemy_below/Destroy()
	if(upper_level)
		upper_level.traits = old_traits
	walker = null
	dummy = null
	upper_level = null
	return ..()

/datum/unit_test/human_ai_enemy_below/proc/dropped()
	return walker.ai_brain.plunges > 0

/datum/unit_test/human_ai_enemy_below/proc/hurt()
	return dummy.health < dummy.maxHealth

/datum/unit_test/human_ai_enemy_below/proc/arrived_below(lower_z)
	return walker.z == lower_z

/datum/unit_test/human_ai_enemy_below/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, this scenario needs it")
	var/turf/upper_reference = run_loc_floor_bottom_left
	var/lower_z = (upper_reference.z == world.maxz) ? upper_reference.z - 1 : upper_reference.z + 1
	TEST_ASSERT(lower_z >= 1 && lower_z <= world.maxz, "The test world has no second level")
	var/turf/lower_reference = locate(1, 1, lower_z)
	// The level below is the one the world says is under this one, for as long as the test lasts
	upper_level = SSmapping.z_list[upper_reference.z]
	old_traits = upper_level.traits
	upper_level.traits = old_traits.Copy()
	upper_level.traits[ZTRAIT_DOWN] = lower_z - upper_reference.z

	var/list/rows = list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	)
	var/datum/human_ai_arena/upper = new(rows, upper_reference, 20, 20)
	var/datum/human_ai_arena/lower = new(rows, lower_reference, 20, 20)
	var/turf/hole = locate(upper.origin_x + 10, upper.origin_y + 2, upper_reference.z)
	hole.ChangeTurf(/turf/open_space)
	TEST_ASSERT_EQUAL(SSmapping.get_turf_below(hole), locate(hole.x, hole.y, lower_z), "The level below is not where the test put it")

	dummy = allocate(/mob/living/carbon/xenomorph/drone, locate(lower.origin_x + 10, lower.origin_y + 2, lower_z))
	dummy.maxHealth = 3000
	dummy.health = 3000
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)

	walker = make_soldier(locate(upper.origin_x + 4, upper.origin_y + 2, upper_reference.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = walker.ai_brain
	brain.light_override = 1
	brain.suppress_error_log = TRUE
	TEST_ASSERT_NOTNULL(brain.find_enemy_below(get_turf(walker)), "The enemy under the gap was not seen")
	TEST_ASSERT_EQUAL(brain.below_gap, hole, "The enemy was seen through some other gap")

	// With a grenade to drop, it is dropped
	new /obj/item/explosive/grenade/high_explosive/frag(walker)
	brain.grenade_cache_time = 0
	brain.next_below_scan = 0
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(dropped)), 30), "The unit never dropped its grenade through the gap: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hurt)), 20), "The grenade that was dropped did not hurt the enemy below: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(walker.z, upper_reference.z, "The unit went down with its grenade")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors: [brain.decision_log.Join(" | ")]")
	detach_human_ai(walker)
	qdel(walker)

	// A friend next to the enemy stops the grenade, and without one the unit goes down after the enemy by the ladder
	var/obj/structure/ladder/lower_ladder = allocate(/obj/structure/ladder, locate(lower.origin_x + 14, lower.origin_y + 2, lower_z))
	var/obj/structure/ladder/upper_ladder = allocate(/obj/structure/ladder, locate(upper.origin_x + 14, upper.origin_y + 2, upper_reference.z))
	lower_ladder.height = 0
	upper_ladder.height = 1
	lower_ladder.up = upper_ladder
	upper_ladder.down = lower_ladder
	// The blast of the first grenade threw the enemy off the spot, so it is put back under the gap
	dummy.health = dummy.maxHealth
	dummy.forceMove(locate(lower.origin_x + 10, lower.origin_y + 2, lower_z))
	walker = make_soldier(locate(upper.origin_x + 4, upper.origin_y + 2, upper_reference.z), FACTION_MARINE, FALSE)
	brain = walker.ai_brain
	brain.light_override = 1
	brain.suppress_error_log = TRUE
	var/mob/living/carbon/human/friend = allocate(/mob/living/carbon/human, locate(lower.origin_x + 11, lower.origin_y + 2, lower_z))
	friend.faction = FACTION_MARINE
	new /obj/item/explosive/grenade/high_explosive/frag(walker)
	brain.grenade_cache_time = 0
	brain.next_below_scan = 0
	brain.scan_below(get_turf(walker))
	var/turf/walker_turf = get_turf(walker)
	TEST_ASSERT_NOTNULL(brain.get_enemy_below(), "The enemy below was not seen the second time: hole [hole.type], under it [SSmapping.get_turf_below(walker_turf)], dummy at [dummy.x],[dummy.y],[dummy.z] stat [dummy.stat] health [dummy.health], walker at [walker.x],[walker.y],[walker.z], distance [get_dist(walker, hole)], disposition [brain.get_disposition(dummy)], clarity [brain.clarity_of(dummy, get_turf(dummy), get_dist(walker, hole))], below_gap [brain.below_gap], seen [brain.below_seen_time] now [world.time]")
	TEST_ASSERT(!brain.plunge_ready(), "A grenade was ready to be dropped next to a friend")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(arrived_below), lower_z), 90), "The unit never went down after the enemy, it is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.ladders_climbed >= 1, "The way down was not by the ladder, the unit is at [walker.x],[walker.y],[walker.z]: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.plunges, 0, "A grenade was dropped on a friend")
	detach_human_ai(walker)
	qdel(walker)

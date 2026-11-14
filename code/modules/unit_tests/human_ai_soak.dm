/// Ten walkers keep picking new random goals in a building of doors, tables and barricades, very few trips may fail
/datum/unit_test/human_ai_soak
	var/walkers = 10
	var/seconds = 90
	var/max_failure_percent = 10

/datum/unit_test/human_ai_soak/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, the soak needs it")
	var/list/rows = list(
		"########################",
		"#......#.......#.......#",
		"#......D.......D.......#",
		"#......#.......#.......#",
		"####D#####T#########D###",
		"#......................#",
		"#..TT..................#",
		"#......B...............#",
		"####D######D############",
		"#......#.......#.......#",
		"#......D.......#.......#",
		"#......#.......D.......#",
		"########################",
	)
	for(var/row in rows)
		TEST_ASSERT_EQUAL(length(row), length(rows[1]), "The soak layout has a ragged row: [row]")
	var/datum/human_ai_arena/building = new(rows, run_loc_floor_bottom_left)
	TEST_ASSERT(length(building.floors) > 40, "The soak building has too few open tiles")

	var/list/crowd = list()
	for(var/index in 1 to walkers)
		var/mob/living/carbon/human/walker = allocate(/mob/living/carbon/human, pick(building.floors))
		walker.faction = FACTION_MARINE
		attach_human_ai(walker)
		walker.ai_brain.keep_awake = TRUE
		crowd += walker

	var/trips = 0
	var/failures = 0
	var/list/failure_notes = list()
	var/list/assigned = list()
	for(var/tick in 1 to seconds * 2)
		for(var/mob/living/carbon/human/walker as anything in crowd)
			var/datum/human_ai_brain/brain = walker.ai_brain
			if(!brain || brain.waypoint)
				continue
			if(assigned[walker])
				assigned[walker] = FALSE
				var/last = brain.decision_log[length(brain.decision_log)]
				if(findtext(last, "reached waypoint"))
					trips++
				else
					failures++
					failure_notes += last
			var/turf/next_goal = pick(building.floors)
			if(get_dist(next_goal, walker) < 4)
				continue
			brain.waypoint = next_goal
			assigned[walker] = TRUE
		sleep(5)

	TEST_NOTICE(src, "[trips] trips and [failures] failures in [seconds] s with [walkers] walkers, SShuman_ai cost [round(SShuman_ai.total_cost_ms)] ms")
	TEST_ASSERT(trips >= walkers * 2, "The walkers barely moved, only [trips] trips")
	TEST_ASSERT(failures * 100 <= (trips + failures) * max_failure_percent, "[failures] of [trips + failures] trips failed: [failure_notes.Join(" | ")]")
	for(var/mob/living/carbon/human/walker as anything in crowd)
		TEST_ASSERT_EQUAL(walker.ai_brain?.error_total || 0, 0, "A walker's brain threw errors")

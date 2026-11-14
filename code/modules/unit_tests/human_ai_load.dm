/// 60 idle brains must stay inside their share of the server, and none may error
/datum/unit_test/human_ai_load
	var/budget_ms_per_second = 30
	var/seconds = 10

/datum/unit_test/human_ai_load/Run()
	var/list/crowd = list()
	for(var/index in 1 to HAI_MAX_FULL)
		var/mob/living/carbon/human/member = allocate(/mob/living/carbon/human, pick(block(run_loc_floor_bottom_left, run_loc_floor_top_right)))
		member.faction = FACTION_MARINE
		TEST_ASSERT(attach_human_ai(member), "Brain [index] of [HAI_MAX_FULL] did not attach")
		member.ai_brain.keep_awake = TRUE
		crowd += member

	TEST_ASSERT_EQUAL(SShuman_ai.full_count, HAI_MAX_FULL, "Not every brain got full fidelity")
	SShuman_ai.reset_cost_meter()
	sleep(seconds SECONDS)

	var/cost_per_second = SShuman_ai.total_cost_ms / seconds
	TEST_NOTICE(src, "[SShuman_ai.total_thinks] thinks cost [round(SShuman_ai.total_cost_ms, 0.1)] ms over [seconds] s, [round(cost_per_second, 0.1)] ms/s for [HAI_MAX_FULL] idle brains")
	TEST_ASSERT(SShuman_ai.total_thinks >= HAI_MAX_FULL * seconds * 0.5, "The brains barely thought, only [SShuman_ai.total_thinks] thinks in [seconds] s")
	TEST_ASSERT(cost_per_second <= budget_ms_per_second, "Idle brains cost [round(cost_per_second, 0.1)] ms/s, over the [budget_ms_per_second] ms/s budget")

	for(var/mob/living/carbon/human/member as anything in crowd)
		TEST_ASSERT_NOTNULL(member.ai_brain, "A brain dropped off during the run")
		TEST_ASSERT_EQUAL(member.ai_brain.error_total, 0, "A brain threw errors during the run")

/// Thirty armed brains with thirty enemies in view of them must still fit the budget
/datum/unit_test/human_ai_sight_load
	var/budget_ms_per_second = 75
	var/seconds = 15

/datum/unit_test/human_ai_sight_load/Run()
	var/datum/human_ai_arena/yard = new(list(
		"########################",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"#......................#",
		"########################",
	), run_loc_floor_bottom_left)
	var/list/marines = list()
	for(var/index in 1 to 30)
		var/mob/living/carbon/human/marine = allocate(/mob/living/carbon/human, pick(yard.floors))
		marine.faction = FACTION_MARINE
		var/obj/item/weapon/gun/rifle/m41a/rifle = allocate(/obj/item/weapon/gun/rifle/m41a, marine)
		marine.put_in_hands(rifle)
		attach_human_ai(marine)
		marine.ai_brain.keep_awake = TRUE
		marines += marine
	for(var/index in 1 to 30)
		var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, pick(yard.floors))
		SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)

	SShuman_ai.reset_cost_meter()
	sleep(seconds SECONDS)
	var/cost_per_second = (SShuman_ai.total_cost_ms - SShuman_ai.gun_cost_ms) / seconds
	var/gun_per_second = SShuman_ai.gun_cost_ms / seconds
	TEST_NOTICE(src, "[SShuman_ai.total_thinks] thinks cost [round(cost_per_second, 0.1)] ms/s of AI work plus [round(gun_per_second, 0.1)] ms/s of stock gun code, for 30 shooting brains with 30 enemies in view")
	TEST_ASSERT(cost_per_second <= budget_ms_per_second, "Fighting brains cost [round(cost_per_second, 0.1)] ms/s outside the gun code, over the [budget_ms_per_second] ms/s budget")
	for(var/mob/living/carbon/human/marine as anything in marines)
		TEST_ASSERT_EQUAL(marine.ai_brain?.error_total || 0, 0, "A fighting brain threw errors")

/// An AI rifleman walks to a waypoint, shoots a dummy xeno, ignores a neutral human and lets go of a dead target
/datum/unit_test/human_ai_basics

/datum/unit_test/human_ai_basics/proc/arm(mob/living/carbon/human/human)
	var/obj/item/weapon/gun/rifle/m41a/rifle = allocate(/obj/item/weapon/gun/rifle/m41a, human)
	human.put_in_hands(rifle)
	return rifle

/datum/unit_test/human_ai_basics/proc/wait_until(datum/callback/check, seconds)
	for(var/waited in 1 to seconds * 4)
		if(check.Invoke())
			return TRUE
		sleep(2.5)
	return check.Invoke()

/datum/unit_test/human_ai_basics/proc/at_goal(mob/living/carbon/human/human, turf/goal)
	return get_dist(human, goal) <= 1

/datum/unit_test/human_ai_basics/proc/hurt(mob/living/carbon/xenomorph/dummy)
	return QDELETED(dummy) || dummy.health < dummy.maxHealth || dummy.stat == DEAD

/datum/unit_test/human_ai_basics/proc/clashed(mob/living/carbon/human/human, mob/living/carbon/xenomorph/xeno)
	return QDELETED(xeno) || xeno.health < xeno.maxHealth || human.health < human.maxHealth || human.stat == DEAD

/datum/unit_test/human_ai_basics/proc/rounds_spent(obj/item/weapon/gun/gun, rounds_before)
	return !gun.current_mag || gun.current_mag.current_rounds < rounds_before

/datum/unit_test/human_ai_basics/proc/idle_again(datum/human_ai_brain/brain)
	return QDELETED(brain) || (!brain.get_target() && brain.intent == HAI_INTENT_IDLE)

/datum/unit_test/human_ai_basics/Run()
	var/mob/living/carbon/human/walker = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	TEST_ASSERT(attach_human_ai(walker), "The walker did not take a brain")
	walker.ai_brain.keep_awake = TRUE
	walker.ai_brain.waypoint = run_loc_floor_top_right
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(at_goal), walker, run_loc_floor_top_right), 12), "The walker did not reach its waypoint, it stopped at [walker.x],[walker.y]")
	sleep(1 SECONDS)
	TEST_ASSERT(isnull(walker.ai_brain.waypoint), "The waypoint was not cleared on arrival")
	detach_human_ai(walker)
	allocated -= walker
	qdel(walker)

	var/mob/living/carbon/human/neutral = allocate(/mob/living/carbon/human, locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z))
	neutral.faction = "test_faction"
	var/mob/living/carbon/human/guard = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	guard.faction = FACTION_MARINE
	arm(guard)
	attach_human_ai(guard)
	guard.ai_brain.keep_awake = TRUE
	sleep(3 SECONDS)
	TEST_ASSERT(isnull(guard.ai_brain.get_target()), "The guard picked a neutral human as a target")
	TEST_ASSERT(guard.ai_brain.intent == HAI_INTENT_IDLE, "The guard left idle with nothing hostile in view")
	detach_human_ai(guard)
	allocated -= guard
	qdel(guard)
	allocated -= neutral
	qdel(neutral)

	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	shooter.faction = FACTION_MARINE
	var/obj/item/weapon/gun/rifle/m41a/rifle = arm(shooter)
	var/mob/living/carbon/xenomorph/drone/dummy = allocate(/mob/living/carbon/xenomorph/drone, locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z))
	SSspatial_grid.track(dummy, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT_NOTNULL(rifle.current_mag, "The test rifle spawned without a magazine")
	var/rounds_before = rifle.current_mag.current_rounds
	TEST_ASSERT(attach_human_ai(shooter), "The shooter did not take a brain")
	var/datum/human_ai_brain/brain = shooter.ai_brain
	brain.keep_awake = TRUE
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(hurt), dummy), 15), "The rifleman never hurt the dummy xeno, intent [brain.intent], target [brain.get_target()], rounds [rifle.current_mag.current_rounds]/[rounds_before], dummy [dummy.health]/[dummy.maxHealth] at [dummy.x],[dummy.y] shooter [shooter.x],[shooter.y] dir [shooter.dir] shots [brain.shots_fired] wielded [!!(rifle.flags_item & WIELDED)] errors [brain.error_total] log [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(rifle.current_mag.current_rounds < rounds_before, "The rifle was never fired")
	TEST_ASSERT(brain.intent == HAI_INTENT_ENGAGE, "The rifleman fought without the engage intent")

	dummy.death()
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(idle_again), brain), 15), "The rifleman kept its dead target, intent [brain.intent]")
	TEST_ASSERT(length(brain.decision_log), "The decision log stayed empty")
	detach_human_ai(shooter)

	var/mob/living/carbon/human/duelist = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	duelist.faction = FACTION_MARINE
	var/obj/item/weapon/gun/rifle/m41a/duel_rifle = arm(duelist)
	var/mob/living/carbon/xenomorph/hunter = spawn_ai_xeno(XENO_CASTE_DRONE, locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT_NOTNULL(hunter, "The AI xeno did not spawn")
	allocated += hunter
	var/duel_rounds = duel_rifle.current_mag.current_rounds
	TEST_ASSERT(attach_human_ai(duelist), "The duelist did not take a brain")
	duelist.ai_brain.keep_awake = TRUE
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(clashed), duelist, hunter), 25), "The rifleman and the AI xeno never clashed, intent [duelist.ai_brain?.intent], hp [duelist.health] stat [duelist.stat] log [duelist.ai_brain?.decision_log.Join(" | ")], rounds [duel_rifle.current_mag.current_rounds]/[duel_rounds]")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(rounds_spent), duel_rifle, duel_rounds), 10), "The duelist never fired at the AI xeno")
	TEST_ASSERT_EQUAL(duelist.ai_brain?.error_total || 0, 0, "The duelist's brain threw errors")

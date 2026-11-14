/// Fixed mob states whose movement_delay() must never change unintentionally
/datum/unit_test/movement_golden
	var/list/golden = list(
		"human run" = 3,
		"human walk" = 8,
		"human speed +0.5" = 3.5,
		"human speed -0.5" = 2.5,
		"human slowed" = 5,
		"human superslowed" = 7,
		"human slowed and superslowed" = 7,
		"human temporary slowdown" = 5,
		"human shield slowdown" = 3.5,
		"human reagent -1" = 2.3,
		"human reagent +1" = 4,
		"human hungry" = 4.6,
		"human slightly hungry" = 4.2,
		"human cold" = 5,
		"human bump delay" = 13,
		"human drowsy" = 9,
		"human aura 1 superslowed" = 6.8,
		"human aura 2 superslowed" = 6.7,
		"human aura 2 plain" = 2.7,
		"human mixed" = 6.8,
		"human walk mixed" = 14.5,
		"yautja run" = 2.5,
		"yautja superslowed" = 3.5,
		"yautja slowed" = 3.25,
		"uniform slowdown 1" = 4,
		"uniform slowdown -1" = 2.3,
		"suit slowdown 1" = 4,
		"suit slowdown 1 compensation 0.5" = 4,
		"suit slowdown 0.5 with gun 1 compensation 0.5" = 4,
		"shoes slowdown 1" = 4,
		"gun slowdown 1" = 4,
		"gun slowdown 2 suit compensation 1" = 4,
		"all gear" = 4.25,
		"broken foot" = 4.5,
		"splinted broken leg" = 3.5,
		"broken chest" = 4.5,
		"destroyed foot" = 7,
		"pulling crate" = 6,
		"pulling human passive" = 6,
		"pulling human aggressive" = 12,
		"xeno /mob/living/carbon/xenomorph/ravager run" = 3,
		"xeno /mob/living/carbon/xenomorph/praetorian run" = 2.4,
		"xeno /mob/living/carbon/xenomorph/hivelord run" = 3.2,
		"xeno /mob/living/carbon/xenomorph/defender run" = 2.4,
		"xeno /mob/living/carbon/xenomorph/crusher run" = 3.2,
		"xeno /mob/living/carbon/xenomorph/predalien run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/predalien/noannounce run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/predalien/tutorial run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/runner run" = 1,
		"xeno /mob/living/carbon/xenomorph/boiler run" = 3,
		"xeno /mob/living/carbon/xenomorph/burrower run" = 2.8,
		"xeno /mob/living/carbon/xenomorph/drone run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/drone/tutorial run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/hellhound run" = 2,
		"xeno /mob/living/carbon/xenomorph/lesser_drone run" = 2.4,
		"xeno /mob/living/carbon/xenomorph/lurker run" = 1.6,
		"xeno /mob/living/carbon/xenomorph/sentinel run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/spitter run" = 2.6,
		"xeno /mob/living/carbon/xenomorph/carrier run" = 2.8,
		"xeno /mob/living/carbon/xenomorph/queen run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/combat_ready run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/corrupted run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/forsaken run" = 3.2,
		"xeno /mob/living/carbon/xenomorph/queen/forsaken/combat_ready run" = 3.2,
		"xeno /mob/living/carbon/xenomorph/queen/alpha run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/bravo run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/charlie run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/delta run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/queen/mutated run" = 3.6,
		"xeno /mob/living/carbon/xenomorph/warrior run" = 2.2,
		"xeno /mob/living/carbon/xenomorph/king run" = 3.4,
		"xeno /mob/living/carbon/xenomorph/king/rogue run" = 3.4,
		"xeno /mob/living/carbon/xenomorph/despoiler run" = 2,
		"runner walk" = 6,
		"runner agility" = 1,
		"runner ability +1" = 2,
		"runner frenzy 4" = 0.8,
		"runner slowed" = 1.7,
		"runner superslowed" = 2.5,
		"runner both slows" = 2.5,
		"runner own weeds" = 0.95,
		"runner fast resin" = 0.8,
		"runner weeds and resin" = 0.76,
		"runner everything" = 2.03,
		"drone own weeds" = 2.09,
		"queen superslowed" = 5.1,
		"simple animal run" = 3,
	)

/datum/unit_test/movement_golden/proc/record(name, value)
	if(isnull(golden[name]))
		TEST_FAIL("No golden value for [name]")
		return
	if(abs(golden[name] - value) > 0.001)
		TEST_FAIL("[name]: expected [golden[name]], got [value]")

/datum/unit_test/movement_golden/proc/human_case(name, list/changes, walk = FALSE, type = /mob/living/carbon/human)
	var/mob/living/carbon/human/human = allocate(type, run_loc_floor_bottom_left)
	human.m_intent = walk ? MOVE_INTENT_WALK : MOVE_INTENT_RUN
	for(var/var_name in changes)
		human.vars[var_name] = changes[var_name]
	record(name, human.movement_delay())

/datum/unit_test/movement_golden/proc/item_case(name, slot, slowdown, compensation = 0, gun_slowdown = null)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	human.m_intent = MOVE_INTENT_RUN
	var/obj/item/clothing/item = new /obj/item/clothing(human)
	item.slowdown = slowdown
	item.movement_compensation = compensation
	switch(slot)
		if("uniform")
			human.w_uniform = item
		if("suit")
			human.wear_suit = item
		if("shoes")
			human.shoes = item
	if(!isnull(gun_slowdown))
		var/obj/item/weapon/gun/gun = new /obj/item/weapon/gun(human)
		gun.slowdown = gun_slowdown
		human.put_in_hands(gun)
	record(name, human.movement_delay())

/datum/unit_test/movement_golden/proc/limb_case(name, zone, status)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	human.m_intent = MOVE_INTENT_RUN
	var/obj/limb/limb = human.get_limb(zone)
	if(limb)
		limb.status |= status
	record(name, human.movement_delay())

/datum/unit_test/movement_golden/proc/xeno_case(name, path, list/changes, weeds = FALSE, resin = FALSE, walk = FALSE)
	var/mob/living/carbon/xenomorph/xeno = allocate(path, run_loc_floor_bottom_left)
	xeno.m_intent = walk ? MOVE_INTENT_WALK : MOVE_INTENT_RUN
	for(var/var_name in changes)
		xeno.vars[var_name] = changes[var_name]
	var/obj/effect/alien/weeds/placed_weeds
	var/obj/effect/alien/resin/sticky/fast/placed_resin
	if(weeds)
		placed_weeds = new /obj/effect/alien/weeds(xeno.loc, null, TRUE, FALSE)
	if(resin)
		placed_resin = new /obj/effect/alien/resin/sticky/fast(xeno.loc)
	record(name, xeno.movement_delay())
	qdel(placed_weeds)
	qdel(placed_resin)

/datum/unit_test/movement_golden/Run()

	human_case("human run", list())
	human_case("human walk", list(), walk = TRUE)
	human_case("human speed +0.5", list("speed" = 0.5))
	human_case("human speed -0.5", list("speed" = -0.5))
	human_case("human slowed", list("slowed" = 1))
	human_case("human superslowed", list("superslowed" = 1))
	human_case("human slowed and superslowed", list("slowed" = 1, "superslowed" = 1))
	human_case("human temporary slowdown", list("temporary_slowdown" = 3))
	human_case("human shield slowdown", list("shield_slowdown" = 0.5))
	human_case("human reagent -1", list("reagent_move_delay_modifier" = -1))
	human_case("human reagent +1", list("reagent_move_delay_modifier" = 1))
	human_case("human hungry", list("nutrition" = 100))
	human_case("human slightly hungry", list("nutrition" = 200))
	human_case("human cold", list("bodytemperature" = 200))
	human_case("human bump delay", list("do_bump_delay" = 1))
	human_case("human drowsy", list("drowsyness" = 5))
	human_case("human aura 1 superslowed", list("mobility_aura" = 1, "superslowed" = 1))
	human_case("human aura 2 superslowed", list("mobility_aura" = 2, "superslowed" = 1))
	human_case("human aura 2 plain", list("mobility_aura" = 2))
	human_case("human mixed", list("speed" = 1, "slowed" = 1, "mobility_aura" = 2, "reagent_move_delay_modifier" = -0.5, "nutrition" = 100))
	human_case("human walk mixed", list("speed" = 0.5, "superslowed" = 1, "temporary_slowdown" = 2), walk = TRUE)
	human_case("yautja run", list(), type = /mob/living/carbon/human/yautja)
	human_case("yautja superslowed", list("superslowed" = 1), type = /mob/living/carbon/human/yautja)
	human_case("yautja slowed", list("slowed" = 1), type = /mob/living/carbon/human/yautja)

	item_case("uniform slowdown 1", "uniform", 1)
	item_case("uniform slowdown -1", "uniform", -1)
	item_case("suit slowdown 1", "suit", 1)
	item_case("suit slowdown 1 compensation 0.5", "suit", 1, 0.5)
	item_case("suit slowdown 0.5 with gun 1 compensation 0.5", "suit", 0.5, 0.5, 1)
	item_case("shoes slowdown 1", "shoes", 1)
	item_case("gun slowdown 1", "none", 0, 0, 1)
	item_case("gun slowdown 2 suit compensation 1", "suit", 0, 1, 2)
	item_case("all gear", "suit", 0.5, 0.25, 1)

	limb_case("broken foot", "l_foot", LIMB_BROKEN)
	limb_case("splinted broken leg", "r_leg", LIMB_BROKEN|LIMB_SPLINTED)
	limb_case("broken chest", "chest", LIMB_BROKEN)
	limb_case("destroyed foot", "l_foot", LIMB_DESTROYED)

	var/mob/living/carbon/human/puller = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, run_loc_floor_bottom_left)
	puller.pulling = crate
	crate.pulledby = puller
	record("pulling crate", puller.movement_delay())
	var/mob/living/carbon/human/pulled = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/puller_two = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	puller_two.pulling = pulled
	pulled.pulledby = puller_two
	record("pulling human passive", puller_two.movement_delay())
	puller_two.grab_level = GRAB_AGGRESSIVE
	record("pulling human aggressive", puller_two.movement_delay())

	var/list/castes = list()
	for(var/path in subtypesof(/mob/living/carbon/xenomorph))
		if(ispath(path, /mob/living/carbon/xenomorph/facehugger) || ispath(path, /mob/living/carbon/xenomorph/larva))
			continue
		if(path in castes)
			continue
		castes += path
	for(var/path in castes)
		xeno_case("xeno [path] run", path, list())

	xeno_case("runner walk", /mob/living/carbon/xenomorph/runner, list(), walk = TRUE)
	xeno_case("runner agility", /mob/living/carbon/xenomorph/runner, list("agility" = TRUE))
	xeno_case("runner ability +1", /mob/living/carbon/xenomorph/runner, list("ability_speed_modifier" = 1))
	xeno_case("runner frenzy 4", /mob/living/carbon/xenomorph/runner, list("frenzy_aura" = 4))
	xeno_case("runner slowed", /mob/living/carbon/xenomorph/runner, list("slowed" = 1))
	xeno_case("runner superslowed", /mob/living/carbon/xenomorph/runner, list("superslowed" = 1))
	xeno_case("runner both slows", /mob/living/carbon/xenomorph/runner, list("slowed" = 1, "superslowed" = 1))
	xeno_case("runner own weeds", /mob/living/carbon/xenomorph/runner, list(), weeds = TRUE)
	xeno_case("runner fast resin", /mob/living/carbon/xenomorph/runner, list(), resin = TRUE)
	xeno_case("runner weeds and resin", /mob/living/carbon/xenomorph/runner, list(), weeds = TRUE, resin = TRUE)
	xeno_case("runner everything", /mob/living/carbon/xenomorph/runner, list("agility" = TRUE, "ability_speed_modifier" = 0.5, "frenzy_aura" = 2, "slowed" = 1), weeds = TRUE)
	xeno_case("drone own weeds", /mob/living/carbon/xenomorph/drone, list(), weeds = TRUE)
	xeno_case("queen superslowed", /mob/living/carbon/xenomorph/queen, list("superslowed" = 1))

	check_modifier_api()
	check_state_changes()

	var/mob/living/simple_animal/animal = allocate(/mob/living/simple_animal, run_loc_floor_bottom_left)
	animal.m_intent = MOVE_INTENT_RUN
	record("simple animal run", animal.movement_delay())

/datum/unit_test/movement_golden/proc/near(a, b)
	return abs(a - b) < 0.001

/datum/unit_test/movement_golden/proc/check_state_changes()
	var/mob/living/carbon/human/probe = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/base = probe.movement_delay()

	probe.slowed = 1
	TEST_ASSERT(near(probe.movement_delay(), base + HUMAN_SLOWED_AMOUNT), "a state change after the first call was not picked up")
	probe.slowed = 0
	TEST_ASSERT(near(probe.movement_delay(), base), "a cleared state was not dropped")

	probe.set_body_position(LYING_DOWN)
	TEST_ASSERT(probe.body_position == LYING_DOWN, "the probe could not lie down")
	TEST_ASSERT(probe.recalculate_move_delay, "lying down did not flag a delay recalculation")
	TEST_ASSERT(near(probe.movement_delay(), base + CRAWLING_SLOWDOWN), "crawling did not add the crawl delay")
	probe.set_body_position(STANDING_UP)
	TEST_ASSERT(near(probe.movement_delay(), base), "standing up did not remove the crawl delay")

/datum/unit_test/movement_golden/proc/check_modifier_api()
	var/mob/living/carbon/human/probe = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/base = probe.movement_delay()

	probe.set_movespeed_modifier("test", MOVESPEED_STAGE_ADD, 1)
	TEST_ASSERT(near(probe.movement_delay(), base + 1), "additive modifier was not applied")
	TEST_ASSERT(probe.has_movespeed_modifier("test"), "modifier not listed")
	probe.remove_movespeed_modifier("test")
	TEST_ASSERT(near(probe.movement_delay(), base), "removing the modifier did not restore the delay")
	TEST_ASSERT(!probe.has_movespeed_modifier("test"), "modifier still listed after removal")

	probe.set_movespeed_modifier("test", MOVESPEED_STAGE_ADD, 1)
	probe.set_movespeed_modifier("test", MOVESPEED_STAGE_ADD, 0)
	TEST_ASSERT(!probe.has_movespeed_modifier("test"), "zero amount did not remove the modifier")

	probe.set_movespeed_modifier("test", MOVESPEED_STAGE_REDUCIBLE, -5)
	TEST_ASSERT(near(probe.movement_delay(), base + MOVESPEED_REDUCIBLE_CAP), "reducible sum was not capped")
	probe.remove_movespeed_modifier("test")

	probe.set_movespeed_modifier("test", MOVESPEED_STAGE_POST, 2)
	TEST_ASSERT(near(probe.movement_delay(), base + 2), "post modifier was not applied")
	probe.remove_movespeed_modifier("test")

	probe.set_movespeed_modifier("test", MOVESPEED_STAGE_FINAL, 1.5)
	TEST_ASSERT(near(probe.movement_delay(), base + 1.5), "final modifier was not applied")
	probe.remove_movespeed_modifier("test")

	var/mob/living/carbon/xenomorph/runner/xeno = allocate(/mob/living/carbon/xenomorph/runner, run_loc_floor_bottom_left)
	var/xeno_base = xeno.movement_delay()
	xeno.set_movespeed_modifier("test", MOVESPEED_STAGE_MULT, 0.5)
	TEST_ASSERT(near(xeno.movement_delay(), xeno_base * 0.5), "multiplicative modifier was not applied")
	xeno.remove_movespeed_modifier("test")
	TEST_ASSERT(near(xeno.movement_delay(), xeno_base), "multiplicative modifier was not removed")

/// A body with an ID card of the paygrade on it and the job given, which is all the AI knows of somebody's rank
/datum/unit_test/proc/make_ranked(turf/where, paygrade, job)
	var/mob/living/carbon/human/man = allocate(/mob/living/carbon/human, where)
	man.faction = FACTION_MARINE
	man.job = job
	if(paygrade)
		var/obj/item/card/id/card = new(man)
		card.paygrade = paygrade
		man.wear_id = card
	return man

/// How much the AI respects somebody follows their rank: command staff in full, officers almost, the enlisted by their grade, and the unranked at a flat chance that leaders rise above
/datum/unit_test/human_ai_signal_authority

/datum/unit_test/human_ai_signal_authority/Run()
	var/turf/here = run_loc_floor_bottom_left
	TEST_ASSERT_EQUAL(human_ai_authority(make_ranked(here, PAY_SHORT_MO2, JOB_CO)), 1, "The commanding officer is not respected in full")
	TEST_ASSERT_EQUAL(human_ai_authority(null), 0, "Nobody is respected")
	var/officer = human_ai_authority(make_ranked(here, PAY_SHORT_MO2, "Logistics Officer"))
	TEST_ASSERT_EQUAL(officer, HAI_SIGNAL_OFFICER, "An officer is respected [officer] and not [HAI_SIGNAL_OFFICER]")
	var/private = human_ai_authority(make_ranked(here, PAY_SHORT_ME1, "Rifleman"))
	var/sergeant = human_ai_authority(make_ranked(here, PAY_SHORT_ME5, "Rifleman"))
	TEST_ASSERT(private < HAI_SIGNAL_UNRANKED, "A private is respected [private], as much as a man with no rank at all")
	TEST_ASSERT(sergeant > private, "A sergeant [sergeant] is respected no more than a private [private]")
	TEST_ASSERT(sergeant < officer, "A sergeant [sergeant] is respected as much as an officer [officer]")
	TEST_ASSERT(human_ai_authority(make_ranked(here, PAY_SHORT_ME1, "Squad Leader")) >= HAI_SIGNAL_LEADER, "A squad leader of low rank is not heeded as a leader is")
	// No proper rank: no card, or a civilian one, is a flat chance and a leader's is more
	TEST_ASSERT_EQUAL(human_ai_authority(make_ranked(here, null, "Gangster")), HAI_SIGNAL_UNRANKED, "A man with no card is not at the flat chance")
	TEST_ASSERT_EQUAL(human_ai_authority(make_ranked(here, PAY_SHORT_CIV, "Colonist")), HAI_SIGNAL_UNRANKED, "A civilian is not at the flat chance")
	TEST_ASSERT_EQUAL(human_ai_authority(make_ranked(here, null, "Gangster Boss")), HAI_SIGNAL_LEADER, "A gang boss is not heeded as a leader is")

/// A signal is rolled for by what the one who made it is worth, an order of the command panel never is
/datum/unit_test/human_ai_signal_chance

/datum/unit_test/human_ai_signal_chance/Run()
	var/mob/living/carbon/human/soldier = make_soldier(run_loc_floor_bottom_left, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/datum/npc_order/follow/order = new
	order.delivery = HAI_DELIVERY_COMMAND
	order.authority = 0
	TEST_ASSERT_EQUAL(brain.comply_chance(order), 1, "A command was rolled for")
	order.delivery = HAI_DELIVERY_REQUEST
	TEST_ASSERT_EQUAL(brain.comply_chance(order), 1, "A request with no risk was rolled for")
	order.delivery = HAI_DELIVERY_SIGNAL
	order.authority = 1
	TEST_ASSERT_EQUAL(brain.comply_chance(order), 1, "A signal from somebody who is respected in full was refused")
	order.authority = HAI_SIGNAL_UNRANKED
	TEST_ASSERT_EQUAL(brain.comply_chance(order), HAI_SIGNAL_UNRANKED, "A signal from somebody with no rank is not at the flat chance")
	order.authority = 0.3
	TEST_ASSERT(brain.comply_chance(order) < HAI_SIGNAL_UNRANKED, "A signal from a private is heeded as much as one from somebody with no rank")
	// The disciplined and loyal heed it more and the rest less
	brain.set_personality("professional")
	var/disciplined = brain.comply_chance(order)
	brain.set_personality("reckless")
	TEST_ASSERT(disciplined > brain.comply_chance(order), "A professional does not heed a signal more than a reckless man")
	detach_human_ai(soldier)

/// The emotes make the signal for the friends who can see them and nobody else: units near enough take them up as the spoken command of the same name
/datum/unit_test/human_ai_signal_emotes
	var/mob/living/carbon/human/commander

/datum/unit_test/human_ai_signal_emotes/Destroy()
	commander = null
	return ..()

/datum/unit_test/human_ai_signal_emotes/proc/signal(key)
	var/datum/emote/emote = GLOB.emote_list[key][1]
	return emote.run_emote(commander, null, null, TRUE)

/datum/unit_test/human_ai_signal_emotes/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, this scenario needs it")
	TEST_ASSERT(GLOB.emote_list["followme"], "There is no follow me emote")
	TEST_ASSERT(GLOB.emote_list["holdposition"], "There is no hold position emote")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	commander = make_ranked(locate(yard.origin_x + 5, yard.origin_y + 3, yard.z), PAY_SHORT_MO2, JOB_CO)
	commander.setDir(EAST)
	var/list/near = list()
	for(var/offset in list(-2, -1, 1, 2))
		near += make_soldier(locate(yard.origin_x + 8, yard.origin_y + 3 + offset, yard.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/far = make_soldier(locate(yard.origin_x + 20, yard.origin_y + 3, yard.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/enemy = make_soldier(locate(yard.origin_x + 7, yard.origin_y + 2, yard.z), FACTION_UPP, FALSE)
	var/mob/living/carbon/human/civilian = make_soldier(locate(yard.origin_x + 7, yard.origin_y + 4, yard.z), FACTION_COLONIST, FALSE)
	civilian.ai_brain.set_role("civilian")

	TEST_ASSERT(signal("followme"), "The emote did not run")
	for(var/mob/living/carbon/human/mate as anything in near)
		TEST_ASSERT_EQUAL(mate.ai_brain.current_order?.id, "follow", "A mate who saw the signal did not follow: [mate.ai_brain.decision_log.Join(" | ")]")
		TEST_ASSERT_EQUAL(mate.ai_brain.current_order.get_target(), commander, "A mate follows somebody else")
		TEST_ASSERT_EQUAL(mate.ai_brain.current_order.delivery, HAI_DELIVERY_SIGNAL, "The order was not a signal")
	TEST_ASSERT_NULL(far.ai_brain.current_order, "A unit too far to see the signal took it up")
	TEST_ASSERT_NULL(enemy.ai_brain.current_order, "The enemy followed a signal")
	TEST_ASSERT_NULL(civilian.ai_brain.current_order, "A civilian followed a signal")

	// Another signal in the next breath is not answered, the same people only heed one every few seconds
	TEST_ASSERT(signal("holdposition"), "The second emote did not run")
	for(var/mob/living/carbon/human/mate as anything in near)
		TEST_ASSERT_EQUAL(mate.ai_brain.current_order?.id, "follow", "A signal made at once after another changed what a mate does")
	for(var/mob/living/carbon/human/mate as anything in near)
		mate.ai_brain.voice_heard = list()
	TEST_ASSERT(signal("holdposition"), "The second emote did not run again")
	for(var/mob/living/carbon/human/mate as anything in near)
		TEST_ASSERT_EQUAL(mate.ai_brain.current_order?.id, "hold", "A mate who saw the signal did not hold: [mate.ai_brain.decision_log.Join(" | ")]")

	// Somebody nobody respects is rolled against, every unit that saw it either took it up or refused it, so the first ones are sent away
	for(var/mob/living/carbon/human/unit as anything in near + list(far, enemy, civilian))
		detach_human_ai(unit)
		qdel(unit)
	var/mob/living/carbon/human/private = make_ranked(locate(yard.origin_x + 12, yard.origin_y + 3, yard.z), PAY_SHORT_ME1, "Rifleman")
	private.setDir(EAST)
	var/list/crowd = list()
	for(var/index in 1 to 10)
		var/mob/living/carbon/human/unit = make_soldier(locate(yard.origin_x + 14 + (index % 3), yard.origin_y + 1 + round(index / 3), yard.z), FACTION_MARINE, FALSE)
		crowd += unit
	commander = private
	signal("followme")
	var/took = 0
	var/refused = 0
	for(var/mob/living/carbon/human/unit as anything in crowd)
		if(unit.ai_brain.current_order?.id == "follow")
			took++
		refused += unit.ai_brain.orders_refused
	TEST_ASSERT_EQUAL(took + refused, length(crowd), "Some of the crowd neither took the signal up nor refused it, took [took] refused [refused]")
	TEST_ASSERT(refused > 0, "Every one of ten units heeded a private")
	for(var/mob/living/carbon/human/unit as anything in crowd)
		detach_human_ai(unit)

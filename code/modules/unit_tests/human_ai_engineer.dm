/// An engineer with a pack of sheet metal and what else is asked for
/datum/unit_test/proc/make_engineer(turf/where, sheets = 12, with_sentry = FALSE, mines = 0, with_charge = FALSE)
	var/mob/living/carbon/human/builder = make_soldier(where, FACTION_MARINE, FALSE)
	if(!builder)
		return null
	var/obj/item/storage/backpack/bag = new(builder)
	builder.equip_to_slot_if_possible(bag, WEAR_BACK)
	if(sheets)
		var/obj/item/stack/sheet/metal/metal = new(bag)
		metal.amount = sheets
	if(with_sentry)
		new /obj/item/defenses/handheld/sentry(bag)
	for(var/count in 1 to mines)
		new /obj/item/explosive/mine(bag)
	if(with_charge)
		new /obj/item/explosive/plastic(bag)
	builder.ai_brain.set_role("engineer")
	return builder

/// Engineers wall off a line, deploy a sentry behind it and mines in front, never seal themselves in, and blow a wall when told
/datum/unit_test/human_ai_engineer
	var/datum/human_ai_brain/builder

/datum/unit_test/human_ai_engineer/proc/finished(datum/npc_order/order)
	return order.status != HAI_ORDER_ACTIVE

/datum/unit_test/human_ai_engineer/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 4, yard.origin_y + 4, yard.z)
	var/mob/living/carbon/human/engineer = make_engineer(start, 12, TRUE, 2)
	TEST_ASSERT_NOTNULL(engineer, "The engineer took no brain")
	builder = engineer.ai_brain
	var/turf/line_center = locate(start.x + 6, start.y, start.z)
	var/datum/npc_order/fortify/dig_in = new
	dig_in.target_turf = line_center
	dig_in.facing = EAST
	TEST_ASSERT(builder.give_order(dig_in), "The engineer refused to fortify: [dig_in.refuse_reason]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(finished), dig_in), 120), "The fortify order never ended, phase [dig_in.phase], built [builder.barricades_built]: [builder.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(dig_in.status, HAI_ORDER_DONE, "The fortify order ended as [dig_in.status]: [builder.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(builder.barricades_built, 3, "The engineer built [builder.barricades_built] barricades and skipped [dig_in.skipped]")
	for(var/offset in -1 to 1)
		var/obj/structure/barricade/metal/wall = locate() in locate(line_center.x, line_center.y + offset, line_center.z)
		TEST_ASSERT_NOTNULL(wall, "No barricade at offset [offset] of the line")
		TEST_ASSERT_EQUAL(wall.dir, EAST, "A barricade faces [wall.dir] and not the threat")
	var/obj/item/stack/sheet/metal/leftover = locate() in engineer.get_contents()
	TEST_ASSERT(!leftover || leftover.amount < HAI_BARRICADE_COST, "The engineer kept [leftover?.amount] sheets it should have used")
	TEST_ASSERT(builder.defenses_deployed >= 1, "The sentry was never deployed")
	TEST_ASSERT(locate(/obj/structure/machinery/defenses/sentry) in range(4, line_center), "No sentry stands behind the line")
	TEST_ASSERT(builder.mines_laid >= 1, "No mine was laid in front of the line")
	var/mines_out = 0
	for(var/obj/item/explosive/mine/mine in range(8, line_center))
		if(mine.active)
			mines_out++
	TEST_ASSERT(mines_out >= 1, "The mines are not armed")
	TEST_ASSERT_EQUAL(builder.error_total, 0, "The engineer's brain threw errors: [builder.decision_log.Join(" | ")]")
	detach_human_ai(engineer)

	var/datum/human_ai_arena/hall = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/boxed = make_engineer(locate(hall.origin_x + 2, hall.origin_y + 2, hall.z), 12)
	builder = boxed.ai_brain
	var/datum/npc_order/fortify/seal = new
	seal.target_turf = locate(hall.origin_x + 5, hall.origin_y + 2, hall.z)
	seal.facing = EAST
	TEST_ASSERT(builder.give_order(seal), "The second fortify order was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(finished), seal), 90), "The second fortify order never ended: [builder.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(builder.barricades_built, 2, "The engineer built [builder.barricades_built] barricades where one gap had to stay open")
	TEST_ASSERT(seal.skipped >= 1, "The engineer walled itself in")
	detach_human_ai(boxed)

	var/datum/human_ai_arena/vault = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/wall_turf = locate(vault.origin_x + 10, vault.origin_y + 2, vault.z)
	wall_turf.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/sapper = make_engineer(locate(vault.origin_x + 4, vault.origin_y + 2, vault.z), 0, FALSE, 0, TRUE)
	builder = sapper.ai_brain
	var/datum/npc_order/demolish/blow = new
	blow.target_turf = wall_turf
	TEST_ASSERT(builder.give_order(blow), "The sapper refused to demolish: [blow.refuse_reason]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(finished), blow), 60), "The demolition never ended, phase [blow.phase]: [builder.decision_log.Join(" | ")]")
	TEST_ASSERT(builder.charges_planted >= 1, "No charge was planted")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(wall_gone), wall_turf), 20), "The charge did not bring the wall down, it is still [wall_turf.type]")
	TEST_ASSERT_EQUAL(builder.error_total, 0, "The sapper's brain threw errors")
	detach_human_ai(sapper)

/datum/unit_test/human_ai_engineer/proc/wall_gone(turf/spot)
	return !spot.density

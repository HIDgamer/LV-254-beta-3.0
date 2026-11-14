/// An engineer who keeps a door live while enemies come and lets it down for friends
/datum/unit_test/human_ai_door_shock
	var/obj/structure/machinery/door/airlock/gate
	var/datum/human_ai_brain/guard

/datum/unit_test/human_ai_door_shock/proc/electrified()
	return gate.isElectrified() && gate.electrified_by == FACTION_MARINE

/datum/unit_test/human_ai_door_shock/proc/dead_wire()
	return gate.secondsElectrified == 0

/datum/unit_test/human_ai_door_shock/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/block = new(list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........D.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	), run_loc_floor_bottom_left)
	gate = block.first_door("D")
	var/turf/door_turf = get_turf(gate)
	gate.open(TRUE)
	sleep(2 SECONDS)
	var/mob/living/carbon/human/engineer = make_engineer(locate(block.origin_x + 9, block.origin_y + 2, block.z), 0)
	var/obj/item/device/multitool/tool = new(engineer)
	engineer.put_in_hands(tool)
	guard = engineer.ai_brain
	var/datum/npc_order/guard_door/watch = new
	watch.target_turf = door_turf
	TEST_ASSERT(guard.give_order(watch), "The engineer refused to guard the door: [watch.refuse_reason]")
	sleep(4 SECONDS)
	TEST_ASSERT(!gate.isElectrified(), "The door was electrified with nobody coming")
	var/mob/living/carbon/human/raider = allocate(/mob/living/carbon/human, locate(block.origin_x + 17, block.origin_y + 2, block.z))
	raider.faction = FACTION_CLF
	SSspatial_grid.track(raider, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(electrified)), 15), "The door was not electrified as an enemy came, guard log: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(guard.shocks_armed, 1, "The shock was armed [guard.shocks_armed] times")
	TEST_ASSERT(gate.path_secure(), "The live door is not marked as secure for pathing")
	TEST_ASSERT(gate.ai_tampered, "The door does not show it was tampered with")
	var/list/hint = gate.get_examine_text(raider)
	TEST_ASSERT(findtext(hint.Join(" "), "tampered"), "Examining the door gives no hint")
	var/mob/living/carbon/human/friend = allocate(/mob/living/carbon/human, locate(block.origin_x + 8, block.origin_y + 3, block.z))
	friend.faction = FACTION_MARINE
	TEST_ASSERT(gate.electrified_exempt(friend), "A friend is not spared the shock")
	TEST_ASSERT(!gate.electrified_exempt(raider), "An enemy is spared the shock")
	TEST_ASSERT(!gate.shock(friend, 100), "A friend was shocked")
	var/mob/living/carbon/human/mate = make_soldier(locate(block.origin_x + 10, block.origin_y + 3, block.z), FACTION_MARINE, FALSE)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(dead_wire)), 10), "The door was not let down for a friend at it, guard log: [guard.decision_log.Join(" | ")]")
	TEST_ASSERT(guard.shocks_lifted >= 1, "Lifting the shock was not counted")
	TEST_ASSERT_EQUAL(guard.error_total, 0, "The guard's brain threw errors")
	detach_human_ai(engineer)
	detach_human_ai(mate)

/// A grenade wired to a door goes off for the first stranger who opens it and not for friends, and can be taken out
/datum/unit_test/human_ai_door_trap
	var/obj/structure/machinery/door/airlock/gate

/datum/unit_test/human_ai_door_trap/proc/rigged()
	return !!gate.GetComponent(/datum/component/door_trap)

/datum/unit_test/human_ai_door_trap/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/block = new(list(
		"####################",
		"#..........#.......#",
		"#..........#.......#",
		"#..........D.......#",
		"#..........#.......#",
		"#..........#.......#",
		"####################",
	), run_loc_floor_bottom_left)
	gate = block.first_door("D")
	var/turf/door_turf = get_turf(gate)
	var/mob/living/carbon/human/engineer = make_engineer(locate(block.origin_x + 8, block.origin_y + 3, block.z), 0)
	var/obj/item/explosive/grenade/flashbang/flash = new(engineer)
	var/datum/human_ai_brain/builder = engineer.ai_brain
	var/datum/npc_order/rig_door/rig = new
	rig.target_turf = door_turf
	TEST_ASSERT(builder.give_order(rig), "The engineer refused to rig the door: [rig.refuse_reason]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(rigged)), 20), "The door was never rigged: [builder.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(builder.traps_rigged, 1, "The rigging was not counted")
	TEST_ASSERT(flash.loc == gate, "The grenade is not wired inside the door")
	TEST_ASSERT(gate.path_secure(), "A rigged door is not marked as secure for pathing")
	TEST_ASSERT(gate in GLOB.human_ai_door_traps, "The trap is not in the registry")
	var/list/hint = gate.get_examine_text(engineer)
	TEST_ASSERT(findtext(hint.Join(" "), "tampered"), "A rigged door shows no sign")

	var/mob/living/carbon/human/friend = allocate(/mob/living/carbon/human, locate(block.origin_x + 9, block.origin_y + 2, block.z))
	friend.faction = FACTION_MARINE
	gate.last_opener = friend
	gate.open(TRUE)
	sleep(3 SECONDS)
	TEST_ASSERT(rigged(), "The trap went off for a friend")
	gate.close(TRUE)
	sleep(3 SECONDS)
	var/mob/living/carbon/human/raider = allocate(/mob/living/carbon/human, locate(block.origin_x + 13, block.origin_y + 2, block.z))
	raider.faction = FACTION_CLF
	gate.last_opener = raider
	gate.open(TRUE)
	sleep(3 SECONDS)
	TEST_ASSERT(!rigged(), "The trap did not go off for a stranger")
	TEST_ASSERT(QDELETED(flash) || flash.loc != gate, "The grenade is still inside the door")
	TEST_ASSERT(!(gate in GLOB.human_ai_door_traps), "A spent trap is still in the registry")

	var/obj/item/explosive/grenade/flashbang/second = new(get_turf(engineer))
	var/mob/living/carbon/human/defuser = allocate(/mob/living/carbon/human, locate(block.origin_x + 9, block.origin_y + 4, block.z))
	gate.AddComponent(/datum/component/door_trap, second, FACTION_MARINE)
	TEST_ASSERT(rigged(), "The second trap was not set")
	TEST_ASSERT(gate.disarm_trap(null), "Disarming failed")
	TEST_ASSERT(!rigged(), "The trap is still on after disarming")
	TEST_ASSERT(second.loc == door_turf, "The grenade was not left at the door when the trap came off")
	TEST_ASSERT(!QDELETED(defuser), "The defuser is gone")

	var/mob/living/carbon/human/bomber = make_engineer(locate(block.origin_x + 8, block.origin_y + 2, block.z), 0)
	new /obj/item/explosive/grenade/high_explosive(bomber)
	var/datum/npc_order/rig_door/lethal = new
	lethal.target_turf = door_turf
	TEST_ASSERT(!bomber.ai_brain.give_order(lethal), "The engineer would trap a door with a live frag while that is off")
	TEST_ASSERT_EQUAL(lethal.refuse_reason, "no grenade fit for a trap", "The refusal gave the wrong reason: [lethal.refuse_reason]")
	GLOB.ai_lethal_traps = TRUE
	var/datum/npc_order/rig_door/allowed = new
	allowed.target_turf = door_turf
	TEST_ASSERT(bomber.ai_brain.give_order(allowed), "The engineer refused a frag trap with the lethal switch on: [allowed.refuse_reason]")
	GLOB.ai_lethal_traps = FALSE
	bomber.ai_brain.cancel_order()
	GLOB.ai_traps_enabled = FALSE
	var/datum/npc_order/rig_door/off = new
	off.target_turf = door_turf
	TEST_ASSERT(!bomber.ai_brain.give_order(off), "The engineer rigged a door with the trap switch off")
	GLOB.ai_traps_enabled = TRUE
	TEST_ASSERT_EQUAL(builder.error_total + bomber.ai_brain.error_total, 0, "A brain threw errors")
	detach_human_ai(engineer)
	detach_human_ai(bomber)

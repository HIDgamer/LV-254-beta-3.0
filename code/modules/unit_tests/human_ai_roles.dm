/// A marine with a medic's bag, no brain role set yet
/datum/unit_test/proc/make_medic(turf/where, faction = FACTION_MARINE)
	var/mob/living/carbon/human/medic = make_soldier(where, faction)
	if(!medic)
		return null
	var/obj/item/storage/backpack/bag = new(medic)
	medic.equip_to_slot_if_possible(bag, WEAR_BACK)
	new /obj/item/stack/medical/bruise_pack(bag)
	new /obj/item/stack/medical/ointment(bag)
	new /obj/item/stack/medical/splint(bag)
	medic.ai_brain.set_role("medic")
	return medic

/// A bare human with a bleeding arm, a burnt leg and a broken leg
/datum/unit_test/proc/make_casualty(turf/where, faction = FACTION_MARINE)
	var/mob/living/carbon/human/casualty = allocate(/mob/living/carbon/human, where)
	casualty.faction = faction
	var/obj/limb/arm = casualty.get_limb("l_arm")
	arm.take_damage(20, 0)
	var/obj/limb/burnt = casualty.get_limb("r_leg")
	burnt.take_damage(0, 20)
	var/obj/limb/broken = casualty.get_limb("l_leg")
	broken.status |= LIMB_BROKEN
	return casualty

/// Medics treat the wounded of their side, answer calls, drag the downed out of fire and run triage
/datum/unit_test/human_ai_medic
	var/mob/living/carbon/human/subject
	var/datum/human_ai_brain/doctor

/datum/unit_test/human_ai_medic/proc/nearby_packs(mob/living/carbon/human/medic)
	var/list/found = list()
	for(var/obj/item/stack/medical/pack in range(14, medic))
		found += "[pack.name] x[pack.amount] in [pack.loc] at [pack.x],[pack.y]"
	return found

/datum/unit_test/human_ai_medic/proc/healed()
	var/obj/limb/arm = subject.get_limb("l_arm")
	var/obj/limb/burnt = subject.get_limb("r_leg")
	var/obj/limb/broken = subject.get_limb("l_leg")
	return !doctor.limb_needs_bandage(arm) && !doctor.limb_needs_salve(burnt) && (broken.status & LIMB_SPLINTED)

/datum/unit_test/human_ai_medic/proc/dragged_to_cover(turf/threat)
	return doctor.cover_against(get_turf(subject), threat) >= HAI_COVER_MIN_SCORE && doctor.dragged >= 1

/datum/unit_test/human_ai_medic/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/ward = new(list(
		"####################################",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"####################################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(ward.origin_x + 4, ward.origin_y + 3, ward.z)
	var/mob/living/carbon/human/medic = make_medic(start)
	TEST_ASSERT_NOTNULL(medic, "The medic took no brain")
	doctor = medic.ai_brain
	TEST_ASSERT(doctor.is_medic(), "The role did not stick")
	subject = make_casualty(locate(start.x + 6, start.y + 1, start.z))
	var/list/need = doctor.patient_need(subject)
	TEST_ASSERT_NOTNULL(need, "The medic sees nothing wrong with a wounded man")
	var/mob/living/carbon/human/enemy = make_casualty(locate(start.x + 6, start.y - 2, start.z), FACTION_CLF)
	SSspatial_grid.track(subject, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(healed)), 60), "The medic did not finish treating the casualty, treatments [doctor.treatments], arm bandage needed [doctor.limb_needs_bandage(subject.get_limb("l_arm"))], leg salve needed [doctor.limb_needs_salve(subject.get_limb("r_leg"))], broken leg status [subject.get_limb("l_leg").status], hands [medic.get_active_hand()] and [medic.get_inactive_hand()], carrying [json_encode(list(medic.get_contents()))], packs near [json_encode(nearby_packs(medic))], supplies [json_encode(list(length(doctor.medical_supplies()[HAI_MED_BANDAGE]), length(doctor.medical_supplies()[HAI_MED_SALVE]), length(doctor.medical_supplies()[HAI_MED_SPLINT])))]: [doctor.decision_log.Join(" | ")]")
	TEST_ASSERT(doctor.treatments >= 3, "The medic made only [doctor.treatments] treatments")
	var/obj/limb/enemy_arm = enemy.get_limb("l_arm")
	TEST_ASSERT(doctor.limb_needs_bandage(enemy_arm), "The medic treated an enemy")
	TEST_ASSERT_EQUAL(doctor.error_total, 0, "The medic's brain threw errors")
	sleep(3 SECONDS)
	TEST_ASSERT(!doctor.is_acting(), "The medic is still busy after the last treatment")
	TEST_ASSERT(!istype(medic.get_active_hand(), /obj/item/stack/medical) && !istype(medic.get_inactive_hand(), /obj/item/stack/medical), "The medic kept a pack in hand")
	qdel(enemy)

	var/datum/human_ai_arena/field = new(list(
		"####################################",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"####################################",
	), run_loc_floor_bottom_left, 20, 40)
	medic.forceMove(locate(field.origin_x + 3, field.origin_y + 2, field.z))
	doctor.home_turf = get_turf(medic)
	var/mob/living/carbon/human/caller_mate = make_soldier(locate(field.origin_x + 20, field.origin_y + 2, field.z), FACTION_MARINE, FALSE)
	subject = make_casualty(get_turf(caller_mate))
	caller_mate.forceMove(locate(field.origin_x + 21, field.origin_y + 2, field.z))
	TEST_ASSERT(get_dist(medic, subject) > HAI_MEDIC_RANGE, "The caller is within the medic's sight")
	var/obj/limb/other_arm = subject.get_limb("l_arm")
	TEST_ASSERT(doctor.limb_needs_bandage(other_arm), "The second casualty is not hurt")
	doctor.next_patient_search = 0
	TEST_ASSERT(!doctor.find_patient(), "The medic found a patient it cannot see")
	SShuman_ai.record_talk = TRUE
	SShuman_ai.talk_window_end = 0
	caller_mate.ai_brain.express(HAI_EXPR_MEDIC)
	GLOB.human_ai_medic_calls[REF(subject)] = list(world.time, get_turf(subject), FACTION_MARINE)
	SShuman_ai.record_talk = FALSE
	SSspatial_grid.track(subject, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(healed)), 60), "The medic did not answer the call and treat the caller, it is at [medic.x],[medic.y] and treated [doctor.treatments], subject at [subject.x],[subject.y]: [doctor.decision_log.Join(" | ")]")

	medic.forceMove(locate(field.origin_x + 3, field.origin_y + 2, field.z))
	var/datum/npc_order/triage/sweep = new
	TEST_ASSERT(doctor.give_order(sweep), "The medic refused a triage order")
	subject = make_casualty(locate(field.origin_x + 8, field.origin_y + 2, field.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(healed)), 45), "The medic ignored the casualty during triage")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), sweep), 60), "The triage order never ended")
	TEST_ASSERT_EQUAL(sweep.status, HAI_ORDER_DONE, "The triage order ended as [sweep.status]")

	var/datum/human_ai_arena/fire = new(list(
		"####################################",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"#..................................#",
		"####################################",
	), run_loc_floor_bottom_left)
	var/turf/medic_spot = locate(fire.origin_x + 6, fire.origin_y + 3, fire.z)
	medic.forceMove(medic_spot)
	var/turf/threat_turf = locate(fire.origin_x + 15, fire.origin_y + 3, fire.z)
	for(var/offset in -1 to 1)
		var/obj/structure/barricade/metal/cover = new(locate(fire.origin_x + 9, fire.origin_y + 3 + offset, fire.z))
		cover.setDir(EAST)
	var/mob/living/carbon/xenomorph/drone/shooter = make_target_dummy(threat_turf)
	subject = make_casualty(locate(fire.origin_x + 7, fire.origin_y + 3, fire.z))
	subject.KnockOut(120)
	sleep(3 SECONDS)
	doctor.set_target(shooter)
	doctor.next_patient_search = 0
	for(var/tick in 1 to 4 * 40)
		doctor.last_shot_at_time = world.time
		if(dragged_to_cover(threat_turf))
			break
		sleep(2.5)
	TEST_ASSERT(dragged_to_cover(threat_turf), "The medic did not drag the casualty to cover, casualty at [subject.x],[subject.y] stat [subject.stat], dragged [doctor.dragged], medic at [medic.x],[medic.y], goal [doctor.drag_goal_turf]: [doctor.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(doctor.error_total, 0, "The medic's brain threw errors")
	qdel(shooter)
	detach_human_ai(medic)
	detach_human_ai(caller_mate)

/// A sniper finds a covered nest and leaves it when it is found, a gunner keeps fire on where the enemy ducked out, a grenadier saves its rockets for groups, a leader holds the squad together
/datum/unit_test/human_ai_specialists
	var/datum/human_ai_brain/specialist
	var/turf/first_nest

/datum/unit_test/human_ai_specialists/proc/nested(turf/threat)
	return specialist.in_good_cover(threat) && specialist.shots_fired >= 1

/datum/unit_test/human_ai_specialists/proc/moved_from_nest()
	return get_dist(specialist.body, first_nest) >= 3 && specialist.nest_moves >= 1

/datum/unit_test/human_ai_specialists/proc/gunner_fired(shots)
	return specialist.suppressive_shots >= shots

/datum/unit_test/human_ai_specialists/proc/rallied(datum/human_ai_squad/squad)
	return squad.rallies >= 1

/datum/unit_test/human_ai_specialists/proc/has_formation(datum/human_ai_squad/squad, form)
	return squad.formation == form

/datum/unit_test/human_ai_specialists/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/list/rows = list("####################################")
	for(var/row in 1 to 14)
		rows += "#..................................#"
	rows += "####################################"
	var/datum/human_ai_arena/field = new(rows, run_loc_floor_bottom_left)
	var/turf/start = locate(field.origin_x + 4, field.origin_y + 6, field.z)
	for(var/offset in list(-1, 0, 1, 4, 5, 6))
		var/obj/structure/barricade/metal/wall = new(locate(start.x + 2, start.y + offset, start.z))
		wall.setDir(EAST)
	var/mob/living/carbon/human/sniper = make_soldier(start, FACTION_MARINE, FALSE)
	var/obj/item/weapon/gun/rifle/sniper/M42A/rifle = new(sniper)
	sniper.put_in_hands(rifle)
	specialist = sniper.ai_brain
	specialist.set_role("sniper")
	TEST_ASSERT_EQUAL(specialist.sight_range(), HAI_SNIPER_RANGE, "A sniper does not see further")
	var/turf/threat_turf = locate(start.x + 12, start.y, start.z)
	var/mob/living/carbon/xenomorph/drone/target = make_target_dummy(threat_turf)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(nested), threat_turf), 40), "The sniper never settled in a nest and fired, at [sniper.x],[sniper.y], shots [specialist.shots_fired]: [specialist.decision_log.Join(" | ")]")
	first_nest = get_turf(sniper)
	specialist.set_target(target)
	for(var/hit in 1 to HAI_NEST_HITS)
		specialist.on_shot_at(target)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(moved_from_nest)), 15), "The sniper stayed in its nest after being found: [specialist.decision_log.Join(" | ")]")
	TEST_ASSERT(specialist.nest_avoided(first_nest), "The old nest is not remembered as found")
	TEST_ASSERT_EQUAL(specialist.error_total, 0, "The sniper's brain threw errors")
	qdel(target)
	detach_human_ai(sniper)

	var/datum/human_ai_arena/corner = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#......#####.......#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/gun_turf = locate(corner.origin_x + 3, corner.origin_y + 2, corner.z)
	var/mob/living/carbon/human/gunner = make_soldier(gun_turf, FACTION_MARINE, FALSE)
	var/obj/item/weapon/gun/m60/mg = new(gunner)
	gunner.put_in_hands(mg)
	specialist = gunner.ai_brain
	specialist.set_role("machinegunner")
	var/mob/living/carbon/xenomorph/drone/hider = make_target_dummy(locate(corner.origin_x + 11, corner.origin_y + 2, corner.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(has_target_set), specialist), 8), "The gunner never saw the enemy")
	var/turf/last_seen = get_turf(hider)
	hider.forceMove(locate(corner.origin_x + 18, corner.origin_y + 5, corner.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(gunner_fired), 3), 12), "The gunner laid only [specialist.suppressive_shots] bursts on the spot the enemy left, last seen at [last_seen.x],[last_seen.y]: [specialist.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(specialist.error_total, 0, "The gunner's brain threw errors")
	qdel(hider)
	detach_human_ai(gunner)

	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/grenadier = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 2, yard.z), FACTION_MARINE, FALSE)
	var/obj/item/weapon/gun/launcher/rocket/m5/tube = new(grenadier)
	grenadier.put_in_hands(tube)
	specialist = grenadier.ai_brain
	specialist.set_role("grenadier")
	var/mob/living/carbon/xenomorph/drone/lone = make_target_dummy(locate(yard.origin_x + 12, yard.origin_y + 2, yard.z))
	sleep(8 SECONDS)
	TEST_ASSERT_EQUAL(specialist.shots_fired, 0, "The grenadier spent a rocket on a single drone")
	var/mob/living/carbon/xenomorph/drone/second = make_target_dummy(locate(yard.origin_x + 12, yard.origin_y + 3, yard.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(specialist_shot)), 15), "The grenadier held its rocket against two drones side by side: [specialist.decision_log.Join(" | ")]")
	qdel(lone)
	qdel(second)
	detach_human_ai(grenadier)

	var/datum/human_ai_arena/hall = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/list/bodies = list()
	for(var/index in 0 to 2)
		bodies += make_soldier(locate(hall.origin_x + 4 + index, hall.origin_y + 2, hall.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_squad/squad = create_human_ai_squad(bodies, bodies[1], "Leader Squad")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(has_formation), squad, HAI_FORM_WEDGE), 4), "A squad in the open is not in a wedge")
	var/mob/living/carbon/human/follower = bodies[2]
	follower.ai_brain.stress = 80
	follower.ai_brain.begin_break(HAI_BREAK_FLEE)
	follower.ai_brain.broken_until = world.time + 15 SECONDS
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(rallied), squad), 40), "The leader never steadied a breaking squadmate: [follower.ai_brain.decision_log.Join(" | ")]")
	squad.disband()
	for(var/mob/living/carbon/human/soldier as anything in bodies)
		detach_human_ai(soldier)

	var/datum/human_ai_arena/tunnel = new(list(
		"##########################",
		"#........................#",
		"##########################",
	), run_loc_floor_bottom_left)
	var/list/line = list()
	for(var/index in 0 to 2)
		line += make_soldier(locate(tunnel.origin_x + 3 + index, tunnel.origin_y + 1, tunnel.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_squad/queue = create_human_ai_squad(line, line[1], "Tunnel Squad")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(has_formation), queue, HAI_FORM_COLUMN), 4), "A squad in a tunnel did not form a column, it is in form [queue.formation]")
	TEST_ASSERT(queue.formation_changes >= 1, "The change of formation was not counted")
	queue.disband()
	for(var/mob/living/carbon/human/soldier as anything in line)
		detach_human_ai(soldier)

/datum/unit_test/human_ai_specialists/proc/has_target_set(datum/human_ai_brain/brain)
	return !!brain.get_target()

/datum/unit_test/human_ai_specialists/proc/specialist_shot()
	return specialist.shots_fired >= 1

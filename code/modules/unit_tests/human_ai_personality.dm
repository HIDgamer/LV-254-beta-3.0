/// The twelve presets, the faction relations and the rules of engagement they start with
/datum/unit_test/human_ai_presets

/datum/unit_test/human_ai_presets/Run()
	var/list/expected = list("hostile", "paranoid", "friendly", "cautious", "professional", "reckless", "skittish", "veteran", "ruthless", "guardian", "zealot", "scout")
	for(var/id in expected)
		var/datum/human_ai_personality/preset = GLOB.human_ai_personalities[id]
		TEST_ASSERT_NOTNULL(preset, "Preset [id] does not exist")
		TEST_ASSERT_EQUAL(preset.id, id, "Preset [id] has the wrong id")
		TEST_ASSERT_EQUAL(length(preset.traits), length(GLOB.human_ai_trait_keys), "Preset [id] does not set every trait")
		for(var/key in GLOB.human_ai_trait_keys)
			var/value = preset.traits[key]
			TEST_ASSERT(isnum(value) && value >= 0 && value <= 100, "Preset [id] has [value] for [key]")
		for(var/action_id in preset.action_mults)
			var/known = FALSE
			for(var/datum/human_ai_action/action as anything in GLOB.human_ai_actions)
				if(action.id == action_id)
					known = TRUE
					break
			TEST_ASSERT(known, "Preset [id] scales an action [action_id] that does not exist")
	TEST_ASSERT(GLOB.human_ai_personalities["neutral"], "The neutral preset is gone")
	TEST_ASSERT_EQUAL(GLOB.human_ai_personalities["zealot"].trait("mercy"), 0, "The zealot is merciful")
	TEST_ASSERT_EQUAL(GLOB.human_ai_personalities["hostile"].trait("aggression"), 90, "The hostile preset drifted from the roadmap table")

	var/datum/human_ai_personality/base = GLOB.human_ai_personalities["professional"]
	var/datum/human_ai_personality/shaken = base.customised(10, list("courage" = 5))
	TEST_ASSERT_EQUAL(shaken.trait("courage"), 5, "An override was not applied")
	for(var/key in GLOB.human_ai_trait_keys)
		if(key != "courage")
			TEST_ASSERT(abs(shaken.trait(key) - base.trait(key)) <= 10, "Jitter moved [key] by more than 10")
	TEST_ASSERT_EQUAL(base.trait("courage"), 75, "Customising changed the shared preset")
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	TEST_ASSERT(attach_human_ai(body, "veteran"), "A veteran took no brain")
	body.ai_brain.set_personality("scout", 0, list("alertness" = 10))
	TEST_ASSERT_EQUAL(body.ai_brain.personality.trait("alertness"), 10, "A slider did not reach the brain")
	TEST_ASSERT_EQUAL(GLOB.human_ai_personalities["scout"].trait("alertness"), 100, "A slider changed the shared preset")
	body.ai_brain.set_personality("scout")
	TEST_ASSERT_EQUAL(body.ai_brain.personality, GLOB.human_ai_personalities["scout"], "Setting a plain preset did not share it")
	detach_human_ai(body)

	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, FACTION_UPP), HAI_REL_HOSTILE, "USCM and UPP are not hostile")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_UPP, FACTION_MARINE), HAI_REL_HOSTILE, "UPP and USCM are not hostile both ways")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, FACTION_MARSHAL), HAI_REL_FRIENDLY, "USCM and the marshals are not friendly")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, FACTION_COLONIST), HAI_REL_NEUTRAL, "USCM and colonists are not neutral")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_PMC, FACTION_CLF), HAI_REL_HOSTILE, "PMC and CLF are not hostile")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, FACTION_MARINE), HAI_REL_FRIENDLY, "A faction is not friendly with itself")
	var/list/edited = list()
	set_human_ai_relation(edited, "a", "b", HAI_REL_HOSTILE)
	TEST_ASSERT_EQUAL(edited["a"]["b"], HAI_REL_HOSTILE, "A relation was not stored")
	set_human_ai_relation(edited, "a", "b", HAI_REL_NEUTRAL)
	TEST_ASSERT(!edited["a"]["b"], "A neutral relation was kept")
	TEST_ASSERT_EQUAL(human_ai_default_roe(FACTION_MARSHAL), HAI_ROE_WEAPONS_TIGHT, "Marshals do not start tight")
	TEST_ASSERT_EQUAL(human_ai_default_roe(FACTION_COLONIST), HAI_ROE_WEAPONS_HOLD, "Colonists do not hold fire")
	TEST_ASSERT_EQUAL(human_ai_default_roe(FACTION_CLF), HAI_ROE_WEAPONS_FREE, "The CLF does not start free")

/// Stress builds and fades, brains break in the way their nature says and recover
/datum/unit_test/human_ai_mood

/datum/unit_test/human_ai_mood/proc/moved_away(mob/living/carbon/human/body, turf/from, distance)
	return get_dist(body, from) >= distance

/datum/unit_test/human_ai_mood/proc/closer_than(mob/living/carbon/human/body, atom/target, distance)
	return get_dist(body, target) <= distance

/datum/unit_test/human_ai_mood/proc/recovered(datum/human_ai_brain/brain)
	return !brain.broken_kind

/datum/unit_test/human_ai_mood/proc/covered(datum/human_ai_brain/brain, turf/threat)
	return brain.in_good_cover(threat)

/datum/unit_test/human_ai_mood/proc/break_share(personality_id, kind)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	body.faction = FACTION_MARINE
	attach_human_ai(body, personality_id)
	var/datum/human_ai_brain/brain = body.ai_brain
	brain.set_target(allocate(/mob/living/carbon/human, run_loc_floor_bottom_left))
	var/hits = 0
	for(var/trial in 1 to 400)
		if(brain.choose_break() == kind)
			hits++
	detach_human_ai(body)
	return hits / 400

/datum/unit_test/human_ai_mood/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 10, yard.origin_y + 3, yard.z)
	var/mob/living/carbon/human/soldier = make_soldier(start)
	TEST_ASSERT_NOTNULL(soldier, "The soldier took no brain")
	var/datum/human_ai_brain/brain = soldier.ai_brain

	brain.set_personality("veteran")
	brain.stress = 0
	brain.add_stress(10)
	var/calm_gain = brain.stress
	brain.set_personality("paranoid")
	brain.stress = 0
	brain.add_stress(10)
	TEST_ASSERT(brain.stress > calm_gain * 1.5, "A paranoid brain gains [brain.stress] stress from what gives a veteran [calm_gain]")
	brain.set_personality("neutral")
	brain.stress = 50
	brain.last_mood_time = world.time - 30
	brain.next_mood_time = 0
	brain.update_mood()
	TEST_ASSERT(brain.stress < 46, "Three quiet seconds left the stress at [brain.stress]")

	TEST_ASSERT(GLOB.human_ai_personalities["zealot"].trait("courage") >= 95, "The zealot is not bold enough to resist")
	brain.set_personality("zealot")
	brain.stress = 100
	brain.check_break()
	TEST_ASSERT_EQUAL(brain.broken_kind, HAI_BREAK_NONE, "A zealot broke")
	TEST_ASSERT(brain.stress <= 80, "A zealot's stress was not held below breaking")
	brain.set_personality("skittish")
	brain.stress = 100
	brain.check_break()
	TEST_ASSERT(brain.broken_kind != HAI_BREAK_NONE, "A skittish brain at full stress did not break")
	brain.refresh_intent()
	if(brain.broken_kind != HAI_BREAK_BERSERK)
		TEST_ASSERT_EQUAL(brain.intent, HAI_INTENT_BROKEN, "A broken brain is not in the broken intent")
	brain.broken_until = world.time - 1
	brain.check_break()
	TEST_ASSERT_EQUAL(brain.broken_kind, HAI_BREAK_NONE, "A spell of breaking never ended")
	TEST_ASSERT(brain.stress <= HAI_BREAK_RECOVERY_STRESS, "The brain was not eased after breaking, stress [brain.stress]")
	brain.set_personality("neutral")

	TEST_ASSERT(break_share("reckless", HAI_BREAK_BERSERK) > 0.6, "A reckless brain goes berserk only [break_share("reckless", HAI_BREAK_BERSERK)] of the time")
	var/skittish_boldness = break_share("skittish", HAI_BREAK_BERSERK)
	TEST_ASSERT(skittish_boldness < 0.1, "A skittish brain goes berserk [skittish_boldness] of the time")
	TEST_ASSERT(break_share("skittish", HAI_BREAK_FLEE) + break_share("skittish", HAI_BREAK_HIDE) > 0.4, "A skittish brain rarely runs or hides")
	TEST_ASSERT(break_share("cautious", HAI_BREAK_FLEE) > break_share("hostile", HAI_BREAK_FLEE), "A hostile brain flees more than a cautious one")

	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 7, start.y, start.z))
	brain.set_personality("skittish")
	brain.begin_break(HAI_BREAK_FLEE)
	brain.broken_until = world.time + 12 SECONDS
	var/shots_then = brain.shots_fired
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(moved_away), soldier, get_turf(dummy), 12), 12), "A fleeing brain stayed within [get_dist(soldier, dummy)] tiles of the threat: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.shots_fired, shots_then, "A fleeing brain kept shooting")
	TEST_ASSERT_EQUAL(brain.intent, HAI_INTENT_BROKEN, "A fleeing brain is not in the broken intent")
	brain.broken_until = world.time - 1
	brain.check_break()

	soldier.forceMove(start)
	brain.set_personality("paranoid")
	brain.begin_break(HAI_BREAK_FREEZE)
	brain.broken_until = world.time + 6 SECONDS
	shots_then = brain.shots_fired
	sleep(4 SECONDS)
	TEST_ASSERT(get_turf(soldier) == start, "A frozen brain moved")
	TEST_ASSERT_EQUAL(brain.shots_fired, shots_then, "A frozen brain shot")
	brain.broken_until = world.time - 1
	brain.check_break()

	brain.set_personality("reckless")
	brain.begin_break(HAI_BREAK_BERSERK)
	brain.broken_until = world.time + 12 SECONDS
	brain.berserk_until = brain.broken_until
	shots_then = brain.shots_fired
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(closer_than), soldier, dummy, 3), 12), "A berserk brain stayed [get_dist(soldier, dummy)] tiles from the enemy: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(brain.shots_fired > shots_then, "A berserk brain never fired")
	brain.broken_until = world.time - 1
	brain.check_break()
	qdel(dummy)

	soldier.forceMove(start)
	var/turf/hide_threat = locate(start.x + 8, start.y, start.z)
	for(var/offset in -1 to 1)
		var/obj/structure/barricade/metal/wall = new(locate(start.x + 3, start.y + offset, start.z))
		wall.setDir(EAST)
	brain.set_personality("skittish")
	brain.set_target(null)
	var/mob/living/carbon/xenomorph/drone/hunter = make_target_dummy(hide_threat)
	brain.begin_break(HAI_BREAK_HIDE)
	brain.broken_until = world.time + 15 SECONDS
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(covered), brain, hide_threat), 12), "A hiding brain never got behind cover, at [soldier.x],[soldier.y]: [brain.decision_log.Join(" | ")]")
	brain.broken_until = world.time - 1
	brain.check_break()
	qdel(hunter)

	var/mob/living/carbon/human/captor = make_soldier(locate(start.x + 6, start.y + 2, start.z), FACTION_CLF, TRUE, "friendly")
	var/mob/living/carbon/human/brute = make_soldier(locate(start.x + 6, start.y - 2, start.z), FACTION_CLF, TRUE, "ruthless")
	TEST_ASSERT(captor && brute, "The captors took no brains")
	brain.set_personality("skittish")
	brain.stress = 100
	soldier.forceMove(start)
	brain.begin_break(HAI_BREAK_SURRENDER)
	TEST_ASSERT(brain.surrendered, "A surrender was not recorded")
	TEST_ASSERT(!istype(soldier.get_active_hand(), /obj/item/weapon/gun) && !istype(soldier.get_inactive_hand(), /obj/item/weapon/gun), "A surrendering brain kept its gun")
	TEST_ASSERT_EQUAL(captor.ai_brain.get_disposition(soldier), HAI_DISP_NEUTRAL, "A merciful captor still counts a surrendered enemy as hostile")
	TEST_ASSERT_EQUAL(brute.ai_brain.get_disposition(soldier), HAI_DISP_HOSTILE, "A ruthless captor spares a surrendered enemy")
	sleep(3 SECONDS)
	TEST_ASSERT_EQUAL(brain.intent, HAI_INTENT_BROKEN, "A surrendered brain is not passive")
	brain.end_surrender("test")
	TEST_ASSERT_EQUAL(captor.ai_brain.get_disposition(soldier), HAI_DISP_HOSTILE, "A captor still spares a brain that stopped surrendering")
	detach_human_ai(captor)
	detach_human_ai(brute)

	var/mob/living/carbon/human/friend = make_soldier(locate(start.x + 1, start.y, start.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/victim = make_soldier(locate(start.x + 2, start.y, start.z), FACTION_MARINE, FALSE)
	friend.ai_brain.stress = 0
	victim.death()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(stressed), friend.ai_brain), 5), "A friend's death did not shake the brain beside it")
	TEST_ASSERT_EQUAL(brain.error_total + friend.ai_brain.error_total, 0, "A brain threw errors")
	detach_human_ai(friend)
	detach_human_ai(soldier)

/datum/unit_test/human_ai_mood/proc/stressed(datum/human_ai_brain/brain)
	return brain.stress >= 5

/// An armed stranger who points a gun at the brain is watched, challenged, warned and finally treated as an enemy, each type at its own pace
/datum/unit_test/human_ai_ladder
	var/datum/human_ai_brain/watcher
	var/mob/living/carbon/human/stranger

/datum/unit_test/human_ai_ladder/proc/escalated()
	return watcher.is_overridden_hostile(stranger)

/datum/unit_test/human_ai_ladder/proc/state_is(state)
	var/datum/ai_watch/watch = watcher.watching[REF(stranger)]
	return watch && watch.state == state

/// Seconds until the stranger is called hostile, or a large number when it never is
/datum/unit_test/human_ai_ladder/proc/time_to_escalate(personality_id)
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/guard = make_soldier(locate(yard.origin_x + 4, yard.origin_y + 1, yard.z), FACTION_MARINE, TRUE, personality_id)
	stranger = allocate(/mob/living/carbon/human, locate(yard.origin_x + 8, yard.origin_y + 1, yard.z))
	stranger.faction = "raiders"
	var/obj/item/weapon/gun/rifle/m41a/their_gun = new(stranger)
	stranger.put_in_hands(their_gun)
	stranger.setDir(WEST)
	SSspatial_grid.track(stranger, SPATIAL_GRID_TRACK_NPC)
	watcher = guard.ai_brain
	var/started = world.time
	var/elapsed = 99999
	for(var/waited in 1 to 4 * 40)
		if(escalated())
			elapsed = (world.time - started) * 0.1
			break
		sleep(2.5)
	var/shots = watcher.shots_fired
	detach_human_ai(guard)
	qdel(guard)
	qdel(stranger)
	return list(elapsed, shots)

/datum/unit_test/human_ai_ladder/Run()
	var/list/hostile = time_to_escalate("hostile")
	var/list/professional = time_to_escalate("professional")
	var/list/friendly = time_to_escalate("friendly")
	TEST_NOTICE(src, "Seconds until an armed stranger is called hostile: hostile [hostile[1]], professional [professional[1]], friendly [friendly[1]]")
	TEST_ASSERT(hostile[1] <= 4, "A hostile type took [hostile[1]] seconds to call an armed stranger an enemy")
	TEST_ASSERT(professional[1] > hostile[1] + 6, "A professional gave the stranger only [professional[1]] seconds")
	TEST_ASSERT(friendly[1] > professional[1] + 3, "A friendly type gave the stranger [friendly[1]] seconds, a professional [professional[1]]")
	TEST_ASSERT(friendly[1] < 60, "A friendly type never escalated")

	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/guard = make_soldier(locate(yard.origin_x + 4, yard.origin_y + 1, yard.z), FACTION_MARINE, TRUE, "professional")
	stranger = allocate(/mob/living/carbon/human, locate(yard.origin_x + 8, yard.origin_y + 1, yard.z))
	stranger.faction = "raiders"
	var/obj/item/weapon/gun/rifle/m41a/their_gun = new(stranger)
	stranger.put_in_hands(their_gun)
	stranger.setDir(WEST)
	SSspatial_grid.track(stranger, SPATIAL_GRID_TRACK_NPC)
	watcher = guard.ai_brain
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(state_is), HAI_WATCH_CHALLENGE), 12), "The guard never challenged the stranger: [watcher.decision_log.Join(" | ")]")
	stranger.drop_held_items()
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(state_is), HAI_WATCH_OBSERVE), 6), "The guard did not stand down when the stranger put the gun away")
	sleep(4 SECONDS)
	TEST_ASSERT(!escalated(), "The guard turned on a stranger who gave up the gun")
	TEST_ASSERT_EQUAL(watcher.error_total, 0, "The guard's brain threw errors")
	detach_human_ai(guard)

/// Orders sent as requests are obeyed by nature: zealots and the disciplined nearly always, the timid and the unruly rarely
/datum/unit_test/human_ai_compliance_matrix

/datum/unit_test/human_ai_compliance_matrix/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	TEST_ASSERT(attach_human_ai(body), "No brain")
	var/datum/human_ai_brain/brain = body.ai_brain
	var/datum/npc_order/attack/charge = new
	charge.danger = 0.8
	charge.set_target(body)
	var/list/chances = list()
	for(var/id in GLOB.human_ai_personalities)
		if(id == "neutral")
			continue
		brain.set_personality(id)
		charge.delivery = HAI_DELIVERY_REQUEST
		chances[id] = brain.comply_chance(charge)
		charge.delivery = HAI_DELIVERY_COMMAND
		TEST_ASSERT_EQUAL(brain.comply_chance(charge), 1, "A forced order was not always obeyed by [id]")
		charge.delivery = HAI_DELIVERY_REQUEST
		charge.danger = 0
		TEST_ASSERT_EQUAL(brain.comply_chance(charge), 1, "A harmless request was not always obeyed by [id]")
		charge.danger = 0.8
	var/list/report = list()
	for(var/id in chances)
		report += "[id] [round(chances[id], 0.01)]"
	TEST_NOTICE(src, "Chance of obeying a request of danger 0.8: [report.Join(", ")]")
	var/lowest_obedient = 1
	for(var/id in list("zealot", "veteran", "professional", "guardian"))
		lowest_obedient = min(lowest_obedient, chances[id])
	var/highest_wary = 0
	for(var/id in list("skittish", "paranoid"))
		highest_wary = max(highest_wary, chances[id])
	TEST_ASSERT(lowest_obedient >= 0.75, "The disciplined obey a risky request only [lowest_obedient] of the time")
	TEST_ASSERT(highest_wary <= 0.6, "The timid obey a risky request [highest_wary] of the time")
	TEST_ASSERT(lowest_obedient > highest_wary + 0.25, "Obedient types and wary types are not apart: [lowest_obedient] against [highest_wary]")
	TEST_ASSERT(chances["zealot"] >= chances["veteran"], "A zealot is less obedient than a veteran")
	detach_human_ai(body)

/// The same scene played by every preset: the bold close in and the careful take cover
/datum/unit_test/human_ai_preset_matrix
	var/list/closed = list()
	var/list/final_distance = list()
	var/list/covers = list()
	var/list/first_shot = list()

/datum/unit_test/human_ai_preset_matrix/proc/play(personality_id)
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)
	var/turf/start = locate(yard.origin_x + 5, yard.origin_y + 3, yard.z)
	for(var/offset in list(-2, -1, 1, 2))
		var/obj/structure/barricade/metal/wall = new(locate(start.x + 3, start.y + offset, start.z))
		wall.setDir(EAST)
	var/mob/living/carbon/xenomorph/drone/dummy = make_target_dummy(locate(start.x + 9, start.y, start.z))
	var/mob/living/carbon/human/soldier = make_soldier(start, FACTION_MARINE, TRUE, personality_id)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	soldier.setDir(EAST)
	var/begun = get_dist(soldier, dummy)
	var/at = world.time
	var/shot_at = -1
	for(var/tick in 1 to 4 * 14)
		if(shot_at < 0 && brain.shots_fired)
			shot_at = world.time - at
		sleep(2.5)
	closed[personality_id] = begun - get_dist(soldier, dummy)
	final_distance[personality_id] = get_dist(soldier, dummy)
	covers[personality_id] = brain.cover_moves + (brain.in_good_cover(get_turf(dummy)) ? 1 : 0)
	first_shot[personality_id] = shot_at
	detach_human_ai(soldier)
	qdel(soldier)
	qdel(dummy)

/datum/unit_test/human_ai_preset_matrix/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	for(var/id in list("hostile", "reckless", "zealot", "cautious", "skittish", "paranoid", "professional", "scout"))
		play(id)
	var/list/report = list()
	for(var/id in closed)
		report += "[id] ended [final_distance[id]] tiles away, cover [covers[id]], first shot [first_shot[id]]"
	TEST_NOTICE(src, report.Join("; "))
	var/bold = (final_distance["hostile"] + final_distance["reckless"] + final_distance["zealot"]) / 3
	var/careful = (final_distance["cautious"] + final_distance["skittish"] + final_distance["paranoid"]) / 3
	TEST_ASSERT(careful > bold + 0.8, "The bold ended [bold] tiles from the enemy on average and the careful [careful]: [report.Join("; ")]")
	var/bold_cover = (covers["hostile"] + covers["reckless"] + covers["zealot"]) / 3
	var/careful_cover = (covers["cautious"] + covers["skittish"] + covers["paranoid"]) / 3
	TEST_ASSERT(careful_cover > bold_cover, "The careful used cover [careful_cover] on average and the bold [bold_cover]")
	TEST_ASSERT(covers["cautious"] >= 1 && covers["skittish"] >= 1, "A cautious or skittish brain never found cover")
	TEST_ASSERT(final_distance["zealot"] <= final_distance["professional"], "A zealot stayed further off than a professional")
	for(var/id in first_shot)
		TEST_ASSERT(first_shot[id] >= 0, "[id] never fired a shot in the scene")

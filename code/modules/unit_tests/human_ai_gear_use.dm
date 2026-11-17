/// A unit short of something takes it out of a box or a medkit lying on the floor, and leaves the box and what it does not need where they are
/datum/unit_test/human_ai_container_loot

/datum/unit_test/human_ai_container_loot/proc/got_crowbar(datum/human_ai_brain/brain)
	return !!brain.find_crowbar()

/datum/unit_test/human_ai_container_loot/proc/got_bandages(datum/human_ai_brain/brain)
	brain.med_cache = null
	return length(brain.medical_supplies()[HAI_MED_BANDAGE]) > 0

/datum/unit_test/human_ai_container_loot/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"##############################",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"##############################",
	), run_loc_floor_bottom_left)

	// A crowbar in a box on the floor
	var/mob/living/carbon/human/soldier = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 2, yard.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	TEST_ASSERT_NULL(brain.find_crowbar(), "The soldier has a crowbar to begin with")
	var/obj/item/storage/box/stuff = allocate(/obj/item/storage/box, locate(yard.origin_x + 7, yard.origin_y + 2, yard.z))
	var/obj/item/tool/crowbar/bar = new(stuff)
	var/obj/item/tool/pen/filler = new(stuff)
	TEST_ASSERT(!brain.loot_wanted(filler), "The soldier wants a pen")
	TEST_ASSERT_EQUAL(brain.container_loot(stuff), bar, "The brain does not see the crowbar in the box")
	TEST_ASSERT_EQUAL(brain.find_loot(), stuff, "The brain does not see a box with a crowbar in it as worth a visit")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(got_crowbar), brain), 40), "The soldier never took the crowbar out of the box: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(bar in soldier.get_contents(), "The crowbar is not on the soldier")
	TEST_ASSERT(isturf(stuff.loc), "The box was taken along")
	TEST_ASSERT_EQUAL(filler.loc, stuff, "The soldier took out what it had no use for")
	TEST_ASSERT_NULL(brain.find_loot(), "A box with nothing in it for the soldier is still thought worth a visit")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The brain threw errors: [brain.decision_log.Join(" | ")]")
	detach_human_ai(soldier)

	// A medkit, which is what somebody looking through one near a unit has in front of them
	var/mob/living/carbon/human/medic = make_soldier(locate(yard.origin_x + 3, yard.origin_y + 4, yard.z), FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/medic_brain = medic.ai_brain
	for(var/obj/item/stack/medical/supply in medic.get_contents())
		qdel(supply)
	medic_brain.med_cache = null
	TEST_ASSERT(!length(medic_brain.medical_supplies()[HAI_MED_BANDAGE]), "The soldier still has bandages")
	var/obj/item/storage/firstaid/regular/kit = allocate(/obj/item/storage/firstaid/regular, locate(yard.origin_x + 7, yard.origin_y + 4, yard.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(got_bandages), medic_brain), 40), "The soldier never took bandages out of the medkit: [medic_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(isturf(kit.loc), "The medkit was taken along")
	detach_human_ai(medic)

	// A box in somebody's hands is not searched
	var/mob/living/carbon/human/thief = make_soldier(locate(yard.origin_x + 20, yard.origin_y + 2, yard.z), FACTION_MARINE, FALSE)
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human, locate(yard.origin_x + 22, yard.origin_y + 2, yard.z))
	var/obj/item/storage/box/carried = new(get_turf(holder))
	var/obj/item/tool/crowbar/held_bar = new(carried)
	TEST_ASSERT(holder.put_in_hands(carried, FALSE), "The box could not be put in a hand")
	TEST_ASSERT_NULL(thief.ai_brain.find_crowbar(), "The second soldier has a crowbar to begin with")
	sleep(12 SECONDS)
	TEST_ASSERT_EQUAL(held_bar.loc, carried, "A crowbar was taken out of a box somebody was holding")
	detach_human_ai(thief)

/// A scout in an optical cloak puts it on to go unseen along a patrol, to close in on an enemy still far off, and to get away when it is hurt with the enemy near
/datum/unit_test/human_ai_scout_cloak
	var/obj/item/storage/backpack/marine/satchel/scout_cloak/cloak

/datum/unit_test/human_ai_scout_cloak/Destroy()
	cloak = null
	return ..()

/datum/unit_test/human_ai_scout_cloak/proc/cloaked()
	return cloak.camo_active

/datum/unit_test/human_ai_scout_cloak/proc/sees_target(datum/human_ai_brain/brain, mob/living/enemy)
	return brain.get_target() == enemy && world.time <= brain.target_seen_time + 20

/datum/unit_test/human_ai_scout_cloak/proc/make_scout(turf/where)
	var/mob/living/carbon/human/scout = make_soldier(where, FACTION_MARINE, TRUE)
	scout.ai_brain.light_override = 1
	scout.ai_brain.suppress_error_log = TRUE
	cloak = new(scout)
	dress(scout, cloak, WEAR_BACK)
	return scout

/datum/unit_test/human_ai_scout_cloak/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/field = new(list(
		"########################################",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"########################################",
	), run_loc_floor_bottom_left)

	// What a man carries on his back says he is a scout
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(human_ai_role_for_gear(stranger), "A man with nothing special has a role")
	dress(stranger, new /obj/item/storage/backpack/marine/satchel/scout_cloak(stranger), WEAR_BACK)
	TEST_ASSERT_EQUAL(human_ai_role_for_gear(stranger), "scout", "A man in a cloak is not a scout")

	// On a patrol, with nobody in sight
	var/mob/living/carbon/human/walker = make_scout(locate(field.origin_x + 3, field.origin_y + 3, field.z))
	var/datum/human_ai_brain/brain = walker.ai_brain
	TEST_ASSERT(brain.worn_cloak() == cloak && brain.can_use_cloak(), "The scout does not know it wears a cloak it can use")
	var/datum/npc_order/patrol/route = new
	route.waypoints = list(locate(field.origin_x + 30, field.origin_y + 3, field.z), locate(field.origin_x + 5, field.origin_y + 3, field.z))
	TEST_ASSERT(brain.give_order(route), "The patrol order was refused")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cloaked)), 25), "The scout never put its cloak on to patrol: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT(HAS_TRAIT(walker, TRAIT_CLOAKED), "The scout is not cloaked")
	TEST_ASSERT(brain.cloak_uses >= 1, "The cloak was not counted")
	detach_human_ai(walker)
	qdel(walker)

	// Closing in on an enemy that is still far off
	var/mob/living/carbon/human/stalker = make_scout(locate(field.origin_x + 3, field.origin_y + 3, field.z))
	var/datum/human_ai_brain/stalker_brain = stalker.ai_brain
	stalker.setDir(EAST)
	var/mob/living/carbon/xenomorph/drone/prey = make_target_dummy(locate(field.origin_x + 3 + HAI_CLOAK_AMBUSH_RANGE + 1, field.origin_y + 3, field.z))
	SSspatial_grid.track(prey, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(sees_target), stalker_brain, prey), 25), "The scout never saw the enemy: [stalker_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(stalker_brain.cloak_reason(), "ambush", "A scout with an enemy in sight far off wants its cloak for another reason: [stalker_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cloaked)), 25), "The scout never put its cloak on: [stalker_brain.decision_log.Join(" | ")]")
	detach_human_ai(stalker)
	qdel(stalker)
	qdel(prey)

	// Hurt, with the enemy near
	var/mob/living/carbon/human/runner = make_scout(locate(field.origin_x + 3, field.origin_y + 3, field.z))
	var/datum/human_ai_brain/runner_brain = runner.ai_brain
	runner.setDir(EAST)
	var/mob/living/carbon/xenomorph/drone/chaser = make_target_dummy(locate(field.origin_x + 8, field.origin_y + 3, field.z))
	SSspatial_grid.track(chaser, SPATIAL_GRID_TRACK_NPC)
	runner.apply_damage(50, BRUTE)
	TEST_ASSERT(runner_brain.hurt_badly(), "The scout is not hurt badly enough for the test, it has [runner.health] of [runner.maxHealth]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(sees_target), runner_brain, chaser), 25), "The scout never saw the enemy: [runner_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(runner_brain.cloak_reason(), "escape", "A scout that is hurt with the enemy near wants its cloak for another reason: [runner_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(cloaked)), 25), "The scout never put its cloak on to get away: [runner_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(runner_brain.current_order?.id == "fall_back" || runner_brain.orders_completed >= 1, "The scout did not fall back after cloaking: [runner_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(runner_brain.error_total, 0, "The scout threw errors: [runner_brain.decision_log.Join(" | ")]")
	detach_human_ai(runner)
	qdel(runner)
	qdel(chaser)

/// A sniper in a ghillie suit rigs it up once it has stood still a while, it does not have to be told to hold
/datum/unit_test/human_ai_sniper_hides
	var/obj/item/clothing/suit/storage/marine/ghillie/suit

/datum/unit_test/human_ai_sniper_hides/proc/hidden()
	return suit.camo_active

/datum/unit_test/human_ai_sniper_hides/Run()
	var/mob/living/carbon/human/sniper = make_soldier(run_loc_floor_bottom_left, FACTION_MARINE, FALSE)
	var/datum/human_ai_brain/brain = sniper.ai_brain
	brain.suppress_error_log = TRUE
	dress(sniper, new /obj/item/clothing/under/marine(sniper), WEAR_BODY)
	suit = new(sniper)
	dress(sniper, suit, WEAR_JACKET)
	TEST_ASSERT(brain.worn_ghillie() == suit, "The unit does not know it wears a ghillie suit")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(hidden)), 30), "The sniper never rigged its ghillie suit standing still: [brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(brain.error_total, 0, "The unit's brain threw errors")
	detach_human_ai(sniper)

/// A man uses the strongest gun he has: a rifle that is quick to reload is reloaded, a shotgun that is slow to load is put down for the pistol until the enemy is gone, and with nothing that shoots the knife in the boot comes out
/datum/unit_test/human_ai_weapon_ladder
	var/datum/human_ai_brain/subject
	var/obj/item/weapon/gun/main_gun
	var/obj/item/weapon/gun/side_gun

/datum/unit_test/human_ai_weapon_ladder/Destroy()
	subject = null
	main_gun = null
	side_gun = null
	return ..()

/datum/unit_test/human_ai_weapon_ladder/proc/holds_side()
	return subject.peek_gun() == side_gun

/datum/unit_test/human_ai_weapon_ladder/proc/holds_main()
	return subject.peek_gun() == main_gun

/datum/unit_test/human_ai_weapon_ladder/proc/reloaded()
	return subject.reload_count >= 1

/datum/unit_test/human_ai_weapon_ladder/proc/knife_out()
	return istype(subject.body.get_active_hand(), /obj/item/attachable/bayonet)

/// A man with a gun that is empty and a spare for it, and a pistol that is loaded, with an enemy in sight
/datum/unit_test/human_ai_weapon_ladder/proc/arm(turf/where, main_type, datum/human_ai_arena/yard)
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human, where)
	human_ai_test_skills(shooter)
	shooter.faction = FACTION_MARINE
	shooter.setDir(EAST)
	var/obj/item/storage/backpack/pack = new(shooter)
	shooter.put_in_back(pack)
	var/obj/item/weapon/gun/sample = new main_type(run_loc_floor_bottom_left)
	human_ai_test_spare_ammo(sample, pack)
	qdel(sample)
	main_gun = new main_type(shooter, TRUE)
	shooter.put_in_hands(main_gun)
	side_gun = new /obj/item/weapon/gun/pistol/m4a3(pack)
	TEST_ASSERT(attach_human_ai(shooter), "The shooter took no brain")
	subject = shooter.ai_brain
	subject.keep_awake = TRUE
	subject.suppress_error_log = TRUE
	subject.light_override = 1
	return shooter

/datum/unit_test/human_ai_weapon_ladder/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/shooter_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)

	// A rifle that is quick to load is loaded and not put down
	var/mob/living/carbon/xenomorph/drone/target = make_target_dummy(locate(shooter_turf.x + 6, shooter_turf.y, yard.z))
	SSspatial_grid.track(target, SPATIAL_GRID_TRACK_NPC)
	var/mob/living/carbon/human/shooter = arm(shooter_turf, /obj/item/weapon/gun/rifle/m41a, yard)
	TEST_ASSERT(subject.reload_cost(main_gun) <= HAI_SWITCH_COOLDOWN, "A rifle magazine takes [subject.reload_cost(main_gun)] to load, longer than a pistol takes to draw, the test would prove nothing")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(reloaded)), 20), "The rifle was never reloaded: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(subject.weapon_switches, 0, "A man switched to his pistol with a rifle that loads in a moment: [subject.decision_log.Join(" | ")]")
	detach_human_ai(shooter)
	qdel(shooter)

	// A shotgun that takes long to load is put down for the pistol with the enemy in sight
	shooter = arm(shooter_turf, /obj/item/weapon/gun/shotgun/pump, yard)
	TEST_ASSERT(subject.reload_cost(main_gun) > HAI_SWITCH_COOLDOWN, "A shotgun takes only [subject.reload_cost(main_gun)] to load, the test would prove nothing")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(holds_side)), 20), "The man never took up his pistol while his shotgun was empty: [subject.decision_log.Join(" | ")]")
	var/shots_with_pistol_before = subject.shots_fired
	sleep(4 SECONDS)
	TEST_ASSERT(subject.shots_fired > shots_with_pistol_before, "The man did not fire the pistol once he held it: [subject.decision_log.Join(" | ")]")
	// With the enemy gone, the shotgun is what he holds again, and he loads it
	target.forceMove(locate(yard.origin_x + 18, yard.origin_y + 1, yard.z))
	qdel(target)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(holds_main)), 30), "The man did not take his shotgun back once the enemy was gone: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(reloaded)), 30), "The man did not load his shotgun once he held it again: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(subject.error_total, 0, "The brain threw errors: [subject.decision_log.Join(" | ")]")
	detach_human_ai(shooter)
	qdel(shooter)

	// With nothing that shoots, the knife in the boot comes out for an enemy that is close
	var/mob/living/carbon/human/knifeman = allocate(/mob/living/carbon/human, shooter_turf)
	human_ai_test_skills(knifeman)
	knifeman.faction = FACTION_MARINE
	knifeman.setDir(EAST)
	var/obj/item/clothing/shoes/marine/knife/boots = new(knifeman)
	dress(knifeman, boots, WEAR_FEET)
	var/obj/item/weapon/gun/rifle/m41a/dry = new(knifeman, TRUE)
	knifeman.put_in_hands(dry)
	TEST_ASSERT(attach_human_ai(knifeman), "The knifeman took no brain")
	subject = knifeman.ai_brain
	subject.keep_awake = TRUE
	subject.suppress_error_log = TRUE
	subject.light_override = 1
	TEST_ASSERT(istype(subject.find_melee_weapon(), /obj/item/attachable/bayonet), "The man does not see the knife in his boot as something to fight with: [subject.find_melee_weapon()]")
	var/mob/living/carbon/xenomorph/drone/close = make_target_dummy(locate(shooter_turf.x + 1, shooter_turf.y, yard.z))
	SSspatial_grid.track(close, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(knife_out)), 25), "The man never drew the knife from his boot with nothing left to shoot: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT_NULL(boots.stored_item, "The knife is still thought to be in the boot it was drawn from")
	TEST_ASSERT_EQUAL(subject.error_total, 0, "The brain threw errors: [subject.decision_log.Join(" | ")]")
	detach_human_ai(knifeman)
	qdel(knifeman)
	qdel(close)

/// A smartgunner gets the gun ready the way a player does and fires it, swaps the drum through the feed cover and the battery when they run out, and takes the arm off to put the gun away
/datum/unit_test/human_ai_smartgunner
	var/datum/human_ai_brain/subject
	var/obj/item/weapon/gun/smartgun/gun
	var/saw_cover_open = FALSE

/datum/unit_test/human_ai_smartgunner/Destroy()
	subject = null
	gun = null
	return ..()

/datum/unit_test/human_ai_smartgunner/proc/ready_and_firing()
	return gun.armbrace && gun.recoil_compensation && subject.shots_fired >= 3

/datum/unit_test/human_ai_smartgunner/proc/reloaded()
	if(gun.cover_open)
		saw_cover_open = TRUE
	return subject.reload_count >= 1 && !gun.cover_open

/datum/unit_test/human_ai_smartgunner/proc/new_battery(obj/item/heavygun_battery/spare)
	return gun.battery == spare

/datum/unit_test/human_ai_smartgunner/proc/stood_down()
	return !gun.armbrace && !gun.recoil_compensation

/datum/unit_test/human_ai_smartgunner/proc/make_gunner(turf/where, harness = TRUE)
	var/mob/living/carbon/human/gunner = allocate(/mob/living/carbon/human, where)
	human_ai_test_skills(gunner)
	gunner.faction = FACTION_MARINE
	gunner.setDir(EAST)
	dress(gunner, new /obj/item/clothing/under/marine(gunner), WEAR_BODY)
	if(harness)
		dress(gunner, new /obj/item/clothing/suit/storage/marine/smartgunner(gunner), WEAR_JACKET)
	var/obj/item/storage/backpack/pack = new(gunner)
	gunner.put_in_back(pack)
	gun = new(gunner)
	gunner.put_in_hands(gun)
	TEST_ASSERT(attach_human_ai(gunner), "The smartgunner took no brain")
	subject = gunner.ai_brain
	subject.keep_awake = TRUE
	subject.suppress_error_log = TRUE
	subject.light_override = 1
	return gunner

/datum/unit_test/human_ai_smartgunner/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, these scenarios need it")
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/turf/gunner_turf = locate(yard.origin_x + 2, yard.origin_y + 2, yard.z)
	var/mob/living/carbon/xenomorph/drone/target = make_target_dummy(locate(gunner_turf.x + 7, gunner_turf.y, yard.z))
	SSspatial_grid.track(target, SPATIAL_GRID_TRACK_NPC)

	var/mob/living/carbon/human/gunner = make_gunner(gunner_turf)
	var/obj/item/storage/backpack/pack = gunner.back
	var/obj/item/ammo_magazine/smartgun/spare_drum = new(pack)
	var/obj/item/heavygun_battery/spare_battery = new(pack)
	TEST_ASSERT(subject.smartgun_fit(gun), "A trained man in a harness is not fit for the smartgun")
	TEST_ASSERT(!gun.armbrace, "The smartgun starts with its servo arm engaged, the test would prove nothing")

	// With the enemy in sight the arm and the stabilizer go on and the gun is fired, with its cover shut
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(ready_and_firing)), 25), "The smartgunner never got the gun ready and fired it, arm [gun.armbrace], stabilizer [gun.recoil_compensation], shots [subject.shots_fired]: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT(!gun.cover_open, "The smartgun was fired with its cover open")
	TEST_ASSERT(gun.flags_item & NODROP, "The servo arm is not locking the gun to the hand")

	// The drum runs dry: the cover is opened, the empty drum comes out, the full one goes in, and the cover is closed
	var/obj/item/ammo_magazine/empty_drum = gun.current_mag
	empty_drum.current_rounds = 0
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(reloaded)), 30), "The smartgunner never swapped the drum: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT(saw_cover_open, "The drum was swapped without the cover being opened")
	TEST_ASSERT_EQUAL(gun.current_mag, spare_drum, "The full drum is not the one in the gun")
	TEST_ASSERT(gun.current_mag.current_rounds > 0, "The new drum is empty")
	TEST_ASSERT(empty_drum != gun.current_mag && empty_drum.loc != gun, "The empty drum is still in the gun")

	// The battery runs out: a fresh one is put in
	gun.battery.power_cell.charge = 0
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(new_battery), spare_battery), 20), "The smartgunner never swapped the battery: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT(subject.sg_battery_swaps >= 1, "The battery swap was not counted")

	// The enemy is gone: the stabilizer and the arm come off, and the gun can be put away
	qdel(target)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(stood_down)), 45), "The smartgunner did not stand the gun down once the fight was over, arm [gun.armbrace], stabilizer [gun.recoil_compensation]: [subject.decision_log.Join(" | ")]")
	TEST_ASSERT(!(gun.flags_item & NODROP), "The gun is still locked to the hand")
	TEST_ASSERT_EQUAL(subject.error_total, 0, "The brain threw errors: [subject.decision_log.Join(" | ")]")
	detach_human_ai(gunner)
	qdel(gunner)

	// Without a harness the gun is no use, and the pistol is what the man fires
	var/mob/living/carbon/xenomorph/drone/second = make_target_dummy(locate(gunner_turf.x + 7, gunner_turf.y, yard.z))
	SSspatial_grid.track(second, SPATIAL_GRID_TRACK_NPC)
	var/mob/living/carbon/human/bare = make_gunner(gunner_turf, FALSE)
	var/obj/item/weapon/gun/pistol/m4a3/pistol = new(bare.back)
	TEST_ASSERT(subject.smartgun_unusable(gun), "A smartgun with no harness is thought usable")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(holds_pistol), pistol), 25), "The man without a harness never took up his pistol: [subject.decision_log.Join(" | ")]")
	detach_human_ai(bare)
	qdel(bare)
	qdel(second)

/datum/unit_test/human_ai_smartgunner/proc/holds_pistol(obj/item/weapon/gun/pistol)
	return subject.peek_gun() == pistol

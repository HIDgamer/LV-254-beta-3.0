/// The factions 4hands44 added stand with their own, are at war with who they should be, speak in voices of their own and every one of their squads can be spawned
/datum/unit_test/human_ai_new_faction_relations

/datum/unit_test/human_ai_new_faction_relations/Run()
	var/list/new_factions = list(FACTION_GANGSTER, FACTION_CLOWN_GANG, FACTION_BIKER_GANG, FACTION_YAKUZA, FACTION_DIONYSUS, FACTION_SYNDICATE, FACTION_SCAV, FACTION_WARLORD, FACTION_WAGNER, FACTION_DIAMOND_DOG)
	var/list/known = human_ai_known_factions()
	for(var/faction in new_factions)
		TEST_ASSERT(faction in known, "[faction] is not one the relations editor knows")
		TEST_ASSERT_EQUAL(human_ai_faction_relation(faction, faction), HAI_REL_FRIENDLY, "[faction] is not friendly with itself")
	for(var/faction in list(FACTION_GANGSTER, FACTION_CLOWN_GANG, FACTION_BIKER_GANG, FACTION_YAKUZA, FACTION_DIONYSUS, FACTION_SYNDICATE, FACTION_SCAV, FACTION_WARLORD, FACTION_WAGNER))
		TEST_ASSERT_EQUAL(human_ai_faction_relation(faction, FACTION_MARINE), HAI_REL_HOSTILE, "[faction] does not fight the marines")
		TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MARINE, faction), HAI_REL_HOSTILE, "The marines do not fight [faction]")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_SCAV, FACTION_WARLORD), HAI_REL_FRIENDLY, "The scavs do not stand with their warlords")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_WARLORD, FACTION_SCAV), HAI_REL_FRIENDLY, "The warlords do not stand with their scavs")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_WARLORD, FACTION_UPP), HAI_REL_FRIENDLY, "Crazy Ivan is not a friend of the UPP")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_UPP, FACTION_WARLORD), HAI_REL_FRIENDLY, "The UPP does not stand with Crazy Ivan")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_SCAV, FACTION_UPP), HAI_REL_NEUTRAL, "The scavs were set against the UPP")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_WAGNER, FACTION_DIAMOND_DOG), HAI_REL_HOSTILE, "The Iron Bears do not fight the Diamond Dogs")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_DIAMOND_DOG, FACTION_WAGNER), HAI_REL_HOSTILE, "The Diamond Dogs do not fight the Iron Bears")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_SYNDICATE, FACTION_PMC), HAI_REL_HOSTILE, "The Syndicate does not fight the corporations")
	// The gangs do not stand with one another and nobody was told to fight who they were not meant to
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_YAKUZA, FACTION_BIKER_GANG), HAI_REL_NEUTRAL, "The Yakuza and the bikers are not left to the admins")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_MERCENARY, FACTION_MARINE), HAI_REL_NEUTRAL, "The mercenaries had their relations changed")
	TEST_ASSERT_EQUAL(human_ai_faction_relation(FACTION_DIAMOND_DOG, FACTION_MARINE), HAI_REL_NEUTRAL, "The Diamond Dogs were set against the marines")

	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_YAKUZA).id, "underworld", "The Yakuza do not talk like the underworld")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_SYNDICATE).id, "underworld", "The Syndicate does not talk like the underworld")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_SCAV).id, "scav", "The scavs do not talk like scavs")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_WARLORD).id, "scav", "The warlords do not talk like scavs")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_WAGNER).id, "mercenary", "The Iron Bears do not talk like mercenaries")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_MERCENARY).id, "mercenary", "Mercenaries do not talk like mercenaries")
	TEST_ASSERT_EQUAL(get_human_ai_voice(FACTION_CLF).id, "rebel", "The CLF lost its voice")
	for(var/voice_id in list("mercenary", "underworld", "scav"))
		var/datum/human_ai_voice/bank = GLOB.human_ai_voices[voice_id]
		TEST_ASSERT_NOTNULL(bank, "There is no [voice_id] voice")
		TEST_ASSERT(length(bank.line("contact", null)), "The [voice_id] voice has nothing to say on contact")
		TEST_ASSERT(length(bank.small_talk()), "The [voice_id] voice has no small talk")

/// A man nobody picked a nature for is what his people are like, a boss is a different sort and a chosen nature is never overruled
/datum/unit_test/human_ai_faction_natures

/datum/unit_test/human_ai_faction_natures/Run()
	for(var/faction in GLOB.human_ai_faction_natures)
		var/list/natures = GLOB.human_ai_faction_natures[faction]
		for(var/nature in natures)
			TEST_ASSERT(nature in GLOB.human_ai_personalities, "[faction] has [nature], which is not a nature")
	for(var/nature in GLOB.human_ai_leader_natures)
		TEST_ASSERT(nature in GLOB.human_ai_personalities, "The leaders have [nature], which is not a nature")
	TEST_ASSERT(human_ai_is_leader_job("Yakuza Clan Leader"), "A clan leader is not a leader")
	TEST_ASSERT(human_ai_is_leader_job("Gangster Boss"), "A gangster boss is not a leader")
	TEST_ASSERT(human_ai_is_leader_job("Factory Boss"), "The factory boss is not a leader")
	TEST_ASSERT(!human_ai_is_leader_job("Gangster"), "A gangster is a leader")
	TEST_ASSERT(!human_ai_is_leader_job(null), "Nobody is a leader")

	var/mob/living/carbon/human/man = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	man.create_hud()
	man.faction = FACTION_YAKUZA
	man.job = "Yakuza"
	TEST_ASSERT(attach_human_ai(man), "The Yakuza took no brain")
	TEST_ASSERT(man.ai_brain.personality.id in GLOB.human_ai_faction_natures[FACTION_YAKUZA], "A Yakuza is [man.ai_brain.personality.id], which is not what the Yakuza are like")
	detach_human_ai(man)

	man.job = "Yakuza Clan Leader"
	TEST_ASSERT(attach_human_ai(man), "The clan leader took no brain")
	TEST_ASSERT(man.ai_brain.personality.id in GLOB.human_ai_leader_natures, "A clan leader is [man.ai_brain.personality.id], which is not what leaders are like")
	detach_human_ai(man)

	TEST_ASSERT(attach_human_ai(man, "friendly"), "The Yakuza took no brain with a chosen nature")
	TEST_ASSERT_EQUAL(man.ai_brain.personality.id, "friendly", "A nature that was picked on purpose was overruled")
	detach_human_ai(man)

	// A faction without a doctrine keeps the blank nature it always had
	man.faction = FACTION_MARINE
	man.job = "Squad Rifleman"
	TEST_ASSERT(attach_human_ai(man), "The marine took no brain")
	TEST_ASSERT_EQUAL(man.ai_brain.personality.id, "neutral", "A marine was given a nature by a doctrine he does not have")
	detach_human_ai(man)

/// The people of the factions with a kit carry the grenades it calls for and are not handed a second one of a kind they have
/datum/unit_test/human_ai_faction_kit

/datum/unit_test/human_ai_faction_kit/Run()
	var/mob/living/carbon/human/merc = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	merc.create_hud()
	merc.faction = FACTION_MERCENARY
	var/obj/item/storage/backpack/pack = new(merc)
	merc.put_in_back(pack)
	TEST_ASSERT(attach_human_ai(merc), "The mercenary took no brain")
	var/datum/human_ai_brain/brain = merc.ai_brain
	TEST_ASSERT_NOTNULL(brain.find_grenade(HAI_GRENADE_LETHAL), "A mercenary carries no frag grenade")
	TEST_ASSERT_NOTNULL(brain.find_grenade(HAI_GRENADE_SMOKE), "A mercenary carries no smoke grenade")
	TEST_ASSERT_NULL(brain.find_grenade(HAI_GRENADE_FLASH), "A mercenary was handed a flashbang he does not need")
	detach_human_ai(merc)

	// Whoever already has a grenade of a kind is not given another
	var/mob/living/carbon/human/armed = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	armed.create_hud()
	armed.faction = FACTION_MERCENARY
	var/obj/item/storage/backpack/armed_pack = new(armed)
	armed.put_in_back(armed_pack)
	var/obj/item/explosive/grenade/high_explosive/frag/own = new(armed_pack)
	TEST_ASSERT(attach_human_ai(armed), "The armed mercenary took no brain")
	var/frags = 0
	for(var/obj/item/explosive/grenade/high_explosive/frag/frag in armed.get_contents())
		frags++
	TEST_ASSERT_EQUAL(frags, 1, "A man with a frag grenade was handed another")
	TEST_ASSERT(own in armed.get_contents(), "The grenade he had was taken away")
	TEST_ASSERT_NOTNULL(armed.ai_brain.find_grenade(HAI_GRENADE_SMOKE), "The man with a frag grenade was not handed the smoke he lacked")
	detach_human_ai(armed)

	// The marines have no kit of their own and neither does a synthetic
	var/mob/living/carbon/human/marine = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	marine.create_hud()
	marine.faction = FACTION_MARINE
	var/obj/item/storage/backpack/marine_pack = new(marine)
	marine.put_in_back(marine_pack)
	TEST_ASSERT(attach_human_ai(marine), "The marine took no brain")
	TEST_ASSERT_NULL(marine.ai_brain.find_grenade(HAI_GRENADE_LETHAL), "A marine was handed a grenade by a kit he does not have")
	detach_human_ai(marine)

/// Every one of the squads of the new factions comes out whole with real equipment, takes the nature of its people and has a leader of the right sort
/datum/unit_test/human_ai_new_faction_squads
	var/datum/npc_command_console/console

/datum/unit_test/human_ai_new_faction_squads/Destroy()
	QDEL_NULL(console)
	return ..()

/datum/unit_test/human_ai_new_faction_squads/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/admin = allocate(/mob/living/carbon/human, locate(yard.origin_x + 1, yard.origin_y + 1, yard.z))
	console = make_console(admin)
	var/list/squads = list(
		"gangster_crew" = FACTION_GANGSTER,
		"clown_gang" = FACTION_CLOWN_GANG,
		"biker_gang" = FACTION_BIKER_GANG,
		"yakuza_clan" = FACTION_YAKUZA,
		"dionysus_cult" = FACTION_DIONYSUS,
		"syndicate_cell" = FACTION_SYNDICATE,
		"scav_pack" = FACTION_SCAV,
		"iron_bear_team" = FACTION_WAGNER,
		"diamond_dogs" = FACTION_DIAMOND_DOG,
	)
	var/turf/center = locate(yard.origin_x + 10, yard.origin_y + 3, yard.z)
	for(var/template_id in squads)
		var/list/template = GLOB.human_ai_squad_templates[template_id]
		TEST_ASSERT_NOTNULL(template, "There is no squad [template_id]")
		var/faction = squads[template_id]
		var/list/spawned = console.do_spawn_template(admin, center, list("template" = template_id, "personality" = "neutral", "range" = 3))
		TEST_ASSERT_EQUAL(length(spawned), human_ai_template_size(template), "The squad [template["name"]] did not come out whole")
		var/mob/living/carbon/human/leader = spawned[1]
		TEST_ASSERT(leader.ai_brain?.squad && leader.ai_brain.squad.leader == leader.ai_brain, "The squad [template["name"]] has no leader")
		for(var/mob/living/carbon/human/member as anything in spawned)
			TEST_ASSERT_NOTNULL(member.ai_brain, "A member of [template["name"]] has no brain")
			TEST_ASSERT_EQUAL(member.faction, faction, "A member of [template["name"]] ([member.assigned_equipment_preset?.name], job [member.job], [member.type], stat [member.stat], preset faction [member.assigned_equipment_preset?.faction]) is of the faction [member.faction] and not [faction]")
			if(isworkingjoe(member))
				continue
			var/list/natures = GLOB.human_ai_faction_natures[faction]
			if(human_ai_is_leader_job(member.job))
				natures = GLOB.human_ai_leader_natures
			TEST_ASSERT(member.ai_brain.personality.id in natures, "A member of [template["name"]] ([member.job]) is [member.ai_brain.personality.id], which is not what they are like")
			TEST_ASSERT(length(member.get_contents()) > 1, "A member of [template["name"]] ([member.job]) came out with no equipment")
		for(var/mob/living/carbon/human/member as anything in spawned)
			detach_human_ai(member)
			qdel(member)

/// The scavs and the marines, who were strangers before, open fire on each other
/datum/unit_test/human_ai_new_faction_fight
	var/datum/human_ai_brain/scav_brain
	var/datum/human_ai_brain/marine_brain

/datum/unit_test/human_ai_new_faction_fight/Destroy()
	scav_brain = null
	marine_brain = null
	return ..()

/datum/unit_test/human_ai_new_faction_fight/proc/rifleman(faction, turf/where, direction, datum/human_ai_arena/yard)
	var/mob/living/carbon/human/man = allocate(/mob/living/carbon/human, where)
	human_ai_test_skills(man)
	man.faction = faction
	man.setDir(direction)
	var/obj/item/storage/backpack/pack = new(man)
	man.put_in_back(pack)
	var/obj/item/weapon/gun/sample = new /obj/item/weapon/gun/rifle/m41a(run_loc_floor_bottom_left)
	human_ai_test_spare_ammo(sample, pack)
	human_ai_test_spare_ammo(sample, pack)
	qdel(sample)
	man.put_in_hands(new /obj/item/weapon/gun/rifle/m41a(man, TRUE))
	if(!attach_human_ai(man, "professional"))
		return null
	man.ai_brain.keep_awake = TRUE
	man.ai_brain.suppress_error_log = TRUE
	return man

/datum/unit_test/human_ai_new_faction_fight/Run()
	var/datum/human_ai_arena/yard = new(list(
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	), run_loc_floor_bottom_left)
	var/mob/living/carbon/human/scav = rifleman(FACTION_SCAV, locate(yard.origin_x + 2, yard.origin_y + 2, yard.z), EAST, yard)
	var/mob/living/carbon/human/marine = rifleman(FACTION_MARINE, locate(yard.origin_x + 10, yard.origin_y + 2, yard.z), WEST, yard)
	TEST_ASSERT_NOTNULL(scav, "The scav took no brain")
	TEST_ASSERT_NOTNULL(marine, "The marine took no brain")
	scav_brain = scav.ai_brain
	marine_brain = marine.ai_brain
	TEST_ASSERT(scav_brain.faction_is_enemy(FACTION_MARINE), "A scav does not take the marines for enemies")
	TEST_ASSERT(marine_brain.faction_is_enemy(FACTION_SCAV), "A marine does not take the scavs for enemies")
	TEST_ASSERT(!scav_brain.faction_is_enemy(FACTION_SCAV), "A scav takes scavs for enemies")
	var/waited = 0
	while(waited < 20 && !(scav_brain.shots_fired && marine_brain.shots_fired))
		sleep(1 SECONDS)
		waited++
	TEST_ASSERT(scav_brain.shots_fired > 0, "The scav never fired at the marine in [waited] s, intent [scav_brain.intent], target [scav_brain.get_target()]")
	TEST_ASSERT(marine_brain.shots_fired > 0, "The marine never fired at the scav in [waited] s, intent [marine_brain.intent], target [marine_brain.get_target()]")
	detach_human_ai(scav)
	detach_human_ai(marine)
	for(var/obj/projectile/bullet in world)
		qdel(bullet)

/// Every preset of the new factions puts its people in the faction it says, which the sides of the AI are made of
/datum/unit_test/human_ai_new_faction_presets

/datum/unit_test/human_ai_new_faction_presets/Run()
	var/list/problems = list()
	var/list/wanted = list(FACTION_GANGSTER, FACTION_CLOWN_GANG, FACTION_BIKER_GANG, FACTION_YAKUZA, FACTION_DIONYSUS, FACTION_SYNDICATE, FACTION_SCAV, FACTION_WARLORD, FACTION_WAGNER, FACTION_DIAMOND_DOG)
	var/checked = 0
	for(var/name in GLOB.gear_name_presets_list)
		var/datum/equipment_preset/preset = GLOB.gear_name_presets_list[name]
		if(!(preset.faction in wanted))
			continue
		checked++
		var/mob/living/carbon/human/man = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
		man.create_hud()
		arm_equipment(man, name, TRUE, FALSE)
		if(man.faction != preset.faction)
			problems += "[name] is of the faction [man.faction] and not [preset.faction]"
		qdel(man)
	TEST_ASSERT(checked > 10, "Only [checked] presets of the new factions were found")
	TEST_ASSERT(!length(problems), "[length(problems)] presets do not apply their faction: [problems.Join("; ")]")

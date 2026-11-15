/**
 * How the factions carry themselves in a fight. A man spawned without anybody picking a nature for him takes one from the weighted table of his faction, so a
 * clan of Yakuza fights like disciplined thugs, a cell of CLF like guerrillas who use cover and a cult like fanatics, instead of every one of them being the same
 * blank slate. Whoever picks a nature on purpose is never overruled. A faction that is not in the table keeps what it always had.
 */

/// Faction to the natures its people are given when nobody picked one, weighted
GLOBAL_LIST_INIT(human_ai_faction_natures, list(
	// The rebels: a few fanatics among people who know the ground and fight from cover
	FACTION_CLF = list("cautious" = 3, "veteran" = 2, "scout" = 1, "reckless" = 1, "zealot" = 1),
	// Hired guns do not die for a contract
	FACTION_MERCENARY = list("professional" = 3, "veteran" = 2, "cautious" = 1, "ruthless" = 1),
	FACTION_FREELANCER = list("professional" = 3, "veteran" = 2, "cautious" = 1, "ruthless" = 1),
	FACTION_CONTRACTOR = list("professional" = 3, "veteran" = 2, "cautious" = 2),
	FACTION_PINKERTON = list("professional" = 3, "veteran" = 2, "cautious" = 1),
	FACTION_DUTCH = list("veteran" = 3, "professional" = 2, "ruthless" = 1),
	FACTION_WAGNER = list("veteran" = 2, "professional" = 2, "ruthless" = 2, "zealot" = 1),
	FACTION_DIAMOND_DOG = list("professional" = 3, "veteran" = 2, "scout" = 2, "cautious" = 1),
	FACTION_SYNDICATE = list("professional" = 3, "veteran" = 2, "ruthless" = 1, "cautious" = 1),
	// The zone makes people jumpy and careful
	FACTION_SCAV = list("paranoid" = 2, "cautious" = 2, "scout" = 1, "hostile" = 1, "veteran" = 1),
	FACTION_WARLORD = list("veteran" = 2, "ruthless" = 2, "hostile" = 1),
	// The gangs
	FACTION_GANGSTER = list("hostile" = 2, "reckless" = 2, "ruthless" = 1, "cautious" = 1),
	FACTION_CLOWN_GANG = list("reckless" = 3, "zealot" = 1, "hostile" = 1),
	FACTION_BIKER_GANG = list("hostile" = 2, "reckless" = 2, "ruthless" = 1),
	FACTION_YAKUZA = list("professional" = 2, "ruthless" = 2, "veteran" = 1),
	FACTION_DIONYSUS = list("zealot" = 3, "reckless" = 1, "ruthless" = 1),
))

/// What the leaders and the bosses of the factions in the table are like
GLOBAL_LIST_INIT(human_ai_leader_natures, list("veteran" = 3, "professional" = 2, "ruthless" = 1))

/// Faction to the kinds of grenade each of its people should carry, the ones who carry none of a kind are given one
GLOBAL_LIST_INIT(human_ai_faction_grenades, list(
	FACTION_CLF = list(HAI_GRENADE_SMOKE),
	FACTION_MERCENARY = list(HAI_GRENADE_LETHAL, HAI_GRENADE_SMOKE),
	FACTION_FREELANCER = list(HAI_GRENADE_LETHAL, HAI_GRENADE_SMOKE),
	FACTION_CONTRACTOR = list(HAI_GRENADE_LETHAL, HAI_GRENADE_SMOKE),
	FACTION_PINKERTON = list(HAI_GRENADE_FLASH, HAI_GRENADE_SMOKE),
	FACTION_DUTCH = list(HAI_GRENADE_LETHAL, HAI_GRENADE_SMOKE),
	FACTION_WAGNER = list(HAI_GRENADE_LETHAL, HAI_GRENADE_SMOKE),
	FACTION_DIAMOND_DOG = list(HAI_GRENADE_FLASH, HAI_GRENADE_SMOKE),
	FACTION_SYNDICATE = list(HAI_GRENADE_LETHAL, HAI_GRENADE_FLASH, HAI_GRENADE_SMOKE),
	FACTION_SCAV = list(HAI_GRENADE_LETHAL),
	FACTION_WARLORD = list(HAI_GRENADE_LETHAL, HAI_GRENADE_SMOKE),
))

/// Whether the job is one that leads the others, from the words in its name
/proc/human_ai_is_leader_job(job)
	var/text = lowertext("[job]")
	for(var/keyword in list("leader", "boss", "chief", "armsmaster", "commander"))
		if(findtext(text, keyword))
			return TRUE
	return FALSE

/// The nature a faction's man is given when nobody picked one for him, null when his faction has no doctrine
/proc/human_ai_nature_for(mob/living/carbon/human/human)
	var/list/natures = GLOB.human_ai_faction_natures[human.faction]
	if(!length(natures))
		return null
	if(human_ai_is_leader_job(human.job))
		natures = GLOB.human_ai_leader_natures
	return pick_weight(natures)

/// The grenade a kind of grenade is handed out as
/proc/human_ai_grenade_type(kind)
	switch(kind)
		if(HAI_GRENADE_LETHAL)
			return /obj/item/explosive/grenade/high_explosive/frag
		if(HAI_GRENADE_SMOKE)
			return /obj/item/explosive/grenade/smokebomb
		if(HAI_GRENADE_FLASH)
			return /obj/item/explosive/grenade/flashbang
	return null

/// Hands the body the grenades of the kinds its faction carries that it does not have yet
/datum/human_ai_brain/proc/issue_faction_kit()
	var/list/kinds = GLOB.human_ai_faction_grenades[body.faction]
	if(!length(kinds) || issynth(body) || is_civilian())
		return
	grenade_cache_time = 0
	for(var/kind in kinds)
		if(find_grenade(kind))
			continue
		var/grenade_type = human_ai_grenade_type(kind)
		if(grenade_type)
			give_kit_item(grenade_type)
		grenade_cache_time = 0

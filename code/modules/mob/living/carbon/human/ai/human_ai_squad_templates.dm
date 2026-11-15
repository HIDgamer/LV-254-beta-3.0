/**
 * Squads that can be spawned whole: who is in each and what each one carries, by the name of the equipment preset. The first member is the leader. An admin arms one in the NPC
 * command panel and clicks where it is to appear, which is faster and truer to how the factions field their people than spawning one equipment preset at a time.
 */
GLOBAL_LIST_INIT(human_ai_squad_templates, list(
	"uscm_fireteam" = list("name" = "USCM fireteam", "members" = list(
		list("job" = "Falling Falcons Squad Leader (Equipped)", "count" = 1),
		list("job" = "Falling Falcons Squad Rifleman (Equipped)", "count" = 4),
		list("job" = "Falling Falcons Squad Hospital Corpsman (Equipped)", "count" = 1),
	)),
	"uscm_heavy" = list("name" = "USCM heavy section", "members" = list(
		list("job" = "Falling Falcons Squad Leader (Equipped)", "count" = 1),
		list("job" = "Falling Falcons Squad Rifleman (Equipped)", "count" = 3),
		list("job" = "Falling Falcons Squad Weapons Specialist (Equipped)", "count" = 1),
		list("job" = "Falling Falcons Squad Combat Technician (Equipped)", "count" = 1),
	)),
	"upp_squad" = list("name" = "UPP rifle squad", "members" = list(
		list("job" = "UPP Squad Leader", "count" = 1),
		list("job" = "UPP Soldier", "count" = 4),
		list("job" = "UPP Machinegunner", "count" = 1),
		list("job" = "UPP Specialist", "count" = 1),
		list("job" = "UPP Medic", "count" = 1),
	)),
	"pmc_team" = list("name" = "PMC strike team", "members" = list(
		list("job" = "Weyland-Yutani PMC (Leader)", "count" = 1),
		list("job" = "Weyland-Yutani PMC (Standard)", "count" = 3),
		list("job" = "Weyland-Yutani PMC (Gunner)", "count" = 1),
		list("job" = "Weyland-Yutani PMC (Sniper)", "count" = 1),
		list("job" = "Weyland-Yutani PMC (Corporate Medic)", "count" = 1),
	)),
	"clf_cell" = list("name" = "CLF cell", "members" = list(
		list("job" = "Insurgent Leader", "count" = 1),
		list("job" = "Insurgent Soldier", "count" = 4),
		list("job" = "Insurgent Field Specialist", "count" = 1),
		list("job" = "Insurgent Engineer", "count" = 1),
		list("job" = "Insurgent Medic", "count" = 1),
	)),
	"colony_security" = list("name" = "Colony security detail", "members" = list(
		list("job" = "Colonist - Security", "count" = 4),
	)),
	"gangster_crew" = list("name" = "Gangster crew", "members" = list(
		list("job" = "Gangster Leader(generic)", "count" = 1),
		list("job" = "Gangster(generic)", "count" = 3),
		list("job" = "Gangster elite(generic)", "count" = 1),
	)),
	"clown_gang" = list("name" = "Clown gang", "members" = list(
		list("job" = "Gangster Leader(clown !!silly!!)", "count" = 1),
		list("job" = "Gangster(clown)", "count" = 3),
		list("job" = "Gangster(clown !!silly!!)", "count" = 1),
	)),
	"biker_gang" = list("name" = "Backbiters biker gang", "members" = list(
		list("job" = "Gangster Leader(Backbiter)", "count" = 1),
		list("job" = "Gangster(Backbiter)", "count" = 3),
		list("job" = "Gangster elite(Backbiter)", "count" = 1),
	)),
	"yakuza_clan" = list("name" = "Yakuza clan", "members" = list(
		list("job" = "Gangster Leader(Yakuza)", "count" = 1),
		list("job" = "Gangster(Yakuza)", "count" = 3),
		list("job" = "Gangster elite(Yakuza)", "count" = 1),
	)),
	"dionysus_cult" = list("name" = "Children of Dionysus", "members" = list(
		list("job" = "Gangster Leader(Dionysus-Male)", "count" = 1),
		list("job" = "Gangster(Dionysus-Male)", "count" = 2),
		list("job" = "Gangster(Dionysus-Female)", "count" = 2),
		list("job" = "Gangster elite(Dionysus-Female)", "count" = 1),
	)),
	"syndicate_cell" = list("name" = "Syndicate cell", "members" = list(
		list("job" = "Syndicate Operative", "count" = 4),
	)),
	"scav_pack" = list("name" = "Scav pack", "members" = list(
		list("job" = "S.T.A.L.K.E.R.", "count" = 1),
		list("job" = "S.T.A.L.K.E.R. Elite", "count" = 3),
	)),
	"iron_bear_team" = list("name" = "Iron Bear team", "members" = list(
		list("job" = "Iron Bear PMC", "count" = 1),
		list("job" = "Iron Bear PMC 2", "count" = 4),
	)),
	"diamond_dogs" = list("name" = "Diamond Dogs", "members" = list(
		list("job" = "Diamond Dogs - Snake(Warlord)", "count" = 1),
		list("job" = "Diamond Dogs PMC", "count" = 4),
	)),
))

/// How many people a template has
/proc/human_ai_template_size(list/template)
	var/size = 0
	for(var/list/entry in template["members"])
		size += entry["count"]
	return size

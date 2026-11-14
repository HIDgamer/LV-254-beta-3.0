/// LV-624: the Lazarus Landing colony with its staff, security, goons and a crashed CLF cell
/datum/npc_population_profile/lv624
	map_name = "LV-624"
	group_types = list(
		/datum/npc_population_group/lv624/colonists,
		/datum/npc_population_group/lv624/staff,
		/datum/npc_population_group/lv624/security,
		/datum/npc_population_group/lv624/goons,
		/datum/npc_population_group/lv624/clf,
	)

/datum/npc_population_group/lv624/colonists
	id = "lv_colonists"
	name = "Colonists and workers"
	presets = list(/datum/equipment_preset/survivor/civilian = 4, /datum/equipment_preset/survivor/trucker/lv = 1, /datum/equipment_preset/survivor/engineer/lv = 1)
	personalities = list("skittish" = 3, "friendly" = 3)
	roles = list("civilian" = 1)
	size_min = 5
	size_max = 10
	size_per_player = 0.1
	zones = list(/area/lv624/lazarus/main_hall = 2, /area/lv624/lazarus/canteen = 2, /area/lv624/lazarus/kitchen = 1, /area/lv624/lazarus/hydroponics = 1, /area/lv624/lazarus/fitness = 1, /area/lv624/lazarus/sleep_male = 1, /area/lv624/lazarus/sleep_female = 1)
	behavior = HAI_POP_LOITER
	marine_attitude = "friendly"
	reaction = "cower"

/datum/npc_population_group/lv624/staff
	id = "lv_staff"
	name = "Scientists, doctors and clergy"
	presets = list(/datum/equipment_preset/survivor/scientist/lv = 2, /datum/equipment_preset/survivor/doctor/lv = 2, /datum/equipment_preset/survivor/chaplain/lv = 1, /datum/equipment_preset/survivor/corporate/lv = 1)
	personalities = list("skittish" = 2, "cautious" = 2)
	roles = list("civilian" = 2, "medic" = 1)
	size_min = 3
	size_max = 6
	size_per_player = 0.05
	zones = list(/area/lv624/lazarus/research = 2, /area/lv624/lazarus/medbay = 2, /area/lv624/lazarus/chapel = 1, /area/lv624/lazarus/robotics = 1)
	behavior = HAI_POP_LOITER
	marine_attitude = "friendly"
	reaction = "cower"

/datum/npc_population_group/lv624/security
	id = "lv_security"
	name = "Colony security and marshals"
	presets = list(/datum/equipment_preset/survivor/security/lv = 3, /datum/equipment_preset/survivor/colonial_marshal/lv = 1)
	personalities = list("professional" = 3, "cautious" = 1)
	roles = list("security" = 1)
	size_min = 3
	size_max = 5
	size_per_player = 0.05
	squad_size = 3
	zones = list(/area/lv624/lazarus/security = 2, /area/lv624/lazarus/armory = 1)
	behavior = HAI_POP_GUARD
	marine_attitude = "friendly"

/datum/npc_population_group/lv624/goons
	id = "lv_goons"
	name = "Corporate goons"
	presets = list(/datum/equipment_preset/survivor/goon = 1)
	personalities = list("reckless" = 2, "ruthless" = 1, "veteran" = 1)
	roles = list("rifleman" = 1)
	size_min = 2
	size_max = 4
	size_per_player = 0.05
	squad_size = 4
	zones = list(/area/lv624/lazarus/comms = 1, /area/lv624/lazarus/secure_storage = 1)
	behavior = HAI_POP_GUARD
	marine_attitude = "hostile"

/datum/npc_population_group/lv624/clf
	id = "lv_clf"
	name = "Crashed CLF cell"
	presets = list(/datum/equipment_preset/survivor/clf = 1)
	personalities = list("zealot" = 2, "reckless" = 2)
	roles = list("rifleman" = 3, "medic" = 1)
	size_min = 2
	size_max = 4
	size_per_player = 0.05
	squad_size = 4
	zones = list(/area/lv624/lazarus/crashed_ship = 2, /area/lv624/lazarus/crashed_ship_containers = 1)
	behavior = HAI_POP_GUARD
	marine_attitude = "hostile"
	wound_min = 3
	wound_max = 10

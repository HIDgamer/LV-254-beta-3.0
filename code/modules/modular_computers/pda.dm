/obj/item/modular_computer/pda
	name = "PDA"
	desc = "A portable Weyland-Yutani communications and data device."
	icon_state = "/obj/item/modular_computer/pda/bridge_assistant"
	default_programs = list(
		/datum/computer_file/program/messenger,
		/datum/computer_file/program/notepad,
		/datum/computer_file/program/crew_manifest,
		/datum/computer_file/program/themeify,
	)

/obj/item/modular_computer/pda/update_icon()
	..()
	if(computer_id_slot)
		overlays += image(overlays_icon, "id_overlay")
	if(light_on)
		overlays += image(overlays_icon, "light_overlay")

/// Imprints the PDA with the wearer's name and job
/obj/item/modular_computer/pda/proc/imprint_to(mob/living/carbon/human/owner, client/owner_client)
	var/role = GLOB.pda_roles_by_job[owner.job]
	if(role)
		name = "[role] PDA"
	owner_client ||= owner.client
	var/theme = GLOB.pda_themes[owner_client?.prefs?.pda_theme]
	if(theme)
		device_theme = theme
	imprint_id(owner.real_name, owner.job)

/obj/item/modular_computer/pda/ship_staff
	name = "ship staff PDA"
	desc = "A Weyland-Yutani PDA issued to ship staff for messaging the rest of the crew and keeping notes."

/obj/item/modular_computer/pda/ship_staff/engineering
	icon_state = "/obj/item/modular_computer/pda/engineering"

/obj/item/modular_computer/pda/ship_staff/medical
	icon_state = "/obj/item/modular_computer/pda/medical"
	extra_programs = list(/datum/computer_file/program/lifeline)

/obj/item/modular_computer/pda/ship_staff/security
	icon_state = "/obj/item/modular_computer/pda/security"
	extra_programs = list(/datum/computer_file/program/lifeline)

/obj/item/modular_computer/pda/ship_staff/requisitions
	icon_state = "/obj/item/modular_computer/pda/cargo"
	extra_programs = list(/datum/computer_file/program/supply_request)

/obj/item/modular_computer/pda/ship_staff/liaison
	icon_state = "/obj/item/modular_computer/pda/lawyer"
	can_print_notes = TRUE

/obj/item/modular_computer/pda/senior_staff
	name = "senior staff PDA"
	desc = "A Weyland-Yutani PDA issued to senior staff for messaging the rest of the crew and keeping notes."
	icon_state = "/obj/item/modular_computer/pda/heads/captain"
	extra_programs = list(/datum/computer_file/program/lifeline)
	can_print_notes = TRUE

/obj/item/modular_computer/pda/senior_staff/requisitions
	icon_state = "/obj/item/modular_computer/pda/quartermaster"
	extra_programs = list(
		/datum/computer_file/program/lifeline,
		/datum/computer_file/program/supply_request,
	)

/obj/item/modular_computer/pda/senior_staff/synthetic
	name = "synthetic command PDA"
	desc = "A black Weyland-Yutani PDA issued to the ship's synthetic for command-level messaging and note keeping."
	icon_state = "/obj/item/modular_computer/pda/chaplain"

GLOBAL_LIST_INIT(pda_types_by_job, list(
	JOB_SYNTH = /obj/item/modular_computer/pda/senior_staff/synthetic,
	JOB_CO = /obj/item/modular_computer/pda/senior_staff,
	JOB_XO = /obj/item/modular_computer/pda/senior_staff,
	JOB_SO = /obj/item/modular_computer/pda/senior_staff,
	JOB_AUXILIARY_OFFICER = /obj/item/modular_computer/pda/senior_staff,
	JOB_SEA = /obj/item/modular_computer/pda/senior_staff,
	JOB_CHIEF_POLICE = /obj/item/modular_computer/pda/senior_staff,
	JOB_CHIEF_ENGINEER = /obj/item/modular_computer/pda/senior_staff,
	JOB_CHIEF_REQUISITION = /obj/item/modular_computer/pda/senior_staff/requisitions,
	JOB_CMO = /obj/item/modular_computer/pda/senior_staff,
	JOB_POLICE = /obj/item/modular_computer/pda/ship_staff/security,
	JOB_WARDEN = /obj/item/modular_computer/pda/ship_staff/security,
	JOB_DOCTOR = /obj/item/modular_computer/pda/ship_staff/medical,
	JOB_NURSE = /obj/item/modular_computer/pda/ship_staff/medical,
	JOB_RESEARCHER = /obj/item/modular_computer/pda/ship_staff/medical,
	JOB_MAINT_TECH = /obj/item/modular_computer/pda/ship_staff/engineering,
	JOB_ORDNANCE_TECH = /obj/item/modular_computer/pda/ship_staff/engineering,
	JOB_CARGO_TECH = /obj/item/modular_computer/pda/ship_staff/requisitions,
	JOB_DROPSHIP_PILOT = /obj/item/modular_computer/pda/ship_staff,
	JOB_CAS_PILOT = /obj/item/modular_computer/pda/ship_staff,
	JOB_OPERATIONS_PILOT = /obj/item/modular_computer/pda/ship_staff,
	JOB_DROPSHIP_CREW_CHIEF = /obj/item/modular_computer/pda/ship_staff,
	JOB_INTEL = /obj/item/modular_computer/pda/ship_staff,
	JOB_COMBAT_REPORTER = /obj/item/modular_computer/pda/ship_staff,
	JOB_CORPORATE_LIAISON = /obj/item/modular_computer/pda/ship_staff/liaison,
))

/// Gives the new human a PDA if their job is issued one, in a pouch slot, else a pouch that fits it, else the backpack
/datum/equipment_preset/proc/load_pda(mob/living/carbon/human/new_human, client/mob_client)
	var/pda_type = GLOB.pda_types_by_job[new_human.job]
	if(!pda_type)
		return
	var/obj/item/modular_computer/pda/pda = new pda_type(new_human)
	pda.imprint_to(new_human, mob_client)
	for(var/slot in list(WEAR_L_STORE, WEAR_R_STORE, WEAR_IN_L_STORE, WEAR_IN_R_STORE, WEAR_IN_BACK))
		if(new_human.equip_to_slot_if_possible(pda, slot, disable_warning = TRUE))
			return
	new_human.put_in_hands(pda)

GLOBAL_LIST_INIT(pda_roles_by_job, list(
	JOB_SYNTH = "Syn",
	JOB_CO = "CO",
	JOB_XO = "XO",
	JOB_SO = "SO",
	JOB_AUXILIARY_OFFICER = "ASO",
	JOB_SEA = "SEA",
	JOB_CHIEF_POLICE = "CMP",
	JOB_CHIEF_ENGINEER = "CE",
	JOB_CHIEF_REQUISITION = "RO",
	JOB_CMO = "CMO",
	JOB_POLICE = "MP",
	JOB_WARDEN = "Warden",
	JOB_DOCTOR = "Doctor",
	JOB_NURSE = "Nurse",
	JOB_RESEARCHER = "Researcher",
	JOB_MAINT_TECH = "Maint Tech",
	JOB_ORDNANCE_TECH = "Ord Tech",
	JOB_CARGO_TECH = "Cargo Tech",
	JOB_DROPSHIP_PILOT = "DP",
	JOB_CAS_PILOT = "GP",
	JOB_OPERATIONS_PILOT = "OP",
	JOB_DROPSHIP_CREW_CHIEF = "DCC",
	JOB_INTEL = "IO",
	JOB_COMBAT_REPORTER = "CC",
	JOB_CORPORATE_LIAISON = "CL",
))

/// Theme names a PDA can be set to, with the theme each one uses
GLOBAL_LIST_INIT(pda_themes, list(
	PDA_THEME_TERMINAL_NAME = PDA_THEME_TERMINAL,
	PDA_THEME_NTOS_NAME = PDA_THEME_NTOS,
	PDA_THEME_DARK_MODE_NAME = PDA_THEME_DARK_MODE,
	PDA_THEME_LIGHT_MODE_NAME = PDA_THEME_LIGHT_MODE,
	PDA_THEME_RETRO_NAME = PDA_THEME_RETRO,
	PDA_THEME_SYNTH_NAME = PDA_THEME_SYNTH,
	PDA_THEME_CAT_NAME = PDA_THEME_CAT,
	PDA_THEME_SPOOKY_NAME = PDA_THEME_SPOOKY,
))

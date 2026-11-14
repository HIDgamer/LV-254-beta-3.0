/datum/computer_file/program/crew_manifest
	filename = "crew_manifest"
	filedesc = "Crew Manifest"
	extended_desc = "Program for viewing the current crew manifest."
	tgui_id = "NtosCrewManifest"
	program_icon = "clipboard-list"
	program_open_overlay = "crew"

/datum/computer_file/program/crew_manifest/ui_static_data(mob/user)
	var/list/data = list()
	data["departments_with_jobs"] = GLOB.crew_manifest.ui_static_data(user)["departments_with_jobs"]
	return data

/datum/computer_file/program/crew_manifest/ui_data(mob/user)
	var/list/data = list()
	data["manifest"] = GLOB.crew_manifest.ui_data()
	return data

/datum/computer_file/program/crew_manifest/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	return FALSE

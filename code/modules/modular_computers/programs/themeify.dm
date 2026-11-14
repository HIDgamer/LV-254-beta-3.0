/// Lets the owner pick the theme of the computer
/datum/computer_file/program/themeify
	filename = "themeify"
	filedesc = "Themeify"
	extended_desc = "This program allows configuration of your device's theme."
	program_flags = PROGRAM_HEADER
	tgui_id = "NtosThemeConfigure"
	program_icon = "paint-roller"
	program_open_overlay = "generic"

/datum/computer_file/program/themeify/ui_data(mob/user)
	var/list/data = list()
	data["themes"] = list()
	for(var/theme_name in GLOB.pda_themes)
		data["themes"] += list(list("theme_name" = theme_name, "theme_ref" = GLOB.pda_themes[theme_name]))
	return data

/datum/computer_file/program/themeify/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("PRG_change_theme")
			var/theme = GLOB.pda_themes[params["selected_theme"]]
			if(!theme)
				return
			computer.device_theme = theme
			return TRUE

/obj/item/modular_computer
	name = "modular computer"
	desc = "A small portable Weyland-Yutani computer."
	icon = 'icons/obj/items/pda.dmi'
	w_class = SIZE_SMALL
	flags_atom = FPRINT|CONDUCT
	flags_equip_slot = SLOT_WAIST|SLOT_STORE|SLOT_ID
	item_state = "wj_pda"
	item_icons = list(
		WEAR_L_HAND = 'icons/mob/humans/onmob/inhands/equipment/devices_lefthand.dmi',
		WEAR_R_HAND = 'icons/mob/humans/onmob/inhands/equipment/devices_righthand.dmi',
	)
	light_range = 3
	light_power = 1

	var/overlays_icon = 'icons/obj/items/pda_screens.dmi'
	var/icon_state_menu = "menu"
	var/enabled = FALSE
	var/obj/item/card/id/computer_id_slot
	var/saved_identification
	var/saved_job
	var/device_theme = PDA_THEME_TERMINAL
	var/has_light = TRUE
	var/comp_light_color = COLOR_WHITE
	var/list/datum/computer_file/program/stored_files = list()
	var/list/default_programs = list()
	var/list/extra_programs = list()
	var/can_print_notes = FALSE
	var/datum/computer_file/program/active_program
	var/list/datum/computer_file/program/idle_threads = list()

/obj/item/modular_computer/Initialize(mapload)
	. = ..()
	set_light_color(comp_light_color)
	set_light_on(FALSE)
	for(var/program_type in default_programs + extra_programs)
		install_program(new program_type)
	update_icon()

/obj/item/modular_computer/Destroy()
	active_program = null
	idle_threads.Cut()
	QDEL_LIST(stored_files)
	computer_id_slot = null
	return ..()

/obj/item/modular_computer/proc/install_program(datum/computer_file/program/program)
	program.computer = src
	stored_files += program
	program.on_install()

/obj/item/modular_computer/proc/find_program(filename)
	for(var/datum/computer_file/program/program as anything in stored_files)
		if(program.filename == filename)
			return program

/obj/item/modular_computer/proc/get_computer_access()
	return computer_id_slot?.access

/obj/item/modular_computer/GetID()
	return computer_id_slot

/obj/item/modular_computer/GetAccess()
	return computer_id_slot ? computer_id_slot.GetAccess() : ..()

/// Refreshes the wearer's identity when the card in the worn computer changes
/obj/item/modular_computer/proc/update_worn_identity()
	if(!ishuman(loc))
		return
	var/mob/living/carbon/human/wearer = loc
	if(wearer.wear_id != src)
		return
	wearer.sec_hud_set_ID()
	wearer.hud_set_squad()
	wearer.update_inv_wear_id()
	wearer.name = wearer.get_visible_name()

/// Screen overlay for the active program, a waiting notification, or the main menu
/obj/item/modular_computer/proc/get_screen_state()
	if(active_program)
		return active_program.program_open_overlay || icon_state_menu
	for(var/datum/computer_file/program/program as anything in stored_files)
		if(program.alert_pending)
			return "request"
	return icon_state_menu

/obj/item/modular_computer/update_icon()
	overlays.Cut()
	..()
	if(enabled)
		overlays += image(overlays_icon, get_screen_state())

/obj/item/modular_computer/proc/play_ping()
	playsound(src, 'sound/machines/pda_ping.ogg', 25, FALSE)

/obj/item/modular_computer/proc/alert_call(datum/computer_file/program/origin, alerttext)
	if(!origin?.alert_able || origin.alert_silenced || !alerttext)
		return
	if(origin != active_program)
		origin.alert_pending = TRUE
		update_icon()
	play_ping()
	var/mob/holder = ismob(loc) ? loc : null
	if(holder)
		to_chat(holder, SPAN_NOTICE("[icon2html(src, holder)] [alerttext]"))

/obj/item/modular_computer/attack_self(mob/user)
	. = ..()
	if(enabled)
		tgui_interact(user)
	else
		turn_on(user)

/obj/item/modular_computer/Topic(href, href_list)
	. = ..()
	if(.)
		return
	if(!href_list["pda_reply"])
		return
	var/mob/user = usr
	if(!enabled || !istype(user) || (loc != user && loc?.loc != user))
		return
	var/datum/computer_file/program/messenger/messenger = find_program("messenger")
	if(!messenger || !(href_list["pda_reply"] in messenger.saved_chats))
		return
	messenger.leave_chat(messenger.viewing_messages_of, href_list["pda_reply"])
	messenger.viewing_messages_of = href_list["pda_reply"]
	if(active_program != messenger)
		open_program(user, messenger)
	update_open_uis(user)

/obj/item/modular_computer/verb/use_pda_verb()
	set name = "Use PDA"
	set category = "Object"
	set src in usr

	attack_self(usr)

/obj/item/modular_computer/verb/eject_id_verb()
	set name = "Eject ID"
	set category = "Object"
	set src in usr

	if(!remove_id(usr))
		to_chat(usr, SPAN_WARNING("\The [src] has no ID inserted."))

/obj/item/modular_computer/get_examine_text(mob/user)
	. = ..()
	if(computer_id_slot)
		. += SPAN_NOTICE("It has [icon2html(computer_id_slot, user)] [computer_id_slot] inserted.")

/obj/item/modular_computer/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/card/id))
		insert_id(W, user)
		return TRUE
	return ..()

/obj/item/modular_computer/proc/insert_id(obj/item/card/id/inserting_id, mob/user)
	if(computer_id_slot)
		to_chat(user, SPAN_WARNING("\The [src] already has an ID inserted."))
		return FALSE
	if(user && !user.drop_inv_item_to_loc(inserting_id, src))
		return FALSE
	if(!user)
		inserting_id.forceMove(src)
	computer_id_slot = inserting_id
	playsound(src, 'sound/machines/terminal_insert_disc.ogg', 25, TRUE)
	if(user)
		to_chat(user, SPAN_NOTICE("You insert [inserting_id] into [src]."))
	update_worn_identity()
	update_icon()
	update_open_uis()
	return TRUE

/obj/item/modular_computer/proc/remove_id(mob/user)
	if(!computer_id_slot)
		return FALSE
	var/obj/item/card/id/removed_id = computer_id_slot
	computer_id_slot = null
	if(user)
		user.put_in_hands(removed_id)
		to_chat(user, SPAN_NOTICE("You remove [removed_id] from [src]."))
	else
		removed_id.forceMove(get_turf(src))
	update_worn_identity()
	update_icon()
	update_open_uis()
	return TRUE

/obj/item/modular_computer/Exited(atom/movable/AM, direction)
	. = ..()
	if(AM == computer_id_slot)
		computer_id_slot = null
		update_worn_identity()
		update_icon()

/// Copies the inserted ID's name and job onto the computer
/obj/item/modular_computer/proc/imprint_id(name, job_name)
	saved_identification = name || computer_id_slot?.registered_name
	saved_job = job_name || computer_id_slot?.assignment
	for(var/datum/computer_file/program/program as anything in stored_files)
		program.on_imprint()
	update_open_uis()

/obj/item/modular_computer/proc/turn_on(mob/user, open_ui = TRUE)
	if(enabled)
		return FALSE
	enabled = TRUE
	update_icon()
	playsound(src, 'sound/machines/terminal_on.ogg', 25, TRUE)
	if(user)
		to_chat(user, SPAN_NOTICE("You turn on [src]."))
	if(open_ui && user)
		tgui_interact(user)
	return TRUE

/obj/item/modular_computer/proc/shutdown_computer(loud = TRUE)
	for(var/datum/computer_file/program/program as anything in stored_files)
		program.kill_program()
	active_program = null
	idle_threads.Cut()
	enabled = FALSE
	set_light_on(FALSE)
	update_icon()
	SStgui.close_uis(src)
	if(loud)
		playsound(src, 'sound/machines/terminal_off.ogg', 25, TRUE)

/obj/item/modular_computer/proc/toggle_flashlight()
	if(!has_light)
		return FALSE
	set_light_on(!light_on)
	playsound(src, 'sound/handling/click_2.ogg', 25, TRUE)
	update_icon()
	update_open_uis()
	return TRUE

/obj/item/modular_computer/proc/open_program(mob/user, datum/computer_file/program/program)
	if(!istype(program) || !enabled)
		return FALSE
	if(active_program == program)
		return TRUE
	if(!program.on_start(user))
		return FALSE

	idle_threads -= program
	active_program = program
	program.alert_pending = FALSE
	update_icon()
	update_open_uis(user)
	return TRUE

/obj/item/modular_computer/proc/get_header_data()
	var/list/data = list()
	data["PC_device_theme"] = device_theme
	data["PC_stationtime"] = worldtime2text()
	data["PC_stationdate"] = time2text(world.realtime, "DDD, MMM DD")
	data["PC_showexitprogram"] = !!active_program
	data["PC_programheaders"] = list()
	return data

/obj/item/modular_computer/ui_state(mob/user)
	return GLOB.inventory_state

/obj/item/modular_computer/tgui_interact(mob/user, datum/tgui/ui)
	if(!enabled)
		ui?.close()
		return

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		update_open_uis(user)
	else if(active_program?.always_update_ui)
		active_program.tgui_interact(user, ui)

/// Opens the UI for the user, or points every open window at the active program
/obj/item/modular_computer/proc/update_open_uis(mob/user)
	if(!enabled)
		return
	if(user)
		var/datum/tgui/active_ui = SStgui.get_open_ui(user, src)
		if(!active_ui)
			if(active_program)
				active_ui = new(user, src, active_program.tgui_id, active_program.filedesc)
				active_program.tgui_interact(user, active_ui)
			else
				active_ui = new(user, src, "NtosMain", name)
			return active_ui.open()

	for(var/datum/tgui/window as anything in SStgui.open_uis_by_src[REF(src)])
		if(active_program)
			window.interface = active_program.tgui_id
			window.title = active_program.filedesc
			active_program.tgui_interact(window.user, window)
		else
			window.interface = "NtosMain"
			window.title = name
	update_static_data_for_all_viewers()

/obj/item/modular_computer/ui_static_data(mob/user)
	var/list/data = list()
	if(active_program)
		data += active_program.ui_static_data(user)
		return data
	data["show_imprint"] = TRUE
	return data

/obj/item/modular_computer/ui_data(mob/user)
	var/list/data = get_header_data()
	if(active_program)
		data += active_program.ui_data(user)
		return data

	data["has_light"] = has_light
	data["light_on"] = light_on
	data["comp_light_color"] = comp_light_color
	data["login"] = list(
		"IDName" = saved_identification || "Unknown",
		"IDJob" = saved_job || "Unknown",
	)
	data["proposed_login"] = list(
		"IDName" = computer_id_slot?.registered_name,
		"IDJob" = computer_id_slot?.assignment,
	)
	data["removable_media"] = list()
	data["programs"] = list()
	for(var/datum/computer_file/program/program as anything in stored_files)
		data["programs"] += list(list(
			"name" = program.filename,
			"desc" = program.filedesc,
			"header_program" = !!(program.program_flags & PROGRAM_HEADER),
			"running" = !!(program in idle_threads),
			"icon" = program.program_icon,
			"alert" = program.alert_pending,
		))
	return data

/obj/item/modular_computer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = ui.user
	switch(action)
		if("PC_exit")
			active_program?.kill_program(user)
			return TRUE
		if("PC_shutdown")
			shutdown_computer()
			return TRUE
		if("PC_minimize")
			active_program?.background_program(user)
			return TRUE
		if("PC_killprogram")
			var/datum/computer_file/program/killed_program = find_program(params["name"])
			if(!istype(killed_program))
				return
			killed_program.kill_program(user)
			return TRUE
		if("PC_runprogram")
			open_program(user, find_program(params["name"]))
			return TRUE
		if("PC_toggle_light")
			toggle_flashlight()
			return TRUE
		if("PC_Eject_Disk")
			if(params["name"] == "ID" && remove_id(user))
				playsound(src, 'sound/machines/terminal_eject.ogg', 25, TRUE)
				return TRUE
		if("PC_Imprint_ID")
			imprint_id()
			playsound(src, 'sound/machines/terminal_processing.ogg', 15, TRUE)
			return TRUE

	if(active_program)
		return active_program.ui_act(action, params, ui, state)

/obj/item/modular_computer/ui_close(mob/user)
	. = ..()
	active_program?.ui_close(user)

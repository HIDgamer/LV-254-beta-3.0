GLOBAL_LIST_INIT(volume_mixer_categories, list(
	list("id" = VOLUME_SFX, "name" = "Sound Effects"),
	list("id" = VOLUME_VOICE, "name" = "Voices & Emotes"),
	list("id" = VOLUME_WEAPONS, "name" = "Weapons"),
	list("id" = VOLUME_FOOTSTEPS, "name" = "Footsteps"),
	list("id" = VOLUME_AMB, "name" = "Ambience"),
	list("id" = VOLUME_ANNOUNCEMENT, "name" = "Announcements"),
	list("id" = VOLUME_ADM, "name" = "Admin Sounds"),
	list("id" = VOLUME_LOBBY, "name" = "Lobby Music"),
))

/// Per-category volume sliders for the player's sound preferences
/datum/volume_mixer

/datum/volume_mixer/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "VolumeMixer")
		ui.open()

/datum/volume_mixer/ui_state(mob/user)
	return GLOB.always_state

/datum/volume_mixer/ui_static_data(mob/user)
	return list("categories" = GLOB.volume_mixer_categories)

/datum/volume_mixer/ui_data(mob/user)
	var/list/data = list()
	var/list/volumes = list()
	var/list/prefs_volumes = user.client?.prefs?.volume_preferences
	for(var/list/category as anything in GLOB.volume_mixer_categories)
		volumes["[category["id"]]"] = round(prefs_volumes[category["id"]] * 100)
	data["volumes"] = volumes
	return data

/datum/volume_mixer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/client/user_client = ui.user.client
	switch(action)
		if("set_volume")
			var/category = text2num(params["category"])
			var/volume = text2num(params["volume"])
			if(!isnum(category) || !isnum(volume) || category < 1 || category > VOLUME_CATEGORY_COUNT)
				return FALSE
			user_client.set_volume_preference(category, clamp(volume, 0, 100) / 100)
			return TRUE

/client/proc/open_volume_mixer()
	var/static/datum/volume_mixer/mixer = new
	mixer.tgui_interact(mob)

/client/verb/volume_mixer()
	set name = "Volume Mixer"
	set category = "Preferences.Sound"
	set desc = "Adjust the volume of each sound category."
	open_volume_mixer()

/// Stores a volume preference and applies it to any sound currently playing on its channel
/client/proc/set_volume_preference(volume_key, volume)
	prefs.volume_preferences[volume_key] = volume
	prefs.save_preferences()

	switch(volume_key)
		if(VOLUME_AMB)
			soundOutput?.update_ambience(null, null, TRUE)
		if(VOLUME_LOBBY)
			var/sound/lobby_sound = sound()
			lobby_sound.channel = SOUND_CHANNEL_LOBBY
			lobby_sound.volume = 100 * volume
			lobby_sound.status = SOUND_UPDATE
			sound_to(src, lobby_sound)

/datum/preferences/proc/sanitize_volume_preferences()
	var/list/defaults = DEFAULT_VOLUME_PREFERENCES
	var/list/saved = islist(volume_preferences) ? volume_preferences : list()
	var/list/sanitized = list()
	for(var/index in 1 to VOLUME_CATEGORY_COUNT)
		var/value = index <= length(saved) ? saved[index] : defaults[index]
		sanitized += isnum(value) ? clamp(value, 0, 1) : defaults[index]
	volume_preferences = sanitized

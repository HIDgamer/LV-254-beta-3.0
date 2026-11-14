/// What kind of noise a sound file makes, as one of the HAI_NOISE defines
/proc/classify_human_ai_noise(sound_file)
	var/text = lowertext("[sound_file]")
	if(findtext(text, "explo") || findtext(text, "boom") || findtext(text, "blast"))
		return HAI_NOISE_EXPLOSION
	if(findtext(text, "weapons/gun") || findtext(text, "gunshot") || findtext(text, "gun_") || findtext(text, "rifle") || findtext(text, "shotgun"))
		return HAI_NOISE_GUNSHOT
	if(findtext(text, "glass") || findtext(text, "shatter"))
		return HAI_NOISE_GLASS
	if(findtext(text, "door") || findtext(text, "airlock") || findtext(text, "shutter"))
		return HAI_NOISE_DOOR
	if(findtext(text, "alarm") || findtext(text, "siren"))
		return HAI_NOISE_ALARM
	if(findtext(text, "punch") || findtext(text, "slash") || findtext(text, "genhit") || findtext(text, "hit"))
		return HAI_NOISE_MELEE
	return HAI_NOISE_MISC

/**
 * Tells every AI human within earshot about a sound, called from playsound().
 * The emitter is whoever made it when that is known.
 */
/proc/human_ai_noise(turf/source_turf, volume, noise_range, atom/source, sound_file)
	if(!length(GLOB.ai_human_list) || volume < HAI_NOISE_MIN_VOLUME || !source_turf)
		return
	noise_range = min(noise_range, HAI_NOISE_MAX_RANGE)
	var/mob/emitter
	if(ismob(source))
		emitter = source
	else if(isobj(source) && ismob(source.loc))
		emitter = source.loc
	var/kind = classify_human_ai_noise(sound_file)
	if(kind == HAI_NOISE_GUNSHOT && isliving(emitter))
		var/mob/living/shooter = emitter
		if(world.time < shooter.last_ai_gunshot_time + HAI_GUNSHOT_NOISE_REPEAT)
			return
		shooter.last_ai_gunshot_time = world.time
	var/started = TICK_USAGE
	var/emitter_faction = emitter?.faction
	var/loud = kind == HAI_NOISE_GUNSHOT || kind == HAI_NOISE_EXPLOSION || kind == HAI_NOISE_GLASS || kind == HAI_NOISE_ALARM
	for(var/mob/living/carbon/human/listener as anything in SSspatial_grid.ai_humans_in_range(source_turf, noise_range))
		var/datum/human_ai_brain/brain = listener.ai_brain
		if(listener == emitter || !brain || brain.intent == HAI_INTENT_ENGAGE)
			continue
		var/distance = max(abs(listener.x - source_turf.x), abs(listener.y - source_turf.y))
		if(distance > noise_range)
			continue
		if(emitter_faction && listener.faction == emitter_faction)
			if(loud)
				brain.alert_until = max(brain.alert_until, world.time + 3 SECONDS)
			continue
		brain.hear_noise(source_turf, kind, distance, noise_range, emitter)
	SShuman_ai.noise_cost_ms += max(0, TICK_USAGE_TO_MS(started))

/**
 * Tells AI humans near the line of a shot that someone is firing, called as the projectile leaves the barrel.
 * Only bodies within a couple of tiles of the flight path are told, everyone else just hears the noise.
 */
/proc/human_ai_projectile_launched(atom/firer, list/flight_path)
	if(!length(GLOB.ai_human_list) || !ismob(firer) || !length(flight_path))
		return
	var/mob/living/shooter = firer
	var/turf/start = flight_path[1]
	for(var/mob/living/carbon/human/target as anything in SSspatial_grid.ai_humans_in_range(start, HAI_SHOT_NOTICE_RANGE))
		if(target == shooter || !target.ai_brain || target.stat == DEAD || target.faction == shooter.faction)
			continue
		for(var/turf/path_turf as anything in flight_path)
			if(get_dist(path_turf, target) <= HAI_SHOT_NEAR_MISS)
				target.ai_brain.on_shot_at(shooter)
				break

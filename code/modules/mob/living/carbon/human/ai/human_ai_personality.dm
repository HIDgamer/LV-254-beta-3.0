/// Every personality preset by id, built once on first use
GLOBAL_LIST_INIT_TYPED(human_ai_personalities, /datum/human_ai_personality, init_human_ai_personalities())

/proc/init_human_ai_personalities()
	var/list/presets = list()
	for(var/preset_type in subtypesof(/datum/human_ai_personality))
		var/datum/human_ai_personality/preset = new preset_type
		if(!preset.id)
			qdel(preset)
			continue
		presets[preset.id] = preset
	return presets

/proc/get_human_ai_personality(id)
	RETURN_TYPE(/datum/human_ai_personality)
	return GLOB.human_ai_personalities[id] || GLOB.human_ai_personalities["neutral"]

/// A shared set of 0 to 100 trait scores, brains read their behavior weights through it
/datum/human_ai_personality
	/// Unique key, empty leaves the type abstract
	var/id
	var/name
	var/desc
	/// Spawned humans of this preset take their trait scores from here, anything missing is 50
	var/list/traits = list()
	/// Action id to weight multiplier, anything missing is 1
	var/list/action_mults = list()

/datum/human_ai_personality/proc/trait(key)
	var/value = traits[key]
	return isnull(value) ? 50 : value

/datum/human_ai_personality/proc/mult(action_id)
	var/value = action_mults[action_id]
	return isnull(value) ? 1 : value

/// Maps a trait onto a range, 0 gives low and 100 gives high
/datum/human_ai_personality/proc/scaled(key, low, high)
	return low + (high - low) * (trait(key) * 0.01)

/datum/human_ai_personality/proc/mood_band(stress)
	if(stress >= 85)
		return HAI_MOOD_BREAKING
	if(stress >= 60)
		return HAI_MOOD_SHAKEN
	if(stress >= 30)
		return HAI_MOOD_RATTLED
	return HAI_MOOD_STEADY

/datum/human_ai_personality/neutral
	id = "neutral"
	name = "Neutral"
	desc = "No leaning either way."

/// Every action singleton, highest weight first at pick time
GLOBAL_LIST_INIT(human_ai_actions, init_human_ai_actions())

/proc/init_human_ai_actions()
	var/list/actions = list()
	for(var/action_type in subtypesof(/datum/human_ai_action))
		var/datum/human_ai_action/action = new action_type
		if(!action.id)
			qdel(action)
			continue
		actions += action
	return actions

/**
 * One thing a brain can do on a think. Singletons, so all state lives on the brain.
 * Actions must not sleep.
 */
/datum/human_ai_action
	/// Unique key, personalities scale the weight through it. Empty leaves the type abstract
	var/id
	/// Limbs the action occupies for this think
	var/conflicts = NONE
	/// Intents the action may run in, empty means any
	var/list/intents

/// How much the brain wants this right now, 0 or less means not at all
/datum/human_ai_action/proc/get_weight(datum/human_ai_brain/brain)
	return 0

/// Does the work, returns TRUE if it did something
/datum/human_ai_action/proc/trigger(datum/human_ai_brain/brain)
	return FALSE

/datum/human_ai_action/proc/allowed_in(intent)
	return !length(intents) || (intent in intents)

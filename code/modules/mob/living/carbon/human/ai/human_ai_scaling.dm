/// Marine players awake, then aim error, reaction time and aggression bias; a row holds from its player count up to the next row
GLOBAL_LIST_INIT(human_ai_difficulty_table, list(
	list(0, 1.6, 1.4, -0.4),
	list(10, 1.3, 1.2, -0.2),
	list(25, 1.0, 1.0, 0),
	list(45, 0.85, 0.9, 0.2),
	list(70, 0.7, 0.8, 0.3),
))

/// The row of the difficulty table that holds for the player count
/proc/human_ai_difficulty_row(players)
	var/list/found = GLOB.human_ai_difficulty_table[1]
	for(var/list/row as anything in GLOB.human_ai_difficulty_table)
		if(players >= row[1])
			found = row
	return found

/// Sets the difficulty knobs for the number of marine players, nothing changes while the row is the same
/datum/controller/subsystem/human_ai/proc/apply_scaling(players)
	var/list/row = human_ai_difficulty_row(players)
	if(scale_players == row[1])
		return FALSE
	scale_players = row[1]
	aim_error_mult = row[2]
	reaction_mult = row[3]
	aggression_bias = row[4]
	for(var/datum/human_ai_brain/brain as anything in brains)
		brain.apply_posture()
	return TRUE

/**
 * Watches what the human AI costs next to the Xeno Life subsystem and slows the brains that are not in a fight when the two together
 * go over the budget. Zombie AI has no meter of its own and is not counted. Returns the new multiplier.
 */
/datum/controller/subsystem/human_ai/proc/arbitrate()
	var/elapsed = max(world.time - arbiter_time_mark, 1)
	var/human_ms = (total_cost_ms - arbiter_cost_mark) * 10 / elapsed
	arbiter_cost_mark = total_cost_ms
	arbiter_time_mark = world.time
	if(human_ms < 0)
		human_ms = 0
	var/xeno_ms = SSxeno.cost * 10 / max(SSxeno.wait, 1)
	return apply_budget(human_ms, xeno_ms)

/// The multiplier for the measured milliseconds per second of human and other AI work, raised at once and let down slowly
/datum/controller/subsystem/human_ai/proc/apply_budget(human_ms, other_ms)
	var/load = (human_ms + other_ms) / HAI_BUDGET_TOTAL_MS
	arbiter_load = load
	var/wanted = clamp(load, 1, HAI_ARBITER_MAX_SLOWDOWN)
	if(wanted > arbiter_multiplier)
		arbiter_multiplier = wanted
	else
		arbiter_multiplier = max(1, arbiter_multiplier - 0.25, wanted)
	return arbiter_multiplier

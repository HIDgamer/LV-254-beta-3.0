/// A named contribution to a mob's movement delay, summed per stage
/datum/movespeed_modifier
	var/id
	var/stage = MOVESPEED_STAGE_ADD
	var/amount = 0

/datum/movespeed_modifier/New(id, stage, amount)
	src.id = id
	src.stage = stage
	src.amount = amount

/// Adds or updates the modifier with this id, an amount with no effect removes it
/mob/proc/set_movespeed_modifier(id, stage, amount, update = TRUE)
	var/identity = stage == MOVESPEED_STAGE_MULT ? 1 : 0
	var/datum/movespeed_modifier/existing = LAZYACCESS(movespeed_modification, id)
	if(amount == identity)
		if(!existing)
			return
		LAZYREMOVE(movespeed_modification, id)
		qdel(existing)
	else if(existing)
		if(existing.amount == amount && existing.stage == stage)
			return
		existing.amount = amount
		existing.stage = stage
	else
		LAZYSET(movespeed_modification, id, new /datum/movespeed_modifier(id, stage, amount))
	movespeed_dirty = TRUE
	if(update)
		update_movespeed()

/mob/proc/remove_movespeed_modifier(id, update = TRUE)
	var/datum/movespeed_modifier/existing = LAZYACCESS(movespeed_modification, id)
	if(!existing)
		return FALSE
	LAZYREMOVE(movespeed_modification, id)
	qdel(existing)
	movespeed_dirty = TRUE
	if(update)
		update_movespeed()
	return TRUE

/mob/proc/has_movespeed_modifier(id)
	return !!LAZYACCESS(movespeed_modification, id)

/mob/proc/get_movespeed_modifiers()
	return movespeed_modification

/// Recalculates the per stage totals from the current modifiers
/mob/proc/update_movespeed()
	movespeed_dirty = FALSE
	var/list/totals = list(0, 0, 0, 1, 0)
	for(var/id in movespeed_modification)
		var/datum/movespeed_modifier/modifier = movespeed_modification[id]
		if(modifier.stage == MOVESPEED_STAGE_MULT)
			totals[modifier.stage] *= modifier.amount
		else
			totals[modifier.stage] += modifier.amount
	movespeed_totals = totals

/// The summed amount of every modifier in the stage, a product for the multiplicative stage
/mob/proc/movespeed_total(stage)
	if(!movespeed_totals)
		return stage == MOVESPEED_STAGE_MULT ? 1 : 0
	return movespeed_totals[stage]

/// Brings state derived modifiers up to date, then recalculates the totals
/mob/proc/refresh_movespeed_modifiers()
	refresh_derived_movespeed()
	if(movespeed_dirty)
		update_movespeed()

/// Override to set modifiers computed from the mob's current state, use update = FALSE when setting them
/mob/proc/refresh_derived_movespeed()
	return

/// Adds stress, scaled by how composed the brain is
/datum/human_ai_brain/proc/add_stress(amount)
	if(amount <= 0)
		return
	stress = min(100, stress + amount * personality.scaled("composure", 1.4, 0.6))

/// Zealots never give way and guardians hold while their leader is near
/datum/human_ai_brain/proc/resists_breaking()
	if(personality.trait("courage") >= 95)
		return TRUE
	if(personality.trait("loyalty") >= 95 && squad && squad.member_valid(squad.leader))
		return get_dist(body, squad.leader.body) <= 7
	return FALSE

/datum/human_ai_brain/proc/visible_hostiles()
	var/count = 0
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.visible && contact.identified())
			count++
	return count

/// Moves stress with the situation, called from the think every few ticks
/datum/human_ai_brain/proc/update_mood()
	if(world.time < next_mood_time)
		return
	var/seconds = clamp((world.time - last_mood_time) * 0.1, 0.1, 3)
	last_mood_time = world.time
	next_mood_time = world.time + HAI_MOOD_INTERVAL
	var/gain = 0
	var/relief = 2.5
	if(intent == HAI_INTENT_ENGAGE)
		relief = 0
		var/mob/living/target = get_target()
		if(target && in_good_cover(get_turf(target)))
			relief += 0.7
		var/obj/item/weapon/gun/gun = peek_gun()
		if(gun && gun_rounds(gun) <= 3 && !has_spare_ammo(gun))
			gain += 0.5
		if(visible_hostiles() > 2 + (squad ? length(squad.members) - 1 : 0))
			gain += 0.5
	if(squad)
		if(!squad.member_valid(squad.leader))
			gain += 0.3
		if(squad.friends_near(src, 5) >= 2)
			relief += 0.5
	relief *= personality.scaled("composure", 0.6, 1.5)
	if(body.health < body.maxHealth * 0.5)
		express(HAI_EXPR_MEDIC)
	if(intent == HAI_INTENT_ENGAGE && prob(25))
		express(HAI_EXPR_BATTLE_CRY)
	stress = clamp(stress + (gain - relief) * seconds, 0, 100)

/datum/human_ai_brain/proc/choose_break()
	var/courage = personality.trait("courage")
	var/aggression = personality.trait("aggression")
	var/caution = personality.trait("caution")
	var/mob/living/target = get_target()
	var/list/weights = list()
	weights[HAI_BREAK_FLEE] = (100 - courage) * 0.6 + caution * 0.3
	weights[HAI_BREAK_FREEZE] = personality.trait("paranoia") * 0.4 + (100 - personality.trait("composure")) * 0.3
	weights[HAI_BREAK_SURRENDER] = (ishuman(target) && courage < 90) ? (100 - courage) * 0.3 + (100 - aggression) * 0.2 : 0
	weights[HAI_BREAK_BERSERK] = aggression * 0.6 + (100 - caution) * 0.2 + courage * 0.2
	weights[HAI_BREAK_HIDE] = (100 - aggression) * 0.3 + caution * 0.4
	for(var/kind in weights)
		weights[kind] = max(0, round(weights[kind]))
	return pick_weight(weights)

/// Gives way when stress hits the top band, and recovers when the spell runs out
/datum/human_ai_brain/proc/check_break()
	if(berserk_until && world.time >= berserk_until)
		berserk_until = 0
	if(surrendered && world.time >= surrender_until)
		end_surrender("time")
	if(broken_kind)
		if(world.time >= broken_until)
			end_break()
		return
	if(personality.mood_band(stress) < HAI_MOOD_BREAKING)
		return
	if(resists_breaking())
		stress = min(stress, 80)
		return
	begin_break(choose_break())

/datum/human_ai_brain/proc/begin_break(kind)
	broken_kind = kind
	break_count++
	broken_until = world.time + rand(HAI_BREAK_MIN_TIME, HAI_BREAK_MAX_TIME)
	cancel_order("broke")
	cancel_reload("broke")
	clear_cover_goal()
	log_decision("broke: [kind]")
	announce_break(kind)
	switch(kind)
		if(HAI_BREAK_SURRENDER)
			begin_surrender()
		if(HAI_BREAK_BERSERK)
			berserk_until = broken_until

/datum/human_ai_brain/proc/end_break()
	broken_kind = HAI_BREAK_NONE
	stress = min(stress, HAI_BREAK_RECOVERY_STRESS)
	log_decision("recovered")

/datum/human_ai_brain/proc/begin_surrender()
	surrendered = TRUE
	surrender_until = world.time + HAI_SURRENDER_TIME
	body.drop_held_items()
	body.emote("raise")
	set_target(null)

/datum/human_ai_brain/proc/end_surrender(reason)
	if(!surrendered)
		return
	surrendered = FALSE
	surrender_until = 0
	log_decision("stopped surrendering ([reason])")

/// The place the danger comes from, null when the brain knows of none
/datum/human_ai_brain/proc/threat_turf()
	var/mob/living/target = get_target()
	if(target)
		return get_turf(target)
	var/turf/latest
	var/latest_time = -1
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.last_turf && contact.last_time > latest_time)
			latest = contact.last_turf
			latest_time = contact.last_time
	return latest

/// Runs from the threat while broken, or for a wounded brain that decided to pull out
/datum/human_ai_action/flee
	id = "flee"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_BROKEN)

/datum/human_ai_action/flee/get_weight(datum/human_ai_brain/brain)
	return (brain.broken_kind == HAI_BREAK_FLEE && !brain.surrendered) ? 110 : 0

/datum/human_ai_action/flee/trigger(datum/human_ai_brain/brain)
	var/turf/threat = brain.threat_turf()
	if(!threat)
		return FALSE
	if(!brain.flee_goal || world.time >= brain.next_flee_time)
		brain.next_flee_time = world.time + 30
		brain.flee_goal = brain.retreat_turf(threat, 12)
	if(!brain.flee_goal)
		return FALSE
	if(brain.move_to(brain.flee_goal, 1, TRUE))
		return TRUE
	brain.flee_goal = null
	return FALSE

/datum/human_ai_action/hide
	id = "hide"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_BROKEN)

/datum/human_ai_action/hide/get_weight(datum/human_ai_brain/brain)
	return (brain.broken_kind == HAI_BREAK_HIDE && !brain.surrendered) ? 108 : 0

/datum/human_ai_action/hide/trigger(datum/human_ai_brain/brain)
	var/turf/threat = brain.threat_turf()
	if(!threat)
		return FALSE
	if(brain.in_good_cover(threat))
		return FALSE
	var/turf/goal = brain.cover_goal(threat, TRUE) || brain.retreat_turf(threat, 6)
	if(!goal)
		return FALSE
	return brain.move_to(goal, 0, TRUE)

/datum/human_ai_brain/proc/retreat_health_fraction()
	return 0.05 + (100 - personality.trait("courage")) * 0.0035 + personality.trait("caution") * 0.002

/// A wounded brain with an enemy near pulls out unless it is too bold to
/datum/human_ai_brain/proc/wants_retreat()
	if(personality.trait("courage") >= 95 || current_order?.hard || broken_kind)
		return FALSE
	var/mob/living/target = get_target()
	if(!target || world.time > target_seen_time + 40 || get_dist(body, target) > 12)
		return FALSE
	return body.health < body.maxHealth * retreat_health_fraction()

/datum/human_ai_action/retreat
	id = "retreat"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/retreat/get_weight(datum/human_ai_brain/brain)
	return brain.wants_retreat() ? 85 : 0

/datum/human_ai_action/retreat/trigger(datum/human_ai_brain/brain)
	var/turf/threat = brain.threat_turf()
	if(!threat)
		return FALSE
	if(!brain.flee_goal || world.time >= brain.next_flee_time)
		brain.next_flee_time = world.time + 30
		brain.flee_goal = brain.retreat_turf(threat, 10)
	if(!brain.flee_goal)
		return FALSE
	if(brain.move_to(brain.flee_goal, 1, TRUE))
		brain.retreats++
		return TRUE
	brain.flee_goal = null
	return FALSE

/// Swaps in a personality, with every trait nudged by up to the jitter and then set to the given values
/datum/human_ai_brain/proc/set_personality(personality_id, jitter = 0, list/overrides)
	var/datum/human_ai_personality/template = get_human_ai_personality(personality_id)
	base_personality = null
	if(!jitter && !length(overrides))
		personality = template
	else
		personality = template.customised(jitter, overrides)
	apply_posture()

/// Leans the personality toward aggression or caution by the brain's posture plus the global aggression bias, restoring the base personality at zero
/datum/human_ai_brain/proc/apply_posture()
	var/shift = round((posture + SShuman_ai.aggression_bias) * HAI_POSTURE_SHIFT)
	if(!shift)
		if(base_personality)
			personality = base_personality
			base_personality = null
		return
	if(!base_personality)
		base_personality = personality
	personality = base_personality.customised(0, list("aggression" = base_personality.trait("aggression") + shift, "caution" = base_personality.trait("caution") - shift))

/datum/human_ai_personality/proc/customised(jitter, list/overrides)
	var/datum/human_ai_personality/copy = new
	copy.id = id
	copy.name = name
	copy.desc = desc
	copy.action_mults = action_mults
	for(var/key in GLOB.human_ai_trait_keys)
		var/value = trait(key)
		if(jitter)
			value += rand(-jitter, jitter)
		if(!isnull(overrides?[key]))
			value = overrides[key]
		copy.traits[key] = clamp(round(value), 0, 100)
	return copy

GLOBAL_LIST_INIT(human_ai_trait_keys, list("aggression", "caution", "discipline", "courage", "paranoia", "sociability", "alertness", "mercy", "composure", "initiative", "loyalty", "chattiness"))

/// A body going down shakes the AI humans of its side that are near
/datum/human_ai_brain/proc/scare_allies()
	var/turf/here = get_turf(body)
	if(!here)
		return
	for(var/datum/human_ai_brain/other as anything in SShuman_ai.brains)
		if(other == src || other.stopped || QDELETED(other.body) || other.body.faction != body.faction)
			continue
		if(other.body.z == here.z && get_dist(other.body, here) <= HAI_ALLY_DOWN_RANGE)
			other.add_stress(HAI_ALLY_DOWN_STRESS)
			other.express(HAI_EXPR_MAN_DOWN)

/// Tiles a brain sees, snipers see further through the scope
/datum/human_ai_brain/proc/sight_range()
	return (role?.id == "sniper") ? HAI_SNIPER_RANGE : HAI_SIGHT_RANGE

/// Whether the turf is one the sniper or gunner was driven out of recently
/datum/human_ai_brain/proc/nest_avoided(turf/spot)
	for(var/turf/old as anything in avoid_nests)
		if(avoid_nests[old] <= world.time)
			avoid_nests -= old
		else if(get_dist(old, spot) <= 2)
			return TRUE
	return FALSE

/// A sniper or gunner that keeps getting shot at where it sits picks a new spot
/datum/human_ai_action/displace_nest
	id = "displace_nest"
	conflicts = HAI_LIMB_LEGS
	intents = list(HAI_INTENT_ENGAGE)

/datum/human_ai_action/displace_nest/get_weight(datum/human_ai_brain/brain)
	if(!brain.role?.nests)
		return 0
	if(brain.displace_goal)
		return 88
	return (brain.nest_hits >= HAI_NEST_HITS && brain.get_target()) ? 88 : 0

/datum/human_ai_action/displace_nest/trigger(datum/human_ai_brain/brain)
	if(!brain.displace_goal)
		var/turf/threat = brain.threat_turf()
		brain.nest_hits = 0
		if(!threat)
			return FALSE
		brain.avoid_nests[get_turf(brain.body)] = world.time + HAI_NEST_AVOID_TIME
		brain.clear_cover_goal()
		brain.displace_goal = brain.find_cover(threat, FALSE, TRUE)
		if(!brain.displace_goal)
			return FALSE
		brain.nest_moves++
		brain.log_decision("leaving the nest for [brain.displace_goal.x],[brain.displace_goal.y]")
	if(brain.move_to(brain.displace_goal, 0, TRUE))
		return TRUE
	brain.displace_goal = null
	return FALSE

/// The last place an enemy was seen that a gunner can still lay fire on, null when there is none
/datum/human_ai_brain/proc/suppress_turf()
	var/turf/best
	var/best_time = -1
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		if(contact.visible || !contact.identified() || !contact.last_turf || world.time > contact.last_time + HAI_SUPPRESS_MEMORY)
			continue
		if(contact.last_time > best_time)
			best_time = contact.last_time
			best = contact.last_turf
	return best

/// A machinegunner keeps the head of an enemy that ducked out of sight down
/datum/human_ai_action/suppressive_fire
	id = "suppressive_fire"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_ENGAGE, HAI_INTENT_INVESTIGATE, HAI_INTENT_ALERT)

/datum/human_ai_action/suppressive_fire/get_weight(datum/human_ai_brain/brain)
	if(brain.role?.id != "machinegunner" || brain.roe == HAI_ROE_WEAPONS_HOLD || brain.reload_phase != HAI_RELOAD_NONE)
		return 0
	var/obj/item/weapon/gun/gun = brain.peek_gun()
	if(!gun || !get_human_ai_gun_appraisal(gun).suppressive || world.time < brain.volley_pause_until)
		return 0
	var/turf/spot = brain.suppress_turf()
	if(!spot || !brain.gun_can_shoot_now(gun) || !brain.safe_to_fire(gun, spot))
		return 0
	return 50

/datum/human_ai_action/suppressive_fire/trigger(datum/human_ai_brain/brain)
	var/turf/spot = brain.suppress_turf()
	var/obj/item/weapon/gun/gun = brain.get_gun()
	if(!spot || !gun)
		return FALSE
	if(brain.shoot(gun, spot))
		brain.suppressive_shots++
		return TRUE
	return FALSE

/// A grenadier saves launcher rounds for groups and big targets
/datum/human_ai_brain/proc/launcher_worthwhile(mob/living/target)
	if(role?.id != "grenadier")
		return TRUE
	if(isxeno(target))
		var/mob/living/carbon/xenomorph/xeno = target
		if(xeno.tier >= 2)
			return TRUE
	var/neighbors = 0
	for(var/key in contacts)
		var/datum/ai_contact/contact = contacts[key]
		var/mob/living/other = contact.get_subject()
		if(other && other != target && contact.visible && contact.identified() && get_dist(other, target) <= 3)
			neighbors++
	return neighbors >= 1

/// The leader talks wavering squadmates down and eases their stress
/datum/human_ai_squad/proc/rally_members()
	if(!member_valid(leader) || leader.broken_kind)
		return
	for(var/datum/human_ai_brain/brain as anything in members)
		if(brain == leader || !member_valid(brain) || world.time < brain.next_rally_time)
			continue
		if(!brain.broken_kind && brain.stress < 70)
			continue
		if(get_dist(brain.body, leader.body) > HAI_RALLY_RANGE)
			continue
		brain.next_rally_time = world.time + HAI_RALLY_COOLDOWN
		leader.express(HAI_EXPR_RALLY)
		if(!prob((0.4 + leader.personality.trait("discipline") * 0.004 + brain.personality.trait("loyalty") * 0.003) * 100))
			continue
		brain.stress = max(0, brain.stress - HAI_RALLY_RELIEF)
		if(brain.broken_kind && brain.broken_kind != HAI_BREAK_SURRENDER)
			brain.end_break()
		rallies++

/// Column in tight places, line while holding, wedge in the open
/datum/human_ai_squad/proc/choose_formation(list/engaged)
	if(formation_locked || !member_valid(leader))
		return
	var/wanted = HAI_FORM_WEDGE
	if(length(engaged))
		wanted = HAI_FORM_LINE
	else
		var/open_sides = 0
		for(var/direction in GLOB.alldirs)
			var/turf/side = get_step(leader.body, direction)
			if(side && !side.density)
				open_sides++
		if(open_sides <= 4)
			wanted = HAI_FORM_COLUMN
	if(wanted != formation)
		formation = wanted
		formation_changes++

/datum/human_ai_squad/proc/set_formation(new_formation)
	formation = new_formation
	formation_locked = TRUE

/// Faction groups that stand together, factions in one group are friendly with each other
GLOBAL_LIST_INIT(human_ai_sides, list(
	"uscm" = list(FACTION_MARINE, FACTION_MARSHAL, FACTION_TWE, FACTION_NSPA),
	"upp" = list(FACTION_UPP, FACTION_PAP),
	"clf" = list(FACTION_CLF),
	"wy" = list(FACTION_PMC, FACTION_WY, FACTION_HYPERDYNE),
	"deathsquad" = list(FACTION_WY_DEATHSQUAD),
	"pirate" = list(FACTION_PIRATE),
))

/// Pairs of sides that shoot at each other
GLOBAL_LIST_INIT(human_ai_hostile_sides, list(
	list("uscm", "upp"),
	list("uscm", "clf"),
	list("upp", "clf"),
	list("upp", "wy"),
	list("clf", "wy"),
	list("deathsquad", "uscm"),
	list("deathsquad", "upp"),
	list("deathsquad", "clf"),
	list("pirate", "uscm"),
	list("pirate", "upp"),
))

/// Faction to the faction to how the first regards the second, only pairs that are not neutral are stored
GLOBAL_LIST_INIT(human_ai_relations, init_human_ai_relations())

/// Rules of engagement a brain starts with by faction, anything missing is weapons free
GLOBAL_LIST_INIT(human_ai_faction_roe, list(
	FACTION_MARSHAL = HAI_ROE_WEAPONS_TIGHT,
	FACTION_NSPA = HAI_ROE_WEAPONS_TIGHT,
	FACTION_PAP = HAI_ROE_WEAPONS_TIGHT,
	FACTION_COLONIST = HAI_ROE_WEAPONS_HOLD,
	FACTION_SURVIVOR = HAI_ROE_WEAPONS_HOLD,
	FACTION_NEUTRAL = HAI_ROE_WEAPONS_HOLD,
))

/proc/init_human_ai_relations()
	var/list/relations = list()
	for(var/side in GLOB.human_ai_sides)
		var/list/members = GLOB.human_ai_sides[side]
		for(var/faction in members)
			for(var/other in members)
				if(faction != other)
					set_human_ai_relation(relations, faction, other, HAI_REL_FRIENDLY)
	for(var/civilian_faction in list(FACTION_COLONIST, FACTION_SURVIVOR))
		for(var/protector in GLOB.human_ai_sides["uscm"])
			set_human_ai_relation(relations, civilian_faction, protector, HAI_REL_FRIENDLY)
	for(var/list/pair in GLOB.human_ai_hostile_sides)
		for(var/faction in GLOB.human_ai_sides[pair[1]])
			for(var/other in GLOB.human_ai_sides[pair[2]])
				set_human_ai_relation(relations, faction, other, HAI_REL_HOSTILE)
				set_human_ai_relation(relations, other, faction, HAI_REL_HOSTILE)
	return relations

/proc/set_human_ai_relation(list/relations, faction, other, relation)
	var/list/known = relations[faction]
	if(!known)
		known = list()
		relations[faction] = known
	if(relation == HAI_REL_NEUTRAL)
		known -= other
	else
		known[other] = relation

/// How the first faction regards the second
/proc/human_ai_faction_relation(faction, other)
	if(faction == other)
		return HAI_REL_FRIENDLY
	var/list/known = GLOB.human_ai_relations[faction]
	return known?[other] || HAI_REL_NEUTRAL

/proc/human_ai_default_roe(faction)
	return GLOB.human_ai_faction_roe[faction] || HAI_ROE_WEAPONS_FREE

/// What the brain has noticed about someone it does not fight yet
/datum/ai_watch
	var/datum/weakref/subject_ref
	var/level = HAI_DISP_WARY
	var/first_time = 0
	var/last_time = 0
	var/state = HAI_WATCH_OBSERVE
	var/state_since = 0

/datum/ai_watch/Destroy()
	subject_ref = null
	return ..()

/// True when the human holds a gun and has it turned toward the brain's body or is close
/datum/human_ai_brain/proc/threatened_by(mob/living/carbon/human/other)
	if(!istype(other.get_active_hand(), /obj/item/weapon/gun))
		return FALSE
	var/distance = get_dist(other, body)
	if(distance > 7)
		return FALSE
	if(distance <= 2)
		return TRUE
	var/difference = abs(dir2angle(other.dir) - dir2angle(get_dir(other, body)))
	return min(difference, 360 - difference) <= 50

/// Remembers a human who is not an enemy yet but could be, the nearest few
/datum/human_ai_brain/proc/note_watch(mob/living/carbon/human/other, level)
	var/key = REF(other)
	var/datum/ai_watch/watch = watching[key]
	if(!watch)
		if(length(watching) >= HAI_MAX_WATCHED)
			return
		watch = new
		watch.subject_ref = WEAKREF(other)
		watch.first_time = world.time
		watch.state_since = world.time
		watching[key] = watch
	watch.level = level
	watch.last_time = world.time

/datum/human_ai_brain/proc/drop_watch(key)
	var/datum/ai_watch/watch = watching[key]
	if(!watch)
		return
	var/mob/living/subject = watch.subject_ref?.resolve()
	if(watch.state >= HAI_WATCH_CHALLENGE && subject)
		body.lower_aim()
	watching -= key
	qdel(watch)

/// Forgets watched humans that are gone, dead or have not been seen for a while
/datum/human_ai_brain/proc/prune_watch()
	for(var/key in greeted)
		if(world.time > greeted[key] + HAI_GREET_MEMORY)
			greeted -= key
	for(var/key in watching)
		var/datum/ai_watch/watch = watching[key]
		var/mob/living/subject = watch.subject_ref?.resolve()
		if(!subject || QDELETED(subject) || subject.stat == DEAD || world.time > watch.last_time + HAI_WATCH_MEMORY)
			drop_watch(key)

/// Seconds worth of deciseconds the brain spends on each stage of the ladder before it escalates
/datum/human_ai_brain/proc/challenge_time()
	return round((6 + personality.trait("sociability") * 0.1 + personality.trait("mercy") * 0.08) * 10)

/// Bold and merciless types open fire without a word
/datum/human_ai_brain/proc/skips_ladder()
	return personality.trait("aggression") >= 80 && personality.trait("mercy") <= 20

/datum/human_ai_brain/proc/is_overridden_hostile(mob/living/other)
	var/until = disposition_override[REF(other)]
	if(!until)
		return FALSE
	if(world.time >= until)
		disposition_override -= REF(other)
		return FALSE
	return TRUE

/// Turns a watched human into an enemy for a while
/datum/human_ai_brain/proc/escalate_watch(datum/ai_watch/watch, mob/living/subject, reason)
	disposition_override[REF(subject)] = world.time + HAI_ESCALATION_MEMORY
	watch.state = HAI_WATCH_HOSTILE
	watch.state_since = world.time
	body.lower_aim()
	escalations++
	log_decision("[subject] is hostile ([reason])")
	express(HAI_EXPR_HOSTILE)

/// The nearest watched human that is still worth attention
/datum/human_ai_brain/proc/nearest_watch()
	var/datum/ai_watch/best
	var/best_distance = INFINITY
	for(var/key in watching)
		var/datum/ai_watch/watch = watching[key]
		if(watch.state == HAI_WATCH_HOSTILE)
			continue
		var/mob/living/subject = watch.subject_ref?.resolve()
		if(!subject)
			continue
		var/distance = get_dist(body, subject)
		if(distance < best_distance)
			best_distance = distance
			best = watch
	return best

/// One step of the ladder of force with the nearest human being watched: observe, challenge, warn, then escalate
/datum/human_ai_brain/proc/watch_step()
	var/datum/ai_watch/watch = nearest_watch()
	if(!watch)
		return FALSE
	var/mob/living/carbon/human/subject = watch.subject_ref.resolve()
	if(!istype(subject))
		return FALSE
	body.face_atom(subject)
	var/distance = get_dist(body, subject)
	var/armed = istype(subject.get_active_hand(), /obj/item/weapon/gun)
	var/threat = armed && threatened_by(subject)
	if(subject.ai_brain?.surrendered || !armed)
		if(watch.state != HAI_WATCH_OBSERVE)
			watch.state = HAI_WATCH_OBSERVE
			watch.state_since = world.time
			body.lower_aim()
		return TRUE
	switch(watch.state)
		if(HAI_WATCH_OBSERVE)
			if(roe == HAI_ROE_WEAPONS_HOLD)
				return TRUE
			if(!threat || (watch.level < HAI_DISP_SUSPECT && distance > HAI_CHALLENGE_RANGE))
				return TRUE
			if(skips_ladder())
				escalate_watch(watch, subject, "no challenge")
				return TRUE
			watch.state = HAI_WATCH_CHALLENGE
			watch.state_since = world.time
			challenges++
			if(get_active_gun())
				body.gunpoint_triggers = (personality.trait("mercy") >= 60) ? GUNPOINT_TRIGGER_ITEMS : (GUNPOINT_TRIGGER_MOVE | GUNPOINT_TRIGGER_ITEMS)
				body.hold_up(subject)
			log_decision("challenging [subject]")
			express(HAI_EXPR_CHALLENGE)
		if(HAI_WATCH_CHALLENGE)
			if(!threat)
				watch.state = HAI_WATCH_OBSERVE
				watch.state_since = world.time
				body.lower_aim()
			else if(world.time >= watch.state_since + challenge_time() * 0.5)
				watch.state = HAI_WATCH_WARN
				watch.state_since = world.time
				warnings++
				log_decision("warning [subject]")
				express(HAI_EXPR_WARN)
		if(HAI_WATCH_WARN)
			if(!threat)
				watch.state = HAI_WATCH_OBSERVE
				watch.state_since = world.time
				body.lower_aim()
			else if(world.time >= watch.state_since + challenge_time() * 0.5 || distance <= 1)
				if(roe == HAI_ROE_NONLETHAL_ONLY)
					return TRUE
				escalate_watch(watch, subject, "ignored the warning")
	return TRUE

/datum/human_ai_brain/proc/get_active_gun()
	var/obj/item/weapon/gun/gun = body.get_active_hand()
	return istype(gun) ? gun : null

/// Keeps an eye on a human who might be a danger and runs the ladder of force on them
/datum/human_ai_action/watch_human
	id = "watch_human"
	conflicts = HAI_LIMB_HANDS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED)

/datum/human_ai_action/watch_human/get_weight(datum/human_ai_brain/brain)
	return length(brain.watching) ? 55 : 0

/datum/human_ai_action/watch_human/trigger(datum/human_ai_brain/brain)
	return brain.watch_step()

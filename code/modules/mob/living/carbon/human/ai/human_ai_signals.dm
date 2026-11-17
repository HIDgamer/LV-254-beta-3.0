/**
 * Hand signals. The follow me and hold position emotes are two of the spoken commands made without a word, and everybody can make them. A unit that sees one
 * heeds it as far as the one who made it is respected, so a signal from a colonel is taken up by nearly everyone and one from a private by few. The ones who
 * give orders through the NPC command panel are never rolled for, those are commands and are always obeyed, which is how the factions without ranks of their own
 * keep a say too: their rank and file is heeded at a flat chance and their leaders a bit more.
 */

/**
 * How much the player is respected by the AI humans, 0 to 1. Command staff count in full, officers almost, enlisted men by their rank where the faction has a
 * ladder of them, and whoever has no proper rank, civilians, mercenaries, gangs and the like, at a flat chance. Anybody whose job leads a group is heeded
 * at least as a leader is, whatever their papers say.
 */
/proc/human_ai_authority(mob/living/carbon/human/commander)
	if(!istype(commander))
		return 0
	if(human_ai_command_job(human_ai_job_of(commander)))
		return 1
	var/authority = HAI_SIGNAL_UNRANKED
	var/obj/item/card/id/card = commander.get_idcard()
	var/datum/paygrade/grade = card ? GLOB.paygrades[card.paygrade] : null
	// A paygrade that belongs to no army is not a rank
	if(grade?.default_faction)
		if(grade.officer_grade >= GRADE_FLAG)
			authority = 1
		else if(grade.officer_grade >= GRADE_OFFICER)
			authority = HAI_SIGNAL_OFFICER
		else
			authority = clamp(0.3 + grade.ranking * 0.05, 0.3, 0.85)
	if(human_ai_is_leader_job(commander.job))
		authority = max(authority, HAI_SIGNAL_LEADER)
	return authority

/**
 * A signal the body can see being made: a unit that is friendly to the one who makes it, within sight and reach of it, takes it as the spoken command of the same
 * name, only it goes through the roll that a signal does. True when the order was taken up.
 */
/datum/human_ai_brain/proc/see_signal(mob/living/carbon/human/commander, command)
	if(stopped || QDELETED(body) || body.stat != CONSCIOUS || is_civilian() || surrendered || broken_kind)
		return FALSE
	if(commander.ai_brain || commander.stat != CONSCIOUS || commander.handcuffed || commander.z != body.z || get_dist(body, commander) > HAI_VOICE_RANGE)
		return FALSE
	if(get_disposition(commander) > HAI_DISP_FRIEND || !(commander in view(HAI_VOICE_RANGE, body)))
		return FALSE
	var/speaker_key = REF(commander)
	if(world.time < voice_heard[speaker_key] + HAI_VOICE_GAP)
		return FALSE
	if(length(voice_heard) >= 6)
		voice_heard.Cut(1, 2)
	voice_heard[speaker_key] = world.time
	return obey_voice(command, commander, HAI_DELIVERY_SIGNAL)

/// Makes the signal for everyone who can see it, returns how many units took it up
/proc/human_ai_signal(mob/living/carbon/human/commander, command)
	if(!istype(commander) || commander.ai_brain || commander.stat != CONSCIOUS || commander.handcuffed)
		return 0
	var/answered = 0
	for(var/mob/living/carbon/human/candidate in view(HAI_VOICE_RANGE, commander))
		if(answered >= HAI_SIGNAL_ANSWERS)
			break
		if(candidate == commander || !candidate.ai_brain)
			continue
		if(candidate.ai_brain.see_signal(commander, command))
			answered++
	return answered

/// Waves the people near to follow
/datum/emote/living/carbon/human/follow_me
	key = "followme"
	key_third_person = "signals to follow"
	name = "Follow me"
	message = "signals everyone nearby to follow."
	hands_use_check = TRUE

/datum/emote/living/carbon/human/follow_me/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	if(. && intentional && ishuman(user))
		human_ai_signal(user, "follow")

/// Holds up a fist for the people near to stay where they are
/datum/emote/living/carbon/human/hold_position
	key = "holdposition"
	key_third_person = "signals to hold position"
	name = "Hold position"
	message = "signals everyone nearby to hold position."
	hands_use_check = TRUE

/datum/emote/living/carbon/human/hold_position/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	if(. && intentional && ishuman(user))
		human_ai_signal(user, "hold")

/// Admin switches: whether the AI may rig doors at all and whether lethal grenades may be used for it
GLOBAL_VAR_INIT(ai_traps_enabled, TRUE)
GLOBAL_VAR_INIT(ai_lethal_traps, FALSE)

/// Every door that has a trap rigged to it
GLOBAL_LIST_EMPTY(human_ai_door_traps)

/// A grenade wired to a door, it goes off the first time someone who is not on the owner's side opens the door
/datum/component/door_trap
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/obj/item/explosive/grenade/grenade
	var/owner_faction

/datum/component/door_trap/Initialize(obj/item/explosive/grenade/rigged, faction)
	if(!istype(parent, /obj/structure/machinery/door) || !istype(rigged))
		return COMPONENT_INCOMPATIBLE
	grenade = rigged
	owner_faction = faction
	grenade.forceMove(parent)
	RegisterSignal(parent, COMSIG_DOOR_OPENED, PROC_REF(on_open))
	GLOB.human_ai_door_traps += parent
	var/obj/structure/machinery/door/rigged_door = parent
	rigged_door.sync_pathfinding()

/datum/component/door_trap/Destroy(force)
	GLOB.human_ai_door_traps -= parent
	if(parent)
		UnregisterSignal(parent, COMSIG_DOOR_OPENED)
		var/obj/structure/machinery/door/old_door = parent
		INVOKE_ASYNC(old_door, TYPE_PROC_REF(/obj/structure/machinery/door, sync_pathfinding))
	grenade = null
	return ..()

/datum/component/door_trap/proc/exempt(mob/living/who)
	return who.faction == owner_faction || human_ai_faction_relation(owner_faction, who.faction) == HAI_REL_FRIENDLY

/datum/component/door_trap/proc/on_open(datum/source, mob/opener)
	SIGNAL_HANDLER
	if(opener)
		if(!isliving(opener) || exempt(opener))
			return
	else
		var/found = FALSE
		for(var/mob/living/near in range(2, parent))
			if(near.stat != DEAD && !exempt(near))
				found = TRUE
				break
		if(!found)
			return
	var/obj/item/explosive/grenade/set_off = grenade
	var/turf/at = get_turf(parent)
	grenade = null
	set_off.forceMove(at)
	INVOKE_ASYNC(set_off, TYPE_PROC_REF(/obj/item/explosive/grenade, prime))
	qdel(src)

/obj/structure/machinery/door/proc/disarm_trap(mob/user)
	var/datum/component/door_trap/trap = GetComponent(/datum/component/door_trap)
	if(!trap)
		return FALSE
	if(user && !do_after(user, 30, INTERRUPT_ALL, BUSY_ICON_FRIENDLY, src))
		return FALSE
	trap = GetComponent(/datum/component/door_trap)
	if(!trap)
		return FALSE
	var/obj/item/explosive/grenade/freed = trap.grenade
	if(freed)
		freed.forceMove(get_turf(src))
	trap.grenade = null
	qdel(trap)
	return TRUE

/obj/structure/machinery/door/airlock/proc/electrified_exempt(mob/user)
	if(!electrified_by || !isliving(user))
		return FALSE
	var/mob/living/who = user
	return who.faction == electrified_by || human_ai_faction_relation(electrified_by, who.faction) == HAI_REL_FRIENDLY

/// Wires the door to shock whoever is not on the engineer's side, for a while
/obj/structure/machinery/door/airlock/proc/ai_electrify(mob/living/engineer, seconds)
	if(!arePowerSystemsOn() || secondsElectrified != 0)
		return FALSE
	secondsElectrified = seconds
	electrified_by = engineer.faction
	ai_tampered = TRUE
	sync_pathfinding()
	addtimer(CALLBACK(src, PROC_REF(ai_unelectrify), electrified_by), seconds SECONDS)
	return TRUE

/obj/structure/machinery/door/airlock/proc/ai_unelectrify(for_faction)
	if(QDELETED(src) || electrified_by != for_faction || secondsElectrified == -1)
		return
	secondsElectrified = 0
	electrified_by = null
	sync_pathfinding()

/datum/human_ai_brain/proc/find_multitool()
	for(var/obj/item/tool in body.get_contents())
		if(HAS_TRAIT(tool, TRAIT_TOOL_MULTITOOL))
			return tool
	return null

/// A grenade the engineer may trap a door with: flash and smoke always, the lethal kinds only when admins allow it
/datum/human_ai_brain/proc/find_trap_grenade()
	for(var/obj/item/explosive/grenade/grenade in body.get_contents())
		var/kind = human_ai_grenade_kind(grenade)
		if(kind == HAI_GRENADE_FLASH || kind == HAI_GRENADE_SMOKE || (kind == HAI_GRENADE_LETHAL && GLOB.ai_lethal_traps))
			return grenade
	return null

/datum/human_ai_brain/proc/door_at(turf/where)
	return locate(/obj/structure/machinery/door) in where

/// The turf beside the door on the engineer's side to stand on
/datum/human_ai_brain/proc/door_step(turf/door_turf)
	var/turf/best
	var/best_distance = INFINITY
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(door_turf, direction)
		if(candidate && !candidate.density && !(locate(/obj/structure/machinery/door) in candidate) && get_dist(body, candidate) < best_distance)
			best_distance = get_dist(body, candidate)
			best = candidate
	return best

/// Wires a grenade to a door
/datum/npc_order/rig_door
	id = "rig_door"
	name = "Rig door"
	hard = TRUE
	danger = 0.2

/datum/npc_order/rig_door/can_perform(datum/human_ai_brain/performer)
	if(!performer.role?.supports_order(id))
		return "no engineer kit"
	if(!GLOB.ai_traps_enabled)
		return "traps are switched off"
	if(length(GLOB.human_ai_door_traps) >= HAI_MAX_TRAPS)
		return "too many traps"
	var/obj/structure/machinery/door/target = performer.door_at(target_turf)
	if(!target)
		return "no door"
	if(target.GetComponent(/datum/component/door_trap))
		return "already rigged"
	return performer.find_trap_grenade() ? null : "no grenade fit for a trap"

/datum/npc_order/rig_door/tick(datum/human_ai_brain/performer)
	if(performer.is_acting())
		return FALSE
	var/obj/structure/machinery/door/target = performer.door_at(target_turf)
	if(!target)
		finish(HAI_ORDER_FAILED)
		return FALSE
	var/turf/stand = performer.door_step(target_turf)
	if(!stand)
		finish(HAI_ORDER_FAILED)
		return FALSE
	if(performer.body.loc != stand)
		if(performer.move_to(stand, 0, FALSE))
			return TRUE
		finish(HAI_ORDER_FAILED)
		return FALSE
	var/obj/item/explosive/grenade/grenade = performer.find_trap_grenade()
	if(!grenade || !performer.hand_item(grenade))
		finish(HAI_ORDER_FAILED)
		return FALSE
	performer.body.face_atom(target)
	performer.acting_until = world.time + 40
	addtimer(CALLBACK(performer, TYPE_PROC_REF(/datum/human_ai_brain, finish_rigging), target, grenade), 40)
	finish(HAI_ORDER_DONE)
	return FALSE

/datum/human_ai_brain/proc/finish_rigging(obj/structure/machinery/door/target, obj/item/explosive/grenade/grenade)
	if(stopped || QDELETED(body) || QDELETED(target) || QDELETED(grenade) || get_dist(body, target) > 1)
		return
	body.drop_inv_item_to_loc(grenade, body.loc)
	target.AddComponent(/datum/component/door_trap, grenade, body.faction)
	traps_rigged++
	log_decision("rigged the door at [target.x],[target.y]")

/// Stays by a door and shocks it while enemies come near and no friend is at it
/datum/npc_order/guard_door
	id = "guard_door"
	name = "Guard door"
	hard = TRUE
	danger = 0.2

/datum/npc_order/guard_door/can_perform(datum/human_ai_brain/performer)
	if(!performer.role?.supports_order(id))
		return "no engineer kit"
	if(!GLOB.ai_traps_enabled)
		return "traps are switched off"
	if(!istype(performer.door_at(target_turf), /obj/structure/machinery/door/airlock))
		return "no airlock"
	return performer.find_multitool() ? null : "no multitool"

/datum/npc_order/guard_door/tick(datum/human_ai_brain/performer)
	if(performer.is_acting() || world.time < wait_until)
		return FALSE
	var/obj/structure/machinery/door/airlock/target = performer.door_at(target_turf)
	if(!istype(target))
		finish(HAI_ORDER_FAILED)
		return FALSE
	var/turf/stand = performer.door_step(target_turf)
	if(stand && performer.body.loc != stand && get_dist(performer.body, target) > 1)
		return performer.move_to(stand, 0, FALSE)
	wait_until = world.time + HAI_DOOR_GUARD_INTERVAL
	var/hostile_near = FALSE
	for(var/key in performer.contacts)
		var/datum/ai_contact/contact = performer.contacts[key]
		if(contact.identified() && contact.last_turf && (contact.visible || contact.confidence >= 0.4) && get_dist(contact.last_turf, target) <= HAI_DOOR_APPROACH)
			hostile_near = TRUE
			break
	var/friend_near = FALSE
	for(var/mob/living/near in range(HAI_DOOR_STEP, target))
		if(near != performer.body && near.stat != DEAD && performer.get_disposition(near) <= HAI_DISP_FRIEND)
			friend_near = TRUE
			break
	if(friend_near && target.secondsElectrified != 0 && target.electrified_by == performer.body.faction)
		target.secondsElectrified = 0
		target.electrified_by = null
		target.sync_pathfinding()
		performer.shocks_lifted++
		performer.log_decision("let the door down for friends")
	else if(hostile_near && !friend_near && target.secondsElectrified == 0)
		var/obj/item/tool = performer.find_multitool()
		if(tool && target.ai_electrify(performer.body, HAI_SHOCK_TIME))
			performer.shocks_armed++
			performer.acting_until = world.time + 20
			performer.body.face_atom(target)
			performer.log_decision("electrified the door")
	return FALSE

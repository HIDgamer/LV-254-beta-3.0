#define GUNPOINT_DELAY_STAGE_2 (2.5 SECONDS)
#define GUNPOINT_DELAY_STAGE_3 (7.5 SECONDS)
#define GUNPOINT_MULT_STAGE_1 1
#define GUNPOINT_MULT_STAGE_2 1.5
#define GUNPOINT_MULT_STAGE_3 2
/// Tiles the shooter can be from the target without losing the aim
#define GUNPOINT_RANGE 5
#define GUNPOINT_FLINCH_CHANCE 5
/// Damage a single hit needs to deal before it can make the shooter flinch
#define GUNPOINT_FLINCH_MIN_DAMAGE 12
#define GUNPOINT_MAX_DUMP_ROUNDS 40

/// Red crosshair over a person held at gunpoint, everyone can see it
/obj/effect/gunpoint_marker
	icon = 'icons/effects/Targeted.dmi'
	icon_state = "sniper_lockon"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	vis_flags = VIS_INHERIT_PLANE
	layer = ABOVE_MOB_LAYER
	pixel_y = 4

/// A shooter holding a human at gunpoint, the target acting makes the gun empty into them
/datum/component/gunpoint
	dupe_mode = COMPONENT_DUPE_UNIQUE

	var/mob/living/carbon/human/target
	var/obj/item/weapon/gun/weapon
	var/obj/effect/gunpoint_marker/marker
	var/stage = 1
	var/damage_mult = GUNPOINT_MULT_STAGE_1
	var/triggers = GUNPOINT_TRIGGER_MOVE
	var/point_of_no_return = FALSE

/datum/component/gunpoint/Initialize(mob/living/carbon/human/target, obj/item/weapon/gun/weapon)
	if(!ishuman(parent) || !istype(target) || !istype(weapon))
		return COMPONENT_INCOMPATIBLE
	src.target = target
	src.weapon = weapon
	var/mob/living/carbon/human/shooter = parent
	triggers = shooter.gunpoint_triggers
	RegisterSignal(target, COMSIG_MOB_FIRED_GUN, PROC_REF(target_acted))
	if(triggers & GUNPOINT_TRIGGER_MOVE)
		RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(target_moved))
	if(triggers & GUNPOINT_TRIGGER_ITEMS)
		RegisterSignal(target, list(COMSIG_MOB_ITEM_ATTACK_SELF, COMSIG_MOB_PICKUP_ITEM, COMSIG_MOB_ATTEMPTING_EQUIP, COMSIG_MOB_SWAPPED_HAND), PROC_REF(target_acted))
	if(triggers & GUNPOINT_TRIGGER_COMMS)
		RegisterSignal(target, COMSIG_LIVING_SPEAK, PROC_REF(target_spoke))
	RegisterSignal(target, COMSIG_PARENT_QDELETING, PROC_REF(cancel))
	RegisterSignal(weapon, list(COMSIG_ITEM_DROPPED, COMSIG_ITEM_EQUIPPED), PROC_REF(cancel))
	marker = new(null)
	target.vis_contents += marker
	target.add_filter("gunpoint_outline", 2, list("type" = "outline", "color" = "#FF0000", "alpha" = 0, "size" = 1))
	animate(target.get_filter("gunpoint_outline"), alpha = 255, time = 0.6 SECONDS, loop = -1)
	animate(alpha = 80, time = 0.6 SECONDS)
	shooter.visible_message(SPAN_DANGER("[shooter] aims [weapon] at [target]!"), SPAN_DANGER("You aim [weapon] at [target]!"))
	to_chat(target, SPAN_DANGER("[shooter] is holding you at gunpoint, don't move or act!"))
	if(target.client)
		playsound_client(target.client, 'sound/machines/chime.ogg', vol = 50)
	addtimer(CALLBACK(src, PROC_REF(update_stage), 2), GUNPOINT_DELAY_STAGE_2)

/datum/component/gunpoint/Destroy(force)
	if(target)
		UnregisterSignal(target, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_FIRED_GUN, COMSIG_MOB_ITEM_ATTACK_SELF, COMSIG_MOB_PICKUP_ITEM, COMSIG_MOB_ATTEMPTING_EQUIP, COMSIG_MOB_SWAPPED_HAND, COMSIG_LIVING_SPEAK, COMSIG_PARENT_QDELETING))
		if(marker)
			target.vis_contents -= marker
		target.remove_filter("gunpoint_outline")
	QDEL_NULL(marker)
	if(weapon)
		UnregisterSignal(weapon, list(COMSIG_ITEM_DROPPED, COMSIG_ITEM_EQUIPPED, COMSIG_GUN_BEFORE_FIRE))
	target = null
	weapon = null
	return ..()

/datum/component/gunpoint/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(check_deescalate))
	RegisterSignal(parent, list(COMSIG_MOB_TAKE_DAMAGE, COMSIG_HUMAN_TAKE_DAMAGE), PROC_REF(flinch))

/datum/component/gunpoint/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_TAKE_DAMAGE, COMSIG_HUMAN_TAKE_DAMAGE))

/datum/component/gunpoint/proc/update_stage(new_stage)
	if(QDELETED(src) || check_deescalate())
		return
	stage = new_stage
	if(stage == 2)
		to_chat(parent, SPAN_DANGER("You steady [weapon] on [target]."))
		to_chat(target, SPAN_DANGER("[parent] has steadied [weapon] on you!"))
		damage_mult = GUNPOINT_MULT_STAGE_2
		addtimer(CALLBACK(src, PROC_REF(update_stage), 3), GUNPOINT_DELAY_STAGE_3)
	else if(stage == 3)
		to_chat(parent, SPAN_DANGER("You have fully steadied [weapon] on [target]."))
		to_chat(target, SPAN_DANGER("[parent] has fully steadied [weapon] on you!"))
		damage_mult = GUNPOINT_MULT_STAGE_3

/// Breaks the aim when the shooter can no longer keep the target in sight or in reach
/datum/component/gunpoint/proc/check_deescalate()
	SIGNAL_HANDLER
	var/mob/living/carbon/human/shooter = parent
	if(shooter.is_mob_incapacitated() || get_dist(shooter, target) > GUNPOINT_RANGE || !can_see(shooter, target, GUNPOINT_RANGE))
		cancel()
		return TRUE

/datum/component/gunpoint/proc/target_moved(datum/source, turf/oldloc, direction, forced)
	SIGNAL_HANDLER
	if(forced)
		return
	INVOKE_ASYNC(src, PROC_REF(fire_shot), TRUE)

/datum/component/gunpoint/proc/target_acted(datum/source, ...)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(fire_shot), TRUE)

/datum/component/gunpoint/proc/target_spoke(datum/source, ...)
	SIGNAL_HANDLER
	if(!target.speaking_over_radio)
		return
	INVOKE_ASYNC(src, PROC_REF(fire_shot), TRUE)

/// Fires the charged shot, emptying the magazine into the target after it when dump is set
/datum/component/gunpoint/proc/fire_shot(dump = FALSE)
	if(point_of_no_return || QDELETED(src))
		return
	point_of_no_return = TRUE
	var/mob/living/carbon/human/shooter = parent
	var/obj/item/weapon/gun/shooting_gun = weapon
	var/mob/living/carbon/human/victim = target
	var/rounds = 1
	if(dump)
		rounds = clamp(shooting_gun.current_mag?.current_rounds, 1, GUNPOINT_MAX_DUMP_ROUNDS)
	RegisterSignal(shooting_gun, COMSIG_GUN_BEFORE_FIRE, PROC_REF(boost_shot))
	addtimer(CALLBACK(src, PROC_REF(cancel_quietly)), 3 SECONDS)
	shooting_gun.Fire(victim, shooter, null, TRUE)
	if(rounds > 1)
		gunpoint_dump(shooter, shooting_gun, victim, rounds - 1)

/datum/component/gunpoint/proc/boost_shot(obj/item/weapon/gun/source, obj/projectile/projectile_to_fire)
	SIGNAL_HANDLER
	projectile_to_fire.damage *= damage_mult
	UnregisterSignal(weapon, COMSIG_GUN_BEFORE_FIRE)
	qdel(src)

/datum/component/gunpoint/proc/cancel_quietly()
	if(!QDELETED(src))
		qdel(src)

/datum/component/gunpoint/proc/cancel()
	SIGNAL_HANDLER
	if(QDELETED(src))
		return
	if(!point_of_no_return && target && weapon)
		var/mob/living/carbon/human/shooter = parent
		shooter.visible_message(SPAN_DANGER("[shooter] breaks [shooter.p_their()] aim on [target]!"), SPAN_DANGER("You are no longer aiming [weapon] at [target]."))
	qdel(src)

/// A hit shooter may flinch and fire once
/datum/component/gunpoint/proc/flinch(datum/source, list/damagedata, damagetype)
	SIGNAL_HANDLER
	if(damagedata["damage"] < GUNPOINT_FLINCH_MIN_DAMAGE || !prob(GUNPOINT_FLINCH_CHANCE))
		return
	var/mob/living/carbon/human/shooter = parent
	shooter.visible_message(SPAN_DANGER("[shooter] flinches!"), SPAN_DANGER("You flinch!"))
	INVOKE_ASYNC(src, PROC_REF(fire_shot), FALSE)

/// Keeps firing at the target until the rounds run out or the shooter can no longer fire
/proc/gunpoint_dump(mob/living/carbon/human/shooter, obj/item/weapon/gun/shooting_gun, mob/living/carbon/human/victim, rounds)
	set waitfor = FALSE
	for(var/shot in 1 to rounds)
		sleep(max(shooting_gun.get_fire_delay(), 1))
		if(QDELETED(shooter) || QDELETED(shooting_gun) || QDELETED(victim) || victim.stat == DEAD)
			return
		if(shooter.stat != CONSCIOUS || shooter.get_active_hand() != shooting_gun || !shooting_gun.current_mag?.current_rounds)
			return
		shooting_gun.Fire(victim, shooter, null, TRUE)

#undef GUNPOINT_DELAY_STAGE_2
#undef GUNPOINT_DELAY_STAGE_3
#undef GUNPOINT_MULT_STAGE_1
#undef GUNPOINT_MULT_STAGE_2
#undef GUNPOINT_MULT_STAGE_3
#undef GUNPOINT_RANGE
#undef GUNPOINT_FLINCH_CHANCE
#undef GUNPOINT_FLINCH_MIN_DAMAGE
#undef GUNPOINT_MAX_DUMP_ROUNDS

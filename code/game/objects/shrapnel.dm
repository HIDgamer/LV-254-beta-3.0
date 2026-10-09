
/// Shrapnel fragments currently in flight, see SHRAPNEL_ACTIVE_LIMIT
GLOBAL_VAR_INIT(active_shrapnel, 0)

/proc/create_shrapnel(turf/epicenter, shrapnel_number = 10, shrapnel_direction, shrapnel_spread = 45, datum/ammo/shrapnel_type = /datum/ammo/bullet/shrapnel, datum/cause_data/cause_data, ignore_source_mob = FALSE, on_hit_coefficient = 0.15, use_shrapnel_angle = FALSE)

	epicenter = get_turf(epicenter)

	// Self-heal: with no projectile in flight at all the fragment counter cannot be anything but zero
	if(GLOB.active_shrapnel && !SSprojectiles.has_projectiles())
		GLOB.active_shrapnel = 0

	// Circuit breaker: once too many fragments are already airborne, bursts are thinned to the remaining budget
	// but never below SHRAPNEL_MIN_BURST, so an explosion always throws something
	var/shrapnel_budget = SHRAPNEL_ACTIVE_LIMIT - GLOB.active_shrapnel
	if(shrapnel_number > shrapnel_budget)
		shrapnel_number = max(shrapnel_budget, min(shrapnel_number, SHRAPNEL_MIN_BURST))

	var/initial_angle = 0
	var/angle_increment = 0

	if(use_shrapnel_angle && shrapnel_spread < 360)
		initial_angle = shrapnel_direction - shrapnel_spread
		angle_increment = shrapnel_spread*2/shrapnel_number
	else if (shrapnel_direction)
		initial_angle = dir2angle(shrapnel_direction) - shrapnel_spread
		angle_increment = shrapnel_spread*2/shrapnel_number
	else
		angle_increment = 360/shrapnel_number
	var/angle_randomization = angle_increment/2

	var/mob/living/mob_standing_on_turf
	var/mob/living/mob_lying_on_turf
	var/atom/source = epicenter

	for(var/mob/living/M in epicenter) //find a mob at the epicenter. Non-prone mobs take priority
		if(M.density && !mob_standing_on_turf)
			mob_standing_on_turf = M
		else if(!mob_lying_on_turf)
			mob_lying_on_turf = M

	if(mob_standing_on_turf && isturf(mob_standing_on_turf.loc))
		source = mob_standing_on_turf//we designate any mob standing on the turf as the "source" so that they don't simply get hit by every projectile


	for(var/i=0;i<shrapnel_number;i++)

		var/obj/projectile/S = new(epicenter, cause_data)
		S.generate_bullet(new shrapnel_type)

		var/mob/source_mob = cause_data?.resolve_mob()
		if(!(ignore_source_mob && mob_standing_on_turf == source_mob) && mob_standing_on_turf && prob(100*on_hit_coefficient)) //if a non-prone mob is on the same turf as the shrapnel explosion, some of the shrapnel hits him
			S.ammo.on_hit_mob(mob_standing_on_turf, S)
			S.handle_mob(mob_standing_on_turf)
		else if (!(ignore_source_mob && mob_lying_on_turf == source_mob) && mob_lying_on_turf && prob(100*on_hit_coefficient))
			S.ammo.on_hit_mob(mob_lying_on_turf, S)
			S.handle_mob(mob_lying_on_turf)

		else
			var/angle = initial_angle + i*angle_increment + rand(-angle_randomization,angle_randomization)
			var/atom/target = get_angle_target_turf(epicenter, angle, 20)
			S.projectile_flags |= PROJECTILE_SHRAPNEL
			S.shrapnel_counted = TRUE
			GLOB.active_shrapnel++
			S.fire_at(target, source_mob, source, S.ammo.max_range, S.ammo.shell_speed, null)

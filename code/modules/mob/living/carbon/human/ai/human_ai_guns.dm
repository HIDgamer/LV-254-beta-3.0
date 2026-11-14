GLOBAL_LIST_EMPTY(human_ai_gun_appraisals)

/// How one kind of gun is handled, worked out from a sample and shared by every brain holding that kind
/datum/human_ai_gun_appraisal
	var/gun_type
	var/family = HAI_GUN_OTHER
	var/feed = HAI_FEED_NONE
	var/cycle = HAI_CYCLE_AUTO
	/// Double barrels open at the breech to take shells
	var/break_action = FALSE
	/// Revolvers swing the cylinder open to take rounds
	var/cylinder = FALSE
	var/two_handed = FALSE
	/// Cannot be fired one handed at all
	var/wield_only = FALSE
	var/can_semi = FALSE
	var/can_burst = FALSE
	var/can_auto = FALSE
	var/burst_amount = 1
	/// Deciseconds between shots
	var/fire_delay = 5
	/// Tiles, shooting from closer than this hurts the shooter or the shooter's friends
	var/min_range = 0
	var/ideal_range = 5
	var/max_range = 7
	/// Fire or blast around the point of impact, friends near the target are at risk
	var/area_effect = FALSE
	/// Rounds that kill by volume get spent faster, used to pick long or short bursts
	var/suppressive = FALSE

/proc/get_human_ai_gun_appraisal(obj/item/weapon/gun/gun)
	RETURN_TYPE(/datum/human_ai_gun_appraisal)
	var/datum/human_ai_gun_appraisal/appraisal = GLOB.human_ai_gun_appraisals[gun.type]
	if(!appraisal)
		appraisal = new
		appraisal.analyse(gun)
		GLOB.human_ai_gun_appraisals[gun.type] = appraisal
	return appraisal

/datum/human_ai_gun_appraisal/proc/analyse(obj/item/weapon/gun/gun)
	gun_type = gun.type
	two_handed = (gun.flags_item & TWOHANDED) && !(gun.flags_gun_features & GUN_ONE_HAND_WIELDED)
	wield_only = !!(gun.flags_gun_features & GUN_WIELDED_FIRING_ONLY)
	fire_delay = max(gun.get_fire_delay(), 1)
	burst_amount = max(gun.get_burst_amount(), 1)
	can_semi = !!(GUN_FIREMODE_SEMIAUTO in gun.gun_firemode_list)
	can_burst = burst_amount > 1 && (GUN_FIREMODE_BURSTFIRE in gun.gun_firemode_list)
	can_auto = !!(GUN_FIREMODE_AUTOMATIC in gun.gun_firemode_list)
	if(!can_semi && !can_burst && !can_auto)
		can_semi = TRUE

	family = HAI_GUN_RIFLE
	if(istype(gun, /obj/item/weapon/gun/flamer))
		family = HAI_GUN_FLAMER
	else if(istype(gun, /obj/item/weapon/gun/launcher))
		family = HAI_GUN_LAUNCHER
	else if(istype(gun, /obj/item/weapon/gun/energy))
		family = HAI_GUN_OTHER
	else if(istype(gun, /obj/item/weapon/gun/boltaction) || istype(gun, /obj/item/weapon/gun/rifle/sniper))
		family = HAI_GUN_SNIPER
	else if(istype(gun, /obj/item/weapon/gun/smartgun) || istype(gun, /obj/item/weapon/gun/m60) || istype(gun, /obj/item/weapon/gun/pkp) || istype(gun, /obj/item/weapon/gun/minigun) || istype(gun, /obj/item/weapon/gun/rifle/lmg))
		family = HAI_GUN_HEAVY
	else
		switch(gun.gun_category)
			if(GUN_CATEGORY_HANDGUN)
				family = HAI_GUN_PISTOL
			if(GUN_CATEGORY_SMG)
				family = HAI_GUN_SMG
			if(GUN_CATEGORY_RIFLE)
				family = HAI_GUN_RIFLE
			if(GUN_CATEGORY_SHOTGUN)
				family = HAI_GUN_SHOTGUN
			if(GUN_CATEGORY_HEAVY)
				family = HAI_GUN_HEAVY
			else
				family = HAI_GUN_OTHER

	if(istype(gun, /obj/item/weapon/gun/flamer))
		feed = HAI_FEED_TANK
	else if(istype(gun, /obj/item/weapon/gun/launcher/rocket))
		feed = HAI_FEED_ROCKET
	else if(istype(gun, /obj/item/weapon/gun/launcher/grenade))
		feed = HAI_FEED_GRENADE
	else if(istype(gun, /obj/item/weapon/gun/energy) || istype(gun, /obj/item/weapon/gun/launcher))
		feed = HAI_FEED_NONE
	else if(gun.flags_gun_features & GUN_INTERNAL_MAG)
		feed = HAI_FEED_INTERNAL
	else if(gun.current_mag || initial(gun.current_mag))
		feed = HAI_FEED_MAGAZINE

	if(istype(gun, /obj/item/weapon/gun/shotgun/pump) || istype(gun, /obj/item/weapon/gun/lever_action) || istype(gun, /obj/item/weapon/gun/boltaction) || istype(gun, /obj/item/weapon/gun/rifle/xm51))
		cycle = HAI_CYCLE_MANUAL
	break_action = istype(gun, /obj/item/weapon/gun/shotgun/double)
	cylinder = istype(gun, /obj/item/weapon/gun/revolver)

	switch(family)
		if(HAI_GUN_PISTOL)
			ideal_range = 4
			max_range = 7
		if(HAI_GUN_SMG)
			ideal_range = 5
			max_range = 8
		if(HAI_GUN_RIFLE)
			ideal_range = 7
			max_range = 9
		if(HAI_GUN_SHOTGUN)
			ideal_range = 3
			max_range = 6
		if(HAI_GUN_SNIPER)
			ideal_range = 11
			max_range = HAI_SNIPER_RANGE
		if(HAI_GUN_HEAVY)
			ideal_range = 7
			max_range = 9
			suppressive = TRUE
		if(HAI_GUN_LAUNCHER)
			ideal_range = 6
			max_range = 9
			min_range = 3
			area_effect = TRUE
		if(HAI_GUN_FLAMER)
			ideal_range = 3
			max_range = 4
			min_range = 2
			area_effect = TRUE
		else
			ideal_range = 4
			max_range = 7
	if(gun.effective_range_max)
		max_range = clamp(gun.effective_range_max, 3, (family == HAI_GUN_SNIPER) ? HAI_SNIPER_RANGE : HAI_SIGHT_RANGE)
		ideal_range = min(ideal_range, max_range)
	if(can_auto && !can_semi && !can_burst)
		suppressive = TRUE

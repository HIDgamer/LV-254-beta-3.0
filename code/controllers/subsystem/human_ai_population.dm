/datum/config_entry/flag/human_ai_population

/// Fills a map with ambient AI humans from the profile of that map, off unless the config or an admin switches it on
SUBSYSTEM_DEF(human_ai_population)
	name = "Human AI Population"
	wait = HAI_POP_CHECK_INTERVAL
	flags = SS_KEEP_TIMING
	priority = SS_PRIORITY_HUMAN_AI_POPULATION

	/// The master switch, nothing is placed while it is off
	var/enabled = FALSE
	var/enabled_by_config = FALSE
	var/datum/npc_population_profile/profile
	var/list/health_report
	var/roundstart_at = 0
	var/landed = FALSE
	/// Reference text of a dead ambient human to the time it was found dead
	var/list/corpse_times = list()
	var/placed_total = 0
	var/round_over_done = FALSE
	var/cleared_total = 0
	var/last_run_ms = 0

/datum/controller/subsystem/human_ai_population/stat_entry(msg)
	msg = "[enabled ? "ON" : "off"] P:[placed_total] [profile ? profile.map_name : "no profile"]"
	return ..()

/datum/controller/subsystem/human_ai_population/Initialize()
	RegisterSignal(SSdcs, COMSIG_GLOB_DS_FIRST_LANDED, PROC_REF(on_first_landed))
	enabled_by_config = !!CONFIG_GET(flag/human_ai_population)
	enabled = enabled_by_config
	return SS_INIT_SUCCESS

/datum/controller/subsystem/human_ai_population/proc/on_first_landed()
	SIGNAL_HANDLER
	landed = TRUE

/// The profile of the ground map that is loaded, null when the map has none
/datum/controller/subsystem/human_ai_population/proc/find_profile()
	var/datum/map_config/ground = SSmapping.configs[GROUND_MAP]
	return ground ? GLOB.npc_population_profiles[ground.map_name] : null

/datum/controller/subsystem/human_ai_population/fire(resumed = FALSE)
	if(SSticker?.current_state >= GAME_STATE_FINISHED)
		round_over()
		return
	if(!enabled || SSticker?.current_state != GAME_STATE_PLAYING)
		return
	if(!profile)
		profile = find_profile()
	if(!roundstart_at)
		roundstart_at = world.time + HAI_POP_ROUNDSTART_DELAY
	if(world.time < roundstart_at)
		return
	if(!health_report && profile)
		health_report = check_health(profile)
	run_groups()

/// Gives every enabled group the chance to place what it is due, returns how many humans were put down
/datum/controller/subsystem/human_ai_population/proc/run_groups()
	if(!enabled || SSlag_switch.measures[SIMPLIFY_HUMAN_AI])
		return 0
	var/started = TICK_USAGE
	var/list/watchers = npc_population_watchers()
	var/budget = HAI_POP_BURST
	for(var/datum/npc_population_group/group as anything in all_groups(TRUE))
		if(!group.enabled)
			continue
		budget -= maintain_group(group, watchers, budget)
		if(budget <= 0)
			break
	clear_corpses(watchers)
	last_run_ms = max(0, TICK_USAGE_TO_MS(started))
	return HAI_POP_BURST - budget

/// The groups of the map profile and of the hooks, only the hooks that run now when asked
/datum/controller/subsystem/human_ai_population/proc/all_groups(only_active = FALSE)
	var/list/found = list()
	if(profile)
		found += profile.groups
	for(var/hook_id in GLOB.npc_population_hooks)
		var/datum/npc_population_hook/hook = GLOB.npc_population_hooks[hook_id]
		if(only_active && !hook.active())
			continue
		found += hook.groups
	return found

/// Players the placement guards keep humans away from
/proc/npc_population_watchers()
	var/list/watchers = list()
	for(var/mob/player as anything in GLOB.player_list)
		if(player.client && !isobserver(player))
			watchers += player
	watchers += GLOB.npc_population_extra_watchers
	return watchers

/// Places what the group is due, returns how many humans it put down
/datum/controller/subsystem/human_ai_population/proc/maintain_group(datum/npc_population_group/group, list/watchers, budget)
	if(budget <= 0)
		return 0
	switch(group.timing)
		if(HAI_POP_ON_EVENT)
			return 0
		if(HAI_POP_ON_LANDING)
			if(!landed)
				return 0
	group.prune_members()
	var/target = group.target_size()
	var/alive = group.alive_count()
	if(group.max_alive)
		target = min(target, group.max_alive)
	if(group.timing == HAI_POP_TRICKLE || group.respawn)
		if(alive >= target || world.time < group.next_spawn)
			return 0
		group.next_spawn = world.time + HAI_POP_TRICKLE_GAP
		return place(group, watchers, 1)
	if(group.placed)
		return 0
	var/missing = target - group.spawned_total
	if(missing <= 0)
		group.placed = TRUE
		return 0
	var/made = place(group, watchers, min(missing, budget))
	if(!made && group.place_failures >= HAI_POP_PLACE_TRIES)
		group.placed = TRUE
	if(group.spawned_total >= target)
		group.placed = TRUE
	return made

/// Puts up to the count of humans of the group on free turfs and organises them, returns how many were made
/datum/controller/subsystem/human_ai_population/proc/place(datum/npc_population_group/group, list/watchers, count)
	var/list/batch = list()
	for(var/index in 1 to count)
		var/turf/where = group.pick_turf(watchers)
		if(!where)
			group.place_failures++
			break
		if(!SShuman_ai.has_room())
			break
		var/mob/living/carbon/human/human = group.spawn_member(where)
		if(!human)
			group.place_failures++
			break
		batch += human
	group.organise(batch)
	placed_total += length(batch)
	return length(batch)

/// Removes bodies of ambient humans that nobody is looking at after a while
/datum/controller/subsystem/human_ai_population/proc/clear_corpses(list/watchers)
	for(var/datum/npc_population_group/group as anything in all_groups())
		for(var/datum/weakref/ref as anything in group.members.Copy())
			var/mob/living/carbon/human/human = ref.resolve()
			if(!human || QDELETED(human) || human.stat != DEAD || human.client)
				continue
			var/key = REF(human)
			if(!corpse_times[key])
				corpse_times[key] = world.time
				continue
			if(world.time < corpse_times[key] + HAI_POP_CORPSE_TIME || seen_by_any(human, watchers))
				continue
			corpse_times -= key
			group.members -= ref
			cleared_total++
			qdel(human)

/datum/controller/subsystem/human_ai_population/proc/seen_by_any(mob/body, list/watchers)
	var/turf/where = get_turf(body)
	for(var/mob/watcher as anything in watchers)
		var/turf/seen_from = get_turf(watcher)
		if(seen_from && seen_from.z == where.z && get_dist(seen_from, where) < HAI_POP_MIN_PLAYER_DISTANCE)
			return TRUE
	return FALSE

/// Checks that the profile can be carried out on the loaded map: the data, then the zones for turfs and pockets that are too small
/datum/controller/subsystem/human_ai_population/proc/check_health(datum/npc_population_profile/checked)
	var/list/report = checked.validate()
	for(var/datum/npc_population_group/group as anything in checked.groups)
		if(length(group.fixed_turfs))
			continue
		for(var/area_type in group.zones)
			var/area/room = GLOB.areas_by_type[area_type]
			if(!room)
				report += "[group.id]: the area [area_type] is not on this map"
				continue
		var/list/pools = group.get_zone_turfs()
		var/total = 0
		for(var/area_type in pools)
			var/list/usable = pools[area_type]
			total += length(usable)
			if(length(usable) < HAI_POP_POCKET_SIZE && !pocket_is_open(usable[1]))
				report += "[group.id]: the usable ground of [area_type] is a closed pocket of [length(usable)] turfs"
		if(total < group.size_max)
			report += "[group.id]: only [total] usable turfs for up to [group.size_max] humans"
	return report

/// Whether the turf has open ground around it that goes on for more than a pocket
/datum/controller/subsystem/human_ai_population/proc/pocket_is_open(turf/start)
	var/list/frontier = list(start)
	var/list/seen = list()
	seen[start] = TRUE
	var/index = 1
	while(index <= length(frontier) && length(seen) <= HAI_POP_POCKET_SIZE)
		var/turf/current = frontier[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next_turf = get_step(current, direction)
			if(!next_turf || seen[next_turf] || next_turf.density || !istype(next_turf, /turf/open))
				continue
			seen[next_turf] = TRUE
			frontier += next_turf
	return length(seen) > HAI_POP_POCKET_SIZE

/// Puts every group back as if the round had just begun, bodies are left where they are
/datum/controller/subsystem/human_ai_population/proc/reset_groups()
	for(var/datum/npc_population_group/group as anything in all_groups())
		group.members = list()
		group.spawned_total = 0
		group.placed = FALSE
		group.place_failures = 0
		group.next_spawn = 0
		group.zone_turfs = null

/// Deletes every ambient human the director placed and puts the groups back
/datum/controller/subsystem/human_ai_population/proc/clear_all()
	var/count = 0
	for(var/datum/npc_population_group/group as anything in all_groups())
		for(var/datum/weakref/ref as anything in group.members)
			var/mob/living/carbon/human/human = ref.resolve()
			if(human && !QDELETED(human))
				qdel(human)
				count++
	corpse_times.Cut()
	reset_groups()
	return count

/// Places everything an admin asked one group for right now, whatever its timing says
/datum/controller/subsystem/human_ai_population/proc/populate_now(datum/npc_population_group/group)
	if(!profile)
		profile = find_profile()
	var/list/watchers = npc_population_watchers()
	group.prune_members()
	var/missing = min(group.target_size() - group.alive_count(), HAI_COMMAND_MAX_SPAWN)
	if(missing <= 0)
		return 0
	var/made = place(group, watchers, missing)
	group.placed = TRUE
	return made

/// Runs the health check again, for after the map or a profile changed
/datum/controller/subsystem/human_ai_population/proc/recheck()
	if(!profile)
		profile = find_profile()
	if(!profile)
		return
	for(var/datum/npc_population_group/group as anything in profile.groups)
		group.zone_turfs = null
	health_report = check_health(profile)

/// Stops every AI human thinking once the round is over so the end screen stays quiet
/datum/controller/subsystem/human_ai_population/proc/round_over()
	if(round_over_done)
		return
	round_over_done = TRUE
	SShuman_ai.paused = TRUE

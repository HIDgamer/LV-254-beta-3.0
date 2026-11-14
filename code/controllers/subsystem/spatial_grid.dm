/// A square block of the map and the tracked mobs standing in it
/datum/spatial_grid_cell
	var/list/mob/clients = list()
	var/list/mob/npcs = list()

SUBSYSTEM_DEF(spatial_grid)
	name = "Spatial Grid"
	wait = 1 SECONDS
	priority = SS_PRIORITY_SPATIAL_GRID

	/// Cell lists per z level, laid out row by row
	var/list/grids = list()
	var/grid_cols = 1
	var/grid_rows = 1
	var/list/mob/tracked = list()
	var/list/mob/currentrun

/datum/controller/subsystem/spatial_grid/Initialize()
	grid_cols = SPATIAL_GRID_CELL_INDEX(world.maxx)
	grid_rows = SPATIAL_GRID_CELL_INDEX(world.maxy)
	for(var/z in 1 to world.maxz)
		create_z_grid(z)
	return SS_INIT_SUCCESS

/datum/controller/subsystem/spatial_grid/stat_entry(msg)
	msg = "T:[length(tracked)]"
	return ..()

/datum/controller/subsystem/spatial_grid/fire(resumed = FALSE)
	if(!resumed)
		for(var/client/player as anything in GLOB.clients)
			var/mob/player_mob = player.mob
			if(player_mob && !(player_mob.spatial_grid_flags & SPATIAL_GRID_TRACK_CLIENT))
				track(player_mob, SPATIAL_GRID_TRACK_CLIENT)
		for(var/mob/living/npc as anything in GLOB.ai_xeno_list)
			if(!(npc.spatial_grid_flags & SPATIAL_GRID_TRACK_NPC))
				track(npc, SPATIAL_GRID_TRACK_NPC)
		currentrun = tracked.Copy()

	while(length(currentrun))
		var/mob/tracked_mob = currentrun[length(currentrun)]
		currentrun.len--
		if(QDELETED(tracked_mob))
			continue
		if((tracked_mob.spatial_grid_flags & SPATIAL_GRID_TRACK_CLIENT) && !tracked_mob.client)
			untrack(tracked_mob, SPATIAL_GRID_TRACK_CLIENT)
		refresh_cell(tracked_mob)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/spatial_grid/proc/create_z_grid(z)
	if(length(grids) < z)
		grids.len = z
	var/list/cells = new /list(grid_cols * grid_rows)
	for(var/index in 1 to length(cells))
		cells[index] = new /datum/spatial_grid_cell
	grids[z] = cells
	return cells

/datum/controller/subsystem/spatial_grid/proc/cell_at(x, y, z)
	var/list/cells = (z <= length(grids)) ? grids[z] : null
	if(!cells)
		cells = create_z_grid(z)
	var/col = clamp(SPATIAL_GRID_CELL_INDEX(x), 1, grid_cols)
	var/row = clamp(SPATIAL_GRID_CELL_INDEX(y), 1, grid_rows)
	return cells[(row - 1) * grid_cols + col]

/// Starts tracking the mob as the given kind, a mob can be tracked as both
/datum/controller/subsystem/spatial_grid/proc/track(mob/tracked_mob, kind)
	if(QDELETED(tracked_mob) || (tracked_mob.spatial_grid_flags & kind) == kind)
		return
	if(!tracked_mob.spatial_grid_flags)
		tracked += tracked_mob
		RegisterSignal(tracked_mob, COMSIG_MOVABLE_MOVED, PROC_REF(on_tracked_moved))
		RegisterSignal(tracked_mob, COMSIG_PARENT_QDELETING, PROC_REF(on_tracked_deleted))
	tracked_mob.spatial_grid_flags |= kind
	remove_from_cell(tracked_mob)
	refresh_cell(tracked_mob)

/// Stops tracking the mob as the given kind
/datum/controller/subsystem/spatial_grid/proc/untrack(mob/tracked_mob, kind)
	if(!(tracked_mob.spatial_grid_flags & kind))
		return
	tracked_mob.spatial_grid_flags &= ~kind
	remove_from_cell(tracked_mob)
	if(tracked_mob.spatial_grid_flags)
		refresh_cell(tracked_mob)
		return
	tracked -= tracked_mob
	UnregisterSignal(tracked_mob, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING))

/datum/controller/subsystem/spatial_grid/proc/on_tracked_moved(mob/source)
	SIGNAL_HANDLER
	refresh_cell(source)

/datum/controller/subsystem/spatial_grid/proc/on_tracked_deleted(mob/source)
	SIGNAL_HANDLER
	untrack(source, SPATIAL_GRID_TRACK_ALL)

/datum/controller/subsystem/spatial_grid/proc/remove_from_cell(mob/tracked_mob)
	var/datum/spatial_grid_cell/cell = tracked_mob.spatial_grid_cell
	if(!cell)
		return
	cell.clients -= tracked_mob
	cell.npcs -= tracked_mob
	tracked_mob.spatial_grid_cell = null

/// Files the mob under the cell it is standing in now, mobs inside containers use the container's turf
/datum/controller/subsystem/spatial_grid/proc/refresh_cell(mob/tracked_mob)
	var/turf/standing_on = get_turf(tracked_mob)
	var/datum/spatial_grid_cell/cell = standing_on ? cell_at(standing_on.x, standing_on.y, standing_on.z) : null
	if(cell == tracked_mob.spatial_grid_cell)
		return
	remove_from_cell(tracked_mob)
	if(!cell)
		return
	if(tracked_mob.spatial_grid_flags & SPATIAL_GRID_TRACK_CLIENT)
		cell.clients += tracked_mob
	if(tracked_mob.spatial_grid_flags & SPATIAL_GRID_TRACK_NPC)
		cell.npcs += tracked_mob
	tracked_mob.spatial_grid_cell = cell

/**
 * Tracked mobs standing inside the shape on a z level.
 * Returns clients, or mobs with SPATIAL_GRID_SCAN_MOBS. AI hostiles are only returned,
 * as mobs, with SPATIAL_GRID_INCLUDE_NPC_HOSTILES. limit stops the search after that many results.
 */
/datum/controller/subsystem/spatial_grid/proc/players_in_range(datum/shape/range, z_level, flags = 0, limit = 0)
	var/list/found = list()
	if(!range || !z_level || z_level > length(grids) || !grids[z_level])
		return found
	var/list/cells = grids[z_level]
	var/half_width = range.bounds_x * 0.5
	var/half_height = range.bounds_y * 0.5
	var/min_col = clamp(SPATIAL_GRID_CELL_INDEX(range.center_x - half_width), 1, grid_cols)
	var/max_col = clamp(SPATIAL_GRID_CELL_INDEX(range.center_x + half_width), 1, grid_cols)
	var/min_row = clamp(SPATIAL_GRID_CELL_INDEX(range.center_y - half_height), 1, grid_rows)
	var/max_row = clamp(SPATIAL_GRID_CELL_INDEX(range.center_y + half_height), 1, grid_rows)
	var/exclude_observers = flags & SPATIAL_GRID_EXCLUDE_OBSERVER
	var/scan_mobs = flags & SPATIAL_GRID_SCAN_MOBS
	var/include_npcs = flags & SPATIAL_GRID_INCLUDE_NPC_HOSTILES

	for(var/row in min_row to max_row)
		for(var/col in min_col to max_col)
			var/datum/spatial_grid_cell/cell = cells[(row - 1) * grid_cols + col]
			for(var/mob/player_mob as anything in cell.clients)
				if(!player_mob.client || (exclude_observers && isobserver(player_mob)))
					continue
				var/turf/standing_on = get_turf(player_mob)
				if(!standing_on || standing_on.z != z_level || !range.contains_xy(standing_on.x, standing_on.y))
					continue
				found += scan_mobs ? player_mob : player_mob.client
				if(limit && length(found) >= limit)
					return found
			if(!include_npcs)
				continue
			for(var/mob/npc as anything in cell.npcs)
				if(QDELETED(npc) || npc.stat == DEAD || (scan_mobs && npc.client))
					continue
				var/turf/standing_on = get_turf(npc)
				if(!standing_on || standing_on.z != z_level || !range.contains_xy(standing_on.x, standing_on.y))
					continue
				found += npc
				if(limit && length(found) >= limit)
					return found
	return found

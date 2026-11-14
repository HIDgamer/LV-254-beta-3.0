/**
 * Builds a walled arena from ASCII rows in the unit test z level and loads it into the native pathfinder.
 * # wall, . floor, D airlock, L locked airlock, A airlock that needs access, W window, T table, B barricade facing east, 1-9 floor with a marker
 */
/datum/human_ai_arena
	var/z
	var/width
	var/height
	var/origin_x
	var/origin_y
	var/list/marks = list()
	var/list/doors = list()
	/// Open floor tiles with nothing on them
	var/list/floors = list()

/datum/human_ai_arena/New(list/rows, turf/reference, x_start = 20, y_start = 20)
	z = reference.z
	origin_x = x_start
	origin_y = y_start
	height = length(rows)
	width = length(rows[1])
	var/area/arena_area = get_area(reference)
	for(var/y in 0 to height + 1)
		for(var/x in 0 to width + 1)
			var/turf/old_turf = locate(origin_x + x - 1, origin_y + y - 1, z)
			for(var/atom/movable/leftover as anything in old_turf)
				if(!istype(leftover, /obj/effect/landmark))
					qdel(leftover)
	for(var/row_index in 1 to height)
		var/row = rows[row_index]
		var/y = origin_y + height - row_index
		for(var/col in 1 to width)
			build_cell(locate(origin_x + col - 1, y, z), copytext(row, col, col + 1), arena_area)
	SSxeno_pathfinding.load_z_level(z)

/datum/human_ai_arena/proc/build_cell(turf/cell, char, area/arena_area)
	var/turf/built = cell.ChangeTurf(char == "#" ? /turf/closed/wall/almayer : /turf/open/floor)
	arena_area.contents += built
	switch(char)
		if(".")
			floors += built
		if("D", "L", "A")
			var/obj/structure/machinery/door/airlock/door = new /obj/structure/machinery/door/airlock/almayer/generic(built)
			doors[char] += list(door)
			if(char == "L")
				door.lock(TRUE)
			else if(char == "A")
				door.req_access = list(ACCESS_MARINE_COMMAND)
		if("W")
			new /obj/structure/window/framed/almayer(built)
		if("T")
			new /obj/structure/surface/table(built)
		if("B")
			var/obj/structure/barricade/metal/barricade = new(built)
			barricade.setDir(EAST)
		if("1", "2", "3", "4", "5", "6", "7", "8", "9")
			marks[char] = built

/datum/human_ai_arena/proc/mark(char)
	RETURN_TYPE(/turf)
	return marks[char]

/datum/human_ai_arena/proc/first_door(char)
	RETURN_TYPE(/obj/structure/machinery/door/airlock)
	var/list/found = doors[char]
	return length(found) ? found[1] : null

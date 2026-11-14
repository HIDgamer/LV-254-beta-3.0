#define SPATIAL_TEST_NPC_SCAN (SPATIAL_GRID_SCAN_MOBS | SPATIAL_GRID_INCLUDE_NPC_HOSTILES)

/// The grid files tracked mobs by cell and answers shape queries with the right filtering
/datum/unit_test/spatial_grid_tracking/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/z = origin.z
	var/edge_x = origin.x + 16 - ((origin.x - 1) % 16)
	var/turf/west_tile = locate(edge_x - 1, origin.y, z)
	var/turf/east_tile = locate(edge_x, origin.y, z)
	var/turf/far_tile = locate(edge_x + 40, origin.y, z)
	TEST_ASSERT(west_tile && east_tile && far_tile, "Test tiles do not exist")

	var/mob/living/carbon/human/west_mob = allocate(/mob/living/carbon/human, west_tile)
	var/mob/living/carbon/human/east_mob = allocate(/mob/living/carbon/human, east_tile)
	SSspatial_grid.track(west_mob, SPATIAL_GRID_TRACK_NPC)
	SSspatial_grid.track(east_mob, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(west_mob.spatial_grid_cell != east_mob.spatial_grid_cell, "Tiles either side of a cell edge shared a cell")

	var/list/both = SSspatial_grid.players_in_range(SQUARE(edge_x - 0.5, origin.y, 6), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(length(both) == 2 && (west_mob in both) && (east_mob in both), "A shape over a cell edge missed a mob, got [length(both)]")

	var/list/east_only = SSspatial_grid.players_in_range(SQUARE(edge_x + 1, origin.y, 3), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(length(east_only) == 1 && (east_mob in east_only), "A small shape returned the wrong mobs, got [length(east_only)]")

	var/list/plain = SSspatial_grid.players_in_range(SQUARE(edge_x - 0.5, origin.y, 6), z, SPATIAL_GRID_SCAN_MOBS)
	TEST_ASSERT(!length(plain), "NPC hostiles were returned without the include flag")

	var/list/limited = SSspatial_grid.players_in_range(SQUARE(edge_x - 0.5, origin.y, 6), z, SPATIAL_TEST_NPC_SCAN, 1)
	TEST_ASSERT(length(limited) == 1, "The result limit was ignored, got [length(limited)]")

	var/list/wrong_z = SSspatial_grid.players_in_range(SQUARE(edge_x - 0.5, origin.y, 6), z + 1, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(!length(wrong_z), "A different z level returned mobs")

	var/list/circle = SSspatial_grid.players_in_range(CIRCLE(edge_x - 0.5, origin.y, 0.4), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(!length(circle), "A circle that touches no tile returned mobs")

	west_mob.forceMove(far_tile)
	var/list/moved_away = SSspatial_grid.players_in_range(SQUARE(edge_x - 0.5, origin.y, 6), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(length(moved_away) == 1 && (east_mob in moved_away), "A moved mob stayed in its old cell")
	var/list/arrived = SSspatial_grid.players_in_range(SQUARE(far_tile.x, far_tile.y, 3), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(length(arrived) == 1 && (west_mob in arrived), "A moved mob was not filed in its new cell")

	east_mob.stat = DEAD
	var/list/dead = SSspatial_grid.players_in_range(SQUARE(edge_x, origin.y, 6), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(!length(dead), "A dead NPC was returned")
	east_mob.stat = CONSCIOUS

	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, east_tile)
	east_mob.forceMove(crate)
	var/list/inside = SSspatial_grid.players_in_range(SQUARE(edge_x, origin.y, 3), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(length(inside) == 1 && (east_mob in inside), "A mob inside a crate was lost")
	crate.forceMove(far_tile)
	SSspatial_grid.refresh_cell(east_mob)
	var/list/carried = SSspatial_grid.players_in_range(SQUARE(far_tile.x, far_tile.y, 3), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT((east_mob in carried) && (west_mob in carried), "A refresh did not follow the crate to its new cell")

	SSspatial_grid.untrack(west_mob, SPATIAL_GRID_TRACK_NPC)
	TEST_ASSERT(!west_mob.spatial_grid_flags && !west_mob.spatial_grid_cell && !(west_mob in SSspatial_grid.tracked), "An untracked mob kept its tracking state")
	var/list/after_untrack = SSspatial_grid.players_in_range(SQUARE(far_tile.x, far_tile.y, 3), z, SPATIAL_TEST_NPC_SCAN)
	TEST_ASSERT(length(after_untrack) == 1 && (east_mob in after_untrack), "An untracked mob was still returned")

	var/datum/spatial_grid_cell/east_cell = east_mob.spatial_grid_cell
	allocated -= east_mob
	qdel(east_mob)
	TEST_ASSERT(!(east_mob in SSspatial_grid.tracked) && !(east_mob in east_cell.npcs), "A deleted mob stayed in the grid")

#undef SPATIAL_TEST_NPC_SCAN

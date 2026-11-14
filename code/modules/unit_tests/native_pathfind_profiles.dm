/// The native pathfinder's human profile, secure doors and danger layer, on a throwaway z index
/datum/unit_test/native_pathfind_profiles
	var/static/test_z = 4242

/datum/unit_test/native_pathfind_profiles/proc/load_grid(width, height, list/overrides)
	var/list/cells = list()
	for(var/index in 1 to width * height)
		cells += "0"
	for(var/list/override in overrides)
		cells[(override[2] - 1) * width + override[1]] = override[3]
	return rust_xeno_pathfind_init_z("[test_z],[width],[height]", cells.Join(""))

/datum/unit_test/native_pathfind_profiles/proc/route(sx, sy, ex, ey, profile)
	return rust_xeno_pathfind_route("[test_z],[sx],[sy],[ex],[ey]", profile)

/datum/unit_test/native_pathfind_profiles/proc/path_length(path)
	return length(path) ? length(splittext(path, ";")) : 0

/datum/unit_test/native_pathfind_profiles/Run()
	if(!xeno_pathfind_profiles_available())
		log_world("native_pathfind_profiles skipped: the loaded rust-g predates route profiles, rebuild tools/rust/rust-g")
		return

	TEST_ASSERT_EQUAL(load_grid(10, 10, list()), "ok", "The test grid did not load")
	TEST_ASSERT_EQUAL(path_length(route(1, 1, 6, 6, XENO_PATHFIND_PROFILE_HUMAN)), 6, "The human route did not step diagonally")
	TEST_ASSERT_EQUAL(path_length(route(1, 1, 6, 6, XENO_PATHFIND_PROFILE_XENO)), 11, "The xeno route stopped being cardinal only")
	TEST_ASSERT_EQUAL(route(1, 1, 6, 6, null), route(1, 1, 6, 6, XENO_PATHFIND_PROFILE_XENO), "A route without a profile is not the xeno route")
	TEST_ASSERT_EQUAL(route(1, 1, 6, 6, 7), "", "An unknown profile did not fail closed")

	var/list/wall = list()
	for(var/y in 1 to 10)
		wall += list(list(5, y, "1"))
	var/list/window_wall = wall.Copy()
	window_wall[1] = list(5, 1, "3")
	TEST_ASSERT_EQUAL(load_grid(10, 10, window_wall), "ok", "The window grid did not load")
	TEST_ASSERT(length(route(4, 1, 6, 1, XENO_PATHFIND_PROFILE_XENO)), "A xeno should smash through the window")
	TEST_ASSERT_EQUAL(route(4, 1, 6, 1, XENO_PATHFIND_PROFILE_HUMAN), "", "A human route went through a breakable obstacle")

	var/list/secure_wall = wall.Copy()
	secure_wall[1] = list(5, 1, "5")
	secure_wall[9] = list(5, 9, "0")
	TEST_ASSERT_EQUAL(load_grid(10, 10, secure_wall), "ok", "The secure door grid did not load")
	TEST_ASSERT(findtext(route(4, 1, 6, 1, XENO_PATHFIND_PROFILE_XENO), "5,1"), "A xeno should force the secure door")
	var/human_path = route(4, 1, 6, 1, XENO_PATHFIND_PROFILE_HUMAN)
	TEST_ASSERT(findtext(human_path, "5,9") && !findtext(human_path, "5,1"), "A human should take the open gap over the secure door")
	rust_xeno_pathfind_update("[test_z],5,9,1")
	TEST_ASSERT(findtext(route(4, 1, 6, 1, XENO_PATHFIND_PROFILE_HUMAN), "5,1"), "A human should use the secure door when nothing else exists")

	TEST_ASSERT_EQUAL(load_grid(11, 11, list()), "ok", "The danger grid did not load")
	rust_xeno_pathfind_threat("[test_z],6,1,200")
	TEST_ASSERT(findtext(route(1, 1, 11, 1, XENO_PATHFIND_PROFILE_HUMAN), ";6,1;"), "Hive threat bent a human route")
	rust_xeno_pathfind_danger("[test_z],6,1,200,2")
	TEST_ASSERT(!findtext(route(1, 1, 11, 1, XENO_PATHFIND_PROFILE_HUMAN), ";6,1;"), "Contact danger did not bend a human route")
	for(var/cooling in 1 to 12)
		rust_xeno_pathfind_decay_danger()
	TEST_ASSERT(findtext(route(1, 1, 11, 1, XENO_PATHFIND_PROFILE_HUMAN), ";6,1;"), "Decayed danger still bends the route")

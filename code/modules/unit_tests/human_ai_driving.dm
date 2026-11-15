/// A squad with a long way to go gets into a van that is close: the leader drives it along the route, a mate rides along, and they get out when it gets there
/datum/unit_test/human_ai_driving
	var/datum/human_ai_brain/driver_brain
	var/datum/human_ai_brain/rider_brain
	var/obj/vehicle/multitile/van/truck

/datum/unit_test/human_ai_driving/Destroy()
	driver_brain = null
	rider_brain = null
	truck = null
	return ..()

/datum/unit_test/human_ai_driving/proc/van_ready()
	return truck.interior?.ready

/datum/unit_test/human_ai_driving/proc/driver_in()
	return !!driver_brain.ride_ref

/datum/unit_test/human_ai_driving/proc/rider_in()
	return !!rider_brain.ride_ref

/datum/unit_test/human_ai_driving/proc/halfway(turf/mark)
	return truck.x >= mark.x

/datum/unit_test/human_ai_driving/proc/both_out()
	return driver_brain.rides > 0 && rider_brain.rides > 0 && !driver_brain.ride_ref && !rider_brain.ride_ref

/datum/unit_test/human_ai_driving/Run()
	TEST_ASSERT(SSxeno_pathfinding.available, "The native pathfinder is not available, this scenario needs it")
	var/wall = ""
	var/floor = "#"
	for(var/column in 1 to 80)
		wall += "#"
	for(var/column in 1 to 78)
		floor += "."
	floor += "#"
	var/datum/human_ai_arena/road = new(list(wall, floor, floor, floor, floor, floor, floor, floor, wall), run_loc_floor_bottom_left)
	truck = allocate(/obj/vehicle/multitile/van, locate(road.origin_x + 4, road.origin_y + 3, road.z))
	TEST_ASSERT_NOTNULL(truck, "No van was made")
	truck.add_hardpoint(new /obj/item/hardpoint/support/locomotion)
	TEST_ASSERT(truck.move_delay < VEHICLE_SPEED_STATIC, "The van has wheels and cannot move")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(van_ready)), 30), "The interior of the van never came up")

	var/mob/living/carbon/human/leader = make_soldier(locate(road.origin_x + 8, road.origin_y + 5, road.z), armed = FALSE)
	var/mob/living/carbon/human/mate = make_soldier(locate(road.origin_x + 9, road.origin_y + 2, road.z), armed = FALSE)
	TEST_ASSERT(leader && mate, "The soldiers took no brain")
	driver_brain = leader.ai_brain
	rider_brain = mate.ai_brain
	driver_brain.suppress_error_log = TRUE
	rider_brain.suppress_error_log = TRUE
	TEST_ASSERT(!skillcheck(leader, SKILL_VEHICLE, SKILL_VEHICLE_SMALL), "The test soldier could drive from the start")
	create_human_ai_squad(list(leader, mate), leader, "test squad")

	var/turf/far = locate(road.origin_x + 72, road.origin_y + 4, road.z)
	var/datum/npc_order/move/go = new
	go.target_turf = far
	TEST_ASSERT(driver_brain.give_order(go), "The move command was refused")

	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(driver_in)), 40), "The leader never got into the van: [driver_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(driver_brain.ride_role, "driver", "The leader did not take the wheel")
	TEST_ASSERT_EQUAL(truck.seats[VEHICLE_DRIVER], leader, "The leader is not the driver of the van")
	TEST_ASSERT(leader.buckled, "The driver is not strapped into the seat")
	TEST_ASSERT(skillcheck(leader, SKILL_VEHICLE, SKILL_VEHICLE_SMALL), "The leader was not taught to drive")
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(rider_in)), 40), "The mate never got into the van: [rider_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(rider_brain.ride_role, "passenger", "The mate did not ride along")

	var/turf/middle = locate(road.origin_x + 36, road.origin_y + 3, road.z)
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(halfway), middle), 200), "The van did not get halfway, it is at [truck.x],[truck.y] after [driver_brain.drive_steps] steps, blocked [driver_brain.ride_blocked]: [driver_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(driver_brain.drive_steps > 20, "The van got there with [driver_brain.drive_steps] steps")

	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(both_out)), 200), "The riders did not get out, driver in [!!driver_brain.ride_ref], rider in [!!rider_brain.ride_ref], van at [truck.x],[truck.y]: [driver_brain.decision_log.Join(" | ")]")
	TEST_ASSERT(get_dist(get_turf(truck), far) <= HAI_RIDE_ARRIVE + 2, "The van stopped [get_dist(get_turf(truck), far)] tiles from the goal")
	var/turf/leader_turf = get_turf(leader)
	var/turf/mate_turf = get_turf(mate)
	TEST_ASSERT_EQUAL(leader_turf.z, road.z, "The driver did not get back out onto the road")
	TEST_ASSERT_EQUAL(mate_turf.z, road.z, "The passenger did not get back out onto the road")
	TEST_ASSERT(!leader.buckled, "The driver is still strapped in")
	TEST_ASSERT_NULL(truck.seats[VEHICLE_DRIVER], "Nobody is driving but the seat is not free")
	TEST_ASSERT_EQUAL(driver_brain.error_total, 0, "The driver threw errors: [driver_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(rider_brain.error_total, 0, "The passenger threw errors: [rider_brain.decision_log.Join(" | ")]")
	// The way on is on foot, to the goal that was given
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(order_over), go), 60), "The order never ended after the ride, the leader is at [leader.x],[leader.y]: [driver_brain.decision_log.Join(" | ")]")
	TEST_ASSERT_EQUAL(go.status, HAI_ORDER_DONE, "The order ended as [go.status] and not done")
	detach_human_ai(leader)
	detach_human_ai(mate)

/// A man who cannot be taught to drive does not take a vehicle that asks for more, and one with an enemy next to it does not take it at all
/datum/unit_test/human_ai_driving_refusals
	var/obj/vehicle/multitile/van/truck

/datum/unit_test/human_ai_driving_refusals/Destroy()
	truck = null
	return ..()

/datum/unit_test/human_ai_driving_refusals/proc/van_ready()
	return truck.interior?.ready

/datum/unit_test/human_ai_driving_refusals/Run()
	var/datum/human_ai_arena/road = new(list(
		"########################################",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"#......................................#",
		"########################################",
	), run_loc_floor_bottom_left)
	truck = allocate(/obj/vehicle/multitile/van, locate(road.origin_x + 4, road.origin_y + 2, road.z))
	TEST_ASSERT(ai_wait(CALLBACK(src, PROC_REF(van_ready)), 30), "The interior of the van never came up")
	var/mob/living/carbon/human/soldier = make_soldier(locate(road.origin_x + 8, road.origin_y + 3, road.z), armed = FALSE)
	var/datum/human_ai_brain/brain = soldier.ai_brain
	var/turf/far = locate(road.origin_x + 36, road.origin_y + 3, road.z)

	// A van without wheels is not worth getting into
	brain.next_ride_scan = 0
	TEST_ASSERT(!brain.find_ride(far), "A man wanted to drive a van that has no wheels")
	truck.add_hardpoint(new /obj/item/hardpoint/support/locomotion)

	TEST_ASSERT(brain.can_drive(truck), "A car asks for more than a man can pick up")
	truck.required_skill = SKILL_VEHICLE_LARGE
	TEST_ASSERT(!brain.can_drive(truck), "A man with no training can drive a vehicle for crewmen")
	TEST_ASSERT(!brain.learn_to_drive(truck), "A man was taught to drive a vehicle that asks for a crewman")
	truck.required_skill = SKILL_VEHICLE_SMALL

	brain.next_ride_scan = 0
	TEST_ASSERT(brain.find_ride(far), "A man with far to go did not find the van close by")
	TEST_ASSERT_EQUAL(brain.ride_pick_role, "driver", "The man would not drive")
	brain.next_ride_scan = 0
	TEST_ASSERT(!brain.find_ride(locate(road.origin_x + 12, road.origin_y + 3, road.z)), "A man with a short way to go wanted a van")

	// The vehicle of the other side, a locked one and a wreck are left alone
	truck.vehicle_faction = FACTION_UPP
	brain.next_ride_scan = 0
	TEST_ASSERT(!brain.find_ride(far), "A man wanted to drive the vehicle of the enemy")
	truck.vehicle_faction = FACTION_MARINE
	truck.door_locked = TRUE
	brain.next_ride_scan = 0
	TEST_ASSERT(!brain.find_ride(far), "A man tried a van that was locked")
	truck.door_locked = FALSE
	brain.next_ride_scan = 0
	TEST_ASSERT(brain.find_ride(far), "The way was not clear again")
	brain.skip_ride(truck)
	TEST_ASSERT(!brain.find_ride(far), "A vehicle that did not work out was taken again at once")

	// A man in the middle of a fight gets in no vehicles
	brain.ride_skipped = null
	brain.next_ride_scan = 0
	TEST_ASSERT(brain.ride_ready(), "The man was not free to take a ride")
	brain.ride_cooldown_until = world.time + 1 MINUTES
	TEST_ASSERT(!brain.ride_ready(), "A man who has just got out got back in at once")
	detach_human_ai(soldier)

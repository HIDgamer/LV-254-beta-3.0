/**
 * Riding and driving. A unit with a long way to go on foot and a vehicle of its own side close by gets in and takes the wheel, and the people of its squad get in
 * after it. It drives along the route the native pathfinder gives, never into something it can see is in the way, and everyone gets out when the vehicle gets
 * where it is going, when the enemy is near, when it is falling apart or when it cannot go on.
 */

/obj/vehicle/multitile
	/// Until when whoever rides along is to get out, set by the driver when the ride is over
	var/ai_unload_until = 0

/// The vehicle the body rides in, null when it is on its feet
/datum/human_ai_brain/proc/get_ride()
	RETURN_TYPE(/obj/vehicle/multitile)
	var/obj/vehicle/multitile/vehicle = ride_ref?.resolve()
	return (vehicle && !QDELETED(vehicle)) ? vehicle : null

/// Whether the thing, a man or anything else, is inside the interior of this vehicle
/obj/vehicle/multitile/proc/ai_contains(atom/movable/thing)
	var/turf/there = get_turf(thing)
	if(!there || !interior?.reservation)
		return FALSE
	var/list/bounds = interior.get_bound_turfs()
	var/turf/low = bounds[1]
	var/turf/high = bounds[2]
	return there.z == low.z && there.x >= low.x && there.x <= high.x && there.y >= low.y && there.y <= high.y

/// The vehicle somebody is inside of, null when they are in none
/proc/human_ai_vehicle_of(atom/movable/thing)
	RETURN_TYPE(/obj/vehicle/multitile)
	if(!thing || !length(GLOB.all_multi_vehicles))
		return null
	for(var/obj/vehicle/multitile/vehicle as anything in GLOB.all_multi_vehicles)
		if(!QDELETED(vehicle) && vehicle.ai_contains(thing))
			return vehicle
	return null

/// Whether the body is inside the interior of the vehicle
/datum/human_ai_brain/proc/is_inside(obj/vehicle/multitile/vehicle)
	return vehicle.ai_contains(body)

/// Whoever the body follows, a player or another unit, null when it follows nobody
/datum/human_ai_brain/proc/followed_mob()
	RETURN_TYPE(/mob/living)
	var/atom/movable/leader = get_follow_target()
	if(!leader && current_order?.id == "follow" && current_order.status == HAI_ORDER_ACTIVE)
		leader = current_order.get_target()
	return (isliving(leader) && !QDELETED(leader)) ? leader : null

/// The turf outside the vehicle at the way in that is nearest to the body, where it has to stand to get in
/datum/human_ai_brain/proc/entrance_turf_of(obj/vehicle/multitile/vehicle)
	RETURN_TYPE(/turf)
	var/turf/best
	var/best_distance = INFINITY
	for(var/name in vehicle.entrances)
		var/list/offset = vehicle.entrances[name]
		var/turf/spot = locate(vehicle.x + offset[1], vehicle.y + offset[2], vehicle.z)
		if(!spot || spot.density)
			continue
		var/distance = get_dist(body, spot)
		if(distance < best_distance)
			best = spot
			best_distance = distance
	return best

/// Whether the body can take the wheel: a car does not ask for more than a man can pick up, anything bigger needs a crewman
/datum/human_ai_brain/proc/can_drive(obj/vehicle/multitile/vehicle)
	return vehicle.required_skill <= SKILL_VEHICLE_SMALL || skillcheck(body, SKILL_VEHICLE, vehicle.required_skill)

/// Teaches the body enough to drive a car if it does not know it, false when the vehicle asks for more than that
/datum/human_ai_brain/proc/learn_to_drive(obj/vehicle/multitile/vehicle)
	if(skillcheck(body, SKILL_VEHICLE, vehicle.required_skill))
		return TRUE
	if(vehicle.required_skill > SKILL_VEHICLE_SMALL)
		return FALSE
	if(!body.skills)
		body.skills = new /datum/skills()
	body.skills.set_skill(SKILL_VEHICLE, SKILL_VEHICLE_SMALL)
	return TRUE

/// Where the body is headed on foot, null when nowhere in particular
/datum/human_ai_brain/proc/travel_goal()
	RETURN_TYPE(/turf)
	if(current_order && current_order.status == HAI_ORDER_ACTIVE && current_order.id == "move" && current_order.dest)
		return current_order.dest
	if(waypoint)
		return waypoint
	var/atom/movable/leader = get_follow_target()
	return leader ? get_turf(leader) : null

/// Whether the body is free to look for a ride
/datum/human_ai_brain/proc/ride_ready()
	if(ride_ref || is_civilian() || role?.passive || role?.maintains || surrendered || broken_kind || leash_center || stopped)
		return FALSE
	if(world.time < ride_cooldown_until || is_acting() || body.stat != CONSCIOUS || body.buckled || body.body_position != STANDING_UP)
		return FALSE
	if(get_target() || suppressed() || body.on_fire || reload_phase != HAI_RELOAD_NONE)
		return FALSE
	return TRUE

/// Whether the vehicle is one this body may take a place in
/datum/human_ai_brain/proc/ride_allowed(obj/vehicle/multitile/vehicle, following = FALSE)
	if(QDELETED(vehicle) || vehicle.health <= 0 || vehicle.z != body.z || !vehicle.interior?.ready || vehicle.towed_by || vehicle.door_locked)
		return FALSE
	// Whoever follows somebody in goes wherever that one does, wheels or not, and is not put off by having got out of it before
	if(!following)
		// A vehicle without wheels or tracks is a box, nobody gets anywhere in it
		if(vehicle.move_delay >= VEHICLE_SPEED_STATIC)
			return FALSE
		if(ride_skipped?[REF(vehicle)] > world.time)
			return FALSE
	return !vehicle_is_enemy(vehicle)

/**
 * Looks for a vehicle close by: an empty one that can be driven to the goal, which the body drives, or one that a mate of its squad drives, which it rides in.
 * Remembered for a few seconds. Returns TRUE when there is one to get into, see ride_pick_ref and ride_pick_role.
 */
/datum/human_ai_brain/proc/find_ride(turf/goal)
	if(world.time < next_ride_scan)
		return !!ride_pick_ref?.resolve()
	var/mob/living/leader = followed_mob()
	next_ride_scan = world.time + (leader ? HAI_RIDE_FOLLOW_SCAN_GAP : HAI_RIDE_SCAN_GAP)
	ride_pick_ref = null
	ride_pick_role = null
	if(!length(GLOB.all_multi_vehicles))
		return FALSE
	// The one being followed got into a vehicle: that is where the way on goes, whether the leader drives it or not
	var/obj/vehicle/multitile/leader_ride = leader ? human_ai_vehicle_of(leader) : null
	if(leader_ride && get_dist(body, leader_ride) <= HAI_RIDE_SCAN_RANGE && ride_allowed(leader_ride, TRUE) && leader_ride.interior.passengers_taken_slots < leader_ride.interior.passengers_slots)
		ride_pick_ref = WEAKREF(leader_ride)
		ride_pick_role = "passenger"
		return TRUE
	var/far_goal = goal && goal.z == body.z && get_dist(body, goal) >= HAI_RIDE_MIN_DISTANCE
	var/obj/vehicle/multitile/best
	var/best_role
	var/best_distance = INFINITY
	for(var/obj/vehicle/multitile/vehicle as anything in GLOB.all_multi_vehicles)
		var/distance = get_dist(body, vehicle)
		if(distance > HAI_RIDE_SCAN_RANGE || distance >= best_distance || !ride_allowed(vehicle))
			continue
		var/mob/living/carbon/human/pilot = vehicle.seats[VEHICLE_DRIVER]
		var/role
		if(!pilot)
			if(!far_goal || vehicle.clamped || !can_drive(vehicle))
				continue
			role = "driver"
		else
			if(!istype(pilot) || !pilot.ai_brain || !squad || pilot.ai_brain.squad != squad)
				continue
			if(vehicle.interior.passengers_taken_slots >= vehicle.interior.passengers_slots)
				continue
			role = "passenger"
		best = vehicle
		best_role = role
		best_distance = distance
	if(!best)
		return FALSE
	ride_pick_ref = WEAKREF(best)
	ride_pick_role = best_role
	return TRUE

/// Leaves the vehicle alone for a while, for when getting into it did not work out
/datum/human_ai_brain/proc/skip_ride(obj/vehicle/multitile/vehicle)
	if(vehicle)
		LAZYSET(ride_skipped, REF(vehicle), world.time + HAI_RIDE_SKIP)
	ride_pick_ref = null
	ride_pick_role = null
	next_ride_scan = world.time + HAI_RIDE_SCAN_GAP

/// Every seat of the kind in the vehicle that nobody sits in
/proc/human_ai_free_seats(obj/vehicle/multitile/vehicle, seat_type)
	var/list/found = list()
	if(!vehicle.interior?.reservation)
		return found
	var/list/bounds = vehicle.interior.get_bound_turfs()
	for(var/turf/spot as anything in block(bounds[1], bounds[2]))
		for(var/obj/structure/bed/seat in spot)
			if(istype(seat, seat_type) && !seat.buckled_mob)
				found += seat
	return found

/// Climbs in at the entrance the body stands at and takes a seat: the driver's when it is to drive, otherwise any that is free
/datum/human_ai_brain/proc/board_vehicle(obj/vehicle/multitile/vehicle, role, turf/goal)
	if(QDELETED(vehicle) || QDELETED(body) || stopped)
		acting_until = 0
		return
	body.face_atom(vehicle)
	if(role == "driver")
		learn_to_drive(vehicle)
	vehicle.handle_player_entrance(body)
	acting_until = 0
	if(QDELETED(body) || stopped)
		return
	if(QDELETED(vehicle) || !is_inside(vehicle))
		log_decision("could not get into [vehicle]")
		skip_ride(vehicle)
		return
	var/obj/structure/bed/seat
	if(role == "driver")
		for(var/obj/structure/bed/free in human_ai_free_seats(vehicle, /obj/structure/bed/chair/comfy/vehicle/driver))
			seat = free
			break
	if(!seat)
		for(var/obj/structure/bed/free in human_ai_free_seats(vehicle, /obj/structure/bed/chair/vehicle))
			var/obj/structure/bed/chair/vehicle/bench = free
			if(!bench.broken)
				seat = free
				break
	if(seat)
		body.forceMove(get_turf(seat))
		seat.do_buckle(body, body)
		if(body.buckled != seat)
			log_decision("could not take the seat in [vehicle]")
	var/driving = (role == "driver" && vehicle.seats[VEHICLE_DRIVER] == body)
	ride_ref = WEAKREF(vehicle)
	ride_role = driving ? "driver" : "passenger"
	ride_goal = goal
	ride_path = null
	ride_blocked = 0
	ride_started = world.time
	ride_orphaned_since = 0
	ride_wait_until = (driving && squad) ? world.time + HAI_RIDE_WAIT : 0
	// Somebody who follows a man into a vehicle rides for as long as that man does
	var/mob/living/leader = followed_mob()
	ride_leader_ref = (!driving && leader && vehicle.ai_contains(leader)) ? WEAKREF(leader) : null
	ride_rejoin = FALSE
	rides++
	reset_progress()
	log_decision("got into [vehicle] as [ride_role]")

/// Gets out of the vehicle, whatever it takes, and goes back to being a man on foot
/datum/human_ai_brain/proc/leave_vehicle(obj/vehicle/multitile/vehicle, reason)
	log_decision("got out of [vehicle]: [reason]")
	if(ride_role == "driver")
		vehicle.ai_unload_until = max(vehicle.ai_unload_until, world.time + HAI_RIDE_UNLOAD_TIME)
	var/obj/seat = body.buckled
	if(seat)
		seat.manual_unbuckle(body)
	var/exited = FALSE
	if(vehicle.interior)
		exited = vehicle.interior.exit(body, entrance_turf_of(vehicle))
		if(!exited)
			exited = vehicle.interior.exit(body, null)
	if(!exited && is_inside(vehicle))
		body.forceMove(get_turf(vehicle))
	end_ride(vehicle)

/// The ride is over, nothing is left of it but the memory that the vehicle is not worth getting back into for a while
/datum/human_ai_brain/proc/end_ride(obj/vehicle/multitile/vehicle)
	// Getting out because the one being followed did is no reason to leave that vehicle alone, the leader may get back in
	if(vehicle && !ride_rejoin)
		LAZYSET(ride_skipped, REF(vehicle), world.time + HAI_RIDE_SKIP)
	ride_ref = null
	ride_leader_ref = null
	ride_role = null
	ride_goal = null
	ride_path = null
	ride_blocked = 0
	ride_cooldown_until = world.time + (ride_rejoin ? HAI_RIDE_REJOIN : HAI_RIDE_REBOARD)
	ride_rejoin = FALSE
	next_step_time = 0
	reset_progress()

/// The first enemy in sight of the vehicle, null when the road is clear
/datum/human_ai_brain/proc/ride_contact(obj/vehicle/multitile/vehicle)
	RETURN_TYPE(/mob/living)
	for(var/mob/living/candidate in view(HAI_RIDE_CONTACT_RANGE, get_turf(vehicle)))
		if(candidate.stat == DEAD || candidate == body)
			continue
		if(get_disposition(candidate) >= HAI_DISP_HOSTILE)
			return candidate
	return null

/// Why the ride is over, null when it goes on
/datum/human_ai_brain/proc/unload_reason(obj/vehicle/multitile/vehicle)
	if(world.time >= ride_started + HAI_RIDE_MAX_TIME)
		return "the ride took too long"
	if(world.time < vehicle.ai_unload_until)
		return "everybody out"
	if(vehicle.health <= 0 || vehicle.health < initial(vehicle.health) * HAI_RIDE_WRECK)
		return "the vehicle is falling apart"
	if(ride_role != "driver")
		// Along with somebody being followed, the ride is over when that one's is
		if(ride_leader_ref)
			var/mob/living/leader = ride_leader_ref.resolve()
			if(!leader || QDELETED(leader) || leader.stat == DEAD || !vehicle.ai_contains(leader))
				ride_rejoin = TRUE
				return "the one being followed got out"
			return null
		var/mob/living/pilot = vehicle.seats[VEHICLE_DRIVER]
		if(!pilot || pilot.stat != CONSCIOUS)
			if(!ride_orphaned_since)
				ride_orphaned_since = world.time
			else if(world.time >= ride_orphaned_since + HAI_RIDE_ORPHAN)
				return "nobody is driving"
		else
			ride_orphaned_since = 0
		return null
	if(world.time >= next_ride_alarm)
		next_ride_alarm = world.time + HAI_RIDE_ALARM_GAP
		var/mob/living/enemy = ride_contact(vehicle)
		if(enemy)
			return "[enemy] is close"
	if(!ride_goal || get_dist(get_turf(vehicle), ride_goal) <= HAI_RIDE_ARRIVE)
		return "arrived"
	if(ride_blocked >= HAI_RIDE_STUCK)
		return "the way is blocked"
	return null

/// One tick of a ride: leave if the ride is over, drive if the body is the driver
/datum/human_ai_brain/proc/ride_think()
	var/obj/vehicle/multitile/vehicle = get_ride()
	if(!vehicle || !is_inside(vehicle))
		end_ride(vehicle)
		return
	var/reason = unload_reason(vehicle)
	if(reason)
		leave_vehicle(vehicle, reason)
		return
	if(ride_role == "driver")
		drive_step(vehicle)

/// The direction along the grid that gets from one turf toward another
/proc/human_ai_cardinal_toward(turf/origin, turf/target)
	var/delta_x = target.x - origin.x
	var/delta_y = target.y - origin.y
	if(!delta_x && !delta_y)
		return 0
	if(abs(delta_x) >= abs(delta_y))
		return delta_x > 0 ? EAST : WEST
	return delta_y > 0 ? NORTH : SOUTH

/// Whether the vehicle can take a step that way without running into anything, which is what can_move says without the crash it causes for those inside
/datum/human_ai_brain/proc/ride_clear(obj/vehicle/multitile/vehicle, direction)
	var/bound_x_tiles = vehicle.bound_x / world.icon_size
	var/bound_y_tiles = vehicle.bound_y / world.icon_size
	var/turf/min_turf = locate(vehicle.x + bound_x_tiles, vehicle.y + bound_y_tiles, vehicle.z)
	var/bound_width_tiles = vehicle.bound_width / world.icon_size
	var/bound_height_tiles = vehicle.bound_height / world.icon_size
	var/list/old_turfs = CORNER_BLOCK(min_turf, bound_width_tiles, bound_height_tiles)
	var/turf/new_loc = get_step(vehicle, direction)
	if(!new_loc)
		return FALSE
	min_turf = locate(new_loc.x + bound_x_tiles, new_loc.y + bound_y_tiles, vehicle.z)
	for(var/turf/spot as anything in CORNER_BLOCK(min_turf, bound_width_tiles, bound_height_tiles))
		if(spot in old_turfs)
			continue
		if(!spot.Enter(vehicle, vehicle.towing))
			return FALSE
	return TRUE

/// One move of the vehicle toward the goal along the route of the native pathfinder
/datum/human_ai_brain/proc/drive_step(obj/vehicle/multitile/vehicle)
	if(world.time < ride_wait_until || world.time < vehicle.next_move || !ride_goal)
		return
	var/turf/here = get_turf(vehicle)
	if(!here)
		return
	while(length(ride_path) && (ride_path[1] == here || (length(ride_path) > 1 && get_dist(here, ride_path[1]) <= 1)))
		ride_path.Cut(1, 2)
	if(!length(ride_path) || world.time > ride_path_at + HAI_RIDE_PATH_AGE)
		if(!SShuman_ai.take_path_budget())
			return
		ride_path = request_path(here, ride_goal)
		ride_path_at = world.time
		if(!length(ride_path))
			ride_path = null
			ride_blocked++
			return
	var/turf/next_turf = ride_path[1]
	var/direction = human_ai_cardinal_toward(here, next_turf)
	if(!direction)
		ride_path.Cut(1, 2)
		return
	if(!ride_clear(vehicle, direction))
		ride_blocked++
		ride_path = null
		if(SSxeno_pathfinding?.available && xeno_pathfind_profiles_available())
			var/turf/blocked_turf = get_step(here, direction)
			if(blocked_turf)
				rust_xeno_pathfind_danger("[blocked_turf.z],[blocked_turf.x],[blocked_turf.y],[HAI_HAZARD_PATH_DANGER],1")
		return
	if(vehicle.relaymove(body, direction))
		ride_blocked = 0
		drive_steps++
	else
		ride_blocked++

/// A man on foot with far to go gets into a vehicle of his side that is close, or into the one his squad is driving
/datum/human_ai_action/board_vehicle
	id = "board_vehicle"
	conflicts = HAI_LIMB_HANDS|HAI_LIMB_LEGS
	intents = list(HAI_INTENT_IDLE, HAI_INTENT_ALERT, HAI_INTENT_ORDERED)

/datum/human_ai_action/board_vehicle/get_weight(datum/human_ai_brain/brain)
	if(!brain.ride_ready())
		return 0
	return brain.find_ride(brain.travel_goal()) ? 108 : 0

/datum/human_ai_action/board_vehicle/trigger(datum/human_ai_brain/brain)
	var/obj/vehicle/multitile/vehicle = brain.ride_pick_ref?.resolve()
	var/role = brain.ride_pick_role
	if(!vehicle || QDELETED(vehicle) || !role)
		return FALSE
	var/turf/door = brain.entrance_turf_of(vehicle)
	if(!door)
		brain.skip_ride(vehicle)
		return FALSE
	if(get_turf(brain.body) != door)
		if(brain.move_to(door, 0, get_dist(brain.body, door) > HAI_SPRINT_MIN_DISTANCE))
			return TRUE
		if(brain.move_state != HAI_MOVE_ARRIVED)
			brain.log_decision("cannot get to the door of [vehicle]")
			brain.skip_ride(vehicle)
			return FALSE
	brain.acting_until = world.time + 10 SECONDS
	INVOKE_ASYNC(brain, TYPE_PROC_REF(/datum/human_ai_brain, board_vehicle), vehicle, role, brain.travel_goal())
	return TRUE

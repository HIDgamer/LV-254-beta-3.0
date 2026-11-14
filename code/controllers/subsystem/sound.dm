SUBSYSTEM_DEF(sound)
	name   = "Sound"
	flags   = SS_POST_FIRE_TIMING | SS_NO_INIT
	wait   = 2
	priority   = SS_PRIORITY_SOUND
	runlevels   = RUNLEVELS_DEFAULT|RUNLEVEL_LOBBY

	var/list/template_queue = list() // Full Template Queue
	var/list/run_queue = list() // Queue subset being processed during this tick
	var/list/run_hearers = null // Hearers for currently being processed template

	var/list/listener_clients = list() // Clients that can hear sounds, as of this fire
	var/list/listener_x = list()
	var/list/listener_y = list()
	var/list/listener_z = list()

/datum/controller/subsystem/sound/fire(resumed = FALSE)
	if(!resumed) // Controller first firing for this tick
		snapshot_listeners()
		run_queue = template_queue.Copy()
		template_queue = list()
		run_hearers = null // null explicitely indicates we need to do ranging!

	for(var/datum/sound_template/run_template in run_queue)
		if(!run_hearers) // Initialize for handling next template
			run_hearers = run_queue[run_template] // get base hearers
			if(run_template.range) // ranging
				run_hearers |= run_template.get_hearers()
			for(var/list/rect as anything in run_template.interior_rects)
				run_hearers |= listeners_in_box(rect[1], rect[2], rect[3] * 0.5, rect[4] * 0.5, rect[5])
			if(MC_TICK_CHECK)
				return
		while(length(run_hearers)) // Output sound to hearers
			var/client/C = run_hearers[length(run_hearers)]
			run_hearers.len--
			if(C && C.soundOutput)
				C.soundOutput.process_sound(run_template)
			if(MC_TICK_CHECK)
				return
		run_queue.Remove(run_template) // Everyone that had to get this sound got it. Bye, template
		run_hearers = null // Reset so we know next one is new

/// Records where every listening client is right now, hearers are found from this instead of the stale quadtree
/datum/controller/subsystem/sound/proc/snapshot_listeners()
	listener_clients = list()
	listener_x = list()
	listener_y = list()
	listener_z = list()
	for(var/client/listener as anything in GLOB.clients)
		if(!listener.soundOutput)
			continue
		var/turf/listener_turf = get_turf(listener.mob)
		if(!listener_turf)
			continue
		listener_clients += listener
		listener_x += listener_turf.x
		listener_y += listener_turf.y
		listener_z += listener_turf.z

/// Listening clients within half_x and half_y tiles of the point on the z level
/datum/controller/subsystem/sound/proc/listeners_in_box(center_x, center_y, half_x, half_y, z_level)
	. = list()
	for(var/index in 1 to length(listener_clients))
		if(listener_z[index] != z_level)
			continue
		if(abs(listener_x[index] - center_x) > half_x || abs(listener_y[index] - center_y) > half_y)
			continue
		. += listener_clients[index]

/datum/controller/subsystem/sound/proc/queue(datum/sound_template/template, list/client/hearers, list/datum/interior/extra_interiors)
	if(!hearers)
		hearers = list()
	if(extra_interiors && SSmapping)
		for(var/datum/interior/VI in extra_interiors)
			if(VI?.ready)
				var/list/bounds = VI.get_middle_coords()
				if(length(bounds) >= 3)
					LAZYADD(template.interior_rects, list(list(bounds[1], bounds[2], VI.map_template.width, VI.map_template.height, bounds[3])))
	template_queue[template] = hearers

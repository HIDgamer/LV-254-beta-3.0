/// The surface this turf sounds like underfoot
/turf/open/proc/get_footstep_surface()
	return get_footstep_surface_for(type)

/// The surface a turf type sounds like, cached per type
/proc/get_footstep_surface_for(turf_type)
	var/surface = GLOB.footstep_surface_cache[turf_type]
	if(isnull(surface))
		surface = resolve_footstep_surface(turf_type)
		GLOB.footstep_surface_cache[turf_type] = surface
	return surface

/proc/resolve_footstep_surface(turf_type)
	var/path = lowertext("[turf_type]")
	for(var/keyword in GLOB.footstep_surface_keywords)
		if(findtext(path, keyword))
			return GLOB.footstep_surface_keywords[keyword]
	if(ispath(turf_type, /turf/open/floor) || ispath(turf_type, /turf/open/hybrisa))
		return FOOTSTEP_FLOOR
	return FOOTSTEP_SAND

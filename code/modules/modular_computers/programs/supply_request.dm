#define SUPPLY_REQUEST_MAX_PENDING 3
#define SUPPLY_REQUEST_MAX_PACKS 10
#define SUPPLY_REQUEST_MAX_REASON 200

/// Orders supplies remotely, the request still needs approval at an ASRS console
/datum/computer_file/program/supply_request
	filename = "supply_request"
	filedesc = "Supply Request"
	extended_desc = "Request supplies remotely. Requests wait in the ASRS queue until approved there."
	tgui_id = "NtosSupplyRequest"
	program_icon = "truck"
	program_open_overlay = "shipping"
	run_access = list(ACCESS_MARINE_CARGO)

	var/list/current_order = list()
	var/system_message
	/// Submitted orders as list(ordernum, weakref, reason)
	var/list/submitted = list()

/datum/computer_file/program/supply_request/proc/is_orderable(datum/supply_packs/pack)
	if(!pack?.buyable || pack.contraband)
		return FALSE
	if(isnull(pack.contains) && isnull(pack.containertype))
		return FALSE
	return !!(pack.group in GLOB.supply_controller.all_supply_groups)

/datum/computer_file/program/supply_request/proc/get_order_status(list/entry)
	var/datum/weakref/order_ref = entry["ref"]
	var/datum/supply_order/order = order_ref?.resolve()
	if(!order)
		return "Denied"
	if(order in GLOB.supply_controller.requestlist)
		return "Awaiting approval"
	if(order in GLOB.supply_controller.shoppinglist)
		return "Approved by [order.approvedby]"
	return "Delivered"

/datum/computer_file/program/supply_request/proc/count_awaiting()
	. = 0
	for(var/list/entry as anything in submitted)
		var/datum/weakref/order_ref = entry["ref"]
		var/datum/supply_order/order = order_ref?.resolve()
		if(order && (order in GLOB.supply_controller.requestlist))
			.++

/datum/computer_file/program/supply_request/ui_static_data(mob/user)
	var/list/data = list()
	data["categories"] = GLOB.supply_controller.all_supply_groups
	var/list/packs = list()
	for(var/pack_type in GLOB.supply_packs_datums)
		var/datum/supply_packs/pack = GLOB.supply_packs_datums[pack_type]
		if(!is_orderable(pack))
			continue
		var/list/contents = list()
		var/list/counts = list()
		for(var/atom/contents_type as anything in pack.contains)
			counts[contents_type::name]++
		for(var/item_name in counts)
			contents += counts[item_name] > 1 ? "[counts[item_name]]x [item_name]" : item_name
		packs += list(list(
			"name" = pack.name,
			"cost" = pack.cost,
			"category" = pack.group,
			"type" = "[pack.type]",
			"contents" = contents,
		))
	data["packs"] = packs
	return data

/datum/computer_file/program/supply_request/ui_data(mob/user)
	var/list/data = list()
	data["points"] = GLOB.supply_controller.points
	data["message"] = system_message
	data["max_pack_quantity"] = SUPPLY_REQUEST_MAX_PACKS
	var/list/cart = list()
	var/cart_cost = 0
	for(var/pack_type in current_order)
		var/datum/supply_packs/pack = GLOB.supply_packs_datums[pack_type]
		cart += list(list("type" = "[pack_type]", "name" = pack.name, "cost" = pack.cost, "quantity" = current_order[pack_type]))
		cart_cost += pack.cost * current_order[pack_type]
	data["cart"] = cart
	data["cart_cost"] = cart_cost
	var/list/orders = list()
	for(var/index = length(submitted), index >= 1 && length(orders) < 5, index--)
		var/list/entry = submitted[index]
		orders += list(list("num" = entry["num"], "reason" = entry["reason"], "status" = get_order_status(entry)))
	data["orders"] = orders
	return data

/datum/computer_file/program/supply_request/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("adjust_cart")
			var/pack_type = text2path(params["pack"])
			var/datum/supply_packs/pack = GLOB.supply_packs_datums[pack_type]
			if(!is_orderable(pack))
				return
			var/quantity = clamp(floor(text2num(params["to"])), 0, SUPPLY_REQUEST_MAX_PACKS)
			if(quantity <= 0)
				current_order -= pack_type
			else
				current_order[pack_type] = quantity
			return TRUE
		if("discard_cart")
			current_order = list()
			return TRUE
		if("submit")
			return submit_order(ui.user, params["reason"])
		if("acknowledged")
			system_message = null
			return TRUE

/datum/computer_file/program/supply_request/proc/submit_order(mob/user, reason)
	reason = strip_html(reason, SUPPLY_REQUEST_MAX_REASON)
	if(!length(reason))
		system_message = "A reason is required."
		return TRUE
	if(!length(current_order))
		system_message = "Your cart is empty."
		return TRUE
	if(count_awaiting() >= SUPPLY_REQUEST_MAX_PENDING)
		system_message = "You already have [SUPPLY_REQUEST_MAX_PENDING] requests awaiting approval."
		return TRUE
	var/list/to_order = list()
	for(var/pack_type in current_order)
		var/datum/supply_packs/pack = GLOB.supply_packs_datums[pack_type]
		if(!is_orderable(pack))
			continue
		for(var/iterator in 1 to current_order[pack_type])
			to_order += pack
	if(!length(to_order))
		current_order = list()
		return TRUE

	var/datum/supply_order/supply_order = new
	supply_order.ordernum = GLOB.supply_controller.ordernum++
	supply_order.objects = to_order
	supply_order.reason = reason
	supply_order.orderedby = computer.computer_id_slot?.registered_name || computer.saved_identification
	supply_order.orderedby_rank = computer.computer_id_slot?.assignment || computer.saved_job
	GLOB.supply_controller.requestlist += supply_order
	submitted += list(list("num" = supply_order.ordernum, "ref" = WEAKREF(supply_order), "reason" = reason))
	current_order = list()
	system_message = "Request #[supply_order.ordernum] sent. It needs approval at the ASRS console."
	notify_asrs_consoles(supply_order)
	return TRUE

/datum/computer_file/program/supply_request/proc/notify_asrs_consoles(datum/supply_order/supply_order)
	for(var/obj/structure/machinery/computer/supply/asrs/console in GLOB.supply_controller.bound_supply_computer_list)
		playsound(console, 'sound/machines/pda_ping.ogg', 25, FALSE)
		console.visible_message(SPAN_NOTICE("[console] pings: remote supply request #[supply_order.ordernum]."))
		SStgui.update_uis(console)

#undef SUPPLY_REQUEST_MAX_PENDING
#undef SUPPLY_REQUEST_MAX_PACKS
#undef SUPPLY_REQUEST_MAX_REASON

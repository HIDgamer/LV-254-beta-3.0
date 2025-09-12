GLOBAL_LIST_INIT(cm_vending_gear_clown, list(
		list("SPECIALIST KITS (CHOOSE 1)", 0, null, null, null),
		list("Mastermind", 0, /obj/item/storage/box/spec/clown/mastermind, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_REGULAR),
		list("Technician", 0, /obj/item/storage/box/spec/clown/technician, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_REGULAR),
		list("Enforcer", 0, /obj/item/storage/box/spec/clown/enforcer, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_REGULAR),
		list("Fugitive", 0, /obj/item/storage/box/spec/clown/fugitive, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_REGULAR),
		list("Ghost", 0, /obj/item/storage/box/spec/clown/ghost, MARINE_CAN_BUY_ESSENTIALS, VENDOR_ITEM_REGULAR),

		list("PRIMARY AMMUNITION BOXES (CHOOSE 1)", 0, null, null, null),
		list("M16 Magazine Box", 0, /obj/item/ammo_box/magazine/M16, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),
		list("MAR-40 Magazine Box", 0, /obj/item/ammo_box/magazine/MAR40, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),
		list("M60 Magazine Box", 0, /obj/item/ammo_box/magazine/M60, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),
		list("P90 Magazine Box", 0, /obj/item/ammo_box/magazine/p90, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),
		list("Shotgun Slugs", 0, /obj/item/ammo_magazine/shotgun/slugs, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),
		list("Flechette Shells", 0, /obj/item/ammo_magazine/shotgun/flechette, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),
		list("Flechette Shells", 0, /obj/item/ammo_magazine/shotgun, MARINE_CAN_BUY_AMMO_PRIMARY, VENDOR_ITEM_REGULAR),

		list("SIDEARM AMMUNITION BOXES (CHOOSE 1)", 0, null, null, null),
		list("M1911 Magazine Box (.45)", 0, /obj/item/ammo_box/magazine/m1911, MARINE_CAN_BUY_AMMO_SECONDARY, VENDOR_ITEM_REGULAR),
		list("Desert Eagle Magazine Box (.50)", 0, /obj/item/ammo_box/magazine/heavy, MARINE_CAN_BUY_AMMO_SECONDARY, VENDOR_ITEM_REGULAR),

		list("EXPLOSIVES", 0, null, null, null),
		list("40mm HE Impact Grenade", 15, /obj/item/explosive/grenade/high_explosive/impact, null, VENDOR_ITEM_REGULAR),
		list("40mm HE Incendiary Grenade", 15, /obj/item/explosive/grenade/incendiary/impact, null, VENDOR_ITEM_REGULAR),
		list("40mm HE Buckshot Grenade", 15, /obj/item/explosive/grenade/high_explosive/airburst/buckshot, null, VENDOR_ITEM_REGULAR),
		list("M15 Frag Grenade Packet (x3 grenades)", 45, /obj/item/storage/box/packet/m15, null, VENDOR_ITEM_REGULAR),
))

/obj/structure/machinery/cm_vending/gear/clown
	name = "\improper Gang Equipment Rack"
	desc = "An automated weapons rack for the Clown Gang. Features specialists kits and backup supplies."
	req_access = list(ACCESS_ILLEGAL_CLOWN)
	vendor_role = list(JOB_GANGSTER_CLOWN)
	icon_state = "gear"
	use_snowflake_points = TRUE

/obj/structure/machinery/cm_vending/gear/clown/get_listed_products(mob/user)
	return GLOB.cm_vending_gear_clown

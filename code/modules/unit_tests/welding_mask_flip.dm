/// A reinforced welding mask has no hinge and no sprite for being flipped up, nobody, the AI included, flips it into a missing icon state
/datum/unit_test/welding_mask_flip

/datum/unit_test/welding_mask_flip/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/clothing/head/welding/tagrilla/reinforced = allocate(/obj/item/clothing/head/welding/tagrilla)
	dress(wearer, reinforced, WEAR_HEAD)
	TEST_ASSERT_EQUAL(wearer.head, reinforced, "The reinforced mask is not on the head")
	var/mob/old_usr = usr
	usr = wearer
	reinforced.toggle()
	usr = old_usr
	TEST_ASSERT(!reinforced.up, "The reinforced welding mask was flipped up")
	TEST_ASSERT_EQUAL(reinforced.icon_state, "tagrilla", "The reinforced welding mask took an icon state that does not exist")

	// An ordinary mask still flips, to a state that exists
	var/mob/living/carbon/human/welder = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/clothing/head/welding/plain = allocate(/obj/item/clothing/head/welding)
	dress(welder, plain, WEAR_HEAD)
	TEST_ASSERT_EQUAL(welder.head, plain, "The welding mask is not on the head")
	usr = welder
	plain.toggle()
	usr = old_usr
	TEST_ASSERT(plain.up, "An ordinary welding mask did not flip up")
	TEST_ASSERT_EQUAL(plain.icon_state, "weldingup", "An ordinary welding mask flipped to the wrong state")

	// The AI leaves the reinforced one alone
	TEST_ASSERT(attach_human_ai(wearer), "The brain would not attach")
	TEST_ASSERT_NULL(wearer.ai_brain.weld_gear(), "The AI took the reinforced welding mask for gear it can flip")
	detach_human_ai(wearer)

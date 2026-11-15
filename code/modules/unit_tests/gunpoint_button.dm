/// Players get a Hold Up button on the HUD that lowers the aim when it is pressed while someone is held
/datum/unit_test/gunpoint_button

/datum/unit_test/gunpoint_button/Run()
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/captive = allocate(/mob/living/carbon/human, locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	var/obj/item/weapon/gun/pistol/m4a3/pistol = allocate(/obj/item/weapon/gun/pistol/m4a3, shooter)
	TEST_ASSERT(shooter.put_in_hands(pistol, FALSE), "The pistol could not be put in the shooter's hand")
	var/datum/action/human_action/hold_up/button = give_action(shooter, /datum/action/human_action/hold_up)
	TEST_ASSERT(button, "The Hold Up button was not given")
	TEST_ASSERT_EQUAL(give_action(shooter, /datum/action/human_action/hold_up), button, "A second Hold Up button was made")
	shooter.AddComponent(/datum/component/gunpoint, captive, pistol)
	TEST_ASSERT(shooter.GetComponent(/datum/component/gunpoint), "The shooter is not holding anyone up")
	button.action_activate()
	TEST_ASSERT(!shooter.GetComponent(/datum/component/gunpoint), "Pressing the button did not lower the aim")

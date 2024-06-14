//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

/obj/item/device/mmi/digital/New()
	src.brainmob = new(src)
	src.brainmob.stat = CONSCIOUS
	src.brainmob.add_language("Droid",TRUE)
	src.brainmob.remove_language("English")
	src.brainmob.container = src
	src.brainmob.silent = 0
	..()

/obj/item/device/mmi/digital/transfer_identity(var/mob/living/human/H)
	brainmob.dna = H.dna
	brainmob.stat = 0
	if(H.mind)
		H.mind.transfer_to(brainmob)
	return

/obj/item/device/mmi/digital/attack_self()
	return

/obj/item/device/mmi
	name = "man-machine interface"
	desc = "A complex life support shell that interfaces between a brain and electronic devices."
	icon = 'icons/obj/assemblies.dmi'
	icon_state = "mmi_empty"
	w_class = 3
	//Revised. Brainmob is now contained directly within object of transfer. MMI in this case.

	var/locked = 0
	var/mob/living/brain/brainmob = null	//The current occupant.
	var/obj/item/organ/brain/brainobj = null	//The current brain organ.
	var/obj/mecha = null//This does not appear to be used outside of reference in mecha.dm.

/obj/item/device/mmi/proc/transfer_identity(mob/living/human/H)//Same deal as the regular brain proc. Used for human-->robot people.
	brainmob = new(src)
	brainmob.SetName(H.real_name)
	brainmob.real_name = H.real_name
	brainmob.dna = H.dna
	brainmob.container = src

	SetName("[initial(name)]: [brainmob.real_name]")
	update_icon()
	locked = 1
	return

/obj/item/device/mmi/attackby(obj/item/tool, mob/user)
	// Brain - Install brain
	if (istype(tool, /obj/item/organ/brain))
		if (brainobj)
			USE_FEEDBACK_FAILURE("\The [src] already has \a [brainobj].")
			return TRUE
		var/obj/item/organ/brain/brain = tool
		if (brain.damage >= brain.max_damage)
			USE_FEEDBACK_FAILURE("\The [tool] is too damaged to install in \the [src].")
			return TRUE
		if (!brain.brainmob || !brain.can_use_mmi)
			USE_FEEDBACK_FAILURE("\The [src] doesn't accept \the [tool].")
			return TRUE
		if (!user.unEquip(tool, src))
			FEEDBACK_UNEQUIP_FAILURE(user, tool)
			return TRUE
		brainmob = brain.brainmob
		brain.brainmob = null
		brainmob.forceMove(src)
		brainmob.container = src
		brainmob.set_stat(CONSCIOUS)
		brainmob.switch_from_dead_to_living_mob_list()
		brainobj = brain
		SetName("[initial(name)]: ([brainmob.real_name])")
		locked = TRUE
		update_icon()
		user.visible_message(
			SPAN_NOTICE("\The [user] installs \a [tool] into \a [src]."),
			SPAN_NOTICE("You install \the [tool] into \the [src].")
		)
		return TRUE
	return ..()

/obj/item/device/mmi/attack_self(mob/user as mob)
	if(!brainmob)
		to_chat(user, SPAN_WARNING("You upend the MMI, but there's nothing in it."))
	else if(locked)
		to_chat(user, SPAN_WARNING("You upend the MMI, but the brain is clamped into place."))
	else
		to_chat(user, SPAN_NOTICE("You upend the MMI, spilling the brain onto the floor."))
		var/obj/item/organ/brain/brain
		if (brainobj)	//Pull brain organ out of MMI.
			brainobj.forceMove(user.loc)
			brain = brainobj
			brainobj = null
		else	//Or make a new one if empty.
			brain = new(user.loc)
		brainmob.container = null//Reset brainmob mmi var.
		brainmob.forceMove(brain)//Throw mob into brain.
		brainmob.remove_from_living_mob_list() //Get outta here
		brain.brainmob = brainmob//Set the brain to use the brainmob
		brainmob = null//Set mmi brainmob var to null

		update_icon()
		SetName(initial(name))

/obj/item/device/mmi/relaymove(var/mob/user, var/direction)
	if(user.stat || user.stunned)
		return

/obj/item/device/mmi/Destroy()
	/*
	if(isrobot(loc))
		var/mob/living/silicon/robot/borg = loc
		borg.mmi = null
	*/
	if(brainmob)
		qdel(brainmob)
		brainmob = null
	..()
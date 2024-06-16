/atom
	layer = 2
	appearance_flags = TILE_BOUND
	var/level = 2
	var/flags = FALSE
	///First atom flags var
	var/flags_1 = NONE

	var/list/fingerprints
	var/list/fingerprintshidden
	var/fingerprintslast = null

	var/list/blood_DNA
	var/was_bloodied
	var/blood_color
	var/last_bumped = FALSE
	var/pass_flags = FALSE
	var/throwpass = FALSE
	var/germ_level = GERM_LEVEL_AMBIENT // The higher the germ level, the more germ on the atom.
	var/simulated = TRUE //filter for actions - used by lighting overlays
	var/fluorescent // Shows up under a UV light.
	var/allow_spin = TRUE

	///Chemistry.
	var/datum/reagents/reagents = null

	//var/chem_is_open_container = FALSE
	// replaced by OPENCONTAINER flags and atom/proc/is_open_container()
	///Chemistry.

	var/crafted = FALSE //optimization for map loaded atoms

	//Detective Work, used for the duplicate data points kept in the scanners
	var/list/original_atom

	// supply trains

	var/uses_initial_density = FALSE

	var/initial_density = FALSE

	var/uses_initial_opacity = FALSE

	var/initial_opacity = FALSE

	var/radiation = 0

	var/list/mergewith = list()

/// Init this specific atom
/datum/controller/subsystem/atoms/proc/InitAtom(atom/A, from_template = FALSE, list/arguments)

	var/the_type = A.type

	if(QDELING(A))
		// Check init_start_time to not worry about atoms created before the atoms SS that are cleaned up before this
		if (A.gc_destroyed > init_start_time)
			BadInitializeCalls[the_type] |= BAD_INIT_QDEL_BEFORE
		return TRUE

	// This is handled and battle tested by dreamchecker. Limit to UNIT_TESTS just in case that ever fails.
	#ifdef UNIT_TESTS
	var/start_tick = world.time
	#endif

	var/result = A.Initialize(arglist(arguments))

	#ifdef UNIT_TESTS
	if(start_tick != world.time)
		BadInitializeCalls[the_type] |= BAD_INIT_SLEPT
	#endif

	var/qdeleted = FALSE

	switch(result)
		if (INITIALIZE_HINT_NORMAL)
			EMPTY_BLOCK_GUARD // Pass
		if(INITIALIZE_HINT_LATELOAD)
			if(arguments[1]) //mapload
				late_loaders += A
			else
				A.LateInitialize()
		if(INITIALIZE_HINT_QDEL)
			qdel(A)
			qdeleted = TRUE
		else
			BadInitializeCalls[the_type] |= BAD_INIT_NO_HINT

	if(!A) //possible harddel
		qdeleted = TRUE
	else if(!(A.flags_1 & INITIALIZED_1))
		BadInitializeCalls[the_type] |= BAD_INIT_DIDNT_INIT
	else
		SEND_SIGNAL(A, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZE)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_ATOM_AFTER_POST_INIT, A)
		var/atom/location = A.loc
		if(location)
			/// Sends a signal that the new atom `src`, has been created at `loc`
			SEND_SIGNAL(location, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, A, arguments[1])
		if(created_atoms && from_template && ispath(the_type, /atom/movable))//we only want to populate the list with movables
			created_atoms += A.get_all_contents()

	return qdeleted || QDELING(A)

/**
 * Called when an atom is created in byond (built in engine proc)
 *
 * Not a lot happens here in SS13 code, as we offload most of the work to the
 * [Intialization][/atom/proc/Initialize] proc, mostly we run the preloader
 * if the preloader is being used and then call [InitAtom][/datum/controller/subsystem/atoms/proc/InitAtom] of which the ultimate
 * result is that the Intialize proc is called.
 *
 */
/atom/New(loc, ...)
	var/do_initialize = SSatoms.initialized
	if(do_initialize != INITIALIZATION_INSSATOMS)
		args[1] = do_initialize == INITIALIZATION_INNEW_MAPLOAD
		if(SSatoms.InitAtom(src, FALSE, args))
			//we were deleted
			return

/**
 * The primary method that objects are setup in SS13 with
 *
 * we don't use New as we have better control over when this is called and we can choose
 * to delay calls or hook other logic in and so forth
 *
 * During roundstart map parsing, atoms are queued for intialization in the base atom/New(),
 * After the map has loaded, then Initalize is called on all atoms one by one. NB: this
 * is also true for loading map templates as well, so they don't Initalize until all objects
 * in the map file are parsed and present in the world
 *
 * If you're creating an object at any point after SSInit has run then this proc will be
 * immediately be called from New.
 *
 * mapload: This parameter is true if the atom being loaded is either being intialized during
 * the Atom subsystem intialization, or if the atom is being loaded from the map template.
 * If the item is being created at runtime any time after the Atom subsystem is intialized then
 * it's false.
 *
 * The mapload argument occupies the same position as loc when Initialize() is called by New().
 * loc will no longer be needed after it passed New(), and thus it is being overwritten
 * with mapload at the end of atom/New() before this proc (atom/Initialize()) is called.
 *
 * You must always call the parent of this proc, otherwise failures will occur as the item
 * will not be seen as initalized (this can lead to all sorts of strange behaviour, like
 * the item being completely unclickable)
 *
 * You must not sleep in this proc, or any subprocs
 *
 * Any parameters from new are passed through (excluding loc), naturally if you're loading from a map
 * there are no other arguments
 *
 * Must return an [initialization hint][INITIALIZE_HINT_NORMAL] or a runtime will occur.
 *
 * Note: the following functions don't call the base for optimization and must copypasta handling:
 * * [/turf/proc/Initialize]
 * * [/turf/open/space/proc/Initialize]
 */
/atom/proc/Initialize(mapload, ...)
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_CALL_PARENT(TRUE)

	if(flags_1 & INITIALIZED_1)
		stack_trace("Warning: [src]([type]) initialized multiple times!")
	flags_1 |= INITIALIZED_1

	SET_PLANE_IMPLICIT(src, plane)

	if(greyscale_config && greyscale_colors) //we'll check again at item/init for inhand/belt/worn configs.
		update_greyscale()

	//atom color stuff
	if(color)
		add_atom_colour(color, FIXED_COLOUR_PRIORITY)

	if (light_system == COMPLEX_LIGHT && light_power && light_range)
		update_light()

	SETUP_SMOOTHING()

	if(uses_integrity)
		atom_integrity = max_integrity
	TEST_ONLY_ASSERT((!armor || istype(armor)), "[type] has an armor that contains an invalid value at intialize")

	// apply materials properly from the default custom_materials value
	// This MUST come after atom_integrity is set above, as if old materials get removed,
	// atom_integrity is checked against max_integrity and can BREAK the atom.
	// The integrity to max_integrity ratio is still preserved.
	set_custom_materials(custom_materials)

	if(ispath(ai_controller))
		ai_controller = new ai_controller(src)

	return INITIALIZE_HINT_NORMAL

/**
 * Late Intialization, for code that should run after all atoms have run Intialization
 *
 * To have your LateIntialize proc be called, your atoms [Initalization][/atom/proc/Initialize]
 *  proc must return the hint
 * [INITIALIZE_HINT_LATELOAD] otherwise it will never be called.
 *
 * useful for doing things like finding other machines on GLOB.machines because you can guarantee
 * that all atoms will actually exist in the "WORLD" at this time and that all their Intialization
 * code has been run
 */
/atom/proc/LateInitialize()
	set waitfor = FALSE
	SHOULD_CALL_PARENT(FALSE)
	stack_trace("[src] ([type]) called LateInitialize but has nothing on it!")


/atom/Destroy()
	if (reagents)
		QDEL_NULL(reagents)
	. = ..()

/atom/proc/can_join_with(var/atom/W)
	return FALSE
/atom/proc/check_relatives(var/update_self = FALSE, var/update_others = FALSE)
	return FALSE

/atom/proc/CanPass(atom/movable/mover, turf/target, height=1.5, air_group = FALSE)
	//Purpose: Determines if the object (or airflow) can pass this atom.
	//Called by: Movement, airflow.
	//Inputs: The moving atom (optional), target turf, "height" and air group
	//Outputs: Boolean if can pass.

	return (!density || !height || air_group)


/atom/proc/reveal_blood()
	return

/atom/proc/assume_air(datum/gas_mixture/giver)
	return null

/atom/proc/remove_air(amount)
	return null

/atom/proc/return_air()
	if (loc)
		return loc.return_air()
	else
		return null

/atom/proc/on_reagent_change()
	return

/atom/proc/Bumped(AM as mob|obj)
	return

// Convenience proc to see if a container is open for chemistry handling
// returns true if open
// false if closed
/atom/proc/is_open_container()
	return flags & OPENCONTAINER

/*//Convenience proc to see whether a container can be accessed in a certain way.

	proc/can_subract_container()
		return flags & EXTRACT_CONTAINER

	proc/can_add_container()
		return flags & INSERT_CONTAINER
*/

/atom/proc/CheckExit()
	return TRUE

// If you want to use this, the atom must have the PROXMOVE flag, and the moving
// atom must also have the PROXMOVE flag currently to help with lag. ~ ComicIronic
/atom/proc/HasProximity(atom/movable/AM as mob|obj)
	return

/atom/proc/emp_act(var/severity)
	return

/atom/proc/pre_bullet_act(var/obj/item/projectile/P)

/atom/proc/bullet_act(var/obj/item/projectile/P, def_zone)
	P.on_hit(src, FALSE, def_zone)
	if (istype(P, /obj/item/projectile/shell) && istype (src, /obj/structure))
		ex_act(3.0)
	. = FALSE

/atom/proc/in_contents_of(container)//can take class or object instance as argument
	if (ispath(container))
		if (istype(loc, container))
			return TRUE
	else if (src in container)
		return TRUE
	return

/*
 *	atom/proc/search_contents_for (path,list/filter_path=null)
 * Recursevly searches all atom contens (including contents contents and so on).
 *
 * ARGS: path - search atom contents for atoms of this type
 *	   list/filter_path - if set, contents of atoms not of types in this list are excluded from search.
 *
 * RETURNS: list of found atoms
 */

/atom/proc/search_contents_for (path,list/filter_path=null)
	var/list/found = list()
	for (var/atom/A in src)
		if (istype(A, path))
			found += A
		if (filter_path)
			var/pass = FALSE
			for (var/type in filter_path)
				pass |= istype(A, type)
			if (!pass)
				continue
		if (A.contents.len)
			found += A.search_contents_for (path,filter_path)
	return found





//All atoms
/atom/proc/examine(mob/user, var/distance = -1, var/infix = "", var/suffix = "")
	//This reformat names to get a/an properly working on item descriptions when they are bloody
	var/f_name = "\a [src][infix]."
	if (blood_DNA && !istype(src, /obj/effect/decal))
		if (gender == PLURAL)
			f_name = "some "
		else
			f_name = "a "
		if (blood_color != "#030303")
			f_name += "<span class='danger'>blood-stained</span> [name][infix]!"
		else
			f_name += "oil-stained [name][infix]."

	if (!isobserver(user))
		user.visible_message("<font size=1>[user.name] looks at \the [src].</font>", "<font size =1>You look at \the [src].</font>")

	to_chat(user, "\icon[src] That's [f_name] [suffix]")

	if(desc) // If the description is not null.
		to_chat(user, desc)

	return distance == -1 || (get_dist(src, user) <= distance)

//called to set the atom's dir and used to add behaviour to dir-changes
/atom/proc/set_dir(new_dir)
	var/old_dir = dir
	if (new_dir == old_dir)
		return FALSE

	dir = new_dir
	GLOB.dir_set_event.raise_event(src, old_dir, new_dir)
	return TRUE

/atom/proc/ex_act()
	return


/atom/proc/fire_act()
	if (isobject(src))
		var/obj/NS = src
		if (!NS.flammable)
			return
		else
			if(istype(NS, /obj/item/stack/material/wood))
				var/obj/item/stack/material/wood/W = NS
				if(W.ash_production) //Needed to not break the ash production from wood
					return
			if (prob(27))
				visible_message("<span class = 'warning'>\The [NS] is burned away.</span>")
				if (prob(3))
					new/obj/effect/effect/smoke(loc)
				qdel(src)
	else
		return

/atom/proc/melt()
	return

/atom/proc/hitby(atom/movable/AM as mob|obj)
	if (density)
		AM.throwing = FALSE
	if (istype(AM, /obj/item/weapon/snowball))
		var/obj/item/weapon/snowball/SB = AM
		SB.icon_state = "snowball_hit"
		SB.update_icon()
		spawn(6)
			qdel(SB)
		return
	return

/atom/proc/add_hiddenprint(mob/living/M as mob)
	if (isnull(M)) return
	if (isnull(M.key)) return
	if (ishuman(M))
		var/mob/living/human/H = M
		if (!istype(H.dna, /datum/dna))
			return FALSE
		if (H.gloves)
			if (fingerprintslast != H.key)
				fingerprintshidden += text("\[[time_stamp()]\] (Wearing gloves). Real name: [], Key: []",H.real_name, H.key)
				fingerprintslast = H.key
			return FALSE
		if (!( fingerprints ))
			if (fingerprintslast != H.key)
				fingerprintshidden += text("\[[time_stamp()]\] Real name: [], Key: []",H.real_name, H.key)
				fingerprintslast = H.key
			return TRUE
	else
		if (fingerprintslast != M.key)
			fingerprintshidden += text("\[[time_stamp()]\] Real name: [], Key: []",M.real_name, M.key)
			fingerprintslast = M.key
	return

/atom/proc/add_fingerprint(mob/living/M as mob, ignoregloves = FALSE)
	if (isnull(M)) return
	if (isnull(M.key)) return
	if (ishuman(M))
		//Fibers
		add_fibers(M)
		//Add the list if it does not exist.
		if (!fingerprintshidden)
			fingerprintshidden = list()

		//First, make sure their DNA makes sense.
		var/mob/living/human/H = M
		if (!istype(H.dna, /datum/dna) || !H.dna.uni_identity || (length(H.dna.uni_identity) != 32))
			if (!istype(H.dna, /datum/dna))
				H.dna = new /datum/dna(null)
				H.dna.real_name = H.real_name
		H.check_dna()

		//Now, deal with gloves.
		if (H.gloves && H.gloves != src)
			if (fingerprintslast != H.key)
				fingerprintshidden += text("\[[]\](Wearing gloves). Real name: [], Key: []",time_stamp(), H.real_name, H.key)
				fingerprintslast = H.key
			H.gloves.add_fingerprint(M)

		//Deal with gloves the pass finger/palm prints.
		if (!ignoregloves)
			if (H.gloves && H.gloves != src)
				if(istype(H.gloves, /obj/item/clothing/gloves))
					var/obj/item/clothing/gloves/G = H.gloves
					if(!prob(G.fingerprint_chance))
						return 0

		//More adminstuffz
		if (fingerprintslast != H.key)
			fingerprintshidden += text("\[[]\]Real name: [], Key: []",time_stamp(), H.real_name, H.key)
			fingerprintslast = H.key

		//Make the list if it does not exist.
		if (!fingerprints)
			fingerprints = list()

		//Hash this shit.
		var/full_print = H.get_full_print()

		// Add the fingerprints
		//
		if (fingerprints[full_print])
			switch(stringpercent(fingerprints[full_print]))		//tells us how many stars are in the current prints.

				if (28 to 32)
					if (prob(1))
						fingerprints[full_print] = full_print 		// You rolled a one buddy.
					else
						fingerprints[full_print] = stars(full_print, rand(0,40)) // 24 to 32

				if (24 to 27)
					if (prob(3))
						fingerprints[full_print] = full_print	 	//Sucks to be you.
					else
						fingerprints[full_print] = stars(full_print, rand(15, 55)) // 20 to 29

				if (20 to 23)
					if (prob(5))
						fingerprints[full_print] = full_print		//Had a good run didn't ya.
					else
						fingerprints[full_print] = stars(full_print, rand(30, 70)) // 15 to 25

				if (16 to 19)
					if (prob(5))
						fingerprints[full_print] = full_print		//Welp.
					else
						fingerprints[full_print]  = stars(full_print, rand(40, 100))  // FALSE to 21

				if (0 to 15)
					if (prob(5))
						fingerprints[full_print] = stars(full_print, rand(0,50)) 	// small chance you can smudge.
					else
						fingerprints[full_print] = full_print

		else
			fingerprints[full_print] = stars(full_print, rand(0, 20))	//Initial touch, not leaving much evidence the first time.


		return TRUE
	else
		//Smudge up dem prints some
		if (fingerprintslast != M.key)
			fingerprintshidden += text("\[[]\]Real name: [], Key: []",time_stamp(), M.real_name, M.key)
			fingerprintslast = M.key

	//Cleaning up shit.
	if (fingerprints && !fingerprints.len)
		qdel(fingerprints)
	return


/atom/proc/transfer_fingerprints_to(var/atom/A)

	if (!istype(A.fingerprints,/list))
		A.fingerprints = list()

	if (!istype(A.fingerprintshidden,/list))
		A.fingerprintshidden = list()

	if (!istype(fingerprintshidden, /list))
		fingerprintshidden = list()

	//skytodo
	//A.fingerprints |= fingerprints			//detective
	//A.fingerprintshidden |= fingerprintshidden	//admin
	if (A.fingerprints && fingerprints)
		A.fingerprints |= fingerprints.Copy()			//detective
	if (A.fingerprintshidden && fingerprintshidden)
		A.fingerprintshidden |= fingerprintshidden.Copy()	//admin	A.fingerprintslast = fingerprintslast


//returns TRUE if made bloody, returns FALSE otherwise
/atom/proc/add_blood(mob/living/human/M as mob)
	if (flags & NOBLOODY)
		return FALSE

	if (!blood_DNA || !istype(blood_DNA, /list))	//if our list of DNA doesn't exist yet (or isn't a list) initialise it.
		blood_DNA = list()

	was_bloodied = TRUE
	blood_color = "#A10808"
	
	if (istype(M))
		if (!istype(M.dna, /datum/dna))
			M.dna = new /datum/dna(null)
			M.dna.real_name = M.real_name
		M.check_dna()
		if (M.species)
			blood_color = M.species.blood_color
		if (M.droid)
			blood_color = "#030303"
	. = TRUE
	return TRUE

/atom/proc/add_vomit_floor(mob/living/human/M as mob, var/toxvomit = FALSE)
	if ( istype(src, /turf) )
		var/obj/effect/decal/cleanable/vomit/this = new /obj/effect/decal/cleanable/vomit(src)

		// Make toxins vomit look different
		if (toxvomit)
			this.icon_state = "vomittox_[pick(1,4)]"

/atom/proc/add_vomit_floor_bloody(mob/living/human/M as mob, var/toxvomit = FALSE)
	if ( istype(src, /turf) )
		new /obj/effect/decal/cleanable/vomit/bloody(src)


/atom/proc/clean_blood()
	if (!simulated)
		return
	fluorescent = FALSE
	germ_level = FALSE
	if (istype(blood_DNA, /list))
		blood_DNA = null
		return TRUE

/atom/proc/checkpass(passflag)
	return pass_flags&passflag

/atom/proc/isinspace()
	return FALSE

// Show a message to all mobs and objects in sight of this atom
// Use for objects performing visible actions
// message is output to anyone who can see, e.g. "The [src] does something!"
// blind_message (optional) is what blind people will hear e.g. "You hear something!"
/atom/proc/visible_message(var/message, var/blind_message)

	var/list/see = get_mobs_or_objects_in_view(7,src, TRUE, FALSE) | viewers(get_turf(src), null)

	for (var/I in see)
		if (isobj(I))
			spawn(0)
				if (I) //It's possible that it could be deleted in the meantime.
					var/obj/O = I
					O.show_message( message, TRUE, blind_message, 2)
		else if (ismob(I))
			var/mob/M = I
			if (M.see_invisible >= invisibility) // Cannot view the invisible
				M.show_message( message, TRUE, blind_message, 2)
			else if (blind_message)
				M.show_message(blind_message, 2)

// Show a message to all mobs and objects in earshot of this atom
// Use for objects performing audible actions
// message is the message output to anyone who can hear.
// deaf_message (optional) is what deaf people will see.
// hearing_distance (optional) is the range, how many tiles away the message can be heard.
/atom/proc/audible_message(var/message, var/deaf_message, var/hearing_distance)

	var/range = 7
	if (hearing_distance)
		range = hearing_distance
	var/list/hear = get_mobs_or_objects_in_view(range,src)

	for (var/I in hear)
		if (isobj(I))
			spawn(0)
				if (I) //It's possible that it could be deleted in the meantime.
					var/obj/O = I
					O.show_message( message, 2, deaf_message, TRUE)
		else if (ismob(I))
			var/mob/M = I
			M.show_message( message, 2, deaf_message, TRUE)

/atom/Entered(var/atom/movable/AM, var/atom/old_loc, var/special_event)
	if (loc && special_event == MOVED_DROP)
		AM.forceMove(loc, MOVED_DROP)
		return CANCEL_MOVE_EVENT
	return ..()

/turf/Entered(var/atom/movable/AM, var/atom/old_loc, var/special_event)
	return ..(AM, old_loc, FALSE)

//Kicking
/atom/proc/kick_act(mob/living/human/user)
	if (!user.canClick())
		return
	//They're not adjcent to us so we can't kick them. Can't kick in straightjacket or while being incapacitated (except lying), can't kick while legcuffed or while being locked in closet
	if(!Adjacent(user) || user.incapacitated(INCAPACITATION_STUNNED|INCAPACITATION_KNOCKOUT|INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY) \
		|| istype(user.loc, /obj/structure/closet))
		return

	if(user.handcuffed && prob(45) && !user.incapacitated(INCAPACITATION_FORCELYING))//User can fail to kick smbd if cuffed
		user.visible_message(SPAN_DANGER("[user.name] loses \his balance while trying to kick \the [src]."), \
                    " You lost your balance.")
		user.Weaken(1)
		return

	if(user.middle_click_intent == "kick")//We're in kick mode, we can kick.
		for(var/limbcheck in list("l_leg","r_leg"))//But we need to see if we have legs.
			var/obj/item/organ/affecting = user.get_organ(limbcheck)
			if(!affecting)//Oh shit, we don't have have any legs, we can't kick.
				return 0

		user.setClickCooldown(16)
		return 1 //We do have legs now though, so we can kick.

//Biting
/atom/proc/bite_act(mob/living/human/user)
	if (!user.canClick())
		return
	if(!Adjacent(user) || user.incapacitated(INCAPACITATION_STUNNED|INCAPACITATION_KNOCKOUT) || istype(user.loc, /obj/structure/closet) || !ishuman(src))
		return
	if(user.pacifist)
		to_chat(src, "<font color='yellow'><b><big>I don't want to bite!</big></b></font>")
		return
	var/mob/living/human/target = src
	if(user.middle_click_intent == "bite")//We're in bite mode, so bite the opponent
		var/limbcheck = user.targeted_organ
		if (limbcheck == "random")
			limbcheck = pick("l_arm","r_arm","l_hand","r_hand")
		if(limbcheck in list("l_hand","r_hand","l_arm","r_arm") || user.werewolf)
			var/obj/item/organ/external/affecting = target.get_organ(limbcheck)
			if(!affecting)
				to_chat(user, SPAN_NOTICE("[src] is missing that body part."))
				return FALSE
			else
				visible_message("<span class='danger'>[user] bites the [src]'s [affecting.name]!</span>","<span class='danger'>You bite the [src]'s [affecting.name]!</span>")
				if (ishuman(src) && ishuman(user))
					if (user.werewolf && user.body_build.name != "Default")
						affecting.createwound(BRUISE, rand(15,21)*user.getStatCoeff("strength"))
						if (prob(20))
							target.werewolf = 1
					else
						affecting.createwound(BRUISE, rand(6,9)*user.getStatCoeff("strength"))
					target.emote("painscream")
				else
					target.adjustBruteLoss(rand(6,7))
				if (prob(30))
					if (limbcheck == "l_hand")
						if (target.l_hand)
							// Disarm left hand
							//Urist McAssistant dropped the macguffin with a scream just sounds odd. Plus it doesn't work with NO_PAIN
							target.visible_message("<span class='danger'>[target] drops \the [target.l_hand]!</span>")
							target.drop_l_hand()
					if (limbcheck == "r_hand")
						if (target.r_hand)
							// Disarm right hand
							target.visible_message("<span class='danger'>[target] drops \the [target.r_hand]!</span>")
							target.drop_r_hand()
		else
			to_chat(user, SPAN_NOTICE("You cannot bite that part of the body, it's too far away!"))
			return FALSE

		user.setClickCooldown(25)
		return TRUE

//Jumping
/atom/proc/jump_act(atom/target, mob/living/human/user)
	if (!user.canClick())
		return
	//No jumping on the ground dummy && No jumping in space && No jumping in straightjacket or while being incapacitated (except handcuffs) && No jumping vhile being legcuffed or locked in closet
	if(user.incapacitated(INCAPACITATION_STUNNED|INCAPACITATION_KNOCKOUT|INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY|INCAPACITATION_FORCELYING) || user.isinspace() \
		|| istype(user.loc, /obj/structure/closet))
		return
	if (user.handcuffed && !isnull(user.pulledby)) // Can't jump while being handcuffed and pulled by someone
		return
	for(var/limbcheck in list("l_leg","r_leg"))//But we need to see if we have legs.
		var/obj/item/organ/affecting = user.get_organ(limbcheck)
		if(!affecting)//Oh shit, we don't have have any legs, we can't jump.
			return
	var/maxdist = 2
	if (ishuman(user))
		if (user.gorillaman)
			maxdist = 3
	if (istype(target, /turf/floor/beach/water) || user.stats["stamina"][1] <= 25 || get_dist(target,user)>maxdist)
		return
	if ((istype(target, /obj) && target.density == TRUE) || (istype(target, /turf) && target.density == TRUE))
		return
	for (var/obj/O in range(1,user))
		if (istype(O, /obj/structure/vehicleparts/frame))
			return
	for (var/obj/O in get_turf(target))
		if (O.density)
			to_chat(user, SPAN_DANGER("You hit the [O]!"))
			user.adjustBruteLoss(rand(2,7))
			user.Weaken(2)
			user.setClickCooldown(22)
			return

	//is there a wall in the way?
	if (get_dist(target,user)==2)
		var/dir_to_tgt = get_dir(user,target)
		for(var/obj/O in range(1,user))
			if ((get_dir(user,O) in nearbydirections(dir_to_tgt)) && (O.density == TRUE || istype(O, /obj/structure/window/barrier/railing)))
				to_chat(user, SPAN_DANGER("You hit the [O]!"))
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
			if (istype(O, /obj/structure/vehicleparts/frame))
				var/obj/structure/vehicleparts/frame/F = O
				if (!F.CanPass())
					to_chat(user, SPAN_DANGER("You hit the [F.axis]!"))
					user.adjustBruteLoss(rand(2,7))
					user.Weaken(2)
					user.setClickCooldown(22)
					return

		for(var/turf/T in range(1,user))
			if ((get_dir(user,T) in nearbydirections(dir_to_tgt)) && T.density == TRUE)
				to_chat(user, SPAN_DANGER("You hit the [T]!"))
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
	if (maxdist == 3 && get_dist(target,user)==3)
		var/dir_to_tgt = get_dir(user,target)
		for(var/obj/O in range(2,user))
			if ((get_dir(user,O) in nearbydirections(dir_to_tgt)) && (O.density == TRUE || istype(O, /obj/structure/window/barrier/railing)))
				to_chat(user, SPAN_DANGER("You hit the [O]!"))
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
		for(var/turf/T in range(2,user))
			if ((get_dir(user,T) in nearbydirections(dir_to_tgt)) && T.density == TRUE)
				to_chat(user, SPAN_DANGER("You hit the [T]!"))
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
	//Nice, we can jump, let's do that then.
	playsound(user, user.gender == MALE ? 'sound/effects/jump_male.ogg' : 'sound/effects/jump_female.ogg', 25)
	user.visible_message("[user] jumps.")
	user.stats["stamina"][1] = max(user.stats["stamina"][1] - rand(20,40), 0)
	user.throw_at(target, 5, 0.5, user)
	user.setClickCooldown(22)

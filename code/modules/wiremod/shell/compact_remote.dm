/obj/item/compact_remote
	name = "compact remote"
	desc = "A handheld remote that sends a signal to its built-in circuit when pressed."
	icon = 'icons/obj/science/circuits.dmi'
	icon_state = "setup_small_simple"
	w_class = WEIGHT_CLASS_TINY

	var/obj/item/integrated_circuit/circuit
	var/obj/item/circuit_component/compact_remote/remote_input

/obj/item/compact_remote/New()
	. = ..()
	circuit = new /obj/item/integrated_circuit
	circuit.forceMove(src)
	remote_input = new /obj/item/circuit_component/compact_remote
	remote_input.removable = FALSE
	if(!circuit.add_component(remote_input))
		qdel(remote_input)
		remote_input = null
		stack_trace("Failed to initialize the compact remote circuit.")

/obj/item/compact_remote/Destroy()
	QDEL_NULL(circuit)
	remote_input = null
	return ..()

/obj/item/compact_remote/attack_self(mob/user)
	if(!user || !remote_input || !circuit)
		return FALSE
	remote_input.send_trigger(user)
	return TRUE

/obj/item/compact_remote/AltClick(mob/user)
	if(circuit && wiremod_circuit_state.can_use_topic(circuit, user) == STATUS_INTERACTIVE)
		circuit.ui_interact(user)
		return
	return ..()

/obj/item/circuit_component/compact_remote
	display_name = "Compact Remote"
	desc = "Sends a signal to the circuit whenever the compact remote is pressed."
	removable = FALSE

	var/datum/port/output/user_output
	var/datum/port/output/signal_output

/obj/item/circuit_component/compact_remote/populate_ports()
	user_output = add_output_port("User", PORT_TYPE_ANY)
	signal_output = add_output_port("Signal", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/compact_remote/proc/send_trigger(mob/user)
	user_output.set_output(user)
	signal_output.set_output(COMPONENT_SIGNAL)
	if(parent)
		GLOB.nanomanager.update_uis(parent)

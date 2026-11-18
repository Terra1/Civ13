/obj/item/circuit_component
	name = "component"
	desc = "A programmable integrated circuit component."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "component"
	w_class = WEIGHT_CLASS_TINY

	var/display_name = "Generic"
	var/category = "General"
	var/obj/item/integrated_circuit/parent
	var/list/datum/circuit_input/input_ports = list()
	var/list/datum/circuit_output/output_ports = list()

/obj/item/circuit_component/New(mapload)
	. = ..()
	populate_ports()

/obj/item/circuit_component/proc/populate_ports()
	return

/obj/item/circuit_component/proc/add_input(name, datatype = PORT_TYPE_ANY, proc_to_call)
	var/datum/circuit_input/input = new(src, name, datatype)
	input.proc_to_call = proc_to_call
	input_ports += input
	return input

/obj/item/circuit_component/proc/add_output(name, datatype = PORT_TYPE_ANY)
	var/datum/circuit_output/output = new(src, name, datatype)
	output_ports += output
	return output

/obj/item/circuit_component/proc/trigger_component()
	return

/obj/item/circuit_component/Destroy()
	for(var/datum/circuit_input/input in input_ports)
		input.disconnect()
		qdel(input)
	for(var/datum/circuit_output/output in output_ports)
		for(var/datum/circuit_input/input in output.connected_inputs.Copy())
			input.disconnect()
		qdel(output)
	input_ports.Cut()
	output_ports.Cut()
	if(parent)
		parent.attached_components -= src
		parent = null
	return ..()

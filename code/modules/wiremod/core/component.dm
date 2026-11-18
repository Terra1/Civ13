/obj/item/circuit_component
	name = COMPONENT_DEFAULT_NAME
	desc = "A programmable integrated circuit component."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "component"
	w_class = WEIGHT_CLASS_TINY

	var/display_name = "Component"
	var/category = COMPONENT_DEFAULT_CATEGORY
	var/obj/item/integrated_circuit/parent
	var/list/datum/port/input/input_ports = list()
	var/list/datum/port/output/output_ports = list()
	var/rel_x = 0
	var/rel_y = 0
	var/circuit_flags = 0
	var/removable = TRUE

/obj/item/circuit_component/New()
	. = ..()
	populate_ports()

/obj/item/circuit_component/proc/populate_ports()
	return

/obj/item/circuit_component/proc/add_input_port(port_name, port_type = PORT_TYPE_ANY, order = 1, trigger = PROC_REF(input_received), default = null)
	var/datum/port/input/new_port = new(src, port_name, port_type, trigger, default)
	input_ports += new_port
	return new_port

/obj/item/circuit_component/proc/add_output_port(port_name, port_type = PORT_TYPE_ANY, order = 1)
	var/datum/port/output/new_port = new(src, port_name, port_type)
	output_ports += new_port
	return new_port

/obj/item/circuit_component/proc/remove_input_port(datum/port/input/input_port)
	if(!(input_port in input_ports))
		return null
	input_ports -= input_port
	qdel(input_port)
	return null

/obj/item/circuit_component/proc/remove_output_port(datum/port/output/output_port)
	if(!(output_port in output_ports))
		return null
	output_ports -= output_port
	qdel(output_port)
	return null

/obj/item/circuit_component/proc/disconnect()
	for(var/datum/port/input/input_port in input_ports)
		input_port.disconnect()
	for(var/datum/port/output/output_port in output_ports)
		output_port.disconnect_all()

/obj/item/circuit_component/proc/pre_input_received(datum/port/input/input_port)
	return

/obj/item/circuit_component/proc/trigger_component(datum/port/input/input_port)
	pre_input_received(input_port)
	if(input_port?.trigger)
		return call(src, input_port.trigger)(input_port)
	return input_received(input_port)

/obj/item/circuit_component/proc/input_received(datum/port/input/input_port)
	return

/obj/item/circuit_component/Destroy()
	disconnect()
	for(var/datum/port/input/input_port in input_ports.Copy())
		qdel(input_port)
	for(var/datum/port/output/output_port in output_ports.Copy())
		qdel(output_port)
	input_ports.Cut()
	output_ports.Cut()
	if(parent)
		parent.attached_components -= src
		parent = null
	return ..()

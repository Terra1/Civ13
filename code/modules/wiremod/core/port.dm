/datum/circuit_port
	var/name = "Port"
	var/datatype = PORT_TYPE_ANY
	var/value = null
	var/obj/item/circuit_component/connected_component

/datum/circuit_port/New(obj/item/circuit_component/component, port_name, port_type)
	connected_component = component
	name = port_name
	datatype = port_type

/datum/circuit_input
	parent_type = /datum/circuit_port
	var/datum/circuit_output/connected_output
	var/proc_to_call

/datum/circuit_output
	parent_type = /datum/circuit_port
	var/list/datum/circuit_input/connected_inputs = list()

/datum/circuit_output/proc/set_output(new_value)
	value = new_value
	for(var/datum/circuit_input/input in connected_inputs)
		input.set_input(value)

/datum/circuit_input/proc/set_input(new_value)
	value = new_value
	if(proc_to_call && connected_component)
		call(connected_component, proc_to_call)(src)

/datum/circuit_input/proc/connect(datum/circuit_output/output)
	if(!output || output == connected_output)
		return
	if(connected_output)
		disconnect()
	connected_output = output
	output.connected_inputs |= src
	set_input(output.value)

/datum/circuit_input/proc/disconnect()
	if(connected_output)
		connected_output.connected_inputs -= src
		connected_output = null

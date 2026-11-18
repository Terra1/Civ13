/datum/circuit_datatype
	var/datatype
	var/list/can_receive_from = list()

/datum/circuit_datatype/proc/can_receive_from_datatype(other_type)
	return datatype == PORT_TYPE_ANY || datatype == other_type || other_type in can_receive_from

/datum/circuit_datatype/proc/convert(value)
	return value

/datum/circuit_datatype/any
	datatype = PORT_TYPE_ANY

/datum/circuit_datatype/any/can_receive_from_datatype(other_type)
	return TRUE

/datum/circuit_datatype/number
	datatype = PORT_TYPE_NUMBER
	can_receive_from = list(PORT_TYPE_BOOLEAN)

/datum/circuit_datatype/number/convert(value)
	if(isnull(value))
		return null
	if(isnum(value))
		return value
	if(istext(value))
		return text2num(value)
	return null

/datum/circuit_datatype/boolean
	datatype = PORT_TYPE_BOOLEAN
	can_receive_from = list(PORT_TYPE_NUMBER)

/datum/circuit_datatype/boolean/convert(value)
	if(istext(value))
		return lowertext(value) in list("true", "yes", "on", "1")
	return !!value

/datum/circuit_datatype/string
	datatype = PORT_TYPE_STRING

/datum/circuit_datatype/string/can_receive_from_datatype(other_type)
	return TRUE

/datum/circuit_datatype/string/convert(value)
	if(isnull(value))
		return null
	if(istype(value, /atom))
		var/atom/atom_value = value
		return "[atom_value.type]"
	return copytext("[value]", 1, PORT_MAX_STRING_LENGTH)

/datum/circuit_datatype/signal
	datatype = PORT_TYPE_SIGNAL

/datum/circuit_datatype/list
	datatype = PORT_TYPE_LIST

/datum/circuit_datatype/list/can_receive_from_datatype(other_type)
	return other_type == PORT_TYPE_LIST || other_type == PORT_TYPE_ANY

/proc/circuit_datatype_for(type_key)
	var/static/list/handlers
	if(!handlers)
		handlers = list()
		handlers[PORT_TYPE_ANY] = new /datum/circuit_datatype/any
		handlers[PORT_TYPE_NUMBER] = new /datum/circuit_datatype/number
		handlers[PORT_TYPE_BOOLEAN] = new /datum/circuit_datatype/boolean
		handlers[PORT_TYPE_STRING] = new /datum/circuit_datatype/string
		handlers[PORT_TYPE_SIGNAL] = new /datum/circuit_datatype/signal
		handlers[PORT_TYPE_LIST] = new /datum/circuit_datatype/list
	return handlers[type_key]

/datum/port
	var/name = "Port"
	var/datatype = PORT_TYPE_ANY
	var/value
	var/datum/circuit_datatype/datatype_handler
	var/obj/item/circuit_component/connected_component

/datum/port/New(obj/item/circuit_component/component, port_name, port_type = PORT_TYPE_ANY)
	connected_component = component
	name = port_name
	set_datatype(port_type)

/datum/port/proc/set_datatype(new_type)
	var/datum/circuit_datatype/new_handler = circuit_datatype_for(new_type)
	if(!new_handler)
		CRASH("Unknown Wiremod port datatype '[new_type]'")
	datatype = new_type
	datatype_handler = new_handler
	value = null

/datum/port/proc/set_value(new_value)
	value = datatype_handler.convert(new_value)

/datum/port/input
	var/datum/port/output/connected_output
	var/trigger

/datum/port/input/New(obj/item/circuit_component/component, port_name, port_type = PORT_TYPE_ANY, input_trigger = null, default_value = null)
	connected_component = component
	name = port_name
	trigger = input_trigger
	set_datatype(port_type)
	if(!isnull(default_value))
		set_input(default_value, FALSE)

/datum/port/input/proc/connect(datum/port/output/output)
	if(!output || output == connected_output || !datatype_handler.can_receive_from_datatype(output.datatype))
		return FALSE
	disconnect()
	connected_output = output
	if(!output.connected_inputs)
		output.connected_inputs = list()
	output.connected_inputs |= src
	if(datatype != PORT_TYPE_SIGNAL)
		set_input(output.value)
	return TRUE

/datum/port/input/proc/disconnect()
	if(connected_output)
		connected_output.connected_inputs -= src
		connected_output = null

/datum/port/input/proc/set_input(new_value, should_trigger = TRUE)
	set_value(new_value)
	if(should_trigger && trigger && connected_component?.parent)
		connected_component.parent.queue_input(src)

/datum/port/input/Destroy()
	disconnect()
	return ..()

/datum/port/output
	var/list/datum/port/input/connected_inputs

/datum/port/output/proc/set_output(new_value)
	set_value(new_value)
	for(var/datum/port/input/input in connected_inputs?.Copy())
		input.set_input(value)

/datum/port/output/proc/disconnect_all()
	for(var/datum/port/input/input in connected_inputs?.Copy())
		input.disconnect()
	value = null

/datum/port/output/Destroy()
	disconnect_all()
	return ..()

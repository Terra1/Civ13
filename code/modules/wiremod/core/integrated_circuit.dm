GLOBAL_LIST_EMPTY(integrated_circuits)

/proc/wiremod_available_components()
	return list(
		/obj/item/circuit_component/arithmetic,
		/obj/item/circuit_component/comparison,
		/obj/item/circuit_component/logic,
		/obj/item/circuit_component/length,
		/obj/item/circuit_component/random,
		/obj/item/circuit_component/list_index,
		/obj/item/circuit_component/list_concat,
		/obj/item/circuit_component/list_add,
		/obj/item/circuit_component/list_remove,
		/obj/item/circuit_component/string_concat,
		/obj/item/circuit_component/string_contains,
		/obj/item/circuit_component/string_case,
		/obj/item/circuit_component/string_replace,
		/obj/item/circuit_component/string_split,
		/obj/item/circuit_component/string_to_number,
		/obj/item/circuit_component/delay,
	)

/proc/wiremod_available_component_names()
	return list(
		"Arithmetic", "Comparison", "Logic", "Length", "Random", "List Index",
		"List Concat", "List Add", "List Remove", "String Concat", "String Contains",
		"String Case", "String Replace", "String Split", "String to Number", "Delay",
	)

/proc/wiremod_display_value(value)
	if(isnull(value))
		return "(unset)"
	if(islist(value))
		return "List ([length(value)] entries)"
	if(isatom(value))
		var/atom/atom_value = value
		return "[atom_value.type]"
	return copytext("[value]", 1, 101)

/proc/wiremod_action_index(value, maximum)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value) || value < 1 || value > maximum || value != round(value))
		return 0
	return value

/proc/wiremod_ui_boolean(value)
	if(isnum(value))
		return !!value
	if(istext(value))
		return lowertext(value) in list("true", "yes", "on", "1")
	return FALSE

/proc/wiremod_ui_coordinate(value, fallback = 0)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value))
		return fallback
	return max(-10000, min(10000, value))

/proc/wiremod_ui_port_color(port_type)
	if(port_type == PORT_TYPE_NUMBER)
		return "green"
	if(port_type == PORT_TYPE_BOOLEAN)
		return "yellow"
	if(port_type == PORT_TYPE_STRING)
		return "orange"
	if(port_type == PORT_TYPE_SIGNAL)
		return "purple"
	if(port_type == PORT_TYPE_LIST)
		return "grey"
	return "blue"

/proc/wiremod_ui_component_data(obj/item/circuit_component/component, component_index = 0, obj/item/integrated_circuit/circuit = null)
	var/list/input_data = list()
	for(var/port_index = 1, port_index <= length(component.input_ports), port_index++)
		var/datum/port/input/input_port = component.input_ports[port_index]
		var/list/connected_to = list()
		if(circuit && input_port.connected_output)
			var/output_ref = circuit.ui_port_reference(input_port.connected_output, TRUE)
			if(output_ref)
				connected_to += output_ref
		var/input_ref = component_index ? "input-[component_index]-[port_index]" : ""
		var/current_data
		if(!islist(input_port.value))
			current_data = input_port.value
		input_data += list(list(
			"name" = input_port.name,
			"type" = input_port.datatype,
			"color" = wiremod_ui_port_color(input_port.datatype),
			"ref" = input_ref,
			"connected_to" = connected_to,
			"current_data" = current_data
		))
	var/list/output_data = list()
	for(var/port_index = 1, port_index <= length(component.output_ports), port_index++)
		var/datum/port/output/output_port = component.output_ports[port_index]
		var/output_ref = component_index ? "output-[component_index]-[port_index]" : ""
		output_data += list(list(
			"name" = output_port.name,
			"type" = output_port.datatype,
			"color" = wiremod_ui_port_color(output_port.datatype),
			"ref" = output_ref
		))
	return list(
		"type" = "[component.type]",
		"name" = component.display_name,
		"description" = component.desc,
		"category" = component.category,
		"input_ports" = input_data,
		"output_ports" = output_data
	)

/proc/wiremod_ui_component_catalog()
	var/static/list/catalog
	if(catalog)
		return catalog
	catalog = list()
	for(var/typepath in wiremod_available_components())
		var/obj/item/circuit_component/prototype = new typepath()
		catalog += list(wiremod_ui_component_data(prototype))
		qdel(prototype)
	return catalog

/datum/topic_state/wiremod_circuit/can_use_topic(var/src_object, var/mob/user)
	if(!user || user.stat || user.restrained() || !istype(src_object, /obj/item/integrated_circuit))
		return STATUS_CLOSE
	var/obj/item/integrated_circuit/circuit = src_object
	if(circuit.loc == user || circuit.Adjacent(user))
		return STATUS_INTERACTIVE
	if(istype(circuit.loc, /obj/item/compact_remote))
		var/obj/item/compact_remote/remote = circuit.loc
		if(remote.loc == user || remote.Adjacent(user))
			return STATUS_INTERACTIVE
	return STATUS_CLOSE

/var/global/datum/topic_state/wiremod_circuit/wiremod_circuit_state = new()

/obj/item/integrated_circuit
	name = "integrated circuit"
	desc = "A programmable circuit board. Insert circuit components and connect their ports."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "integrated_circuit"
	w_class = WEIGHT_CLASS_SMALL

	var/list/obj/item/circuit_component/attached_components = list()
	var/list/datum/circuit_variable/circuit_variables = list()
	var/list/execution_queue = list()
	var/on = TRUE
	var/grid_mode = TRUE
	var/screen_x = 0
	var/screen_y = 0
	var/is_executing = FALSE
	var/datum/port/output/pending_output
	var/obj/item/circuit_component/examined_component
	var/examined_rel_x = 0
	var/examined_rel_y = 0
	var/examined_output_port = 0

/obj/item/integrated_circuit/New()
	. = ..()
	GLOB.integrated_circuits += src

/obj/item/integrated_circuit/Destroy()
	execution_queue.Cut()
	for(var/obj/item/circuit_component/component in attached_components.Copy())
		remove_component(component)
		qdel(component)
	for(var/variable_name in circuit_variables)
		qdel(circuit_variables[variable_name])
	circuit_variables.Cut()
	GLOB.integrated_circuits -= src
	return ..()

/obj/item/integrated_circuit/proc/add_component(obj/item/circuit_component/component, mob/user)
	if(!component || component.parent || component == src)
		return FALSE
	if(length(attached_components) >= CIRCUIT_MAX_COMPONENTS)
		if(user)
			to_chat(user, "<span class='warning'>The circuit is at its component limit.</span>")
		return FALSE
	component.disconnect()
	component.forceMove(src)
	component.parent = src
	attached_components += component
	component.rel_x = 48 + ((length(attached_components) - 1) * 24)
	component.rel_y = 64 + ((length(attached_components) - 1) * 24)
	return TRUE

/obj/item/integrated_circuit/proc/remove_component(obj/item/circuit_component/component)
	if(!component || component.parent != src)
		return FALSE
	if(pending_output && pending_output.connected_component == component)
		pending_output = null
	if(examined_component == component)
		examined_component = null
		examined_output_port = 0
	if(istype(component, /obj/item/circuit_component/variable))
		var/obj/item/circuit_component/variable/variable_component = component
		if(variable_component.circuit_variable)
			variable_component.circuit_variable.listeners -= variable_component
			variable_component.circuit_variable = null
	component.disconnect()
	attached_components -= component
	component.parent = null
	component.forceMove(loc)
	return TRUE

/obj/item/integrated_circuit/proc/queue_input(datum/port/input/input_port)
	if(!on || !input_port || input_port.connected_component?.parent != src)
		return
	execution_queue += input_port
	if(is_executing)
		return
	is_executing = TRUE
	var/executed = 0
	while(length(execution_queue) && executed < CIRCUIT_MAX_EXECUTIONS)
		var/datum/port/input/next_input = execution_queue[1]
		execution_queue.Cut(1, 2)
		if(next_input?.connected_component?.parent == src)
			next_input.connected_component.trigger_component(next_input)
		executed++
	if(length(execution_queue))
		stack_trace("Wiremod circuit execution limit reached in [src]; dropping [length(execution_queue)] queued input(s).")
		execution_queue.Cut()
	is_executing = FALSE
	GLOB.nanomanager.update_uis(src)

/obj/item/integrated_circuit/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/circuit_component))
		var/obj/item/circuit_component/component = item
		if(add_component(component, user))
			to_chat(user, "<span class='notice'>You insert [component] into [src].</span>")
			return TRUE
		return FALSE
	return ..()

/obj/item/integrated_circuit/attack_self(mob/user)
	ui_interact(user)

/obj/item/integrated_circuit/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if(!user || wiremod_circuit_state.can_use_topic(src, user) != STATUS_INTERACTIVE)
		return
	open_tgui(user, ui_key, "wiremod_circuit.tmpl", name, 760, 700, circuit_editor_data(), ui, force_open, wiremod_circuit_state, keep_interaction = TRUE)

/obj/item/integrated_circuit/proc/circuit_editor_data()
	var/list/component_data = list()
	var/list/stored_designs = list()
	var/list/variable_data = list()
	for(var/component_index = 1, component_index <= length(attached_components), component_index++)
		var/obj/item/circuit_component/component = attached_components[component_index]
		var/list/component_view = wiremod_ui_component_data(component, component_index, src)
		component_view["index"] = component_index
		component_view["x"] = component.rel_x
		component_view["y"] = component.rel_y
		component_view["removable"] = component.removable
		component_data += list(component_view)
	for(var/typepath in wiremod_available_components())
		stored_designs["[typepath]"] = TRUE
	for(var/variable_name in circuit_variables)
		var/datum/circuit_variable/variable = circuit_variables[variable_name]
		variable_data += list(list(
			"name" = variable.name,
			"datatype" = variable.datatype,
			"color" = variable.color,
			"is_list" = variable.is_list
		))
	var/list/pending_output_data
	var/list/examined_notices = list()
	if(pending_output && pending_output.connected_component?.parent == src)
		pending_output_data = list(
			"component" = pending_output.connected_component.display_name,
			"port" = pending_output.name
		)
	if(examined_component && examined_output_port && examined_output_port <= length(examined_component.output_ports))
		var/datum/port/output/examined_port = examined_component.output_ports[examined_output_port]
		examined_notices += list(list(
			"content" = "[examined_port.name]: [wiremod_display_value(examined_port.value)]",
			"color" = "transparent"
		))
	return list(
		"on" = on,
		"display_name" = name,
		"grid_mode" = grid_mode,
		"screen_x" = screen_x,
		"screen_y" = screen_y,
		"components" = component_data,
		"stored_designs" = stored_designs,
		"global_basic_types" = list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY),
		"variables" = variable_data,
		"is_admin" = FALSE,
		"component_catalog" = wiremod_ui_component_catalog(),
		"pending_output" = pending_output_data,
		"examined_name" = examined_component?.display_name,
		"examined_desc" = examined_component?.desc,
		"examined_notices" = examined_notices,
		"examined_rel_x" = examined_rel_x,
		"examined_rel_y" = examined_rel_y
	)

/obj/item/integrated_circuit/ui_actions(ui_key)
	return list(
		"toggle", "add_component", "remove_component", "select_output", "connect", "disconnect", "cancel_connect", "set_input",
		"print_component", "detach_component", "set_component_coordinates", "add_connection", "remove_connection",
		"set_component_input", "get_component_value", "move_screen", "toggle_grid_mode", "set_display_name",
		"set_examined_component", "remove_examined_component", "add_variable", "remove_variable",
		"add_setter_or_getter"
	)

/obj/item/integrated_circuit/ui_action_fields(ui_key, action)
	if(action == "remove_component")
		return list("component")
	if(action == "detach_component")
		return list("component_id")
	if(action in list("select_output", "connect", "disconnect"))
		return list("component", "port")
	if(action == "set_input")
		return list("component", "port", "input")
	if(action == "print_component")
		return list("component_to_print", "rel_x", "rel_y")
	if(action == "set_component_coordinates")
		return list("component_id", "rel_x", "rel_y")
	if(action == "add_connection")
		return list("input_component_id", "input_port_id", "output_component_id", "output_port_id")
	if(action == "remove_connection")
		return list("component_id", "is_input", "port_id")
	if(action == "set_component_input")
		return list("component_id", "port_id", "input", "set_null", "marked_atom")
	if(action == "get_component_value")
		return list("component_id", "port_id")
	if(action == "move_screen")
		return list("screen_x", "screen_y")
	if(action == "set_display_name")
		return list("display_name")
	if(action == "set_examined_component")
		return list("component_id", "x", "y")
	if(action == "add_variable")
		return list("variable_name", "variable_datatype", "is_list", "is_assoc_list")
	if(action == "remove_variable")
		return list("variable_name")
	if(action == "add_setter_or_getter")
		return list("variable", "is_setter", "rel_x", "rel_y")
	return null

/obj/item/integrated_circuit/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if(wiremod_circuit_state.can_use_topic(src, user) != STATUS_INTERACTIVE)
		return TRUE
	if(action == "toggle")
		on = !on
	else if(action == "toggle_grid_mode")
		grid_mode = !grid_mode
	else if(action == "add_component")
		var/type_index = wiremod_action_index(params["value"], length(wiremod_available_components()))
		if(type_index)
			var/list/component_types = wiremod_available_components()
			var/typepath = component_types[type_index]
			var/obj/item/circuit_component/new_component = new typepath()
			if(!add_component(new_component, user))
				qdel(new_component)
	else if(action == "print_component")
		var/typepath
		for(var/available_type in wiremod_available_components())
			if("[available_type]" == params["component_to_print"])
				typepath = available_type
				break
		if(typepath)
			var/obj/item/circuit_component/new_component = new typepath()
			if(add_component(new_component, user))
				new_component.rel_x = wiremod_ui_coordinate(params["rel_x"], new_component.rel_x)
				new_component.rel_y = wiremod_ui_coordinate(params["rel_y"], new_component.rel_y)
			else
				qdel(new_component)
		else
			to_chat(user, "<span class='warning'>That circuit component is unavailable.</span>")
	else if(action == "remove_component")
		var/component_index = wiremod_action_index(params["component"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			if(component.removable)
				remove_component(component)
				user.put_in_hands(component)
	else if(action == "detach_component")
		var/component_index = wiremod_action_index(params["component_id"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			if(component.removable)
				remove_component(component)
				user.put_in_hands(component)
	else if(action == "set_component_coordinates")
		var/component_index = wiremod_action_index(params["component_id"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			component.rel_x = wiremod_ui_coordinate(params["rel_x"], component.rel_x)
			component.rel_y = wiremod_ui_coordinate(params["rel_y"], component.rel_y)
	else if(action == "add_connection")
		var/input_component_index = wiremod_action_index(params["input_component_id"], length(attached_components))
		var/output_component_index = wiremod_action_index(params["output_component_id"], length(attached_components))
		if(input_component_index && output_component_index)
			var/obj/item/circuit_component/input_component = attached_components[input_component_index]
			var/obj/item/circuit_component/output_component = attached_components[output_component_index]
			var/input_port_index = wiremod_action_index(params["input_port_id"], length(input_component.input_ports))
			var/output_port_index = wiremod_action_index(params["output_port_id"], length(output_component.output_ports))
			if(input_port_index && output_port_index)
				if(!input_component.input_ports[input_port_index].connect(output_component.output_ports[output_port_index]))
					to_chat(user, "<span class='warning'>Those circuit ports cannot be connected.</span>")
	else if(action == "remove_connection")
		var/component_index = wiremod_action_index(params["component_id"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/is_input = wiremod_ui_boolean(params["is_input"])
			var/port_count = is_input ? length(component.input_ports) : length(component.output_ports)
			var/port_index = wiremod_action_index(params["port_id"], port_count)
			if(port_index)
				if(is_input)
					component.input_ports[port_index].disconnect()
				else
					component.output_ports[port_index].disconnect_all()
	else if(action == "set_component_input")
		var/component_index = wiremod_action_index(params["component_id"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/port_index = wiremod_action_index(params["port_id"], length(component.input_ports))
			if(port_index)
				var/datum/port/input/input_port = component.input_ports[port_index]
				if(wiremod_ui_boolean(params["marked_atom"]))
					to_chat(user, "<span class='warning'>Entity inputs are not available in core circuits.</span>")
				else if(wiremod_ui_boolean(params["set_null"]))
					if(!input_port.connected_output)
						input_port.set_input(null)
				else if(input_port.datatype == PORT_TYPE_SIGNAL)
					input_port.set_input(null)
				else if(!input_port.connected_output && input_port.datatype in list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY))
					set_manual_input(input_port, params["input"], user)
	else if(action == "get_component_value")
		var/component_index = wiremod_action_index(params["component_id"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/port_index = wiremod_action_index(params["port_id"], length(component.output_ports))
			if(port_index)
				var/datum/port/output/output_port = component.output_ports[port_index]
				to_chat(user, "<span class='notice'>[output_port.name] value: [html_encode(wiremod_display_value(output_port.value))]</span>")
	else if(action == "move_screen")
		screen_x = wiremod_ui_coordinate(params["screen_x"], screen_x)
		screen_y = wiremod_ui_coordinate(params["screen_y"], screen_y)
	else if(action == "set_display_name")
		if(istext(params["display_name"]))
			var/new_name = copytext(params["display_name"], 1, 33)
			if(length(new_name))
				name = new_name
	else if(action == "set_examined_component")
		var/component_index = wiremod_action_index(params["component_id"], length(attached_components))
		if(component_index)
			examined_component = attached_components[component_index]
			examined_output_port = 0
			examined_rel_x = wiremod_ui_coordinate(params["x"], 0)
			examined_rel_y = wiremod_ui_coordinate(params["y"], 0)
	else if(action == "remove_examined_component")
		examined_component = null
		examined_output_port = 0
	else if(action == "select_output")
		var/component_index = wiremod_action_index(params["component"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/port_index = wiremod_action_index(params["port"], length(component.output_ports))
			if(port_index)
				pending_output = component.output_ports[port_index]
	else if(action == "connect")
		var/component_index = wiremod_action_index(params["component"], length(attached_components))
		if(component_index && pending_output?.connected_component?.parent == src)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/port_index = wiremod_action_index(params["port"], length(component.input_ports))
			if(port_index)
				component.input_ports[port_index].connect(pending_output)
		pending_output = null
	else if(action == "disconnect")
		var/component_index = wiremod_action_index(params["component"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/port_index = wiremod_action_index(params["port"], length(component.input_ports))
			if(port_index)
				component.input_ports[port_index].disconnect()
	else if(action == "cancel_connect")
		pending_output = null
	else if(action == "set_input")
		var/component_index = wiremod_action_index(params["component"], length(attached_components))
		if(component_index)
			var/obj/item/circuit_component/component = attached_components[component_index]
			var/port_index = wiremod_action_index(params["port"], length(component.input_ports))
			if(port_index)
				var/datum/port/input/input_port = component.input_ports[port_index]
				var/manual_value = params["input"]
				if(!isnull(manual_value) && !istext(manual_value))
					manual_value = "[manual_value]"
				if(input_port.datatype in list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY) && !input_port.connected_output && istext(manual_value))
					set_manual_input(input_port, manual_value, user)
	else if(action == "add_variable")
		var/raw_variable_name = params["variable_name"]
		if(!istext(raw_variable_name))
			to_chat(user, "<span class='warning'>Enter a variable name.</span>")
		else
			var/variable_name = trim(copytext(raw_variable_name, 1, 25))
			var/variable_datatype = params["variable_datatype"]
			if(!length(variable_name) || variable_name in circuit_variables)
				to_chat(user, "<span class='warning'>Enter a new variable name.</span>")
			else if(!(variable_datatype in list(PORT_TYPE_NUMBER, PORT_TYPE_BOOLEAN, PORT_TYPE_STRING, PORT_TYPE_ANY)))
				to_chat(user, "<span class='warning'>That variable type is unavailable.</span>")
			else
				var/is_list = wiremod_ui_boolean(params["is_list"]) || wiremod_ui_boolean(params["is_assoc_list"])
				var/datum/circuit_variable/variable = new(variable_name, variable_datatype, is_list)
				circuit_variables[variable_name] = variable
	else if(action == "remove_variable")
		var/variable_name = params["variable_name"]
		var/datum/circuit_variable/variable = circuit_variables[variable_name]
		if(variable)
			for(var/obj/item/circuit_component/variable/variable_component in attached_components.Copy())
				if(variable_component.circuit_variable == variable)
					remove_component(variable_component)
					qdel(variable_component)
			circuit_variables -= variable_name
			qdel(variable)
		else
			to_chat(user, "<span class='warning'>That circuit variable no longer exists.</span>")
	else if(action == "add_setter_or_getter")
		var/variable_name = params["variable"]
		var/datum/circuit_variable/variable = circuit_variables[variable_name]
		if(!variable)
			to_chat(user, "<span class='warning'>That circuit variable no longer exists.</span>")
		else
			var/is_setter = wiremod_ui_boolean(params["is_setter"])
			var/obj/item/circuit_component/variable/variable_component
			if(is_setter)
				variable_component = new /obj/item/circuit_component/variable/setter()
				var/obj/item/circuit_component/variable/setter/setter_component = variable_component
				setter_component.value_input.set_datatype(variable.port_datatype)
				variable_component.display_name = "Setter: [variable.name]"
			else
				variable_component = new /obj/item/circuit_component/variable/getter()
				var/obj/item/circuit_component/variable/getter/getter_component = variable_component
				getter_component.value_output.set_datatype(variable.port_datatype)
				variable_component.display_name = "Getter: [variable.name]"
			variable_component.circuit_variable = variable
			if(add_component(variable_component, user))
				variable_component.rel_x = wiremod_ui_coordinate(params["rel_x"], variable_component.rel_x)
				variable_component.rel_y = wiremod_ui_coordinate(params["rel_y"], variable_component.rel_y)
				if(!is_setter)
					variable.listeners += variable_component
					var/obj/item/circuit_component/variable/getter/added_getter = variable_component
					added_getter.value_output.set_output(variable.value)
			else
				qdel(variable_component)
	return TRUE

/obj/item/integrated_circuit/proc/set_manual_input(datum/port/input/input_port, manual_value, mob/user)
	if(istext(manual_value) && length(manual_value) > PORT_MAX_STRING_LENGTH)
		to_chat(user, "<span class='warning'>Input is too long.</span>")
		return FALSE
	if(input_port.datatype == PORT_TYPE_NUMBER)
		if(istext(manual_value))
			manual_value = text2num(manual_value)
			if(isnull(manual_value))
				to_chat(user, "<span class='warning'>Enter a valid number.</span>")
				return FALSE
		else if(!isnum(manual_value))
			to_chat(user, "<span class='warning'>Enter a valid number.</span>")
			return FALSE
	else if(input_port.datatype == PORT_TYPE_BOOLEAN)
		if(isnum(manual_value))
			manual_value = !!manual_value
		else if(istext(manual_value))
			manual_value = lowertext(manual_value)
			if(!(manual_value in list("true", "false", "yes", "no", "on", "off", "1", "0")))
				to_chat(user, "<span class='warning'>Enter true or false.</span>")
				return FALSE
	else if(input_port.datatype == PORT_TYPE_ANY)
		if(istext(manual_value))
			var/numeric_value = text2num(manual_value)
			if(!isnull(numeric_value))
				manual_value = numeric_value
		else if(!isnull(manual_value) && !isnum(manual_value))
			manual_value = "[manual_value]"
	else if(input_port.datatype == PORT_TYPE_STRING && !istext(manual_value))
		manual_value = "[manual_value]"
	input_port.set_input(manual_value)
	return TRUE

/obj/item/integrated_circuit/proc/ui_port_reference(datum/port/target_port, is_output)
	if(!target_port)
		return null
	for(var/component_index = 1, component_index <= length(attached_components); component_index++)
		var/obj/item/circuit_component/component = attached_components[component_index]
		if(component != target_port.connected_component)
			continue
		var/list/ports = is_output ? component.output_ports : component.input_ports
		for(var/port_index = 1, port_index <= length(ports); port_index++)
			if(ports[port_index] == target_port)
				var/direction = is_output ? "output" : "input"
				return "[direction]-[component_index]-[port_index]"
	return null

/datum/circuit_variable
	var/name
	var/datatype
	var/port_datatype
	var/color
	var/value
	var/is_list = FALSE
	var/list/obj/item/circuit_component/variable/getter/listeners = list()

/datum/circuit_variable/New(variable_name, variable_datatype, variable_is_list = FALSE)
	. = ..()
	name = variable_name
	datatype = variable_datatype
	is_list = variable_is_list
	port_datatype = is_list ? PORT_TYPE_LIST : datatype
	color = wiremod_ui_port_color(port_datatype)
	if(is_list)
		value = list()

/datum/circuit_variable/proc/set_value(new_value)
	if(port_datatype == PORT_TYPE_LIST)
		if(!islist(new_value))
			return FALSE
		var/list/new_list_value = new_value
		value = new_list_value.Copy()
	else
		var/datum/circuit_datatype/handler = circuit_datatype_for(port_datatype)
		value = handler.convert(new_value)
	for(var/obj/item/circuit_component/variable/getter/listener as anything in listeners.Copy())
		if(listener.parent)
			listener.value_output.set_output(value)
	return TRUE

/obj/item/circuit_component/variable
	display_name = "Variable"
	category = "Utility"

	var/datum/circuit_variable/circuit_variable

/obj/item/circuit_component/variable/getter
	display_name = "Variable Getter"

	var/datum/port/output/value_output

/obj/item/circuit_component/variable/getter/populate_ports()
	value_output = add_output_port("Value", PORT_TYPE_ANY)

/obj/item/circuit_component/variable/getter/Destroy()
	if(circuit_variable)
		circuit_variable.listeners -= src
		circuit_variable = null
	return ..()

/obj/item/circuit_component/variable/setter
	display_name = "Variable Setter"

	var/datum/port/input/value_input

/obj/item/circuit_component/variable/setter/populate_ports()
	value_input = add_input_port("Input", PORT_TYPE_ANY, trigger = PROC_REF(set_variable))

/obj/item/circuit_component/variable/setter/proc/set_variable(datum/port/input/input_port)
	if(circuit_variable)
		circuit_variable.set_value(input_port.value)

/obj/item/integrated_circuit/examine(mob/user)
	. = ..()
	. += "It contains [length(attached_components)] component[length(attached_components) == 1 ? "" : "s"]."
	if(on)
		. += "The circuit is active."

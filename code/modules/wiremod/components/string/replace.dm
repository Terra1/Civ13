/obj/item/circuit_component/string_replace
	name = "string replace component"
	display_name = "String Replace"
	category = "String"

	var/datum/port/input/value_input
	var/datum/port/input/search
	var/datum/port/input/replacement
	var/datum/port/output/result

/obj/item/circuit_component/string_replace/populate_ports()
	value_input = add_input_port("String", PORT_TYPE_STRING, trigger = PROC_REF(replace_text))
	search = add_input_port("Search", PORT_TYPE_STRING, trigger = PROC_REF(replace_text))
	replacement = add_input_port("Replacement", PORT_TYPE_STRING, trigger = PROC_REF(replace_text))
	result = add_output_port("Result", PORT_TYPE_STRING)

/obj/item/circuit_component/string_replace/proc/replace_text(datum/port/input/input)
	if(isnull(value_input.value) || !length(search.value))
		result.set_output(value_input.value)
		return
	result.set_output(replacetext(value_input.value, search.value, replacement.value))

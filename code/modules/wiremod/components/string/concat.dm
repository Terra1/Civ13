/obj/item/circuit_component/string_concat
	name = "string concat component"
	display_name = "String Concat"
	category = "String"

	var/datum/circuit_input/input_a
	var/datum/circuit_input/input_b
	var/datum/circuit_output/result

/obj/item/circuit_component/string_concat/populate_ports()
	input_a = add_input("A", PORT_TYPE_STRING, PROC_REF(concatenate))
	input_b = add_input("B", PORT_TYPE_STRING, PROC_REF(concatenate))
	result = add_output("Result", PORT_TYPE_STRING)

/obj/item/circuit_component/string_concat/proc/concatenate(datum/circuit_input/input)
	result.set_output("[input_a.value ? input_a.value : ""][input_b.value ? input_b.value : ""]")

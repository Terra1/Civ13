/obj/item/circuit_component/comparison
	name = "comparison component"
	display_name = "Comparison"
	category = "Math"

	var/datum/circuit_input/input_a
	var/datum/circuit_input/input_b
	var/datum/circuit_output/result

/obj/item/circuit_component/comparison/populate_ports()
	input_a = add_input("A", PORT_TYPE_ANY, PROC_REF(calculate))
	input_b = add_input("B", PORT_TYPE_ANY, PROC_REF(calculate))
	result = add_output("Result", PORT_TYPE_BOOLEAN)

/obj/item/circuit_component/comparison/proc/calculate(datum/circuit_input/input)
	result.set_output(input_a.value == input_b.value)

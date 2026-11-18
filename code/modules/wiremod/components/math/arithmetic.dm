/obj/item/circuit_component/arithmetic
	name = "arithmetic component"
	display_name = "Arithmetic"
	category = "Math"

	var/datum/circuit_input/input_a
	var/datum/circuit_input/input_b
	var/datum/circuit_output/result
	var/datum/circuit_input/operation

/obj/item/circuit_component/arithmetic/populate_ports()
	input_a = add_input("A", PORT_TYPE_NUMBER, PROC_REF(calculate))
	input_b = add_input("B", PORT_TYPE_NUMBER, PROC_REF(calculate))
	operation = add_input("Operation", PORT_TYPE_STRING, PROC_REF(calculate))
	result = add_output("Result", PORT_TYPE_NUMBER)

/obj/item/circuit_component/arithmetic/proc/calculate(datum/circuit_input/input)
	if(isnull(input_a.value) || isnull(input_b.value))
		return
	var/output
	switch(operation.value)
		if("Subtract")
			output = input_a.value - input_b.value
		if("Multiply")
			output = input_a.value * input_b.value
		if("Divide")
			if(input_b.value == 0)
				output = null
			else
				output = input_a.value / input_b.value
		if("Minimum")
			output = min(input_a.value, input_b.value)
		if("Maximum")
			output = max(input_a.value, input_b.value)
		else
			output = input_a.value + input_b.value
	result.set_output(output)

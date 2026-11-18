/obj/item/circuit_component/delay
	name = "delay component"
	display_name = "Delay"
	category = "Utility"

	var/datum/circuit_input/delay_amount
	var/datum/circuit_input/trigger
	var/datum/circuit_output/output
	var/timer_id

/obj/item/circuit_component/delay/populate_ports()
	delay_amount = add_input("Delay", PORT_TYPE_NUMBER)
	trigger = add_input("Trigger", PORT_TYPE_SIGNAL, PROC_REF(run_delay))
	output = add_output("Output", PORT_TYPE_SIGNAL)

/obj/item/circuit_component/delay/proc/run_delay(datum/circuit_input/input)
	if(isnum(delay_amount.value) && delay_amount.value > 0)
		timer_id = addtimer(CALLBACK(output, TYPE_PROC_REF(/datum/circuit_output, set_output), world.time), delay_amount.value * 10, TIMER_STOPPABLE)
	else
		output.set_output(world.time)

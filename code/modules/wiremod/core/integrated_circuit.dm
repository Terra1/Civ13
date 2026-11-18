GLOBAL_LIST_EMPTY(integrated_circuits)

/obj/item/integrated_circuit
	name = "integrated circuit"
	desc = "A programmable circuit board. Insert circuit components and connect their ports."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "integrated_circuit"
	w_class = WEIGHT_CLASS_SMALL

	var/list/obj/item/circuit_component/attached_components = list()
	var/on = FALSE

/obj/item/integrated_circuit/New(mapload)
	. = ..()
	GLOB.integrated_circuits += src

/obj/item/integrated_circuit/Destroy()
	for(var/obj/item/circuit_component/component in attached_components.Copy())
		remove_component(component)
		qdel(component)
	GLOB.integrated_circuits -= src
	return ..()

/obj/item/integrated_circuit/proc/add_component(obj/item/circuit_component/component, mob/user)
	if(!component || component.parent)
		return FALSE
	component.forceMove(src)
	component.parent = src
	attached_components += component
	return TRUE

/obj/item/integrated_circuit/proc/remove_component(obj/item/circuit_component/component)
	if(!component)
		return
	component.parent = null
	attached_components -= component
	component.forceMove(loc)

/obj/item/integrated_circuit/attackby(obj/item/item, mob/user)
	if(istype(item, /obj/item/circuit_component))
		if(add_component(item, user))
			to_chat(user, "<span class='notice'>You insert [item] into [src].</span>")
		return
	return ..()

/obj/item/integrated_circuit/examine(mob/user)
	. = ..()
	. += "It contains [length(attached_components)] component[length(attached_components) == 1 ? "" : "s"]."
	if(on)
		. += "The circuit is active."

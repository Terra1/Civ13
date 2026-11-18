from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DME = ROOT / "civ13.dme"
MODULE = ROOT / "code" / "modules" / "wiremod"


def module_source():
    return "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in MODULE.rglob("*.dm")
    )


def test_wiremod_core_and_general_components_are_included():
    dme = DME.read_text(encoding="utf-8")
    required = (
        "code\\modules\\wiremod\\core\\component.dm",
        "code\\modules\\wiremod\\core\\integrated_circuit.dm",
        "code\\modules\\wiremod\\core\\port.dm",
        "code\\modules\\wiremod\\shell\\compact_remote.dm",
        "code\\modules\\wiremod\\components\\math\\arithmetic.dm",
        "code\\modules\\wiremod\\components\\list\\index.dm",
        "code\\modules\\wiremod\\components\\string\\split.dm",
        "code\\modules\\wiremod\\components\\utility\\delay.dm",
    )
    assert all(include in dme for include in required)


def test_port_links_check_types_and_disconnect_both_directions():
    source = (MODULE / "core" / "port.dm").read_text(encoding="utf-8")
    assert "datatype_handler.can_receive_from_datatype(output.datatype)" in source
    assert "output.connected_inputs |= src" in source
    assert "connected_output.connected_inputs -= src" in source
    assert "for(var/datum/port/input/input in connected_inputs?.Copy())" in source


def test_component_execution_is_queued_and_bounded():
    source = (MODULE / "core" / "integrated_circuit.dm").read_text(encoding="utf-8")
    assert "execution_queue += input_port" in source
    assert "executed < CIRCUIT_MAX_EXECUTIONS" in source
    assert "execution_queue.Cut()" in source
    assert "CIRCUIT_MAX_COMPONENTS" in source


def test_editor_uses_registered_tgui_and_checks_user_access():
    source = (MODULE / "core" / "integrated_circuit.dm").read_text(encoding="utf-8")
    interfaces = (ROOT / "tgui" / "src" / "interfaces" / "index.tsx").read_text(encoding="utf-8")
    assert "/proc/wiremod_available_components()" in source
    assert "var/typepath = component_types[type_index]" in source
    assert "wiremod_circuit_state.can_use_topic(src, user)" in source
    assert 'open_tgui(user, ui_key, "wiremod_circuit.tmpl"' in source
    assert "'wiremod_circuit.tmpl': WiremodCircuit" in interfaces
    assert "ui_actions(ui_key)" in source
    assert "new typepath()" in source


def test_compact_remote_has_a_non_removable_signal_source():
    source = (MODULE / "shell" / "compact_remote.dm").read_text(encoding="utf-8")
    assert "/obj/item/compact_remote/attack_self(mob/user)" in source
    assert "remote_input.removable = FALSE" in source
    assert 'add_output_port("Signal", PORT_TYPE_SIGNAL)' in source
    assert "remote_input.send_trigger(user)" in source


def test_manual_numeric_and_boolean_inputs_are_validated():
    source = (MODULE / "core" / "integrated_circuit.dm").read_text(encoding="utf-8")
    assert 'manual_value = text2num(manual_value)' in source
    assert 'manual_value in list("true", "false", "yes", "no", "on", "off", "1", "0")' in source
    assert "Enter a valid number." in source
    assert "Enter true or false." in source


def test_variable_getters_unregister_when_removed():
    source = (MODULE / "core" / "integrated_circuit.dm").read_text(encoding="utf-8")
    assert "/obj/item/circuit_component/variable/getter/Destroy()" in source
    assert "circuit_variable.listeners -= src" in source


def test_module_does_not_depend_on_tgstation_ui_or_hardware():
    source = module_source()
    forbidden = (
        "/datum/tgui",
        "SStgui",
        "/obj/machinery/component_printer",
        "/obj/item/stock_parts/power_store",
    )
    assert all(token not in source for token in forbidden)

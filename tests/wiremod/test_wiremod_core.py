from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DME = ROOT / "civ13.dme"
MODULE = ROOT / "code" / "modules" / "wiremod"


def test_wiremod_core_is_included():
    dme = DME.read_text(encoding="utf-8")
    required = (
        "code\\modules\\wiremod\\core\\component.dm",
        "code\\modules\\wiremod\\core\\integrated_circuit.dm",
        "code\\modules\\wiremod\\core\\port.dm",
        "code\\modules\\wiremod\\components\\math\\arithmetic.dm",
    )
    assert all(include in dme for include in required)


def test_wiremod_core_excludes_tg_only_dependencies():
    dm_files = list(MODULE.rglob("*.dm"))
    source = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in dm_files)
    forbidden = (
        "/datum/tgui",
        "SStgui",
        "/obj/machinery/component_printer",
        "/obj/item/stock_parts/power_store",
    )
    assert all(token not in source for token in forbidden)

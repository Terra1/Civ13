# Wiremod core

This module ports the reusable circuit engine and general-purpose components
from tgstation Wiremod into Civ13. The import merge is `5a3f3ef4a5`, whose
second parent is tgstation `16aade0bda`; the upstream commit graph remains
reachable, and `git log --follow` traverses the history of imported source files.

The Civ13 implementation includes typed input/output ports, guarded component
execution, tgstation's graph-based React/TGUI circuit editor imported verbatim
from `bacb22efd80de34f9b992ec3c731a1321147119e`, a compact remote shell, and
math, list, string, and delay components. Thin Civ13 adapters provide the
upstream UI's backend, window layout, and component-catalog asset while the DM
backend exposes only the core components ported here. Unrelated tgstation
shells, hardware integrations, admin components, and game-specific UI assets
are excluded.

Open an integrated circuit in hand to add components, set unconnected scalar
inputs, create typed variables with getter/setter nodes, and connect an output
to a destination input. Inputs accept one connection. The compact remote has a
built-in signal output; Alt-click it to edit its circuit and press it to trigger
connected components. Lists are built with String Split and passed between
list components. Circuit execution is limited to 1,000 queued component calls
per propagation to stop feedback loops.

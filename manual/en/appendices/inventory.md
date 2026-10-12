# Assets and Delivery

> Public 0.4.7 · Plugin and manual only. No extracted character sheets, shared-library payloads, cases or local test projects are bundled.


Package 01 contains three styles, ten categories and 46 parametric building types, 35 lightweight terrain textures, 14 schemes and three local-study characters. Package 02 is the external shared library. Package 03 combines Cases 01–05 and 07 with their dependencies. The large-world case is not included. See [installation order](../quick_start.md), [shared library](../shared_library.md) and [case entries](../history.md).

| Package | Destination | Required? |
|---|---|---|
| 01 Plugin & Manual | addons in the project root; read the manual in a browser | Yes |
| 02 Shared Library | Outside the project; connect through the plugin | Optional |
| 03 Cases 01–05 & 07 | showcase, case01, case07 and local_study in the project root | Optional; cases require only 01 + 03 |

Do not drag the whole release folder into a Godot project. Extracted study assets retain their source and usage restrictions; they are not covered by the plugin code's MIT license.


[← Manual contents](../index.md) · [Release notes](../release_notes.md)

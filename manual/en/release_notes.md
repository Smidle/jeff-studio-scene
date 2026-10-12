# 0.4.7.1 release notes

> Public 0.4.7.1 · Plugin and manual only. No extracted character sheets, shared-library payloads, cases or local test projects are bundled.


A scene-storage and paving fix for 0.4.7. Existing building, weather and character features remain compatible.

## Smaller text scenes

- Fixes generated resources being written to disk but embedded again in the text scene because the live resource was not bound to its external path. New buildings, town terrain and generated road/wall meshes automatically use compressed project-owned `.res` files; `.tscn` retains nodes and external references.
- Adds **Assets → Import & Check → Optimize Scene File**. For an old scene, save first and run this once. The saved scene is backed up before migration; press **Ctrl / Cmd + S** afterward.
- A representative saved-scene copy shrank from **8.09 MiB to about 227 KiB of text**, with model data retained in external resources. Geometry, texture pixels, transforms, skins, collision and terrain remain consistent after reopening. Results depend on scene content.
- Keep `hd2d_generated` when moving, backing up or sharing your project. It contains required scene resources, not disposable caches.

## Placement with eight occupied terrain layers

- Fixes town blueprint placement failing when all eight terrain layers are occupied; this was not a twelve-building limit.
- **Auto** paving first reuses a matching road layer. With no free layer, it switches to a **fitted pixel paving mesh** and reports the fallback without overwriting existing textures.
- Sidebar preview, blueprint and final placement share the decision. Reused road layers retain their appearance. Explicit layer selection, bounds and object-conflict checks remain active.

## Installation and validation

Download only `01_HD2D_0.4.7.1_Plugin_Manual.zip`. Close Godot, back up the old plugin and replace `addons/hd2d_scene_tools`; retain your scenes and generated resources. Both manuals now explain the optimization action and saving workflow with actual interface captures.

Plugin and manuals only: no shared libraries, cases, local test scenes or caches. Public downloads continue to exclude extracted character images and indexes. Targeted Compatibility and Forward+ checks cover external storage, runtime reopening, eight occupied layers, thirteen consecutive blueprint placements and undo/redo. No case or full regression was rerun.

---

## 0.4.7 release notes (since 0.4.6)

## Day/night and weather

- A 24-hour clock: authored start time, dawn/noon/dusk/midnight shortcuts, automatic cycles, day duration, night fill and moonlight.
- Clear, Rain, Snow, Fog, Sandstorm, Thunderstorm, Autumn Maple and Spring Sakura. Cloudy and Blizzard are excluded from the final release; their retired IDs fall back to Clear.
- Optional world-space 3D weather, smooth transitions, roof sheltering and interior exclusion boxes, bounded splashes, vegetation wind linkage and an optional Sky3D pixel sky. New maps enable enhancements; older scenes opt in.
- Plugin terrain and layered ground become uniformly wet/dry, ignoring roof sheltering for wetness. Fixes abrupt coverage edges and mismatched chunk colors. Custom materials are not automatically wetted.
- Rain/snow size, lightning frequency/duration and dedicated Maple/Sakura controls for budget, size, emission timing randomness, individual fall-speed variation, sway, flipping and seeds. Active weather receives the available budget; transitions share it.
- Environment is grouped into Day & Night, Weather and Other, with a fixed gold Apply area and one undo transaction. Scene preview remains in Camera.

## Buildings and towns

- Adds **Machiya, Nordic, Tropical Harbor, Chinese Palace, Gothic and Steamworks**, for nine styles alongside Jiangnan, European and Desert. The existing 10 categories / 46 functional types remain.
- Export the current built-in building as a **textured GLB for Blender**, without changing the scene instance. Original styles retain v5; new styles use v6; old recipes are not automatically rebuilt.
- **Double-row street village** becomes the default, with **one-meter building gaps and front setbacks**. Single rows, concentric layouts, blueprint placement and Q/E rotation remain.

## Fixes and delivery

- Preset character placement automatically creates a missing `Characters` container; one undo/redo covers both container and character and the result saves normally.
- Improved particle budget allocation and random distribution, with fixed-seed reproducibility or a fresh distribution per run.
- Updated bilingual manuals, UI images and installation instructions. Only the plugin and manuals ship; no cases, shared libraries, local forests, test scenes or caches.

**Public versus local-study:** the public GitHub package excludes extracted character images and indexes. Character import, animation and role tools remain available. The local-study package retains its three existing presets, without another resource package.

**Limits:** no persistent puddles, snow accumulation, footprints or automatic seasonal tree textures. Roof collision is a top-surface heightfield; multilevel interiors need exclusion boxes. True depth of field requires Forward+; relevant features have been checked on both renderers.


[← Manual contents](index.md) · [Release notes](release_notes.md)

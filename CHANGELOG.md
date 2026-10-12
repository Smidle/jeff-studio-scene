# 0.4.7 release notes (since 0.4.6)

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

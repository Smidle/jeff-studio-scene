# Embedded Sky3D runtime

Upstream: [TokisanGames/Sky3D v2.1.0](https://github.com/TokisanGames/Sky3D/tree/v2.1.0), commit `6e151bc3d941906643443b3751a1df545a08feda`.

`UPSTREAM.json` records the upstream SHA-256 of every fetched file. The upstream MIT license and all texture licenses remain alongside the files. Milky Way artwork retains its ESO / S. Brunier CC BY 4.0 attribution; see `assets/thirdparty/textures/milkyway/LICENSE` files. This is a runtime dependency, not an independently enabled editor plugin.

Local changes for Jeff Studio 0.4.6 weather:

- All `res://addons/sky_3d/` paths are relocated under this directory. Global classes have a `Jeff` prefix, including Sky3D, SkyDome, TimeOfDay, ScatterLib, OrbitalElements and TODMath.
- Editor plugin entrypoints, plugin configuration and upstream import caches are excluded. Generated sky children have no serialized scene owner; authoring is handled by `HD2DWeatherProfile`.
- The environment signal accepts its emitted environment argument. Texture defaults load when the runtime node is instantiated, avoiding preload failures before a fresh project's first import.
- SkyMaterial quantizes only sky sampling directions and sky colors. A separate sky-only tone curve prevents HDR clipping under the existing scene tone mapper. Its clock comes from the weather controller. The original 32px moon face uses planar disk projection, nearest sampling and stepped phase shading.
- The weather controller disables both Sky3D timers, drives celestial time itself, owns environment lighting, and disables the atmospheric screen quad and volumetric fog. Existing ordinary distance fog, grading and camera depth of field remain in the stage.

The upstream astronomical calculations and atmosphere functions retain their licenses. Original leaf/petal/moon artwork is in `../../assets/weather/`; it is not derived from upstream textures.

0.4.7 integration keeps the vendored runtime unchanged. `HD2DStage` replaces the reference project's `HD2DWeatherProfile` as the authoring owner; its existing day/night clock, azimuth and sun-elevation trajectory drive the sky. Sky3D's own timers and automatic processing remain disabled. No separate Sky3D editor plugin needs enabling.

<a name="manual-top"></a>

# Part III · Environment

<!-- manual-navigation:start -->
[Project home](../../../README.md) / [Manual contents](../../README.md) / [English manual](../index.md) / [Tool guides](README.md)

[← Up one level](README.md) · [中文](../../zh/reference/environment.md)

<details>
<summary>On this page (expand)</summary>

- [Collapsible visual groups](#manual-section-01)
- [Buttons and operations](#manual-section-02)
- [Every parameter](#manual-section-03)
- [Recommended sequence and pitfalls](#manual-section-04)

</details>
<!-- manual-navigation:end -->

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../../DISTRIBUTION.md)

Select the stage root, adjust sky, sunlight and effects, then apply. Presentation post-processing is visible in the game or isolated preview; the native editor viewport remains an editing view.

<a name="manual-section-01"></a>

## Collapsible visual groups

Click a bordered heading to expand or collapse it. Common groups start open (★); your choice is remembered per project. **Expand All / Collapse All** only affects this page. Tab to a heading and use Enter/Space, or Left/Right. Hiding controls keeps drafts and active tools/audition; it neither applies settings nor saves the scene. Shared Apply buttons stay outside the folds.

| Group | Contains |
| --- | --- |
| ★ [Sky & background](#group-environment-sky) | Sky mode, sky and horizon/fog colors; does not generate a sky model. |
| ★ [Sun & shadows](#group-environment-sun) | Sun color/energy, azimuth/elevation and shadow toggle. |
| [Ambient fill](#group-environment-ambient) | Ambient color and energy for shadowed areas. |
| [Wind & cloud shadows](#group-environment-wind) | Stage-wide wind and cloud-shadow strengths; per-asset wind stays in Assets. |
| [Distance fog](#group-environment-fog) | Ordinary distance fog toggle and density, not volumetric fog. |
| [Color adjustments](#group-environment-color) | Saturation and contrast. |
| [Real depth of field](#group-environment-dof) | Far DOF strength; disabled in Compatibility, with the limitation outside the fold. |
| [Presentation effects](#group-environment-post) | Presentation toggle, vignette and screen-zone blur for game/Preview only. |

<a name="group-environment-sky"></a>

**Sky & background**

<a name="group-environment-sun"></a>

**Sun & shadows**

<a name="group-environment-ambient"></a>

**Ambient fill**

<a name="group-environment-wind"></a>

**Wind & cloud shadows**

<a name="group-environment-fog"></a>

**Distance fog**

<a name="group-environment-color"></a>

**Color adjustments**

<a name="group-environment-dof"></a>

**Real depth of field**

<a name="group-environment-post"></a>

**Presentation effects**

<a name="manual-section-02"></a>

## Buttons and operations

| Visible button | What it does / when it applies |
| --- | --- |
| Apply Environment Settings | Commits sky, sunlight, fog, wind, cloud shadows and post-processing in one undoable action, without switching the project renderer. |

<a name="manual-section-03"></a>

## Every parameter

Most numeric fields are drafts until the relevant Apply button is clicked. Tool settings are read when you paint/place; imports and file-selection actions run immediately. Apply is not a disk save: use Ctrl+S / Cmd+S afterward. Check the action descriptions for exceptions.

Ranges show minimum … maximum; step. Options show the available choices. Units and conditions are explained in the final column. Sliders and their numeric boxes edit the same value, not two separate parameters.

| Parameter | Initial default | Range / step / options | Meaning and limits |
| --- | --- | --- | --- |
| <a name="control-sky_color"></a>Sky<br>[Sky & background](#group-environment-sky) | 72b5cd | Color | Zenith sky color or background color, depending on the sky mode. |
| <a name="control-sky_mode"></a>Sky mode<br>[Sky & background](#group-environment-sky) | Procedural sky | Procedural sky, Background color / sky model | Procedural sky generates a gradient sky. Background color / sky model provides a background color only; it does not create a cloud plane or model. |
| <a name="control-ambient_color"></a>Ambient light color<br>[Ambient fill](#group-environment-ambient) | 0.86,0.91,0.76 | Color | Color of ambient fill light, including otherwise shadowed areas. |
| <a name="control-horizon_color"></a>Horizon / fog color<br>[Sky & background](#group-environment-sky) | e4e7d0 | Color | Color used for the procedural horizon and distance fog, helping unify distant tones. |
| <a name="control-sun_color"></a>Sunlight<br>[Sun & shadows](#group-environment-sun) | fff2ca | Color | Color of the main directional light; does not select a sun image. |
| <a name="control-sun_energy"></a>Sunlight energy<br>[Sun & shadows](#group-environment-sun) | 0.85 | 0 … 8; 0.01 | Main sunlight energy; excessive values can wash out highlights and pale textures. |
| <a name="control-sun_yaw"></a>Sun azimuth<br>[Sun & shadows](#group-environment-sun) | -35 | -180 … 180; 0.01 | Sun azimuth around the world's vertical axis in degrees, controlling shadow direction. |
| <a name="control-sun_elevation"></a>Sun elevation<br>[Sun & shadows](#group-environment-sun) | 48 | 0 … 90; 0.01 | Sun elevation above the horizon in degrees; lower angles generally produce longer shadows. |
| <a name="control-shadows"></a>Cast shadows<br>[Sun & shadows](#group-environment-sun) | On / 开 | — | Enables sunlight shadows; individual objects must also permit shadow casting. |
| <a name="control-ambient_energy"></a>Ambient light energy<br>[Ambient fill](#group-environment-ambient) | 0.35 | 0 … 1; 0.01 | Ambient fill intensity; increasing it brightens shaded areas but reduces lighting contrast. |
| <a name="control-wind_strength"></a>Plant wind strength<br>[Wind & cloud shadows](#group-environment-wind) | 0.5 | 0 … 3; 0.01 | Procedural wind strength for plugin plant materials; arbitrary imported materials may not support it. |
| <a name="control-cloud_shadows"></a>Cloud shadow strength<br>[Wind & cloud shadows](#group-environment-wind) | 0.18 | 0 … 1; 0.01 | Procedural cloud-shadow strength in plugin materials; does not automatically load a game's cloud-shadow PNG. |
| <a name="control-fog_enabled"></a>Distance fog<br>[Distance fog](#group-environment-fog) | On / 开 | — | Enables ordinary distance fog, not volumetric fog. |
| <a name="control-fog_density"></a>Fog density<br>[Distance fog](#group-environment-fog) | 0.001 | 0 … 0.1; 0.001 | Distance-fog density; higher values obscure distant objects sooner and can wash out the entire image. |
| <a name="control-saturation"></a>Saturation<br>[Color adjustments](#group-environment-color) | 1.05 | 0.2 … 2; 0.01 | Color saturation, with 1 neutral. Editor and presentation paths can differ; judge the final look in Preview. |
| <a name="control-contrast"></a>Contrast<br>[Color adjustments](#group-environment-color) | 1.04 | 0.2 … 2; 0.01 | Color contrast, with 1 neutral; higher values increase tonal separation. |
| <a name="control-depth_blur"></a>Far depth of field<br>[Real depth of field](#group-environment-dof) | 0 | 0 … 1; 0.01 | Depth-based far-field blur strength; disabled in Compatibility, with an available path in Forward+ / Mobile. |
| <a name="control-presentation_enabled"></a>Presentation effects (game / preview only)<br>[Presentation effects](#group-environment-post) | Off / 关 | — | Enables presentation post-processing in game/Preview without applying the final-film filter to the native editing viewport. |
| <a name="control-vignette"></a>Vignette<br>[Presentation effects](#group-environment-post) | 0.36 | 0 … 1; 0.01 | Edge-darkening strength in the presentation pass; requires presentation post-processing. |
| <a name="control-zone_blur"></a>Screen-zone blur (not depth of field)<br>[Presentation effects](#group-environment-post) | 0 | 0 … 2; 0.01 | Blur based on screen zones, not object distance; available in Compatibility, but not a substitute for actual depth of field. |

<a name="manual-section-04"></a>

## Recommended sequence and pitfalls

Start with procedural sky and sunlight; add fog and post-processing after framing. A cloudy PNG requires an imported plane and native Inspector placement/unshaded material; there is no one-click sky-model generator. These screenshots use Compatibility: disabled depth-of-field controls are expected, not a broken plugin.

Use the shared toolbar reference for saving, stopping tools and previews. This workflow uses the dock, thumbnails, brush and native Inspector; you do not need to write GDScript to author the scene.

To disable wind for one brazier using Assets → Asset wind sway=0 → Apply. Plant wind strength here affects the whole stage. Category names do not enable or disable wind. See the [brazier example](assets.md#control-asset_wind).

---

[← Previous: Camera](camera.md) · [↑ Up one level](README.md) · [Manual contents](../../README.md) · [↑ Back to top](#manual-top) · [Next: Music →](music.md)

# Part III · Scatter and roads

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../../DISTRIBUTION.md)

Ctrl-select plants in Assets, switch to Scatter, select the brush or circular scatter tool, then click the terrain. A road requires at least two control points to generate a surface.

New 2D/3D scatter instances default to static collision; saved foliage records retain their previous settings. For walk-through grass, disable collision using the matching-assets batch action in Assets.

## Collapsible visual groups

Click a bordered heading to expand or collapse it. Common groups start open (★); your choice is remembered per project. **Expand All / Collapse All** only affects this page. Tab to a heading and use Enter/Space, or Left/Right. Hiding controls keeps drafts and active tools/audition; it neither applies settings nor saves the scene. Shared Apply buttons stay outside the folds.

| Group | Contains |
| --- | --- |
| ★ [Plant placement & erase](#group-scatter-plants) | Mixed brush, circular scatter, erase, density and radius. |
| [Randomization & road clearance](#group-scatter-random) | Random scale/yaw ranges, additional road clearance and seed. |
| [Road curves](#group-scatter-road) | Create road, continue adding points, width and remove last point. |
| [Road texture & fences](#group-scatter-fences) | Road texture, repetition, fences toggle and spacing. |

<a id="group-scatter-plants"></a>

**Plant placement & erase**

<a id="group-scatter-random"></a>

**Randomization & road clearance**

<a id="group-scatter-road"></a>

**Road curves**

<a id="group-scatter-fences"></a>

**Road texture & fences**

## Buttons and operations

| Visible button | What it does / when it applies |
| --- | --- |
| Mixed Plant Brush | Drags repeated stamps using selected assets and randomization settings; a drag forms one undo action. |
| Circular Area Scatter | One click scatters plants within a circular area; it does not create a persistent editable polygon-region object. |
| Erase Plants | Removes foliage placement records within the radius, with undo; neither deletes source images nor erases ordinary single-object nodes. |
| Create and Draw Road | Creates a Road and enters point-adding mode. Click successive ground positions, then Esc; at least two points are required. |
| Add Points to Current Road | Continues adding points to the selected Road rather than creating a second road. |
| Choose Road Texture… | Immediately assigns a PNG/JPG/WebP texture to the current road. |
| Apply Road Settings | Commits width, tiling and fence settings and rebuilds the terrain-conforming road mesh. |
| Remove Last Road Point | Removes only the last point of the current road, with undo; does not delete the whole Road node. |

## Every parameter

Most numeric fields are drafts until the relevant Apply button is clicked. Tool settings are read when you paint/place; imports and file-selection actions run immediately. Apply is not a disk save: use Ctrl+S / Cmd+S afterward. Check the action descriptions for exceptions.

Ranges show minimum … maximum; step. Options show the available choices. Units and conditions are explained in the final column. Sliders and their numeric boxes edit the same value, not two separate parameters.

| Parameter | Initial default | Range / step / options | Meaning and limits |
| --- | --- | --- | --- |
| <a id="control-density"></a>Instances per m²<br>[Plant placement & erase](#group-scatter-plants) | 0.3 | 0.01 … 10; 0.01 | Target instances per square meter. Area times density estimates the count, subject to road exclusions, terrain edges and the instance cap. |
| <a id="control-scatter_radius"></a>Scatter / erase radius<br>[Plant placement & erase](#group-scatter-plants) | 5 | 0.2 … 64; 0.1 | World radius in meters for plant painting, circular scatter and erasing. |
| <a id="control-scale_min"></a>Minimum random scale<br>[Randomization & road clearance](#group-scatter-random) | 0.8 | 0.05 … 10; 0.05 | Minimum random scale multiplier for newly placed instances; keep it no greater than the maximum. |
| <a id="control-scale_max"></a>Maximum random scale<br>[Randomization & road clearance](#group-scatter-random) | 1.2 | 0.05 … 10; 0.05 | Maximum random scale multiplier for new instances; excessive foreground scale can obscure actors' faces. |
| <a id="control-yaw_min"></a>Minimum random yaw (°)<br>[Randomization & road clearance](#group-scatter-random) | -20 | -180 … 180; 1 | Minimum random rotation around the vertical Y axis, in degrees. |
| <a id="control-yaw_max"></a>Maximum random yaw (°)<br>[Randomization & road clearance](#group-scatter-random) | 20 | -180 … 180; 1 | Maximum random yaw in degrees; avoid turning flat cards nearly edge-on. |
| <a id="control-road_margin"></a>Extra road clearance<br>[Randomization & road clearance](#group-scatter-random) | 0.5 | 0 … 10; 0.1 | Extra clearance beyond a Road's width, in meters; painted dirt texture is not recognized as a Road. |
| <a id="control-seed"></a>Random seed<br>[Randomization & road clearance](#group-scatter-random) | 42 | 0 … 2147483647; 1 | Random seed; existing record count and operation order also affect generation, so a seed alone does not reproduce a layout. |
| <a id="control-road_width"></a>Road width<br>[Road curves](#group-scatter-road) | 3 | 0.2 … 20; 0.1 | Lateral road width in meters, applied to the current road. |
| <a id="control-road_tile"></a>Road texture repeat<br>[Road texture & fences](#group-scatter-fences) | 3 | 0.2 … 20; 0.1 | Distance in meters for a texture repeat along the road. |
| <a id="control-fences"></a>Generate fences on both sides<br>[Road texture & fences](#group-scatter-fences) | Off / 关 | — | Generates simple fences on both sides of the road; does not automatically use a game's fence model. |
| <a id="control-fence_spacing"></a>Fence spacing<br>[Road texture & fences](#group-scatter-fences) | 2 | 0.5 … 10; 0.1 | Spacing between generated fence elements along the road, in meters; relevant when fences are enabled. |

## Recommended sequence and pitfalls

Create a real Road before scattering to use road exclusion. Brush stamps do not produce the same counts as a full circular scatter. Reduce excess with Erase. Select a Road and drag point and tangent handles; Esc ends point addition. Dedicated per-instance foliage transform gizmos are not yet available; use single-object placement for precise editing.

Use the shared toolbar reference for saving, stopping tools and previews. This workflow uses the dock, thumbnails, brush and native Inspector; you do not need to write GDScript to author the scene.

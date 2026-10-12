# Characters

> Public 0.4.7 · Plugin and manual only. No extracted character sheets, shared-library payloads, cases or local test projects are bundled.


The public plugin does not bundle extracted character presets. Import your own frames or connect a compatible character library.

1. Create a free-walk map and select its Hero node. Set action, source direction, frame count and FPS.
2. Import a PNG sequence, atlas row or SpriteFrames. Import idle/walk/run and the required directions; missing directions are reported, not invented.
3. Set the foot anchor, meters per pixel, walk speed and collision, then Apply Character Settings.
4. Place the character on terrain, save and preview from Camera.
5. With a compatible preset library connected, select a preset and Player / Companion / NPC role, then click Place Character in 3D View. A missing Characters container is created automatically with one undo/redo. Player is unique; companions follow; NPCs stay in place.

## Collapsible visual groups

Click a bordered heading to expand or collapse it. Common groups start open (★); your choice is remembered per project. **Expand All / Collapse All** only affects this page. Tab to a heading and use Enter/Space, or Left/Right. Hiding controls keeps drafts and active tools/audition; it neither applies settings nor saves the scene. Shared Apply buttons stay outside the folds.

| Group | Contains |
|---|---|
| ★ [Action & direction](#group-character-action) | Direction count, action/custom action, source direction and import FPS. |
| ★ [Asset import](#group-character-import) | PNG sequence, atlas grid/row/frame count and SpriteFrames import. |
| [Animation mapping](#group-character-mapping) | Map the selected action/direction to an existing animation name. |
| [Foot anchor & appearance](#group-character-appearance) | Foot preview and anchors, meters per pixel, shading and horizontal flip. |
| [Movement & collision](#group-character-movement) | Walk speed, collider radius/height and actor placement tool. |
| [Character shadows](#group-character-shadow) | Contact and flat-ground projected shadow toggles. |

Godot 4.7.2 / Compatibility / 0.4.5 interface. Click to enlarge each section; taller sections include a second view.

<div class="ui-gallery">
<a id="group-character-action" name="group-character-action"></a><p><strong>Action & direction</strong></p>
<a id="group-character-import" name="group-character-import"></a><p><strong>Asset import</strong></p>
<a id="group-character-mapping" name="group-character-mapping"></a><p><strong>Animation mapping</strong></p>
<a id="group-character-appearance" name="group-character-appearance"></a><p><strong>Foot anchor & appearance</strong></p>
<a id="group-character-movement" name="group-character-movement"></a><p><strong>Movement & collision</strong></p>
<a id="group-character-shadow" name="group-character-shadow"></a><p><strong>Character shadows</strong></p>
</div>

## Buttons and operations

| Visible button | What it does / when it applies |
|---|---|
| Import PNG Sequence (natural name order) | Imports equal-canvas PNGs in natural name order into the current action/direction; set action, direction and FPS first. |
| Import This Atlas Row | Slices a row using the configured columns, rows and row index; does not infer irregular packed atlases. |
| Import Existing SpriteFrames | Loads a prepared SpriteFrames .tres/.res, not an asset library or character Profile; dependent images must be accessible. |
| Map Action / Direction to Animation | Maps the selected action/direction to the named existing animation; does not duplicate or generate frames. |
| Apply Character / Foot Anchor | Commits pivots, direction count, scale, movement, collision and shadows to the current actor profile; check foot alignment in Preview. |
| Place Character on Ground | Enters the actor placement tool; clicking the terrain moves the current actor rather than creating a new one each time. |

## Every parameter

Most numeric fields are drafts until the relevant Apply button is clicked. Tool settings are read when you paint/place; imports and file-selection actions run immediately. Apply is not a disk save: use Ctrl+S / Cmd+S afterward. Check the action descriptions for exceptions.

Ranges show minimum … maximum; step. Options show the available choices. Units and conditions are explained in the final column. Sliders and their numeric boxes edit the same value, not two separate parameters.

| Parameter | Initial default | Range / step / options | Meaning and limits |
|---|---|---|---|
| <span id="control-directions"></span>Direction count<br>[Action & direction](#group-character-action) | 4 | 2, 4, 8 | Desired direction count, not the number of available images; missing directions produce warnings and fallbacks. |
| <span id="control-action"></span>Action<br>[Action & direction](#group-character-action) | idle | idle, walk, run | Action key currently being imported or mapped: idle for standing and walk for locomotion. |
| <span id="control-direction"></span>Source direction<br>[Action & direction](#group-character-action) | s | s, w, n, e, sw, nw, ne, se | Actual source direction for this batch: s south, w west, n north, e east; remaining keys are diagonals. |
| <span id="control-fps"></span>Frames per second<br>[Action & direction](#group-character-action) | 8 | 1 … 60; 1 | Playback frames per second for the imported action; higher values play faster, without generating in-between frames. |
| <span id="control-atlas_columns"></span>Atlas columns<br>[Asset import](#group-character-import) | 4 | 1 … 128; 1 | Number of equal-width columns in a regular sprite atlas. |
| <span id="control-atlas_rows"></span>Atlas rows<br>[Asset import](#group-character-import) | 4 | 1 … 128; 1 | Number of equal-height rows in a regular sprite atlas. |
| <span id="control-atlas_row"></span>Row to read (starts at 1)<br>[Asset import](#group-character-import) | 1 | 1 … 128; 1 | One-based row number to import; it must be within the atlas row count. |
| <span id="control-atlas_count"></span>Frames in this row<br>[Asset import](#group-character-import) | 4 | 1 … 128; 1 | Number of consecutive usable frames in this row; cannot exceed the column count. |
| <span id="control-foot_x"></span>Horizontal anchor<br>[Foot anchor & appearance](#group-character-appearance) | 0.5 | -0.5 … 1.5; 0.01 | Horizontal normalized foot pivot: 0 left, 0.5 center, 1 right; different from atlas crop coordinates. |
| <span id="control-foot_y"></span>Foot anchor<br>[Foot anchor & appearance](#group-character-appearance) | 1 | -0.5 … 1.5; 0.01 | Vertical normalized foot pivot; align to the visible soles, not blindly to the bottom of a transparent canvas. |
| <span id="control-pixel_size"></span>Meters per pixel<br>[Foot anchor & appearance](#group-character-appearance) | 0.025 | 0.001 … 0.1; 0.001 | World meters per source pixel. Display height is approximately image height in pixels times this value. |
| <span id="control-move_speed"></span>Walk speed (m/s)<br>[Movement & collision](#group-character-movement) | 4 | 0 … 20; 0.1 | Basic movement speed in meters per second, independent of animation FPS. |
| <span id="control-collider_radius"></span>Collision radius<br>[Movement & collision](#group-character-movement) | 0.3 | 0.1 … 3; 0.05 | Capsule collider radius in meters; collision is separate from sprite rendering. |
| <span id="control-collider_height"></span>Collision height<br>[Movement & collision](#group-character-movement) | 1.5 | 0.2 … 5; 0.05 | Total capsule height in meters, which should be at least its diameter; do not count transparent margins as body height. |
| <span id="control-character_shaded"></span>Receive sunlight shading<br>[Foot anchor & appearance](#group-character-appearance) | Off / 关 | — | Lets scene lighting shade the sprite; disabled gives more stable color but less scene-light response. |
| <span id="control-character_flip"></span>Manual horizontal flip (no new directions)<br>[Foot anchor & appearance](#group-character-appearance) | Off / 关 | — | Manually mirrors existing images horizontally; does not create a missing directional animation. |
| <span id="control-contact_shadow"></span>Foot contact shadow<br>[Character shadows](#group-character-shadow) | On / 开 | — | Contact shadow beneath the feet to communicate ground contact. |
| <span id="control-projected_shadow"></span>Flat-ground shadow (use cautiously on slopes)<br>[Character shadows](#group-character-shadow) | Off / 关 | — | A projected-shadow approximation suited to flat ground; inspect slopes for floating or intersecting shadows. |
| <span id="control-custom_action"></span>Optional custom action (e.g. attack)<br>[Action & direction](#group-character-action) | — | Text | Nonempty text overrides the action dropdown, e.g. attack. The basic walking controller is not a combat state machine; custom actions need game logic. |
| <span id="control-animation_mapping"></span>Existing animation, e.g. WalkSouth<br>[Animation mapping](#group-character-mapping) | — | Text | Exact existing animation name inside SpriteFrames, not the resource file path. |

## Other visible controls

| Control | Explanation |
|---|---|
| Foot image and yellow baseline | Click the preview to set both pivots, then apply. Equal canvases across animations make consistent alignment easier. |
| Missing-direction warning | Lists missing animations and the actual fallback; does not generate frames or automatically mirror them. |

## Recommended sequence and pitfalls

Start with walk_e and check foot alignment, then add idle and other directions for which actual images exist. Test direction switching and slope collision with WASD/arrows. Legacy manually imported actors retain idle/walk; preset-role actors switch idle/walk/run with movement. This is not a complete combat-animation controller.

Use the shared toolbar reference for saving, stopping tools and previews. This workflow uses the dock, thumbnails, brush and native Inspector; you do not need to write GDScript to author the scene.

## Facing and mirroring

Preset actors automatically face the camera; do not tilt their root nodes. For manually imported actors, enable **Foot Pivot & Appearance → Face the camera** and apply. This corresponds to Profile's **Full Billboard** and affects only the visual.

Expand Profile in the actor's Inspector. **Mirror Directions** is an array of direction keys and defaults to empty. Adding `e` explicitly mirrors supplied frames for the east direction, as in Case 5. It combines with Flip H and never generates new frames. Unprovided directions without an explicit mirror still use animation-mapping fallbacks.

## Facing and running

| Parameter | Default | Range | Purpose |
|---|---|---|---|
| <span id="control-character_face_camera"></span>Face the camera (automatic for preset characters) | On for presets | On / Off | The visual follows camera pitch while feet and collision stay anchored. Enable and apply explicitly for legacy imported actors. |
| <span id="control-run_speed"></span>Run speed | 6.5 m/s | 0–30; step 0.1 | Hold Shift in a free map; preset run animation follows movement speed. |

The bundled game-extracted characters remain local-study material. A future public GitHub distribution must exclude `addons/hd2d_scene_tools/assets/local_study_characters` and its index. No repository is created or uploaded by this update.


[← Manual contents](../index.md) · [Release notes](../release_notes.md)

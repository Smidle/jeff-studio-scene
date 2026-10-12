# Part III · Camera and looping

> Public 0.4.7 · Plugin and manual only. No extracted character sheets, shared-library payloads, cases or local test projects are bundled.


New free maps default to an overhead 45° orthographic camera. Placing a player enables orthographic follow in the same undo action; existing saved scenes are not rewritten. Preset characters fully face the camera to preserve their proportions; the visual rotates while feet, body and collision stay anchored.


Apply the production camera settings, then inspect them in Preview. The lock-and-follow checkbox changes the test viewing mode; free observation never writes its orientation into the production camera.


## Camera presets

Select the stage root → Camera → **Presets & preview lock** → choose a preset → adjust fields → **Apply Camera Settings** in the fixed footer.

A preset fills a framing draft without modifying the scene, follow target or draft bounds. Manual framing edits display **Custom**; matching a preset displays its name. The pale-yellow footer button commits framing, projection and follow bounds in one undo action. It is disabled when no camera exists or nothing has changed.

The footer distinguishes pending changes, applied settings awaiting a save, and an unavailable target. Module changes, folded groups and passive refreshes retain the draft. Changing scene/camera, external camera edits and undo/redo resynchronize the actual values and show a notice. **Apply is not Save**: apply, preview, then press Ctrl / Cmd + S.



| Preset, in order | Projection | Yaw / pitch | Distance | FOV | Focus height | Ortho height |
|---|---|---|---|---|---|---|
| 1 · Side Follow · Low-angle Perspective | Perspective | 0° / 5.19° | 43.9 m | 15.01° | 2.02 m | 18 m (inactive) |
| 2 · Overhead 45° · Orthographic | Orthographic | 0° / 45° | 36 m | 50° (inactive) | 2 m | 17 m |
| 3 · Overhead 45° · Perspective 25° | Perspective | 0° / 45° | 35 m | 25° | 2 m | 17 m (inactive) |
| 4 · Overhead 45° · Perspective 30° | Perspective | 0° / 45° | 30 m | 30° | 2 m | 17 m (inactive) |

Selecting a preset fills only these seven framing draft fields. Target, smoothing, bounds, stage mode, renderer and native editor view stay unchanged. Front means looking from +Z toward −Z; 45° is pitch, not yaw. Use view height for orthographic zoom. Case01 matches preset 1; Cases02–04 still need their own documented values. Case05 defaults to preset 2, with presets 3 and 4 available for comparison.

For orthographic zoom, adjust view height. Perspective framing depends on distance and FOV; the stored ortho height is inactive. Depth blur is configured separately in Environment.

Scene Preview shows applied settings. A pending draft reminds you to apply first. Free observation in Preview never writes back to the production camera.

To view the result: close an existing Preview → select the stage root → select and apply a preset → open Preview again → walk with WASD. Close the isolated copy before trying another preset; it does not automatically inherit subsequent editor changes. Undo with Cmd+Z; save with Cmd+S. Updating the addon does not rewrite existing scenes: reapply preset2 or select3/4 yourself. See [Case05](../history.md).

## Collapsible visual groups

Click a bordered heading to expand or collapse it. Common groups start open (★); your choice is remembered per project. **Expand All / Collapse All** only affects this page. Tab to a heading and use Enter/Space, or Left/Right. Hiding controls keeps drafts and active tools/audition; it neither applies settings nor saves the scene. Shared Apply buttons stay outside the folds.

| Group | Contains |
|---|---|
| ★ [Presets & preview lock](#group-camera-presets) | Four presets, Custom status and preview lock; use the single fixed Apply. |
| ★ [Production framing](#group-camera-framing) | Yaw, pitch, distance, FOV, focus height, ortho height and projection. |
| [Follow bounds](#group-camera-bounds) | Boundary toggle, X/Z origin, width/depth; shares Apply with framing. |
| [Loop stage](#group-camera-loop) | Segment length, speed, pause and seams; loop settings have a separate Apply. |

Godot 4.7.2 / Compatibility / 0.4.5 interface. Click to enlarge each section; taller sections include a second view.

<div class="ui-gallery">
<a id="group-camera-presets" name="group-camera-presets"></a><p><strong>Presets & preview lock</strong></p>
<a id="group-camera-framing" name="group-camera-framing"></a><p><strong>Production framing</strong></p>
<a id="group-camera-bounds" name="group-camera-bounds"></a><p><strong>Follow bounds</strong></p>
<a id="group-camera-loop" name="group-camera-loop"></a><p><strong>Loop stage</strong></p>
</div>

## Buttons and operations

| Visible button | What it does / when it applies |
|---|---|
| Apply Camera Settings | Commits production projection, framing and follow bounds; free-observation orientation is not substituted for these settings. |
| Apply Loop Settings | Commits segment length, speed, pause and seam display; inspect the running loop. The stage mode is chosen by the template. |

## Every parameter

Initial values below describe a new free map; an existing scene displays its saved settings.

Most numeric fields are drafts until the relevant Apply button is clicked. Tool settings are read when you paint/place; imports and file-selection actions run immediately. Apply is not a disk save: use Ctrl+S / Cmd+S afterward. Check the action descriptions for exceptions.

Ranges show minimum … maximum; step. Options show the available choices. Units and conditions are explained in the final column. Sliders and their numeric boxes edit the same value, not two separate parameters. Existing follow bounds outside the ordinary limits expand the inputs to display their values. Fractional bounds use 0.01 m steps; untouched fields retain their original values.

| Parameter | Initial default | Range / step / options | Meaning and limits |
|---|---|---|---|
| <span id="control-camera_locked"></span>Lock angle and follow (preview)<br>[Presets & preview lock](#group-camera-presets) | On / 开 | — | Immediately switches isolated-preview observation mode; does not change the native editor's free view. |
| <span id="control-camera_yaw"></span>Scene camera yaw<br>[Production framing](#group-camera-framing) | 0 | -180 … 180; 0.01 | Production camera azimuth around the Y axis, in degrees. |
| <span id="control-camera_pitch"></span>Scene camera pitch<br>[Production framing](#group-camera-framing) | 45 | 5 … 85; 0.01 | Production camera downward pitch in degrees; smaller values approach an eye-level view. |
| <span id="control-camera_distance"></span>Camera distance<br>[Production framing](#group-camera-framing) | 36 | 2 … 100; 0.1 | Distance from the follow focus in meters; affects perspective framing but is not the orthographic zoom control. |
| <span id="control-camera_fov"></span>Perspective FOV<br>[Production framing](#group-camera-framing) | 50 | 5 … 100; 0.01 | Perspective field of view in degrees; does not control frame size in orthographic mode. |
| <span id="control-camera_focus"></span>Follow focus height<br>[Production framing](#group-camera-framing) | 2 | 0 … 10; 0.01 | Height offset of the follow focus relative to the actor, in meters. |
| <span id="control-camera_size"></span>Orthographic view height<br>[Production framing](#group-camera-framing) | 17 | 2 … 100; 0.1 | Orthographic frame height in meters; smaller values enlarge objects. Unused in perspective mode. |
| <span id="control-orthographic"></span>Orthographic projection<br>[Production framing](#group-camera-framing) | On / 开 | — | Enables orthographic projection without perspective size falloff; disabled uses perspective. |
| <span id="control-bounds"></span>Enable follow bounds<br>[Follow bounds](#group-camera-bounds) | Off / 关 | — | Constrains the follow focus in X/Z; it does not guarantee that every edge of the camera frame remains inside the map. |
| <span id="control-bound_x"></span>Bounds origin X<br>[Follow bounds](#group-camera-bounds) | -120 | -512 … 512; 1 | Starting X coordinate of the boundary rectangle, in meters. |
| <span id="control-bound_z"></span>Bounds origin Z<br>[Follow bounds](#group-camera-bounds) | -120 | -512 … 512; 1 | Starting Z coordinate of the boundary rectangle, in meters. |
| <span id="control-bound_w"></span>Bounds width<br>[Follow bounds](#group-camera-bounds) | 240 | 1 … 1024; 1 | Boundary width along X, in meters. |
| <span id="control-bound_d"></span>Bounds depth<br>[Follow bounds](#group-camera-bounds) | 240 | 1 … 1024; 1 | Boundary depth along Z, in meters. |
| <span id="control-segment_length"></span>Segment length (m)<br>[Loop stage](#group-camera-loop) | 40 | 4 … 256; 0.1 | Width of one reused segment in meters. Artwork must join at its edges; this does not generate seamless terrain automatically. |
| <span id="control-scroll_speed"></span>Scroll speed (negative = reverse)<br>[Loop stage](#group-camera-loop) | 2 | -20 … 20; 0.1 | Scrolling speed in meters per second; negative reverses direction and zero stops motion. |
| <span id="control-loop_pause"></span>Pause scrolling<br>[Loop stage](#group-camera-loop) | Off / 关 | — | Pauses background scrolling at its current position; music pause behavior is configured separately. |
| <span id="control-seams"></span>Show segment boundaries<br>[Loop stage](#group-camera-loop) | Off / 关 | — | Shows segment boundaries for seam inspection; disable after checking the final composition. |

## Recommended sequence and pitfalls

Scenery is the scrolling container; Characters, static sky and camera remain in their appropriate root branches. Author matching segment edges: arbitrary terrain or images are not automatically seamless. Test pause, reverse and speed changes, then hide seam guides for the final view.

Use the shared toolbar reference for saving, stopping tools and previews. This workflow uses the dock, thumbnails, brush and native Inspector; you do not need to write GDScript to author the scene.


[← Manual contents](../index.md) · [Release notes](../release_notes.md)

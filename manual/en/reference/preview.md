# Part III · Isolated Preview and final checks

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../../DISTRIBUTION.md)

Use **Camera → Preview Scene**. The plugin copies the current stage into a separate World3D so test movement, observation and music state do not modify production resources. This window is not another scene editor.

## Every window control

This capture uses an original test plant on empty terrain. It illustrates window controls, not finished flower-field art quality.

| Control / gesture | Default and range | Purpose |
| --- | --- | --- |
| Lock angle and follow | Checked by default; also follows the Camera page's preview-mode choice | Checked restores production orientation, pitch and actor follow. Unchecked allows free observation without changing saved camera settings. |
| Pause scrolling | Initially the source stage's pause state | Pauses only the test copy. Music pause behavior follows the track configuration. |
| Speed slider | -20…20 m/s, step 0.1, initialized from the source | Immediately changes test-copy scroll speed. Negative reverses; zero stops. Apply production speed on Camera. |
| WASD / arrow keys | Preview window has input focus | Moves the basic actor. Losing focus disables movement input to avoid background movement. |
| Left drag | Free-observation mode | Orbits the camera around its focus; does not generate the back of a sprite. |
| Middle / right drag | Free-observation mode | Pans the observation camera. |
| Mouse wheel | Free-observation mode | Moves closer or farther for observation. |
| Status help | Read-only | Shows movement or free-observation instructions for the current mode. |
| Window close button | Native window control | Immediately stops preview music and destroys the copy without saving its position, camera or speed back to the source. |

## A complete user check

1. Apply settings on relevant pages, save and open Preview.
2. Move in each direction for which artwork exists. Check foot alignment and correct animation mapping. Missing-direction warnings should accurately describe the fallback.
3. Walk over a small slope and inspect collision and contact shadows. Flat-ground projected shadows do not suit arbitrary slopes.
4. Pass in front of and behind plants to inspect occlusion. Foreground flowers should not constantly cover the face.
5. On a loop stage, inspect segment joins in forward, reverse, paused and changed-speed states. Layout and image content still require seamless authoring.
6. Unlock to observe, then relock and confirm restoration of production framing. Close the preview and confirm that source objects have not moved.
7. Listen through at least one full music loop. Check the active ♪ track, volume, endpoint and seam. Avoid overlapping audition and preview; closing the window must stop its sound.
8. Reopen Preview after source edits to refresh the copy. F6 runs the actual current scene; F5 runs the project's main scene.

## Limits and troubleshooting

If a recent environment edit is absent, remember that Preview is a snapshot: apply to the source and reopen. If no actor appears, check whether its Profile / SpriteFrames has real frames. A single available direction stays a single available direction; free observation cannot make a plane volumetric. Renderer depth-of-field limits match Environment, and screen-zone blur is not a depth effect.

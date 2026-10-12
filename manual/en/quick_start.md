# Install and get started with 0.4.7.1

> Public 0.4.7.1 · Plugin and manual only. No extracted character sheets, shared-library payloads, cases or local test projects are bundled.


Download only **01_HD2D_0.4.7.1_Plugin_Manual.zip**. No second or third package is required. Cases, shared-library payloads and local test projects are not included. Verified with **Godot 4.7.2**, Compatibility and Forward+. Back up your plugin and project before upgrading.

## 1. Install the plugin

Extract and copy only `addons/hd2d_scene_tools` into an existing Godot project's `addons` directory. Wait for imports, then enable **Jeff Studio Scene** in **Project → Project Settings → Plugins**. Keep the manual outside the project and open `START_HERE.html` in a browser.

For an upgrade, close Godot, back up and replace the old addon directory, then reopen. Keep your scenes, `hd2d_generated`, `hd2d_imports` and external shared library in place. The package does not include or replace `project.godot`.

For an older large scene, run **Assets → Import & Check → Optimize Scene File** once, then save. New buildings and towns use external resources automatically. Retain the project’s `hd2d_generated` folder.

## 2. Create a scene

Choose **New Map**, a free map of 128 meters and 129 height samples per side. Choose plain colors or a built-in surface scheme, then apply in Terrain.

Open **One-click**, select one of nine built-in styles. Double-row layout is the default, with one-meter building gaps and front setbacks. Click the gold **Apply to Scene**, move the blueprint, rotate with Q / E and left-click to place; Esc cancels. Save with Ctrl / Cmd + S. **Asset Workbench → Built-in Buildings** also supports individual placement and textured GLB export for Blender.

## 3. Apply environment and preview

Select the stage root → **Environment**. Set time and weather; Maple and Sakura show dedicated controls. Click the fixed **Apply Environment Settings**, inspect **Camera → Preview Current Scene**, then save.

Import your own character frames in Characters. The local-study package retains its three presets; the public GitHub package excludes extracted artwork. You may use your own artwork or an applicable character library. Preset placement automatically creates a missing `Characters` container and supports one undo.

## Optional resources

An existing external library remains compatible: **Location… → Recheck**, then prepare selected entries only. Keep the full library outside the project. [Library guide](shared_library.md). Historical cases remain in older packages and are not reissued here; [case reference](history.md).

Continue with [release notes](release_notes.md), [environment](reference/environment.md) or [buildings and export](reference/assets.md).


[← Manual contents](index.md) · [Release notes](release_notes.md)

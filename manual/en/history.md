# 03 · Cases and Historical Resources

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../DISTRIBUTION.md)

`03_HD2D_0.4.6_Case_Assets.zip` contains Cases 1–5 and their complete dependencies, preserved from 0.4.5 without regeneration. Case 6 remains in the earlier standalone world-map package.

Install package 01 first, then copy `showcase`, `case01` and `local_study` from package 03 into the project root, retaining relative paths. Package 02 is not required. Back up same-path files before merging into an existing project.

| Case | Scene path |
| --- | --- |
| 1 · Canola field | `res://showcase/Case01_Canola.tscn` |
| 2 · Lily path | `res://showcase/Case02_Lily.tscn` |
| 3 · Grain field | `res://showcase/Case03_Grain.tscn` |
| 4 · Bamboo path | `res://showcase/Case04_Bamboo.tscn` |
| 5 · Jiangnan town | `res://showcase/Case05_Jiangnan.tscn` |

Wait for Godot imports, open a scene and select its root to continue editing. Keep adjacent terrain resources and all asset folders. Use F6 to run; the Camera module retains the explicit scene preview entry.

This acceptance run covers only the plugin and shared library. Cases have not been rerun. Historical case walkthroughs remain in `01_HD2D_0.4.5_Plugin_Manual.zip`; use this version's feature reference for current controls.

### Standalone world map and older files

For Case 6, obtain `04_HD2D_0.4.5_Case06_WorldMap.zip` from the earlier release and follow its included guide, preferably in a separate project. Older releases use package 02 for cases and 03 for the shared library; **0.4.6 uses 02 for the shared library and 03 for cases**. Identify each package by its filename.

Extracted artwork, music and screenshots retain their local-study designation and are not covered by the plugin's MIT code license. Original release files remain unchanged; installed project resources are never automatically migrated or deleted.

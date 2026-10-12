# 03 · Case Bundle: Cases 01–05 and 07

> Public 0.4.7.1 · Plugin and manual only. No extracted character sheets, shared-library payloads, cases or local test projects are bundled.


0.4.7.1 ships the plugin and manuals only. The following is a reference for existing separate resource packages; these resources are not bundled and do not need reinstalling.

`03_HD2D_0.4.6_Case_Assets.zip` combines original Cases 01–05 with Case07, Desert Waystation, including all required resources. Original files remain unchanged. The large world-map case is not included.

Install package 01 first. All six cases run and remain editable without package 02.

## Step 1: Copy complete folders

Copy `showcase`, `case01`, `case07` and `local_study` together into the project root alongside `addons`. Retain paths; do not copy only a tscn file. Back up existing same-path files before merging.

## Step 2: Open a scene

Wait for imports, double-click a scene in FileSystem, then select its stage root.

| Case | Features | Scene path |
|---|---|---|
| 01 · Canola Field | Looping plants and characters | `res://showcase/Case01_Canola.tscn` |
| 02 · Lily Path | Layered flowers and woodland | `res://showcase/Case02_Lily.tscn` |
| 03 · Grain Field | Crops and grass | `res://showcase/Case03_Grain.tscn` |
| 04 · Bamboo Path | Bamboo, flowers and looping | `res://showcase/Case04_Bamboo.tscn` |
| 05 · Jiangnan Town | Native models and free movement | `res://showcase/Case05_Jiangnan.tscn` |
| 07 · Desert Waystation | 20 buildings, 72 plants, ring roads | `res://case07/Case07_Desert_Town.tscn` |

## Step 3: Run or preview

Press **F6**, or open **Camera → Preview Scene**. Cases 01–04 loop automatically; Cases 05 and 07 support free movement. Case07 uses WASD / arrow keys, Shift to run, the wheel to zoom and Tab for the town overview.

## Step 4: Edit and save

Close the running window or preview, then use the relevant plugin module. Gold Apply buttons commit drafts; **Ctrl / Cmd + S** saves. Back up case folders before creating a variant. Saving a scene under another name still shares referenced terrain and assets.

Extracted art, music and related screenshots remain for local study, outside the plugin code's MIT license. Historical releases are preserved.


<details><summary>View actual running captures of all six cases</summary>















</details>


[← Manual contents](index.md) · [Release notes](release_notes.md)

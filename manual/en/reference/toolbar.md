# Interface, Asset Workbench and saving

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../../DISTRIBUTION.md)

**Jeff Studio Scene 0.4.6.** Select objects in Godot's scene tree, place and paint in the central 3D viewport, and adjust settings in the right-hand plugin dock.

## Top toolbar and right dock

The 3D toolbar contains **New Map, Asset Workbench and the current tool**. Hover over the tool status for the scene name, terrain dimensions and samples. **Esc** exits placement or painting.

The brand card displays the name, version, language and theme. Choose Chinese or English, and **Jade Bamboo, Obsidian or Warm Paper**. These are per-project editor preferences; they do not change Godot's language or the rendered scene. The brazier and library stars animate while their panels are visible.

Under the library status, **Location…** connects an external library folder; **Recheck** reloads its indexes and refreshes the lists, then displays the completion time. Hover for the complete path and any error. A location already set in another project on this computer can be reused. Solid-color terrain and local assets work without a shared library.

## Eight modules and fixed Apply frames

The first navigation row is **Terrain → One-click → Assets → Scatter**; the second is **Character → Camera → Environment → Music**. The operations frame below scrolls. Click a section heading to fold it; **Expand All / Collapse All** affects only the current module and your choices are remembered.

Terrain, One-click and Camera keep their Apply frame at the bottom while settings scroll, groups fold or the Asset Workbench opens. A pale-gold border and pale-yellow primary button highlight the action; Warm Paper uses amber. Disabled means there is no pending change or a required target is missing. Other modules place their Apply action below the relevant settings. Changing modules or folding sections never applies or saves. Changing modules cancels town blueprint placement.

- **Terrain:** Terrain Creation Guide shows the current terrain or new-map draft. Use **Apply: Create Map** for a new map, or **Apply Surface Settings** for an existing terrain's surface draft.
- **One-click:** choose a style and walls to preview, then **Apply to Scene (New Town)** to position the blueprint in the viewport: Q / E rotate, left-click confirms, Esc cancels. Switching modules cancels town placement.
- **Preview:** deliberately open **Camera → Preview Scene**.

Tab focuses module buttons and section headings. Use Left/Right to change modules, Home/End for first/last. Enter/Space toggles a section; Left/Right collapses or expands it.

## Asset Workbench

Click **Asset Workbench** in the top toolbar to open the bottom panel. Drag its upper edge to resize it. The workbench uses the chosen theme and contains three sources:

| Source | How to use it |
| --- | --- |
| Presets | Search, filter and page through entries; wait for selection preparation, inspect the preview, then Place Selected Asset |
| My Assets | Browse your own shared-library imports using the same controls |
| Terrain Textures | Choose one texture or a complete scheme; clicking a thumbnail selects it into the target layer or new-map draft, then apply from the right dock |

Left-drag rotates a model preview. Selecting a skin affects future placements; use **Apply Skin** and its scope selector for existing objects. Terrain textures do not become placeable object entries.

Choosing a new map's scheme hides the settings window while retaining its specifications. Inspect the right-side terrain preview before applying. Selection alone does not create a scene. Browsing reads indexes and current-page thumbnails; selecting an entry prepares its own files.

## What a new map contains

<a id="new-free-template"></a>

Both **New Map…** entries open the same settings window. Defaults are a free map, 64 meters per side and 129 height samples per side. Set specifications, choose solid colors or a preset, then click **Apply: Create Map** in the dock footer. See [Terrain](terrain.md) for the detailed flow.

| Node or file | Purpose |
| --- | --- |
| HD2D_FreeWalk / HD2D_LoopStage | Stage root, mode, asset and music libraries, and stage settings |
| Terrain | Editable height and blend weights; generates ground and collision |
| Scenery → Foliage | Scenery and editable plant scatter records |
| Characters → Hero | Initial actor position; select a preset or import animation to display a character |
| CameraRig | Production camera and follow settings; new free maps default to 45° orthographic |
| .tscn and matching _terrain.res in levels | Scene and independent terrain data, with unique filenames when needed |

The basic map contains no buildings, flower fields or BGM. Add these using their modules. Loop stages keep their presentation-oriented camera and playback behavior.

## Native Inspector and handles

Selecting a Stage, Terrain, Character, CameraRig or Road exposes **Edit in Jeff Studio Scene** in the Inspector to open the corresponding plugin controls. Native Transform fields edit position, rotation and scale; Godot's handles provide direct manipulation. Selected roads also expose curve points and tangents.

Keeping terrain at the origin with Scale=1 makes authoring easier. Generated Chunk meshes are rebuilt from terrain data; edit with terrain brushes. Erase Plants operates on Foliage records; remove ordinary objects through the scene tree.

## Apply, Undo and Save

1. Most settings remain drafts until the relevant **Apply**. Import actions run immediately; texture selection stays in a surface draft.
2. Sculpting and painting modify terrain directly. One press-to-release stroke is one undo action; use **Cmd+Z / Ctrl+Z**, and Godot's Edit menu for redo.
3. **Cmd+S / Ctrl+S** saves to disk. Applying does not mean the scene is saved.
4. Saving another .tscn can retain shared external terrain or other resources. Back up and duplicate those resources, or make them unique in the Inspector and save them separately, for an independent variant.
5. Preview movement, temporary camera changes and speed do not write back. Close Preview to edit, then reopen it after changing production settings.

Runtime scenes still require the addon's runtime and shaders. Disabling the editor plugin is fine; keep its directory installed.

## File selection and operation messages

Library Location and import windows use Godot’s complete native editor theme. Back, Forward, Parent Folder and view controls keep their native icons across plugin theme changes. Plugin-owned actions retain pixel icons.

The message under the library status keeps the result and a suggested next step. Creating a map suggests adding characters and plants; applying a camera suggests previewing and saving. Passive refreshes keep the message until another operation or scene change replaces it.

The fixed Apply action keeps the same location and behavior in all themes. These genuine captures show Warm Paper (English) and Obsidian (Chinese):

The workbench also has a **Built-in Buildings** tab for previewing, configuring and placing parametric buildings without a shared library.

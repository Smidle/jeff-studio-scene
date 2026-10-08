<a name="manual-top"></a>

# Install 0.4.6 in Package Order

<!-- manual-navigation:start -->
[Project home](../../README.md) / [Manual contents](../README.md) / [English manual](index.md)

[← Up one level](../README.md) · [中文](../zh/quick_start.md)

<details>
<summary>On this page (expand)</summary>

- [1. Plugin and manual](#manual-section-01)
- [2. Shared library (optional)](#manual-section-02)
- [3. Cases (optional)](#manual-section-03)

</details>
<!-- manual-navigation:end -->

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../DISTRIBUTION.md)

<a name="manual-section-01"></a>

## 1. Plugin and manual

Extract `01_HD2D_0.4.6_Plugin_Manual.zip`. Copy only `addons` into your Godot project root and enable **Jeff Studio Scene** under Project → Project Settings → Plugins. Read the manual in a browser; back up an existing addon before updating.

Package 01 alone provides built-in buildings, 35 terrain textures and three local-study character presets.

<a name="manual-section-02"></a>

## 2. Shared library (optional)

Extract `02_HD2D_0.4.6_Shared_Asset_Library.zip` **outside your Godot project**. At the top of the plugin, choose **Location…**, select `HD2D_Shared_Asset_Library` containing `preset-index.json`, then **Recheck**. Browse, select and place assets from the workbench; only selected dependencies are prepared.

Do not copy the entire library into the project. Back up an existing library and preserve your own `index.json` and `objects`. See [shared-library installation](shared_library.md).

<a name="manual-section-03"></a>

## 3. Cases (optional)

Extract `03_HD2D_0.4.6_Case_Assets.zip`. Follow its guide to copy `showcase`, `case01` and `local_study` into the project root without changing their relative paths. Wait for Godot to import them. Cases include their dependencies and require package 01, not package 02.

These are existing finished scenes; see [Cases and Historical Resources](history.md) for scene paths. This run checks the plugin and shared library only; cases are not claimed as retested. No resource package supplies `project.godot`. Back up and compare same-path files before merging.

### Create your own scene

Choose **New Map**, a free map of 128 meters and 129 height samples per side, then solid colors or a built-in surface scheme. Apply the draft in Terrain. In **One-click**, choose a built-in style and click the gold **Apply to Scene** button. Move the blueprint, rotate with Q / E and left-click to place; Esc cancels. Save with Ctrl+S / Cmd+S.

Use **Character → Place Preset Character** to choose a character and Player / Companion / NPC role. Continue with [Generation](reference/generation.md) and [Assets and instance editing](reference/assets.md).

<a name="community"></a>

JEFF STUDIO · COMMUNITY

<a name="community-title"></a>

### Community & feedback

Share scenes, report issues and follow updates. Joining is optional; the manual works offline.

WeChat group

<a name="community-wechat-title"></a>

### Jeff Studio 内测群

Scan with WeChat

[![Jeff Studio 内测群 WeChat QR code](../images/jeff_studio_wechat_20260924.jpg)](../images/jeff_studio_wechat_20260924.jpg)

[Open original QR image ↗](../images/jeff_studio_wechat_20260924.jpg)

Image states: valid before 1 October 2026. If expired, use the QQ group number or ask the publisher for a new code.

QQ group

<a name="community-qq-title"></a>

### Jeff Studio 插件

Scan with QQ

[![Jeff Studio 插件 QQ QR code](../images/jeff_studio_qq_20260912.jpg)](../images/jeff_studio_qq_20260912.jpg)

[Open original QR image ↗](../images/jeff_studio_qq_20260912.jpg)

Group ID **482858198**

You can also search this group ID in QQ.

---

[← Previous: English manual](index.md) · [↑ Up one level](../README.md) · [Manual contents](../README.md) · [↑ Back to top](#manual-top) · [Next: Shared asset library →](shared_library.md)

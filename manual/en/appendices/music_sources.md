<a name="manual-top"></a>

# Music and External Resource Provenance

<!-- manual-navigation:start -->
[Project home](../../../README.md) / [Manual contents](../../README.md) / [English manual](../index.md) / [Reference appendices](README.md)

[← Up one level](README.md) · [中文](../../zh/appendices/music_sources.md)
<!-- manual-navigation:end -->

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../../DISTRIBUTION.md)

Package 01 includes three local-study characters, but no game music or case scenes. Cases and their dependencies are in package 03. The Music module imports audio you supply and configures audition, looping, fades and scene playback.

Historical music credits and preparation details remain in the original packaged manuals. See [Historical Cases and Resources](../history.md). The plugin code license does not cover external songs, extracted artwork or shared-library content.

The new procedural buildings and base pixel materials come from the plugin's own code and deterministic parameters. They do not read Ronin or extracted game assets. Applied output lives in your project's `hd2d_generated` directory: back it up with the scene and do not delete it as a cache.

---

[← Previous: Scene paths](scenes.md) · [↑ Up one level](README.md) · [Manual contents](../../README.md) · [↑ Back to top](#manual-top)

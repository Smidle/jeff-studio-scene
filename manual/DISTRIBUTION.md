# 0.4.6 公开分发说明

## 本仓库与 Release 包含的内容

- `addons/hd2d_scene_tools/`：Jeff Studio Scene 0.4.6 插件源码、着色器、编辑器美术、建筑图集和原创地表资源。
- `manual/`：中英文完整说明书、文档图片，以及便于 GitHub 阅读的 Markdown 版本。
- `START_HERE.html`：离线说明书语言选择入口。
- `README.md` 与 `LICENSE`：项目介绍及原插件 MIT 许可证。

共享素材库与历史案例包是另外的交付内容，未附在本仓库和本次 Release 中。说明书中保留这些功能与资源包的使用方式，便于已有对应资源的用户查阅。

## 学习版角色素材

原包的 `addons/hd2d_scene_tools/assets/local_study_characters/distribution.json` 明确标记：

```json
{
  "distribution": "local-study-only",
  "exclude_from_public": true
}
```

该目录包含游戏提取角色图集及其索引，按原分发标记从公开 Git 历史和 Release ZIP 中排除。原有本地文件保留。

因此，公开版不附带「斗笠侠客、冷无情、吕小玲」三位预设角色。插件中的角色导入、动画、锚点、身份和移动功能仍然保留，可使用自己的素材，或连接已有的适用角色库。未连接角色库时，预设列表可能为空，并显示学习版预设缺失提示；这不表示建筑或地形安装失败。

说明书中的学习版角色截图与参数演示用于解释功能，不表示公开下载包附带对应角色图集。历史案例和音乐来源章节同样是参考资料，不代表本次发布包含这些资源。

## 原创资源与许可证记录

- 插件源码沿用原包 MIT 许可证，根目录 `LICENSE` 与插件目录内的许可证内容一致。
- 地表目录的 `catalog.json` 标记为 `builtin-original-surfaces`，记录了原创来源、纹理和缩略图校验值。
- 建筑目录的 `v5/atlas-index.json` 保留三个原创风格图集的来源与校验值。
- 编辑器美术的 `editor/art/provenance.json` 保留像素图标与动画的制作记录。

## Public distribution (English)

This repository and its 0.4.6 release contain the plugin, its original built-in building and terrain assets, and the bilingual manual. Optional shared-library and historical case packages are separate and are not included.

The original `local_study_characters` directory is marked `local-study-only` and `exclude_from_public: true`; it is excluded from public Git history and release archives. The three extracted game-character presets are not bundled. Character import and configuration tools remain available for your own assets or an applicable external library. An empty preset list or a missing study-preset message is expected without such a library.

Manual screenshots demonstrate the original learning package. They do not imply that the displayed character sheets, historical cases, or music are included in this public release.

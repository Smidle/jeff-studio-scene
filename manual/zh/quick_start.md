# 按顺序安装 0.4.6

> **GitHub 公开版说明：**下文保留 0.4.6 原学习版说明。三位游戏提取角色预设、可选共享素材库与历史案例包未随公开版提供；内置建筑与地表已包含，角色可使用自己的素材。[查看分发说明](../DISTRIBUTION.md)

## 1. 插件与说明书

解压 `01_HD2D_0.4.6_Plugin_Manual.zip`，只把 `addons` 复制到 Godot 工程根目录。在“项目 → 项目设置 → 插件”启用 **Jeff Studio 场景**。说明书留在浏览器中阅读；更新前备份已有插件。

只安装第一包，即可使用内置建筑、35 张地表纹理和三位学习版预设角色。

## 2. 共享素材库（按需）

将 `02_HD2D_0.4.6_Shared_Asset_Library.zip` 解压到 **Godot 工程外**。在插件顶部 **位置…** 选择含 `preset-index.json` 的 `HD2D_Shared_Asset_Library` 文件夹，再点 **重新检查**。在素材工作台浏览、选择和摆放；只准备选中条目所需资源。

不要将整个库复制进工程。已有共享库时先备份，保留自己的 `index.json` 与 `objects`。[共享库详细安装](shared_library.md)。

## 3. 案例（按需）

解压 `03_HD2D_0.4.6_Case_Assets.zip`，按包内说明将 `showcase`、`case01`、`local_study` 复制到工程根目录，保持相对路径，等待 Godot 导入。案例包自带所需资源；安装第一包后即可使用，不要求连接第二包。

案例沿用既有成品，具体场景入口见[案例与历史资源](history.md)。本轮只检查插件与共享素材库，不将案例标为已重新测试。所有资源包都不包含 `project.godot`；遇到同名资源先备份核对。

### 制作自己的场景

点击 **新建地图**，选择自由地图、128 米、129 个高度采样点；用纯色或内置地表方案，在地形模块底部应用草稿。打开 **一键生成**，选择内置风格，点击金色 **应用到场景**，移动蓝图、Q / E 旋转、左键放置，Esc 取消。Ctrl+S / Cmd+S 保存。

在 **角色 → 放置预设角色** 选择角色及主角／队友／NPC 身份。继续阅读[一键生成](reference/generation.md)与[素材及实例编辑](reference/assets.md)。

<a id="community"></a>

JEFF STUDIO · COMMUNITY

<a id="community-title"></a>

### 交流与反馈

交流场景制作、反馈问题、关注版本更新。自愿加入，说明书可离线阅读。

微信群

<a id="community-wechat-title"></a>

### Jeff Studio 内测群

打开微信扫一扫

[![Jeff Studio 内测群 WeChat QR code](../images/jeff_studio_wechat_20260924.jpg)](../images/jeff_studio_wechat_20260924.jpg)

[点击二维码查看原图 ↗](../images/jeff_studio_wechat_20260924.jpg)

原图注明：2026 年 10 月 1 日前有效。失效后可用 QQ 群号加入，或向发布者索取新码。

QQ 群

<a id="community-qq-title"></a>

### Jeff Studio 插件

打开 QQ 扫一扫

[![Jeff Studio 插件 QQ QR code](../images/jeff_studio_qq_20260912.jpg)](../images/jeff_studio_qq_20260912.jpg)

[点击二维码查看原图 ↗](../images/jeff_studio_qq_20260912.jpg)

群号 **482858198**

也可在 QQ 中搜索群号加入。

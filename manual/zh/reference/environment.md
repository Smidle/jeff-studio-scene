<a name="manual-top"></a>

# 第三部分 · 环境

<!-- manual-navigation:start -->
[项目首页](../../../README.md) / [说明书总目录](../../README.md) / [中文说明书](../index.md) / [功能指南](README.md)

[← 返回上一级](README.md) · [English](../../en/reference/environment.md)

<details>
<summary>本页目录（点击展开）</summary>

- [可折叠功能分组](#manual-section-01)
- [按钮与操作](#manual-section-02)
- [逐项参数](#manual-section-03)
- [操作顺序与常见误区](#manual-section-04)

</details>
<!-- manual-navigation:end -->

> **GitHub 公开版说明：**下文保留 0.4.6 原学习版说明。三位游戏提取角色预设、可选共享素材库与历史案例包未随公开版提供；内置建筑与地表已包含，角色可使用自己的素材。[查看分发说明](../../DISTRIBUTION.md)

选中场景根节点，调节天空、日光与效果，再点“应用环境参数”。只有演出后期需要在游戏或隔离测试中看；原生编辑视口保持用于编辑。

<a name="manual-section-01"></a>

## 可折叠功能分组

点击带边框的标题展开或收起。★为首次默认展开，之后记住本工程的选择。**全部展开／全部收起**只作用于当前页。可用Tab聚焦标题，Enter/Space切换，左/右键收起或展开。收起保留草稿和正在使用的工具／试听，不会应用或保存；跨组“应用”按钮保留在方框外。

| 分组 | 包含功能 |
| --- | --- |
| ★ [天空与背景](#group-environment-sky) | 天空模式、天空颜色及地平线/雾颜色；不自动生成天空模型。 |
| ★ [日光与阴影](#group-environment-sun) | 日光颜色、强度、太阳方位/高度及投影开关。 |
| [环境补光](#group-environment-ambient) | 环境补光颜色与强度，提亮阴影区域。 |
| [风与云影](#group-environment-wind) | 全舞台植物风力与程序云影浓度；单素材风摆在素材页。 |
| [距离雾](#group-environment-fog) | 普通距离雾开关和浓度；不是体积雾。 |
| [调色](#group-environment-color) | 饱和度与对比度。 |
| [真实景深](#group-environment-dof) | 远景景深强度；Compatibility灰显，限制说明在方框外。 |
| [演出后期](#group-environment-post) | 演出后期开关、暗角、分区虚化；只影响游戏和隔离预览。 |

<a name="group-environment-sky"></a>

**天空与背景**

<a name="group-environment-sun"></a>

**日光与阴影**

<a name="group-environment-ambient"></a>

**环境补光**

<a name="group-environment-wind"></a>

**风与云影**

<a name="group-environment-fog"></a>

**距离雾**

<a name="group-environment-color"></a>

**调色**

<a name="group-environment-dof"></a>

**真实景深**

<a name="group-environment-post"></a>

**演出后期**

<a name="manual-section-02"></a>

## 按钮与操作

| 界面按钮 | 作用 / 何时生效 |
| --- | --- |
| 应用环境参数 | 一次提交天空、日光、雾、风、云影与后期设置，可撤销；不切换项目渲染器。 |

<a name="manual-section-03"></a>

## 逐项参数

多数数值先留在面板草稿，点击对应“应用”才提交。笔刷参数在绘制时读取；导入和选择纹理等动作立即执行。应用不等于磁盘保存，最后按 Ctrl+S / Cmd+S。例外以各按钮说明为准。

范围列中“最小值 … 最大值；步长”对应控件限制；下拉框列出可选值。单位和前提写在含义列。滑块与右侧数字框是同一个参数的两种输入方式。

| 参数 | 初始默认 | 范围 / 步长 / 选项 | 含义与限制 |
| --- | --- | --- | --- |
| <a name="control-sky_color"></a>天空<br>[天空与背景](#group-environment-sky) | 72b5cd | Color | 程序天空的天顶颜色或背景颜色，取决于天空模式。 |
| <a name="control-sky_mode"></a>天空模式<br>[天空与背景](#group-environment-sky) | 程序天空 | 程序天空,背景色 / 天空模型 | 程序天空生成渐变天空；背景色/天空模型模式只提供背景色，不自动创建云图平面或模型。 |
| <a name="control-ambient_color"></a>环境补光颜色<br>[环境补光](#group-environment-ambient) | 0.86,0.91,0.76 | Color | 阴影区域等处环境补光的颜色。 |
| <a name="control-horizon_color"></a>地平线 / 雾颜色<br>[天空与背景](#group-environment-sky) | e4e7d0 | Color | 程序地平线与距离雾的颜色，有助于统一远景色调。 |
| <a name="control-sun_color"></a>日光<br>[日光与阴影](#group-environment-sun) | fff2ca | Color | 主方向光的颜色；不是设置太阳图片。 |
| <a name="control-sun_energy"></a>日光强度<br>[日光与阴影](#group-environment-sun) | 0.85 | 0 … 8; 0.01 | 主日光强度；过高会让贴图高光和浅色部分过曝。 |
| <a name="control-sun_yaw"></a>太阳方位<br>[日光与阴影](#group-environment-sun) | -35 | -180 … 180; 0.01 | 太阳绕世界竖直轴的方位，单位度，决定阴影方向。 |
| <a name="control-sun_elevation"></a>太阳高度<br>[日光与阴影](#group-environment-sun) | 48 | 0 … 90; 0.01 | 太阳离地平线的高度角，单位度，较低通常阴影更长。 |
| <a name="control-shadows"></a>投射阴影<br>[日光与阴影](#group-environment-sun) | On / 开 | — | 是否启用日光投射阴影；物体还需自身允许投影。 |
| <a name="control-ambient_energy"></a>环境补光<br>[环境补光](#group-environment-ambient) | 0.35 | 0 … 1; 0.01 | 环境补光强度；调高可提亮背光处，但会降低明暗对比。 |
| <a name="control-wind_strength"></a>植物风力<br>[风与云影](#group-environment-wind) | 0.5 | 0 … 3; 0.01 | 插件植物材质的程序风摆强度；任意导入材质不一定支持。 |
| <a name="control-cloud_shadows"></a>云影浓度<br>[风与云影](#group-environment-wind) | 0.18 | 0 … 1; 0.01 | 插件材质的程序云影浓度，不是自动调用游戏的云影 PNG。 |
| <a name="control-fog_enabled"></a>距离雾<br>[距离雾](#group-environment-fog) | On / 开 | — | 开启普通距离雾；不是体积雾。 |
| <a name="control-fog_density"></a>雾浓度<br>[距离雾](#group-environment-fog) | 0.001 | 0 … 0.1; 0.001 | 距离雾浓度，越高越快遮住远处；过大可能整幅泛白。 |
| <a name="control-saturation"></a>饱和度<br>[调色](#group-environment-color) | 1.05 | 0.2 … 2; 0.01 | 调色饱和度，1 为中性；原生视口与演出后期路径可能不同，最终以预览为准。 |
| <a name="control-contrast"></a>对比度<br>[调色](#group-environment-color) | 1.04 | 0.2 … 2; 0.01 | 调色对比度，1 为中性；数值高加重明暗差。 |
| <a name="control-depth_blur"></a>远景景深虚化<br>[真实景深](#group-environment-dof) | 0 | 0 … 1; 0.01 | 真正按深度的远景景深强度；Compatibility 禁用，Forward+ / Mobile 提供对应路径。 |
| <a name="control-presentation_enabled"></a>演出后期（仅游戏 / 隔离测试）<br>[演出后期](#group-environment-post) | Off / 关 | — | 开启游戏/隔离测试中的演出后期；不会把原生编辑视口改成成片滤镜。 |
| <a name="control-vignette"></a>暗角<br>[演出后期](#group-environment-post) | 0.36 | 0 … 1; 0.01 | 演出后期的边缘变暗强度，需要开启演出后期。 |
| <a name="control-zone_blur"></a>画面分区虚化（不是景深）<br>[演出后期](#group-environment-post) | 0 | 0 … 2; 0.01 | 按屏幕区域而非物体距离虚化；Compatibility 可用，不能冒充真正景深。 |

<a name="manual-section-04"></a>

## 操作顺序与常见误区

先只用程序天空和日光，确认构图后再加雾与后期。PNG 云图需要在素材页导入平面，并用原生 Inspector 配置位置与无光照材质；没有一键天空模型生成器。这里截图来自 Compatibility，真实景深灰显是正常功能提示，不是插件损坏。

保存、退出笔刷和预览请看顶部工具栏说明。这里使用侧栏、缩略图、笔刷和原生 Inspector 完成布景，不要求用户编写 GDScript。

只让一个火盆停止摇摆，请在素材页把该条目的“此素材风摆幅度”设0并应用。这里的“植物风力”影响整个舞台；分类名称不会自动启用或禁用风。详见[素材页火盆示例](assets.md#control-asset_wind)。

---

[← 上一章：镜头](camera.md) · [↑ 返回上一级](README.md) · [说明书总目录](../../README.md) · [↑ 回到页首](#manual-top) · [下一章：音乐 →](music.md)

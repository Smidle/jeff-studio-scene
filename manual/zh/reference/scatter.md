<a name="manual-top"></a>

# 第三部分 · 铺设与道路

<!-- manual-navigation:start -->
[项目首页](../../../README.md) / [说明书总目录](../../README.md) / [中文说明书](../index.md) / [功能指南](README.md)

[← 返回上一级](README.md) · [English](../../en/reference/scatter.md)

<details>
<summary>本页目录（点击展开）</summary>

- [可折叠功能分组](#manual-section-01)
- [按钮与操作](#manual-section-02)
- [逐项参数](#manual-section-03)
- [操作顺序与常见误区](#manual-section-04)

</details>
<!-- manual-navigation:end -->

> **GitHub 公开版说明：**下文保留 0.4.6 原学习版说明。三位游戏提取角色预设、可选共享素材库与历史案例包未随公开版提供；内置建筑与地表已包含，角色可使用自己的素材。[查看分发说明](../../DISTRIBUTION.md)

在素材页按 Ctrl 多选植物，切到铺设页，选择笔刷或圆形散布，再点击地形。道路必须有至少两个控制点才能形成路面。

新散布的 2D／3D 素材默认带静态碰撞，已保存的植被记录保持原值。需要可穿行的草地时，在素材页通过同素材批量应用关闭碰撞。

<a name="manual-section-01"></a>

## 可折叠功能分组

点击带边框的标题展开或收起。★为首次默认展开，之后记住本工程的选择。**全部展开／全部收起**只作用于当前页。可用Tab聚焦标题，Enter/Space切换，左/右键收起或展开。收起保留草稿和正在使用的工具／试听，不会应用或保存；跨组“应用”按钮保留在方框外。

| 分组 | 包含功能 |
| --- | --- |
| ★ [植物铺设与擦除](#group-scatter-plants) | 混合笔刷、圆形散布、擦除、密度与半径。 |
| [随机变化与道路避让](#group-scatter-random) | 缩放/朝向随机范围、道路额外避让和随机种子。 |
| [道路曲线](#group-scatter-road) | 新建道路、继续加点、宽度及删除末尾控制点。 |
| [道路纹理与栅栏](#group-scatter-fences) | 道路纹理选择、重复周期、两侧栅栏开关与间距。 |

<a name="group-scatter-plants"></a>

**植物铺设与擦除**

<a name="group-scatter-random"></a>

**随机变化与道路避让**

<a name="group-scatter-road"></a>

**道路曲线**

<a name="group-scatter-fences"></a>

**道路纹理与栅栏**

<a name="manual-section-02"></a>

## 按钮与操作

| 界面按钮 | 作用 / 何时生效 |
| --- | --- |
| 植物混合笔刷 | 在地面拖动连续盖章，使用多选素材和随机参数，一次拖动是一条撤销。 |
| 圆形区域散布 | 点击一次生成一个圆形范围内的植物；不是可持久编辑的多边形区域对象。 |
| 擦除植物 | 删除半径内植物摆放记录，可撤销；不删除原图，也不擦除普通单件节点。 |
| 新建道路并绘制 | 创建 Road 并进入加点模式，在地面逐点点击，Esc 结束；至少两点。 |
| 为当前道路添加点 | 选中已有 Road 后继续添加点，不是重建第二条路。 |
| 选择道路纹理… | 为当前道路立即指定 PNG/JPG/WebP 纹理。 |
| 应用道路参数 | 提交当前道路宽度、平铺和栅栏设置，更新贴地网格。 |
| 删除最后一个道路控制点 | 只删除当前道路的末尾点，可撤销；不是删除整个道路节点。 |

<a name="manual-section-03"></a>

## 逐项参数

多数数值先留在面板草稿，点击对应“应用”才提交。笔刷参数在绘制时读取；导入和选择纹理等动作立即执行。应用不等于磁盘保存，最后按 Ctrl+S / Cmd+S。例外以各按钮说明为准。

范围列中“最小值 … 最大值；步长”对应控件限制；下拉框列出可选值。单位和前提写在含义列。滑块与右侧数字框是同一个参数的两种输入方式。

| 参数 | 初始默认 | 范围 / 步长 / 选项 | 含义与限制 |
| --- | --- | --- | --- |
| <a name="control-density"></a>每平方米数量<br>[植物铺设与擦除](#group-scatter-plants) | 0.3 | 0.01 … 10; 0.01 | 目标每平方米实例数；区域数量约为面积乘密度，仍受道路排除、地形边缘和数量上限影响。 |
| <a name="control-scatter_radius"></a>铺设 / 擦除半径<br>[植物铺设与擦除](#group-scatter-plants) | 5 | 0.2 … 64; 0.1 | 植物笔刷、区域散布和擦除的世界半径，单位米。 |
| <a name="control-scale_min"></a>随机缩放下限<br>[随机变化与道路避让](#group-scatter-random) | 0.8 | 0.05 … 10; 0.05 | 新铺设实例随机缩放的下限，是原素材大小的倍数；请保持不大于上限。 |
| <a name="control-scale_max"></a>随机缩放上限<br>[随机变化与道路避让](#group-scatter-random) | 1.2 | 0.05 … 10; 0.05 | 新铺设实例随机缩放的上限；过大会使前景花丛挡住角色脸。 |
| <a name="control-yaw_min"></a>随机朝向下限（度）<br>[随机变化与道路避让](#group-scatter-random) | -20 | -180 … 180; 1 | 随机绕竖直 Y 轴旋转的下限，单位度。 |
| <a name="control-yaw_max"></a>随机朝向上限（度）<br>[随机变化与道路避让](#group-scatter-random) | 20 | -180 … 180; 1 | 随机绕 Y 轴旋转的上限；平面贴片不宜转到侧边几乎看不见。 |
| <a name="control-road_margin"></a>道路排除额外距离<br>[随机变化与道路避让](#group-scatter-random) | 0.5 | 0 … 10; 0.1 | 在 Road 路宽之外再留出的空隙，单位米；不识别手绘地表土路。 |
| <a name="control-seed"></a>随机种子<br>[随机变化与道路避让](#group-scatter-random) | 42 | 0 … 2147483647; 1 | 随机序列种子；生成也依赖现有记录数量与操作顺序，仅相同种子不足以重建同一布局。 |
| <a name="control-road_width"></a>道路宽度<br>[道路曲线](#group-scatter-road) | 3 | 0.2 … 20; 0.1 | 道路横向宽度，单位米，应用到当前道路。 |
| <a name="control-road_tile"></a>道路纹理周期<br>[道路纹理与栅栏](#group-scatter-fences) | 3 | 0.2 … 20; 0.1 | 沿道路纹理重复一次的距离，单位米。 |
| <a name="control-fences"></a>沿两侧生成栅栏<br>[道路纹理与栅栏](#group-scatter-fences) | Off / 关 | — | 为道路两侧生成基础栅栏；不是自动调用游戏中的栅栏模型。 |
| <a name="control-fence_spacing"></a>栅栏间距<br>[道路纹理与栅栏](#group-scatter-fences) | 2 | 0.5 … 10; 0.1 | 沿路相邻栅栏的间距，单位米；开启栅栏后有效。 |

<a name="manual-section-04"></a>

## 操作顺序与常见误区

先画真实 Road 再铺花，才有道路排除。笔刷散布每次盖章的数量不同于一次完整圆形散布；过密可用擦除减轻。选择 Road 后拖位置和两侧切线控制柄调曲线，Esc 结束加点。单株精细变换暂没有专用植物控制柄，可使用普通单件摆放。

保存、退出笔刷和预览请看顶部工具栏说明。这里使用侧栏、缩略图、笔刷和原生 Inspector 完成布景，不要求用户编写 GDScript。

---

[← 上一章：素材与实例编辑](assets.md) · [↑ 返回上一级](README.md) · [说明书总目录](../../README.md) · [↑ 回到页首](#manual-top) · [下一章：角色 →](character.md)

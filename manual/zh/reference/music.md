<a name="manual-top"></a>

# 第三部分 · 音乐

<!-- manual-navigation:start -->
[项目首页](../../../README.md) / [说明书总目录](../../README.md) / [中文说明书](../index.md) / [功能指南](README.md)

[← 返回上一级](README.md) · [English](../../en/reference/music.md)

<details>
<summary>本页目录（点击展开）</summary>

- [可折叠功能分组](#manual-section-01)
- [按钮与操作](#manual-section-02)
- [逐项参数](#manual-section-03)
- [其他可见控件](#manual-section-04)
- [操作顺序与常见误区](#manual-section-05)

</details>
<!-- manual-navigation:end -->

> **GitHub 公开版说明：**下文保留 0.4.6 原学习版说明。三位游戏提取角色预设、可选共享素材库与历史案例包未随公开版提供；内置建筑与地表已包含，角色可使用自己的素材。[查看分发说明](../../DISTRIBUTION.md)

导入后选曲，试听、调节、应用，再设为场景 BGM。列表选中与场景启用是两件事：♪ 标记才表示当前场景曲目。

<a name="manual-section-01"></a>

## 可折叠功能分组

点击带边框的标题展开或收起。★为首次默认展开，之后记住本工程的选择。**全部展开／全部收起**只作用于当前页。可用Tab聚焦标题，Enter/Space切换，左/右键收起或展开。收起保留草稿和正在使用的工具／试听，不会应用或保存；跨组“应用”按钮保留在方框外。

| 分组 | 包含功能 |
| --- | --- |
| ★ [音乐导入与曲库](#group-music-import) | 导入音乐、多曲库列表与搜索；选中不等于启用BGM。 |
| [场景BGM管理](#group-music-bgm) | 设为BGM、移除条目、关闭BGM但保留曲库。 |
| ★ [试听与波形](#group-music-audition) | 波形、试听/暂停/停止、进度跳转与时间状态；收起继续试听。 |
| [名称分类与来源](#group-music-identity) | 修改曲目显示名、分类和来源用途；不修改音频文件名。 |
| [自动播放与循环](#group-music-playback) | 运行自动播放、循环、是否随舞台暂停。 |
| [音量与淡入淡出](#group-music-volume) | 音量dB、开始淡入秒数、主动停止淡出秒数。 |
| [循环区间](#group-music-interval) | 循环起点与终点；首次从0播放，非零终点仅PCM WAV支持。 |

<a name="group-music-import"></a>

**音乐导入与曲库**

<a name="group-music-bgm"></a>

**场景BGM管理**

<a name="group-music-audition"></a>

**试听与波形**

<a name="group-music-identity"></a>

**名称分类与来源**

<a name="group-music-playback"></a>

**自动播放与循环**

<a name="group-music-volume"></a>

**音量与淡入淡出**

<a name="group-music-interval"></a>

**循环区间**

<a name="manual-section-02"></a>

## 按钮与操作

| 界面按钮 | 作用 / 何时生效 |
| --- | --- |
| ＋ 导入音乐（可多选） | 导入 WAV/OGG Vorbis/MP3 到场景曲库，工程外文件会复制；编辑时不会自动播放。 |
| 设为场景 BGM | 把选中曲目设为启用曲目（♪）。先应用参数，避免以为未提交草稿也已保存。 |
| 移除条目 | 移除选中曲库条目，可撤销，不删除音频文件。 |
| 关闭场景 BGM（保留曲库） | 禁用当前场景音乐，保留全部曲目和设置。 |
| ▶ 试听 | 使用当前面板草稿从 0 秒播放；不是提交设置，也不代表最终循环已无缝。 |
| 暂停 / 继续 | 暂停或恢复当前试听，不改变场景自动播放设置。 |
| ■ 停止 | 按淡出时长停止试听；切换场景或关闭预览则直接停止。 |
| 应用音乐参数（可撤销） | 验证曲目参数后提交一个可撤销操作。无效区间会拒绝提交，保留原配置；最后仍需保存场景。 |

<a name="manual-section-03"></a>

## 逐项参数

多数数值先留在面板草稿，点击对应“应用”才提交。笔刷参数在绘制时读取；导入和选择纹理等动作立即执行。应用不等于磁盘保存，最后按 Ctrl+S / Cmd+S。例外以各按钮说明为准。

范围列中“最小值 … 最大值；步长”对应控件限制；下拉框列出可选值。单位和前提写在含义列。滑块与右侧数字框是同一个参数的两种输入方式。

| 参数 | 初始默认 | 范围 / 步长 / 选项 | 含义与限制 |
| --- | --- | --- | --- |
| <a name="control-music_autoplay"></a>运行 / 隔离测试时自动播放<br>[自动播放与循环](#group-music-playback) | On / 开 | — | 运行场景或打开隔离测试时播放启用的曲目；编辑时不自动播放。 |
| <a name="control-music_loop"></a>循环播放<br>[自动播放与循环](#group-music-playback) | On / 开 | — | 到终点后回到循环起点；关闭则播放结束停止。不会自动修补旋律接缝。 |
| <a name="control-music_pause_stage"></a>随舞台暂停（默认不勾选）<br>[自动播放与循环](#group-music-playback) | Off / 关 | — | 舞台背景暂停时音乐也暂停；默认关闭，所以暂停背景仍能听到音乐。 |
| <a name="control-music_volume"></a>音量（dB，0 为原音量）<br>[音量与淡入淡出](#group-music-volume) | -18 | -60 … 0; 0.01 | 播放增益，单位 dB；0 为原音量，负值衰减，不会改写音频文件。 |
| <a name="control-music_fade_in"></a>开始淡入（秒）<br>[音量与淡入淡出](#group-music-volume) | 1.5 | 0 … 10; 0.1 | 每次开始播放时由静音到目标音量的时间，单位秒；不是循环接缝交叉淡化。 |
| <a name="control-music_fade_out"></a>试听停止淡出（秒）<br>[音量与淡入淡出](#group-music-volume) | 0.8 | 0 … 10; 0.1 | 主动停止试听时的淡出时间；关闭预览或切换场景会立即停止，不等待淡出。 |
| <a name="control-music_loop_start"></a>循环回到（秒）<br>[循环区间](#group-music-interval) | 0 | 0 … 7200; 0.01 | 首次仍从 0 秒开始，之后每次循环回到此秒数；必须早于有效终点。 |
| <a name="control-music_loop_end"></a>循环终点（0 = 文件结尾）<br>[循环区间](#group-music-interval) | 0 | 0 … 7200; 0.01 | 0 表示文件末尾。非零自定义终点只支持 PCM WAV；OGG/MP3 使用文件末尾。 |

<a name="manual-section-04"></a>

## 其他可见控件

| 控件 | 说明 |
| --- | --- |
| 音乐搜索与曲库 | 按名称或分类筛选；选中只准备编辑，♪ 才是场景 BGM。 |
| 抽样波形与进度条 | 播放后点击波形或拖动进度条跳转。波形只是抽样概览，不是逐样本剪辑器。 |
| 名称 / 分类 | 填写显示名与分类后点应用；不会重命名磁盘文件。 |
| 来源与用途说明 | 随场景保存的自由文本，记录来源和使用限制；不会自动获取授权。 |
| 曲目信息 / 播放状态 | 只读显示路径、格式、长度、播放时间与状态；编辑器不自动播放。 |

<a name="manual-section-05"></a>

## 操作顺序与常见误区

每场景一个背景播放器，不随三段舞台复制三份。先应用，再设为 BGM，保存后重开检查；完整试听一圈，音乐接缝需用音频工具在插件外制作。本页没有多轨混音、自动节拍对齐、降噪、波形裁剪或广告插入功能。

保存、退出笔刷和预览请看顶部工具栏说明。这里使用侧栏、缩略图、笔刷和原生 Inspector 完成布景，不要求用户编写 GDScript。

---

[← 上一章：环境](environment.md) · [↑ 返回上一级](README.md) · [说明书总目录](../../README.md) · [↑ 回到页首](#manual-top) · [下一章：场景预览 →](preview.md)

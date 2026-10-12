# 角色

> 公开版 0.4.7 · 仅插件与说明书，不附带提取角色图片、共享素材库、案例或本地测试工程。


公开插件不附带游戏提取角色预设。请导入自己的动作帧，或连接兼容角色素材库。

1. 新建自由地图，选中 Hero。设置动作、素材方向、帧数和 FPS。
2. 导入 PNG 序列、图集行或 SpriteFrames；分别导入待机、行走、跑步及所需方向。缺失方向会提示，不自动补造动作。
3. 设置脚底锚点、每像素米数、行走速度与碰撞，然后应用角色设置。
4. 把角色摆放到地面，保存，从镜头页预览检查。
5. 连接兼容预设库后，可选角色和主角／队友／NPC 身份，再点在 3D 视图放置角色。缺少 Characters 容器时自动创建，可一起撤销／重做。主角唯一，队友跟随，NPC 原地待机。

## 可折叠功能分组

点击带边框的标题展开或收起。★为首次默认展开，之后记住本工程的选择。**全部展开／全部收起**只作用于当前页。可用Tab聚焦标题，Enter/Space切换，左/右键收起或展开。收起保留草稿和正在使用的工具／试听，不会应用或保存；跨组“应用”按钮保留在方框外。

| 分组 | 包含功能 |
|---|---|
| ★ [动作与方向](#group-character-action) | 方向数量、动作/自定义动作、素材方向与导入FPS。 |
| ★ [素材导入](#group-character-import) | PNG序列、规则图集行列/读取行/有效帧、SpriteFrames导入。 |
| [动画映射](#group-character-mapping) | 输入已有动画名，将当前动作/方向映射到该动画。 |
| [脚底锚点与显示](#group-character-appearance) | 脚底预览与锚点、每像素米数、受光和水平翻转。 |
| [行走与碰撞](#group-character-movement) | 移动速度、碰撞半径/高度、点击地面放置角色工具。 |
| [角色阴影](#group-character-shadow) | 脚下接触阴影和平地投影阴影开关。 |

以下是 0.4.5 / Godot 4.7.2 / Compatibility 界面。点击图片可放大，每图展开一个分组；较长的分组附下半部分。

<div class="ui-gallery">
<a id="group-character-action" name="group-character-action"></a><p><strong>动作与方向</strong></p>
<a id="group-character-import" name="group-character-import"></a><p><strong>素材导入</strong></p>
<a id="group-character-mapping" name="group-character-mapping"></a><p><strong>动画映射</strong></p>
<a id="group-character-appearance" name="group-character-appearance"></a><p><strong>脚底锚点与显示</strong></p>
<a id="group-character-movement" name="group-character-movement"></a><p><strong>行走与碰撞</strong></p>
<a id="group-character-shadow" name="group-character-shadow"></a><p><strong>角色阴影</strong></p>
</div>

## 按钮与操作

| 界面按钮 | 作用 / 何时生效 |
|---|---|
| 导入 PNG 序列（按名称自然排序） | 把多张等画布 PNG 按自然名称顺序导入当前动作/方向；先设置动作、方向与 FPS。 |
| 导入规则精灵图集的这一行 | 按列数、行数和所选行切出一组帧；不支持直接猜解不规则打包图集。 |
| 导入现有 SpriteFrames | 载入已准备好的 SpriteFrames .tres/.res；不是素材库或角色 Profile。外部依赖图片需可访问。 |
| 将所选动作 / 方向映射到此动画 | 把当前动作/方向映射到输入的已有动画名；不复制或自动生成动画帧。 |
| 应用角色配置 / 脚底锚点 | 提交锚点、方向数、大小、速度、碰撞与阴影到当前角色配置。修改后在隔离测试检查脚底。 |
| 点击地面放置角色 | 进入角色落点工具，点击地形调整当前角色位置；不是每次点击新增一个角色。 |

## 逐项参数

多数数值先留在面板草稿，点击对应“应用”才提交。笔刷参数在绘制时读取；导入和选择纹理等动作立即执行。应用不等于磁盘保存，最后按 Ctrl+S / Cmd+S。例外以各按钮说明为准。

范围列中“最小值 … 最大值；步长”对应控件限制；下拉框列出可选值。单位和前提写在含义列。滑块与右侧数字框是同一个参数的两种输入方式。

| 参数 | 初始默认 | 范围 / 步长 / 选项 | 含义与限制 |
|---|---|---|---|
| <span id="control-directions"></span>方向数量<br>[动作与方向](#group-character-action) | 4 | 2,4,8 | 角色希望使用的方向数量，不等于已有图片数量；缺少的方向会提示并回退。 |
| <span id="control-action"></span>动作<br>[动作与方向](#group-character-action) | idle | idle,walk | 当前导入或映射的动作键：idle 为待机、walk 为行走。 |
| <span id="control-direction"></span>素材方向<br>[动作与方向](#group-character-action) | s | s,w,n,e,sw,nw,ne,se | 当前这批原图实际朝向：s 南、w 西、n 北、e 东；其余为对角方向。 |
| <span id="control-fps"></span>每秒帧数<br>[动作与方向](#group-character-action) | 8 | 1 … 60; 1 | 导入动作的每秒帧数，数值高播放更快；不是新增补间帧。 |
| <span id="control-atlas_columns"></span>图集列数<br>[素材导入](#group-character-import) | 4 | 1 … 128; 1 | 规则图集水平方向的等宽格数。 |
| <span id="control-atlas_rows"></span>图集行数<br>[素材导入](#group-character-import) | 4 | 1 … 128; 1 | 规则图集竖向的等高格数。 |
| <span id="control-atlas_row"></span>读取第几行（从 1 开始）<br>[素材导入](#group-character-import) | 1 | 1 … 128; 1 | 本次导入的行号，从 1 开始；必须位于总行数内。 |
| <span id="control-atlas_count"></span>此行有效帧数<br>[素材导入](#group-character-import) | 4 | 1 … 128; 1 | 此行实际使用的连续帧数，不能超过列数。 |
| <span id="control-foot_x"></span>横向锚点<br>[脚底锚点与显示](#group-character-appearance) | 0.5 | -0.5 … 1.5; 0.01 | 精灵横向脚底中心比例；0 左、0.5 中、1 右，和裁框坐标不同。 |
| <span id="control-foot_y"></span>脚底锚点<br>[脚底锚点与显示](#group-character-appearance) | 1 | -0.5 … 1.5; 0.01 | 精灵脚底的竖向比例；按可见脚底定位，不按透明画布最下缘猜测。 |
| <span id="control-pixel_size"></span>每像素米数<br>[脚底锚点与显示](#group-character-appearance) | 0.025 | 0.001 … 0.1; 0.001 | 一个图片像素对应多少世界米。显示高度约等于像素高度乘此值。 |
| <span id="control-move_speed"></span>行走速度 米/秒<br>[行走与碰撞](#group-character-movement) | 4 | 0 … 20; 0.1 | 基础行走速度，单位米/秒；不是精灵动画 FPS。 |
| <span id="control-collider_radius"></span>碰撞半径<br>[行走与碰撞](#group-character-movement) | 0.3 | 0.1 … 3; 0.05 | 胶囊碰撞体半径，单位米；碰撞与图片显示独立。 |
| <span id="control-collider_height"></span>碰撞高度<br>[行走与碰撞](#group-character-movement) | 1.5 | 0.2 … 5; 0.05 | 胶囊总高度，单位米，应至少为直径；注意不要用透明留白估算身体高度。 |
| <span id="control-character_shaded"></span>角色接受日光明暗<br>[脚底锚点与显示](#group-character-appearance) | Off / 关 | — | 让精灵受场景日光影响；关闭时颜色更稳定，但不像实体模型那样受光。 |
| <span id="control-character_flip"></span>手动水平翻转（不补造方向）<br>[脚底锚点与显示](#group-character-appearance) | Off / 关 | — | 手动水平镜像已有图片；不会创建缺失的另一方向动画。 |
| <span id="control-contact_shadow"></span>脚下接触阴影<br>[角色阴影](#group-character-shadow) | On / 开 | — | 角色脚下的接触阴影，帮助表达落地位置。 |
| <span id="control-projected_shadow"></span>平地投影阴影（倾斜坡面慎用）<br>[角色阴影](#group-character-shadow) | Off / 关 | — | 适合平地的投影阴影近似；斜坡可能漂浮或穿地，需要检查。 |
| <span id="control-custom_action"></span>可选：自定义动作名（如 attack）<br>[动作与方向](#group-character-action) | — | Text | 填写后覆盖动作下拉选择；如 attack。基础行走组件不是战斗状态机，自定义动作需游戏逻辑接入。 |
| <span id="control-animation_mapping"></span>现有动画名称，如 WalkSouth<br>[动画映射](#group-character-mapping) | — | Text | 现有 SpriteFrames 中的动画名称，必须精确匹配；不是资源文件路径。 |

## 其他可见控件

| 控件 | 说明 |
|---|---|
| 脚底图片与黄线 | 点击预览设置横/竖锚点，再应用角色配置；全动作等画布才更容易保持对齐。 |
| 缺失方向提示 | 列出缺失动画及实际回退；不是错误补帧服务，不自动镜像。 |

## 操作顺序与常见误区

先处理一组 walk_e 并检查脚底，再补 idle 和其他真实方向。预览用 WASD/方向键测试方向切换与斜坡碰撞。手动导入的旧角色沿用 idle/walk；预设身份角色按移动状态切换 idle/walk/run。这不是完整的战斗动作播放器。

保存、退出笔刷和预览请看顶部工具栏说明。这里使用侧栏、缩略图、笔刷和原生 Inspector 完成布景，不要求用户编写 GDScript。

## 显示方向与镜像

预设角色自动正对镜头，不需要旋转角色根节点。手动导入角色可在 **脚底锚点与显示 → 角色画面正对镜头** 开启并应用；它对应 Profile 的 **Full Billboard**，只影响画面。

在角色 Inspector 展开 Profile，**Mirror Directions** 是需要镜像的方向键数组，默认空。填 `e` 可用已有帧镜像东向，案例 5 使用此设置；它与 Flip H 共同决定翻转，不生成新帧。未提供也未明确镜像的方向仍使用动画映射回退。

## 显示与跑步

| 参数 | 默认 | 范围 | 用途 |
|---|---|---|---|
| <span id="control-character_face_camera"></span>角色画面正对镜头 | 预设角色开启 | 开／关 | 显示面随镜头俯仰转动；脚底与碰撞保持原位。旧手动角色需主动开启并应用。 |
| <span id="control-run_speed"></span>跑步速度 | 6.5 米/秒 | 0–30；步长 0.1 | 自由地图按住 Shift 使用；预设跑步动画随速度切换。 |


[← 说明书目录](../index.md) · [更新说明](../release_notes.md)

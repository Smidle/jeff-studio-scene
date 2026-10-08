@tool
extends HBoxContainer
var controller
var create_button: Button
var assets_button: Button
var activity: Label
func setup(plugin) -> void:
 controller=plugin;name="JeffSceneToolbar"
 create_button=controller.ui.button(self,"新建地图",func():controller.ui.terrain_panel.open_creation())
 assets_button=controller.ui.button(self,"素材工作台",func():controller.workbench.open_current())
 activity=Label.new();activity.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;activity.custom_minimum_size.x=60*EditorInterface.get_editor_scale();activity.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(activity)
 for button in [create_button,assets_button]:button.add_theme_font_size_override("font_size",roundi(12*EditorInterface.get_editor_scale()))
 activity.add_theme_font_size_override("font_size",roundi(11*EditorInterface.get_editor_scale()))
 controller.i18n.changed.connect(refresh)
 var viewport := EditorInterface.get_editor_viewport_3d(0)
 viewport.size_changed.connect(refresh)
 tree_exiting.connect(func():
  if controller.i18n.changed.is_connected(refresh):controller.i18n.changed.disconnect(refresh)
  if viewport.size_changed.is_connected(refresh):viewport.size_changed.disconnect(refresh))
 refresh()
func refresh() -> void:
 if not is_instance_valid(activity):return
 var scale := EditorInterface.get_editor_scale()
 var narrow := EditorInterface.get_editor_viewport_3d(0).size.x/scale<1000
 create_button.custom_minimum_size.x=(66 if narrow else 112)*scale
 assets_button.custom_minimum_size.x=(76 if narrow else 152)*scale
 activity.custom_minimum_size.x=(88 if narrow else 112)*scale
 controller.i18n.text(create_button,"新建" if narrow else "新建地图")
 controller.i18n.text(assets_button,"素材" if narrow else "素材工作台")
 controller.i18n.bind(create_button,"tooltip_text","新建地图")
 controller.i18n.bind(assets_button,"tooltip_text","素材工作台")
 var names := {"select":"选择","village_place":"小镇蓝图","building_place":"建筑蓝图","character_place":"放置预设角色","raise":"升高","lower":"降低","smooth":"平滑","flatten":"平台","ramp":"坡道","paint":"绘制地表","place":"摆放","erase":"擦除","scatter":"散布","road":"道路"}
 var tool: String=controller.i18n.t(names.get(controller.current_tool,controller.current_tool))
 controller.i18n.text(activity,"工具：%s"%tool)
 var lines := PackedStringArray()
 if is_instance_valid(controller.stage):
  lines.append(controller.i18n.t("当前场景：%s")%controller.stage.name)
  var terrain=controller.stage.terrain()
  if terrain and terrain.data:
   lines.append(controller.i18n.t("地形：%s · %.1f 米 · %d×%d 采样")%[terrain.name,terrain.data.size_m,terrain.data.resolution,terrain.data.resolution])
   lines.append(controller.i18n.t("采样间距：%.3f 米")%(terrain.data.size_m/maxf(1,terrain.data.resolution-1)))
 else:lines.append(controller.i18n.t("新建地图，或选择已有场景。"))
 lines.append(controller.i18n.t("活动工具：%s")%tool)
 lines.append(controller.i18n.t("Esc 退出工具 · Ctrl / Cmd + Z 撤销 · Ctrl / Cmd + S 保存"))
 activity.tooltip_text="\n".join(lines)

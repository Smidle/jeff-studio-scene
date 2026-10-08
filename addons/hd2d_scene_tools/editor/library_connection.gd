@tool
extends PanelContainer
## Read indexes only; the refresh action also invalidates visible catalog pages.
var controller
var heading: Label
var details: Label
var stars: Array[Control]=[]
var button: Button
var recheck_button: Button
var checked_at := ""
var checking := false
var style_signature := ""
func setup(plugin) -> void:
 controller=plugin;name="SharedLibraryConnection"
 var box := VBoxContainer.new();add_child(box)
 var headline := HBoxContainer.new();box.add_child(headline)
 var left=preload("animated_icon.gd").new();left.name="LibraryStarLeft";headline.add_child(left);left.setup("library_star",16);stars.append(left)
 heading=controller.ui.label(headline,"");heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.autowrap_mode=TextServer.AUTOWRAP_OFF;heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var right=preload("animated_icon.gd").new();right.name="LibraryStarRight";headline.add_child(right);right.setup("library_star",16,0.72);stars.append(right)
 details=heading
 var actions := HBoxContainer.new();box.add_child(actions)
 button=controller.ui.button(actions,"位置…",func():controller.shared_library.choose_location())
 recheck_button=controller.ui.button(actions,"重新检查",recheck)
 for item in [button,recheck_button]:
  item.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  item.add_theme_font_size_override("font_size",roundi(11*EditorInterface.get_editor_scale()))
 controller.shared_library.location_changed.connect(refresh)
 controller.i18n.changed.connect(refresh)
 theme_changed.connect(restyle)
 tree_exiting.connect(func():
  if controller.i18n.changed.is_connected(refresh):controller.i18n.changed.disconnect(refresh)
  if controller.shared_library.location_changed.is_connected(refresh):controller.shared_library.location_changed.disconnect(refresh))
 refresh.call_deferred()
func restyle() -> void:
 if not controller or not controller.skin:return
 var palette: Array=controller.skin.palette
 var signature := str(palette)+str(EditorInterface.get_editor_scale())
 if style_signature==signature:return
 style_signature=signature
 var style: StyleBoxFlat=controller.skin.box(palette[1],palette[2],EditorInterface.get_editor_scale())
 style.set_border_width_all(maxi(1,roundi(2*EditorInterface.get_editor_scale())))
 style.content_margin_top=4;style.content_margin_bottom=4
 add_theme_stylebox_override("panel",style)
func recheck() -> void:
 if checking:return
 checking=true;recheck_button.disabled=true;controller.i18n.text(heading,"正在检查共享库…")
 await get_tree().process_frame
 var state: Dictionary=controller.shared_library.recheck_connection()
 checked_at=Time.get_time_string_from_system()
 checking=false;recheck_button.disabled=false;refresh(state)
func refresh(state: Dictionary={}) -> void:
 if not is_instance_valid(heading):return
 if state.is_empty():state=controller.shared_library.connection_status()
 var summary: String="共享库已连接 · 无需重复设置" if state.connected else "内置地表可用 · 共享库可选"
 if state.connected and not state.get("terrain",false):summary="共享物件与内置地表可用"
 if state.connected and not state.get("objects",false):summary="地表库可用 · 物件未安装"
 if state.get("invalid",false):summary="共享库索引异常 · 查看详情"
 if not checked_at.is_empty():controller.i18n.text(recheck_button,controller.i18n.t("重新检查")+" · "+checked_at)
 controller.i18n.text(heading,summary)
 heading.tooltip_text=controller.i18n.t("已内置 35 张地表纹理与 14 套方案，无需连接共享库。")+"\n"+controller.shared_library.root_path()+"\n"+controller.i18n.t("物件库：%s · 地表库：%s")%[controller.i18n.t("可用" if state.objects else "未安装"),controller.i18n.t("可用" if state.terrain else "未安装")]+"\n"+controller.i18n.t(state.message)
 if not checked_at.is_empty():heading.tooltip_text+="\n"+controller.i18n.t("已检查")+" "+checked_at
 button.tooltip_text=heading.tooltip_text
 restyle()

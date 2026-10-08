@tool
class_name HD2DWorldHUD
extends CanvasLayer
var locations: OptionButton
var status: Label
var overview_button: Button
var markers: Array[Label]=[]
var panel: Control
var english := false
@export_enum("Auto", "中文", "English") var language: int = 0

func _ready() -> void:
 layer=20
 if Engine.is_editor_hint():
  visible=false
  return
 rebuild()

func rebuild() -> void:
 for child in get_children(): child.queue_free()
 markers.clear()
 var stage := get_parent() as HD2DStage
 if not stage: return
 var terrain := stage.terrain() as HD2DWorldMap
 if not terrain: return
 english=language==2 or (language==0 and not OS.get_locale_language().begins_with("zh"))
 panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
 var border := Panel.new();border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 border.offset_left=12;border.offset_top=12;border.offset_right=-12;border.offset_bottom=-12;border.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style := StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT;style.border_color=Color("b49a61")
 style.set_border_width_all(4);style.set_corner_radius_all(4);border.add_theme_stylebox_override("panel",style);panel.add_child(border)
 var top := HBoxContainer.new();top.position=Vector2(28,28);top.add_theme_constant_override("separation",12);panel.add_child(top)
 var title := Label.new();title.text="CASE 6 · WORLD MAP" if english else "案例 6 · 江湖全图";title.add_theme_color_override("font_color",Color("ead7a0"));top.add_child(title)
 overview_button=Button.new();overview_button.text="Overview / Follow [M]" if english else "整图总览／跟随 [M]";top.add_child(overview_button)
 overview_button.pressed.connect(func(): var party: HD2DWorldParty=stage.get_node("WorldParty");party.set_overview(not party.overview))
 locations=OptionButton.new();locations.custom_minimum_size.x=185;locations.add_item("Locate a place…" if english else "选择地点快速定位…")
 for marker in terrain.world_data().bookmarks:
  locations.add_item(str(marker.get("name",{}).get("en" if english else "zh",marker.destination)))
 locations.item_selected.connect(func(index):
  if index<1: return
  var record: Dictionary=terrain.world_data().bookmarks[index-1]
  var point := terrain.to_global(HD2DWorldMapData.decode_transform(record.transform).origin)
  (stage.get_node("WorldParty") as HD2DWorldParty).locate(point)
 )
 top.add_child(locations)
 var references := OptionButton.new();references.add_item("Reference views…" if english else "参考镜头…")
 for view in HD2DWorldMapRecipe.REFERENCE_VIEWS: references.add_item(view.en if english else view.zh)
 references.item_selected.connect(func(index):
  if index<1: return
  var view: Dictionary=HD2DWorldMapRecipe.REFERENCE_VIEWS[index-1]
  var party := stage.get_node("WorldParty") as HD2DWorldParty
  party.locate(view.point);party.previous_frame=view.frame
  stage.camera_rig().frame_size=view.frame;stage.camera_rig().pitch_degrees=view.pitch;stage.camera_rig().reset_view()
 )
 top.add_child(references)
 status=Label.new();status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);status.position=Vector2(30,-48);panel.add_child(status)
 for marker in terrain.world_data().bookmarks:
  var label := Label.new();label.text=str(marker.get("name",{}).get("en" if english else "zh",marker.destination))
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  label.add_theme_color_override("font_color",Color("f3dfa4"));label.add_theme_color_override("font_shadow_color",Color("171f1f"))
  label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2)
  label.add_theme_font_size_override("font_size",16);panel.add_child(label);markers.append(label)

func _process(_delta: float) -> void:
 var stage := get_parent() as HD2DStage
 if not stage or (Engine.is_editor_hint() and not stage.preview_active): return
 if panel==null: visible=true;rebuild()
 var terrain := stage.terrain() as HD2DWorldMap
 if not terrain or not stage.camera_rig() or not stage.camera_rig().camera: return
 visible=terrain.world_data().presentation_enabled
 if not visible: return
 var camera := stage.camera_rig().camera
 status.text=("Preparing %d nearby tiles…" if english else "正在准备附近 %d 个区块…")%terrain.pending.size() if not terrain.pending.is_empty() else ("WASD / Arrows · Walk     Wheel · Zoom     M · Overview" if english else "WASD／方向键 行走     滚轮 缩放     M 整图总览")
 var occupied: Array[Rect2]=[]
 for i in range(markers.size()):
  var label := markers[i]
  var record: Dictionary=terrain.world_data().bookmarks[i]
  var point := terrain.to_global(HD2DWorldMapData.decode_transform(record.transform).origin)+Vector3.UP*3
  label.visible=not camera.is_position_behind(point)
  if not label.visible: continue
  var screen := camera.unproject_position(point)
  var rect := Rect2(screen-label.size*0.5,label.size+Vector2(12,8))
  label.visible=screen.x>28 and screen.x<get_viewport().get_visible_rect().size.x-28 and screen.y>90 and screen.y<get_viewport().get_visible_rect().size.y-64
  for other in occupied:
   if other.intersects(rect): label.visible=false;break
  if label.visible: label.position=rect.position;occupied.append(rect)

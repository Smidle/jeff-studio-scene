@tool
extends RefCounted
signal changed
const Icons=preload("pixel_icons.gd")
const PALETTES := {
 "jade":["172e29","213d35","80c3a0","edf4e9","a6bdb0"],
 "obsidian":["202631","2d3542","83b8f3","eef2fa","acb7c9"],
 "paper":["f2efe3","e8e4d4","356954","243e32","626e61"]
}
var controller
var selected := "jade"
var icons=Icons.new()
var roots: Array[Node]=[]
var palette: Array[Color]=[]
var theme: Theme
func setup(plugin) -> void:
 controller=plugin
 selected=str(EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","jeff_theme","jade"))
 if not PALETTES.has(selected):selected="jade"
 rebuild()
 controller.get_tree().node_added.connect(node_added)
func register(node: Node) -> void:
 if node not in roots:
  roots.append(node)
  if node is Control and not node is PanelContainer:
   node.draw.connect(paint_surface.bind(node))
   node.resized.connect(node.queue_redraw)
 apply_tree(node)
func paint_surface(node: Control) -> void:
 node.draw_rect(Rect2(Vector2.ZERO,node.size),palette[0])
func set_theme(value: String) -> void:
 if not PALETTES.has(value):return
 selected=value;EditorInterface.get_editor_settings().set_project_metadata("hd2d_scene_tools","jeff_theme",value)
 rebuild()
 for root in roots:
  if is_instance_valid(root):apply_tree(root)
 changed.emit()
func rebuild() -> void:
 palette.clear()
 for value in PALETTES[selected]:palette.append(Color(value))
 theme=Theme.new()
 theme.default_font=EditorInterface.get_editor_theme().default_font
 var scale := EditorInterface.get_editor_scale()
 theme.default_font_size=roundi(13*scale)
 theme.set_color("base_color","Editor",palette[0]);theme.set_color("accent_color","Editor",palette[2]);theme.set_color("font_color","Editor",palette[3])
 for type in ["Label","Button","OptionButton","CheckBox","CheckButton","LineEdit","TextEdit","PopupMenu","ItemList","RichTextLabel"]:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","font_selected_color"]:theme.set_color(state,type,palette[3])
  theme.set_color("font_disabled_color",type,palette[4].lerp(palette[0],0.35))
 for type in ["Button","OptionButton","LineEdit","TextEdit"]:
  for state in ["normal","hover","pressed","hover_pressed","disabled","focus","read_only"]:
   var active: bool=state in ["pressed","hover_pressed","focus"]
   theme.set_stylebox(state,type,box(palette[1].lerp(palette[2],0.2 if active else 0.1 if state=="hover" else 0.0),palette[2] if active else palette[1].lerp(palette[3],0.14),scale))
 for type in ["PanelContainer","Panel","PopupMenu","ItemList","TabContainer"]:theme.set_stylebox("panel",type,box(palette[0],palette[1],scale))
 theme.set_type_variation("JeffFrame","PanelContainer")
 var frame := box(palette[0],palette[2].lerp(palette[0],0.28),scale)
 frame.set_border_width_all(maxi(1,roundi(2*scale)))
 frame.content_margin_top=8*scale;frame.content_margin_bottom=8*scale
 theme.set_stylebox("panel","JeffFrame",frame)
 theme.set_type_variation("JeffApplyFrame","PanelContainer")
 var gold := Color("e7ba58") if selected=="paper" else Color("f2d58e")
 var edge := Color("ad7825") if selected=="paper" else gold
 var apply_frame := box(palette[0].lerp(gold,0.07),edge,scale)
 apply_frame.set_border_width_all(maxi(1,roundi(2*scale)))
 apply_frame.content_margin_top=8*scale;apply_frame.content_margin_bottom=8*scale
 theme.set_stylebox("panel","JeffApplyFrame",apply_frame)
 theme.set_type_variation("JeffPrimaryButton","Button")
 for state in ["normal","hover","pressed","hover_pressed","disabled"]:
  var background := gold.lightened(0.12) if state=="hover" else gold.darkened(0.1) if state in ["pressed","hover_pressed"] else gold
  if state=="disabled":background=palette[1]
  theme.set_stylebox(state,"JeffPrimaryButton",box(background,palette[4] if state=="disabled" else edge,scale))
 for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:theme.set_color(state,"JeffPrimaryButton",Color("29271f"))
 theme.set_color("font_disabled_color","JeffPrimaryButton",palette[4])
 var focus := box(Color.TRANSPARENT,Color("704900") if selected=="paper" else Color("fff4cf"),scale)
 focus.draw_center=false;focus.set_border_width_all(maxi(2,roundi(2*scale)))
 theme.set_stylebox("focus","JeffPrimaryButton",focus)
 theme.set_stylebox("selected","ItemList",box(palette[1].lerp(palette[2],0.25),palette[2],scale))
 theme.set_stylebox("selected_focus","ItemList",theme.get_stylebox("selected","ItemList"))
 theme.set_color("font_placeholder_color","LineEdit",palette[4])
 theme.set_color("caret_color","LineEdit",palette[3])
 theme.set_icon("arrow","OptionButton",icons.texture("down"))
 theme.set_constant("modulate_arrow","OptionButton",0)
 for state in ["unchecked","unchecked_disabled","radio_unchecked","radio_unchecked_disabled"]:theme.set_icon(state,"CheckBox",icons.texture("unchecked",palette[4]))
 for state in ["checked","checked_disabled","radio_checked","radio_checked_disabled"]:theme.set_icon(state,"CheckBox",icons.texture("apply",palette[2]))
 theme.set_color("selection_color","LineEdit",palette[2]*Color(1,1,1,0.3))
func box(background: Color, border: Color, scale: float) -> StyleBoxFlat:
 var result := StyleBoxFlat.new();result.bg_color=background;result.border_color=border
 result.set_border_width_all(maxi(1,roundi(scale)));result.set_corner_radius_all(roundi(4*scale))
 result.content_margin_left=8*scale;result.content_margin_right=8*scale;result.content_margin_top=5*scale;result.content_margin_bottom=5*scale
 return result
func node_added(node: Node) -> void:
 decorate_later.call_deferred(weakref(node))
func decorate_later(reference: WeakRef) -> void:
 var node: Node=reference.get_ref()
 if not is_instance_valid(node):return
 for root in roots:
  if is_instance_valid(root) and (root==node or root.is_ancestor_of(node)):
   apply_tree(node);return
func apply_tree(node: Node) -> void:
 # Native dialogs depend on the full EditorIcons theme and own their buttons.
 # This ancestor guard also covers controls added lazily after the dialog opens.
 var owner: Node=node
 while owner:
  if owner is EditorFileDialog or owner is FileDialog:
   if owner==node:owner.theme=EditorInterface.get_editor_theme()
   return
  owner=owner.get_parent()
 if node is Control or node is Window:node.theme=theme
 if node is Control:node.queue_redraw()
 if node is Button and not node is OptionButton and not node is CheckBox and not node is CheckButton:
  var key: String=str(node.get_meta("jeff_icon",icons.key_for(node.text)))
  node.set_meta("jeff_icon",key);node.icon=icons.texture(key,palette[2]);node.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
  node.expand_icon=true;node.add_theme_constant_override("icon_max_width",roundi(16*EditorInterface.get_editor_scale()))
  node.add_theme_constant_override("h_separation",roundi(6*EditorInterface.get_editor_scale()))
  node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  node.add_theme_color_override("icon_disabled_color",Color(1,1,1,0.4))
  node.clip_text=true
 if node is OptionButton:node.get_popup().theme=theme
 for child in node.get_children():apply_tree(child)
func unregister(node: Node) -> void:
 if is_instance_valid(node) and node is Control:
  if node.draw.is_connected(paint_surface.bind(node)):node.draw.disconnect(paint_surface.bind(node))
  if node.resized.is_connected(node.queue_redraw):node.resized.disconnect(node.queue_redraw)
 roots.erase(node)
func dispose() -> void:
 if controller.get_tree().node_added.is_connected(node_added):controller.get_tree().node_added.disconnect(node_added)
 for root in roots.duplicate():unregister(root)

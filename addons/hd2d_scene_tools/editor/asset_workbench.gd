@tool
extends PanelContainer
var controller
var dock: EditorDock
var mode := 0
var buttons: Array[Button]=[]
var content: VBoxContainer
var brazier: Control
var title: Label
var buildings
func setup(plugin) -> void:
 controller=plugin;name="JeffAssetWorkbench";custom_minimum_size=Vector2(520,270)*EditorInterface.get_editor_scale()
 size_flags_vertical=Control.SIZE_EXPAND_FILL
 theme_type_variation="JeffFrame"
 var body := VBoxContainer.new();add_child(body)
 var header := HBoxContainer.new();header.name="WorkbenchHeader";body.add_child(header)
 header.add_theme_constant_override("separation",roundi(8*EditorInterface.get_editor_scale()))
 brazier=preload("animated_icon.gd").new();brazier.name="WorkbenchBrazier";header.add_child(brazier);brazier.setup("brand_brazier",64)
 var heading := VBoxContainer.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.size_flags_vertical=Control.SIZE_SHRINK_CENTER;header.add_child(heading)
 title=Label.new();heading.add_child(title);controller.i18n.text(title,"素材工作台")
 title.add_theme_font_size_override("font_size",roundi(16*EditorInterface.get_editor_scale()))
 var navigation := HBoxContainer.new();heading.add_child(navigation)
 var group := ButtonGroup.new();group.allow_unpress=false
 for index in range(4):
  var button: Button=controller.ui.button(navigation,["预设素材","我的素材","地表纹理","内置建筑"][index],func():select_mode(index))
  button.toggle_mode=true;button.button_group=group;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.append(button)
 content=VBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(content)
 controller.ui.preset_panel.reparent(content,false)
 controller.ui.preset_panel.preview.custom_minimum_size=Vector2(250,140)*EditorInterface.get_editor_scale()
 controller.ui.terrain_panel.picker.reparent(content,false)
 controller.ui.preset_panel.source_filter.hide()
 buildings=preload("building_workbench.gd").new();content.add_child(buildings);buildings.setup(controller);buildings.hide()
 dock=EditorDock.new();dock.title=controller.i18n.t("Jeff Studio 素材")
 dock.layout_key="jeff_studio_assets";dock.default_slot=EditorDock.DOCK_SLOT_BOTTOM
 dock.available_layouts=EditorDock.DOCK_LAYOUT_HORIZONTAL|EditorDock.DOCK_LAYOUT_FLOATING
 dock.add_child(self);controller.add_dock(dock)
 controller.i18n.bind(dock,"title","Jeff Studio 素材")
 controller.skin.register(self);controller.i18n.watch(self)
 controller.ui.preset_panel.hide();controller.ui.terrain_panel.picker.hide()
 buttons[0].set_pressed_no_signal(true)
 visibility_changed.connect(visibility_updated)
func select_mode(index: int) -> void:
 var picker=controller.ui.terrain_panel.picker
 if index!=2 and picker.receiver.is_valid():picker.cancel_selection()
 mode=index
 for i in range(4):buttons[i].set_pressed_no_signal(i==index)
 controller.ui.preset_panel.visible=index<2
 buildings.visible=index==3
 picker.visible=index==2
 if index==2:
  if not picker.receiver.is_valid():picker.browse_catalog()
 elif index<2:
  controller.ui.preset_panel.source_filter.select(index)
  if controller.ui.preset_panel.records.is_empty():controller.ui.preset_panel.reload_catalog()
  else:controller.ui.preset_panel._filter()
func open_current() -> void:
 select_mode(mode);dock.make_visible()
func open_objects(source: int=-1) -> void:
 select_mode(source if source>=0 else (mode if mode<2 else 0));dock.make_visible()
 controller.ui.preset_panel.refresh_impact()
func open_terrain() -> void:
 mode=2
 for i in range(4):buttons[i].set_pressed_no_signal(i==2)
 buildings.hide();controller.ui.preset_panel.hide();controller.ui.terrain_panel.picker.show();dock.make_visible()
func visibility_updated() -> void:
 if not is_visible_in_tree():
  controller.ui.preset_panel.invalidate_selection(false)
  controller.ui.terrain_panel.picker.cancel_selection()
 elif not controller.ui.preset_panel.visible and not controller.ui.terrain_panel.picker.visible and not buildings.visible:select_mode(mode)
func scene_changed() -> void:
 buildings.context_changed()
 controller.ui.terrain_panel.context_changed()
 controller.ui.preset_panel.invalidate_selection(true)
 controller.ui.terrain_panel.picker.cancel_selection()
func refresh_catalogs() -> void:
 if is_visible_in_tree():
  if mode==2:controller.ui.terrain_panel.picker.reload()
  elif mode<2:controller.ui.preset_panel.reload_catalog()
 else:
  controller.ui.preset_panel.records.clear()
  controller.ui.terrain_panel.library.catalog.clear()
func dispose() -> void:
 buildings.cancel()
 controller.ui.terrain_panel.picker.cancel_selection()
 controller.remove_dock(dock);dock.queue_free()

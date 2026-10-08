@tool
extends PanelContainer
var controller
var brazier: Control
var title: Label
var language: OptionButton
var theme_picker: OptionButton
var text_plates: Array[PanelContainer]=[]
func setup(plugin) -> void:
 controller=plugin;name="JeffStudioBrand";clip_contents=true
 var margin := MarginContainer.new();add_child(margin)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,roundi(8*EditorInterface.get_editor_scale()))
 var layout := HBoxContainer.new();margin.add_child(layout)
 layout.add_theme_constant_override("separation",roundi(8*EditorInterface.get_editor_scale()))
 brazier=preload("animated_icon.gd").new();brazier.name="BrandBrazier";layout.add_child(brazier);brazier.setup("brand_brazier",64)
 var body := VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_SHRINK_CENTER;layout.add_child(body)
 var row := HBoxContainer.new();body.add_child(row)
 title=Label.new();title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.add_theme_font_size_override("font_size",roundi(17*EditorInterface.get_editor_scale()))
 var title_plate := PanelContainer.new();title_plate.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title_plate);title_plate.add_child(title);text_plates.append(title_plate)
 var version := Label.new();var config := ConfigFile.new();config.load("res://addons/hd2d_scene_tools/plugin.cfg")
 version.text=str(config.get_value("plugin","version",""))
 var version_plate := PanelContainer.new();row.add_child(version_plate);version_plate.add_child(version);text_plates.append(version_plate)
 var settings := HBoxContainer.new();body.add_child(settings)
 language=OptionButton.new();language.name="LanguagePicker";language.add_item("中文");language.add_item("English");settings.add_child(language)
 language.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 language.item_selected.connect(func(index):controller.i18n.set_language("zh" if index==0 else "en"))
 theme_picker=OptionButton.new();theme_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;settings.add_child(theme_picker)
 theme_picker.item_selected.connect(func(index):controller.skin.set_theme(["jade","obsidian","paper"][index]))
 controller.i18n.changed.connect(refresh);controller.skin.changed.connect(restyle)
 tree_exiting.connect(func():
  if controller.i18n.changed.is_connected(refresh):controller.i18n.changed.disconnect(refresh)
  if controller.skin.changed.is_connected(restyle):controller.skin.changed.disconnect(restyle))
 refresh();restyle()
func refresh() -> void:
 controller.i18n.text(title,"Jeff Studio 场景")
 language.select(0 if controller.i18n.language=="zh" else 1)
 controller.i18n.bind(language,"tooltip_text","语言")
 theme_picker.clear()
 for value in ["青竹墨绿","曜石深灰","暖纸浅色"]:theme_picker.add_item(controller.i18n.t(value))
 theme_picker.select(["jade","obsidian","paper"].find(controller.skin.selected))
 controller.i18n.bind(theme_picker,"tooltip_text","主题")
func restyle() -> void:
 var palette: Array=controller.skin.palette
 var style: StyleBoxFlat=controller.skin.box(palette[0],palette[2],EditorInterface.get_editor_scale())
 style.set_border_width_all(maxi(1,roundi(2*EditorInterface.get_editor_scale())))
 add_theme_stylebox_override("panel",style)
 for plate in text_plates:
  var stable := StyleBoxFlat.new();stable.bg_color=palette[0];plate.add_theme_stylebox_override("panel",stable)


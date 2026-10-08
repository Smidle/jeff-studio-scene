@tool
extends VBoxContainer
var controller
var library
var source_picker: OptionButton
var kind_picker: OptionButton
var theme_picker: OptionButton
var search: LineEdit
var items: ItemList
var info: Label
var heading: Label
var preview
var page_label: Label
var rows: Array=[]
var page := 0
var generation := 0
var prepared := {}
var receiver: Callable
var target_layer := -1
var locked_scheme := false
const PAGE_SIZE := 12

func _init() -> void:
	visible=false

func setup(plugin, catalog) -> void:
	controller=plugin; library=catalog
	name="TerrainAssetBrowser";size_flags_vertical=Control.SIZE_EXPAND_FILL
	visibility_changed.connect(func():
		if not is_visible_in_tree():cancel_selection())
	var root: VBoxContainer=self
	heading=controller.ui.label(root,"")
	var sources := HBoxContainer.new();root.add_child(sources)
	var source_label: Label=controller.ui.label(sources,"地表来源")
	source_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	source_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	source_picker=OptionButton.new();source_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sources.add_child(source_picker)
	source_picker.add_item("内置轻量 · 512×512");source_picker.add_item("共享原图 / 扩展 · 1024×1024")
	source_picker.item_selected.connect(func(index):library.source_mode=index;reload())
	var filters := HBoxContainer.new(); root.add_child(filters)
	kind_picker=OptionButton.new(); kind_picker.add_item("单张纹理"); kind_picker.add_item("整套方案"); filters.add_child(kind_picker)
	theme_picker=OptionButton.new(); filters.add_child(theme_picker)
	search=LineEdit.new(); search.placeholder_text="搜索地表纹理…"; search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; filters.add_child(search)
	var split := HSplitContainer.new(); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_child(split)
	items=ItemList.new(); items.custom_minimum_size=Vector2(300,140); items.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	items.max_columns=0; items.fixed_column_width=130; items.fixed_icon_size=Vector2i(100,100); items.icon_mode=ItemList.ICON_MODE_TOP
	items.max_text_lines=2; split.add_child(items)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size.x=300*EditorInterface.get_editor_scale();scroll.size_flags_horizontal=Control.SIZE_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;split.add_child(scroll)
	var right := VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(right)
	preview=preload("terrain_preview.gd").new(); right.add_child(preview)
	preview.viewport.get_parent().custom_minimum_size=Vector2(250,140)
	info=controller.ui.label(right,"选择一项查看纹理与重复铺贴。")

	var pagination := HBoxContainer.new(); root.add_child(pagination)
	controller.ui.button(pagination,"上一页",func(): page=maxi(0,page-1); draw_page())
	page_label=controller.ui.label(pagination,"")
	page_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	page_label.custom_minimum_size.x=160
	controller.ui.button(pagination,"下一页",func(): page=mini(maxi(0,(rows.size()-1)/PAGE_SIZE),page+1); draw_page())
	kind_picker.item_selected.connect(func(_i): filter_rows())
	theme_picker.item_selected.connect(func(_i): filter_rows())
	search.text_changed.connect(func(_s): filter_rows())
	items.item_selected.connect(select_item)
	controller.shared_library.location_changed.connect(func():
		if is_visible_in_tree():reload()
		else:library.catalog.clear())
	controller.i18n.changed.connect(func(): if visible: reload())

func open_picker(all_layers: bool, layer: int, callback: Callable) -> void:
	cancel_selection()
	# Dock visibility transitions may cancel an old selection; bind the new target afterward.
	controller.workbench.open_terrain()
	receiver=callback;target_layer=layer;locked_scheme=layer==-2;kind_picker.disabled=locked_scheme;kind_picker.select(1 if all_layers else 0)
	controller.i18n.text(heading,"为新地图选择整套地表" if layer==-2 else ("选择整套地表预设" if all_layers else "正在选择第 %d 层纹理"%(layer+1)))
	search.clear();reload()

func reload() -> void:
	generation+=1; prepared={}
	var data: Dictionary=library.read_catalog()
	theme_picker.clear(); theme_picker.add_item(controller.i18n.t("全部场景")); theme_picker.set_item_metadata(0,"")
	for scheme in data.get("schemes",[]):
		theme_picker.add_item(library.title(scheme)); theme_picker.set_item_metadata(theme_picker.item_count-1,scheme.id)
	filter_rows()
	if not library.error.is_empty(): controller.i18n.text(info,library.error)

func filter_rows() -> void:
	rows=[]; page=0
	var theme_id: String=str(theme_picker.get_item_metadata(theme_picker.selected)) if theme_picker.selected>=0 else ""
	for row in library.catalog.get("schemes" if kind_picker.selected==1 else "textures",[]):
		if not theme_id.is_empty():
			var matches := str(row.get("theme",row.id))==theme_id
			if kind_picker.selected==0:
				for scheme in library.catalog.get("schemes",[]):
					if scheme.id==theme_id and scheme.layers.has(row.id): matches=true
			if not matches: continue
		if not search.text.strip_edges().is_empty() and not (str(row)+library.title(row)).to_lower().contains(search.text.strip_edges().to_lower()): continue
		rows.append(row)
	draw_page()

func draw_page() -> void:
	set_loading(false)
	generation+=1; prepared={}; items.clear()
	preview.hide()
	controller.i18n.text(info,"选择一项查看纹理与重复铺贴。")
	for row in rows.slice(page*PAGE_SIZE,(page+1)*PAGE_SIZE):
		var icon: Texture2D=library.thumbnail(row)
		items.add_item(library.title(row),icon)
	controller.i18n.text(page_label,"第 %d / %d 页 · %d 项"%[page+1,maxi(1,ceili(rows.size()/float(PAGE_SIZE))),rows.size()])

func select_item(index: int) -> void:
	generation+=1; var token := generation; prepared={}
	set_loading(true)
	preview.hide()
	var row: Dictionary=rows[page*PAGE_SIZE+index]
	controller.i18n.text(info,"正在准备选中的地表纹理…")
	var result: Dictionary=await library.prepare(row,func(): return is_instance_valid(self) and is_visible_in_tree() and generation==token)
	if generation!=token or not is_visible_in_tree(): return
	set_loading(false)
	if result.is_empty(): controller.i18n.text(info,library.error); return
	prepared=result
	preview.show()
	var textures: Array=result.textures.duplicate()
	preview.display(textures,PackedColorArray(),float(result.texture_scale))
	controller.i18n.text(info,library.title(row)+"\n"+controller.i18n.t("原图 · 3×3 重复铺贴 · 地表混合预览"))
	use_selection()

func use_selection() -> void:
	if prepared.is_empty() or not receiver.is_valid():return
	receiver.call(prepared.duplicate())
	controller.i18n.text(info,"已选入草稿；在右侧底部点击应用。")

func set_loading(on: bool) -> void:
	if target_layer==-2 and receiver.is_valid():
		controller.ui.terrain_panel.creation_loading=on
		controller.ui.terrain_panel.guide.refresh()

func cancel_selection() -> void:
	set_loading(false)
	generation+=1;prepared={};receiver=Callable();target_layer=-1;locked_scheme=false
	if is_instance_valid(kind_picker):kind_picker.disabled=false
	if is_instance_valid(heading):controller.i18n.text(heading,"地表纹理")
	if is_instance_valid(preview):preview.hide()
	if is_instance_valid(info):controller.i18n.text(info,"选择一项查看纹理与重复铺贴。")

func browse_catalog() -> void:
	var panel=controller.ui.terrain_panel
	if is_instance_valid(panel.target):
		panel.open_presets(panel.active_layer)
	else:
		controller.i18n.text(heading,"浏览地表纹理；新建或选择地形后可使用。")
		kind_picker.select(0);reload()

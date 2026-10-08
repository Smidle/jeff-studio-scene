@tool
extends VBoxContainer
const CATALOG := "res://local_study/preset3d/catalog.json"
const PAGE_SIZE := 48
var controller
var actions
var source_filter: OptionButton
var selection_generation := 0
var search: LineEdit
var series: OptionButton
var category: OptionButton
var models: ItemList
var skins: ItemList
var preview
var info: Label
var impact: Label
var pagination: Label
var scope: OptionButton
var apply_button: Button
var place_button: Button
var cancel_prepare_button: Button
var retry_prepare_button: Button
var loading := false
var records: Array = []
var filtered: Array = []
var page_index := 0
var selected_asset: HD2DAsset
var selected_record: Dictionary = {}
var skin_id: StringName = &""
var skin_ids: Array[StringName] = []
var ready_ui := false

func setup(plugin) -> void:
	controller=plugin
	actions=preload("preset_actions.gd").new(); actions.controller=plugin
	name="ObjectAssetBrowser";size_flags_vertical=Control.SIZE_EXPAND_FILL;hide()
	var body: VBoxContainer=self
	var location := HBoxContainer.new(); body.add_child(location);location.hide()
	source_filter=OptionButton.new(); source_filter.add_item("预设素材"); source_filter.add_item("我的素材"); location.add_child(source_filter)
	source_filter.item_selected.connect(func(_index): _filter())
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			if loading: _cancel_prepare()
			else: selection_generation+=1)
	var filters := HBoxContainer.new(); body.add_child(filters)
	search=LineEdit.new(); search.placeholder_text="搜索素材…"; search.size_flags_horizontal=Control.SIZE_EXPAND_FILL; filters.add_child(search)
	series=OptionButton.new(); series.custom_minimum_size.x=180; filters.add_child(series)
	category=OptionButton.new(); category.custom_minimum_size.x=120; filters.add_child(category)
	var columns := HSplitContainer.new(); columns.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_child(columns)
	var left := VBoxContainer.new(); left.custom_minimum_size.x=300;left.size_flags_horizontal=Control.SIZE_EXPAND_FILL; columns.add_child(left)
	models=ItemList.new(); models.custom_minimum_size=Vector2(300,160); models.size_flags_vertical=Control.SIZE_EXPAND_FILL
	models.icon_mode=ItemList.ICON_MODE_TOP; models.fixed_icon_size=Vector2i(80,80); models.fixed_column_width=110; models.max_columns=0
	left.add_child(models)
	var page_row := HBoxContainer.new(); left.add_child(page_row)
	_button(page_row,"上一页",func(): page_index=maxi(0,page_index-1); _render_page())
	pagination=_label(page_row,""); pagination.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(page_row,"下一页",func(): page_index=mini(maxi(0,ceili(float(filtered.size())/PAGE_SIZE)-1),page_index+1); _render_page())
	var details := ScrollContainer.new();details.custom_minimum_size.x=300*EditorInterface.get_editor_scale();details.size_flags_horizontal=Control.SIZE_FILL;details.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(details)
	var right := VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_child(right)
	preview=preload("model_preview.gd").new(); right.add_child(preview);preview.custom_minimum_size=Vector2(240,140)
	_label(right,"按住鼠标左键旋转模型")
	info=_label(right,"选择素材，再选择外观。")
	var preparation := HBoxContainer.new(); right.add_child(preparation)
	cancel_prepare_button=_button(preparation,"取消准备",_cancel_prepare); cancel_prepare_button.hide()
	retry_prepare_button=_button(preparation,"重试准备",func():
		if not selected_record.is_empty(): await _choose_record(selected_record))
	retry_prepare_button.hide()
	skins=ItemList.new(); skins.custom_minimum_size.y=115; skins.max_columns=4; skins.fixed_column_width=80
	skins.icon_mode=ItemList.ICON_MODE_TOP; skins.fixed_icon_size=Vector2i(64,64); right.add_child(skins)
	place_button=_button(left,"摆放选中素材",_place); place_button.disabled=true
	place_button.theme_type_variation="JeffPrimaryButton"
	place_button.custom_minimum_size.y=34*EditorInterface.get_editor_scale()
	_label(right,"应用范围")
	scope=OptionButton.new(); scope.add_item("选中物件"); scope.add_item("当前场景全部兼容物件"); right.add_child(scope)
	impact=_label(right,"")
	apply_button=_button(right,"应用皮肤",_apply); apply_button.disabled=true
	_button(right,"恢复原始外观",_restore_original)
	_label(body,"选择皮肤只改变预览与后续摆放；应用皮肤后保存场景。")
	search.text_changed.connect(func(_text): _filter())
	series.item_selected.connect(func(_index): _filter())
	category.item_selected.connect(func(_index): _filter())
	models.item_selected.connect(_choose_model)
	skins.item_selected.connect(_choose_skin)
	scope.item_selected.connect(func(_index): refresh_impact())
	controller.i18n.changed.connect(_translate_data)
	EditorInterface.get_selection().selection_changed.connect(refresh_impact)
	ready_ui=true

func _label(parent: Node, value: String) -> Label:
	var label := Label.new(); label.text=value; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label

func _button(parent: Node, value: String, callback: Callable) -> Button:
	var button := Button.new(); button.text=value; button.pressed.connect(callback); parent.add_child(button); return button

func open_catalog() -> void:
	if records.is_empty(): reload_catalog()
	if not records.is_empty() and series.item_count==0: _populate_filters(); _filter()
	scope.select(0)
	_select_context_prop()
	refresh_impact()
	controller.workbench.open_objects(source_filter.selected)

func reload_catalog() -> void:
	if loading: _cancel_prepare()
	else: selection_generation+=1
	selected_asset=null; selected_record={}
	preview.show_asset(null,&""); skins.clear(); skin_ids.clear()
	place_button.disabled=true; apply_button.disabled=true; retry_prepare_button.hide()
	controller.i18n.text(info,"选择素材，再选择外观。")
	var index: Dictionary=controller.shared_library.read_index()
	records=index.get("entries",[])
	if records.is_empty() and FileAccess.file_exists(CATALOG):
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		if data is Dictionary: records=data.get("assets",[])
	if records.is_empty(): controller.i18n.text(info,"共享库为空或未连接。请检查共享库位置，或导入到“我的素材”。")
	_populate_filters(); _filter()

func _select_context_prop() -> void:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.size()!=1: return
	var node: Node=selection[0]
	while node and not node is HD2DProp: node=node.get_parent()
	if not node is HD2DProp or node.asset==null or node.asset.asset_id==&"": return
	for record in records:
		if str(record.id)!=str(node.asset.library_entry_id) and str(record.get("model_id",record.id))!=str(node.asset.asset_id): continue
		source_filter.select(1 if record.get("source", "preset")=="user" else 0)
		search.text=str(record.id); series.select(0); category.select(0); _filter()
		for index in models.item_count:
			if str(models.get_item_metadata(index).id)!=str(record.id): continue
			models.select(index); await _choose_model(index)
			if selected_asset and selected_asset.supports_skin(node.skin_id):
				skin_id=node.skin_id; _render_skins(); _refresh_preview()
			return

func _populate_filters() -> void:
	series.clear(); category.clear()
	series.add_item(controller.i18n.t("全部系列")); series.set_item_metadata(0,"")
	category.add_item(controller.i18n.t("全部分类")); category.set_item_metadata(0,"")
	var families: Dictionary={}; var categories: Dictionary={}
	for record in records:
		families[str(record.series)]=str(record.get("series_title",record.series))
		categories[str(record.category)]=true
	for key in families:
		series.add_item(controller.i18n.t(families[key])); series.set_item_metadata(series.item_count-1,key)
	for key in categories:
		category.add_item(controller.i18n.t(key)); category.set_item_metadata(category.item_count-1,key)

func _filter() -> void:
	filtered.clear(); page_index=0
	var text := search.text.strip_edges().to_lower()
	for record in records:
		if (record.get("source","preset")=="user")!=(source_filter.selected==1): continue
		if series.selected>0 and record.series!=series.get_item_metadata(series.selected): continue
		if category.selected>0 and record.category!=category.get_item_metadata(category.selected): continue
		if not text.is_empty() and not (str(record.title)+" "+str(record.id)+" "+str(record.series)).to_lower().contains(text): continue
		filtered.append(record)
	_render_page()

func _render_page() -> void:
	models.clear()
	for index in range(page_index*PAGE_SIZE,mini(filtered.size(),(page_index+1)*PAGE_SIZE)):
		var record: Dictionary=filtered[index]
		var texture: Texture2D=controller.shared_library.thumbnail(record)
		models.add_item(str(record.title),texture)
		models.set_item_metadata(models.item_count-1,record)
		models.set_item_tooltip(models.item_count-1,str(record.title)+"\n"+str(record.id))
	controller.i18n.text(pagination,"第 %d / %d 页 · %d 项"%[page_index+1,maxi(1,ceili(float(filtered.size())/PAGE_SIZE)),filtered.size()])

func _choose_model(index: int) -> void:
	await _choose_record(models.get_item_metadata(index))

func _cancel_prepare() -> void:
	selection_generation+=1; loading=false
	cancel_prepare_button.hide(); retry_prepare_button.visible=not selected_record.is_empty()
	controller.i18n.text(info,"已取消准备。可以选择其他素材，或点击重试准备。")

func _choose_record(value: Dictionary) -> void:
	selection_generation+=1
	var generation := selection_generation
	selected_record=value
	var record := selected_record.duplicate(true)
	selected_asset=null; place_button.disabled=true; apply_button.disabled=true
	preview.show_asset(null,&""); skins.clear(); skin_ids.clear()
	loading=true; cancel_prepare_button.show(); retry_prepare_button.hide()
	controller.i18n.text(info,"正在准备所选素材及依赖…")
	var asset: HD2DAsset=await controller.shared_library.prepare(record,func(): return generation==selection_generation,func(status):
		if generation==selection_generation: controller.i18n.text(info,str(record.title)+"\n"+status))
	if generation!=selection_generation: return
	loading=false; cancel_prepare_button.hide()
	selected_asset=asset
	if selected_asset==null:
		retry_prepare_button.show()
		preview.show_asset(null,&""); skins.clear(); skin_ids.clear()
		controller.i18n.text(info,controller.shared_library.error if not controller.shared_library.error.is_empty() else "模型依赖缺失，无法使用。"); place_button.disabled=true; apply_button.disabled=true; return
	controller.i18n.text(info,selected_asset.title+"\n"+str(selected_record.get("construction","实体")))
	skin_id=&""; _render_skins(); _refresh_preview()
	place_button.disabled=false

func _render_skins() -> void:
	skins.clear(); skin_ids.clear()
	if selected_asset==null: return
	skin_ids.append(&"")
	for skin in selected_asset.skins:
		if skin and selected_asset.supports_skin(skin.skin_id): skin_ids.append(skin.skin_id)
	for id in skin_ids:
		var label := "原始" if id==&"" else selected_asset.skin_for(id).title
		var texture: Texture2D=controller.shared_library.thumbnail(selected_record,"original" if id==&"" else str(id))
		skins.add_item(controller.i18n.t(label),texture)
		if id==skin_id: skins.select(skins.item_count-1)

func _choose_skin(index: int) -> void:
	skin_id=skin_ids[index]; _refresh_preview()

func _refresh_preview() -> void:
	preview.show_asset(selected_asset,skin_id)
	refresh_impact()

func refresh_impact() -> void:
	if not ready_ui: return
	var batch: Dictionary=actions.targets(skin_id,scope.selected==1)
	var skipped := PackedStringArray()
	for index in mini(8,batch.skipped.size()): skipped.append(str(batch.skipped[index]))
	controller.i18n.text(impact,"将修改 %d 项；不兼容 %d 项。"%[batch.count,batch.skipped.size()]+("\n"+", ".join(skipped) if not skipped.is_empty() else ""))
	impact.tooltip_text="\n".join(PackedStringArray(batch.skipped))
	apply_button.disabled=batch.count==0 or selected_asset==null

func _place() -> void:
	if selected_asset==null or not controller.require_stage(): return
	controller.preset_brush_asset=selected_asset; controller.preset_brush_skin=skin_id
	controller._clear_cursor(); controller.set_tool("place")

func _apply() -> void:
	if selected_asset==null: return
	actions.apply(skin_id,scope.selected==1); refresh_impact()

func _restore_original() -> void:
	skin_id=&""; _render_skins()
	if selected_asset: _refresh_preview()
	else: refresh_impact()
	# Restoring is a staged choice too; the visible Apply button commits it.

func _translate_data() -> void:
	var series_key: Variant=series.get_item_metadata(series.selected) if series.selected>=0 else ""
	var category_key: Variant=category.get_item_metadata(category.selected) if category.selected>=0 else ""
	_populate_filters()
	for index in series.item_count:
		if series.get_item_metadata(index)==series_key: series.select(index)
	for index in category.item_count:
		if category.get_item_metadata(index)==category_key: category.select(index)
	_render_page(); _render_skins(); refresh_impact()

func invalidate_selection(clear: bool=true) -> void:
	selection_generation+=1;loading=false
	cancel_prepare_button.hide()
	if clear:
		selected_asset=null;selected_record={};place_button.disabled=true;apply_button.disabled=true
		preview.show_asset(null,&"");skins.clear();skin_ids.clear()
	else:retry_prepare_button.visible=selected_asset==null and not selected_record.is_empty()

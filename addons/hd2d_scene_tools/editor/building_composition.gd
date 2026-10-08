@tool
extends RefCounted
const Catalog=preload("building_catalog.gd")
const Cache=preload("building_cache.gd")
var panel
var root: VBoxContainer
var fold
var selected: Array=Catalog.DEFAULT_TYPES.duplicate()
var weights: Dictionary=Catalog.DEFAULT_WEIGHTS.duplicate()
var menus := {}
var menu_ids := {}
var last_key := ""
var sequence: Array=[]
var error := ""

func setup(owner_panel, parent: VBoxContainer) -> void:
	panel=owner_panel;root=VBoxContainer.new();parent.add_child(root)
	fold=preload("fold_section.gd").new();root.add_child(fold)
	fold.setup("generation.types","参与生成的建筑类型",panel.controller.i18n,false)
	for group in weights:
		var row := VBoxContainer.new();fold.content.add_child(row)
		panel.ui.label(row,{"residential":"居住","hospitality":"食宿","commerce":"商业","craft":"手工业","public":"公共建筑","agriculture":"农业与仓储"}[group])
		var menu := MenuButton.new();menu.text="选择类型…";menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(menu)
		panel.controller.i18n.bind(menu,"text","选择类型…")
		menus[group]=menu;var ids: Array=[]
		for item in Catalog.types():
			if item.town_group==group: ids.append(item.id)
		menu_ids[group]=ids;menu.get_popup().hide_on_checkable_item_selection=false
		menu.get_popup().id_pressed.connect(func(index):
			var id: String=menu_ids[group][index]
			if id in selected: selected.erase(id)
			else: selected.append(id)
			if group=="agriculture": weights[group]=10.0 if menu_ids[group].any(func(t):return t in selected) else 0.0
			refresh_names();panel.invalidate())
	panel.controller.i18n.changed.connect(refresh_names);refresh_names()

func refresh_names() -> void:
	var style: String=panel.loaded_style.trim_prefix("native-")
	if style not in Catalog.STYLES: style="jiangnan"
	for group in menus:
		var popup: PopupMenu=menus[group].get_popup();popup.clear()
		for i in menu_ids[group].size():
			var id: String=menu_ids[group][i]
			popup.add_check_item(Catalog.title(id,style,panel.controller.i18n.language),i);popup.set_item_checked(i,id in selected)
	fold.set_activity(("已选 %d 种" if panel.controller.i18n.language=="zh" else "%d types selected")%selected.size())

func reset() -> void:
	selected=Catalog.DEFAULT_TYPES.duplicate();weights=Catalog.DEFAULT_WEIGHTS.duplicate();last_key="";refresh_names()

func restore(options: Dictionary) -> void:
	selected=options.get("building_types",Catalog.DEFAULT_TYPES).duplicate()
	weights=Catalog.DEFAULT_WEIGHTS.duplicate();weights.merge(options.get("building_weights",{}),true)
	sequence=options.get("palette_sequence",[]).duplicate();last_key="";refresh_names()

func signature() -> String:
	var ui=panel.ui
	return var_to_str([selected,weights,ui.value("village_count"),ui.value("village_seed"),ui.controls.village_center_type.selected,ui.controls.village_layout.selected,panel.loaded_style,panel.native_generator_version,ui.value("village_shape_seed"),ui.value("village_detail_seed"),ui.value("village_appearance_seed"),ui.controls.village_appearance.selected])

func remember_loaded() -> void:
	last_key=signature();error=""

func prepare(current: Callable) -> bool:
	var ui=panel.ui;var key := signature()
	if key==last_key: return error.is_empty()
	error=""
	var centered: bool=ui.controls.village_layout.selected==2 and ui.controls.village_center_type.selected==2
	var allocation := Catalog.allocate(int(ui.value("village_count")),selected,weights,int(ui.value("village_seed")),centered)
	if not str(allocation.error).is_empty(): error=allocation.error;return false
	var next_palette: Array=[];var next_sequence: Array=[]
	for i in allocation.types.size():
		if not current.call(): return false
		var profile := Catalog.profile(allocation.types[i],panel.loaded_style.trim_prefix("native-"),int(ui.value("village_shape_seed"))+i*7919,int(ui.value("village_detail_seed"))+i*101,true,panel.native_generator_version)
		profile.preset_version=panel.native_preset_version;profile.appearance_seed=int(ui.value("village_appearance_seed"))
		var started := Time.get_ticks_usec()
		next_palette.append({"asset":Cache.obtain(profile),"skin":StringName(["","elegant","warm","weathered"][ui.controls.village_appearance.selected]),"front":0.0});next_sequence.append(i)
		panel.max_slice_ms=maxf(panel.max_slice_ms,(Time.get_ticks_usec()-started)/1000.0)
		panel.say("正在准备建筑 %d / %d…"%[i+1,allocation.types.size()])
		await ui.get_tree().process_frame
		if not current.call(): return false
	panel.palette=next_palette;sequence=next_sequence;last_key=key
	panel.refresh_list();refresh_names();return true

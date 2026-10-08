@tool
extends RefCounted
var controller
var dialog: Window
var search: LineEdit
var list: ItemList
var info: Label
var fields := {}
var records: Array=[]
var page := 0
var selected_id := ""
var original_transform := Transform3D.IDENTITY
var original_values := {}
var target: HD2DWorldMap

func setup(plugin) -> void:
 controller=plugin
 dialog=Window.new();dialog.visible=false;dialog.title="大地图布局与地点";dialog.size=Vector2i(850,640)
 controller.ui.add_child(dialog);dialog.close_requested.connect(dialog.hide)
 controller.i18n.bind(dialog,"title","大地图布局与地点")
 var columns := HBoxContainer.new();columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dialog.add_child(columns)
 var left := VBoxContainer.new();left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(left)
 search=LineEdit.new();search.placeholder_text="搜索模型名称或稳定标识…";controller.i18n.bind(search,"placeholder_text",search.placeholder_text);left.add_child(search)
 search.text_changed.connect(func(_text): page=0;filter_records())
 list=ItemList.new();list.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.custom_minimum_size=Vector2(440,440);left.add_child(list)
 list.item_selected.connect(select_record)
 var pages := HBoxContainer.new();left.add_child(pages)
 controller.ui.button(pages,"上一页",func(): page=maxi(0,page-1);show_page())
 controller.ui.button(pages,"下一页",func(): page=mini(maxi(0,(records.size()-1)/100),page+1);show_page())
 var right := VBoxContainer.new();right.custom_minimum_size.x=290;columns.add_child(right)
 info=controller.ui.label(right,"")
 for key in ["x","y","z","yaw","sx","sy","sz"]:
  controller.ui.label(right,{"x":"X / m","y":"Y / m","z":"Z / m","yaw":"Y / °","sx":"X 缩放","sy":"Y 缩放","sz":"Z 缩放"}[key])
  var field := SpinBox.new();field.min_value=-10000;field.max_value=10000;field.step=0.01;right.add_child(field);fields[key]=field
 controller.ui.button(right,"在素材页修改此物件参数",select_for_asset_edit)
 controller.ui.button(right,"应用此实例的布局修改",apply)
 controller.ui.button(right,"恢复此实例的原始布局",reset_record)
 controller.ui.label(right,"修改保存到地图数据中；区块卸载、重开和撤销不会丢失。")

func open() -> void:
 target=controller.stage.terrain() as HD2DWorldMap if is_instance_valid(controller.stage) else null
 if not target: controller.message("先创建并选中制作副本的舞台。");return
 page=0;filter_records();dialog.popup_centered()

func filter_records() -> void:
 records=[]
 if not is_instance_valid(target): return
 for record in target.world_data().placements:
  if search.text.is_empty() or str(record.model).containsn(search.text) or str(record.id).containsn(search.text): records.append(record)
 show_page()

func show_page() -> void:
 list.clear()
 for i in range(page*100,mini((page+1)*100,records.size())):
  list.add_item(str(records[i].model)+" · "+str(records[i].id));list.set_item_metadata(list.item_count-1,i)
 controller.i18n.text(info,"布局条目：%d · 第 %d 页"%[records.size(),page+1])

func select_record(index: int) -> void:
 var record: Dictionary=records[int(list.get_item_metadata(index))]
 selected_id=record.id
 var patch: Dictionary=target.world_data().object_overrides.get(selected_id,{})
 original_transform=patch.get("transform",HD2DWorldMapData.decode_transform(record.transform))
 var scale := original_transform.basis.get_scale()
 original_values={"x":original_transform.origin.x,"y":original_transform.origin.y,"z":original_transform.origin.z,"yaw":rad_to_deg(original_transform.basis.get_euler().y),"sx":scale.x,"sy":scale.y,"sz":scale.z}
 for key in fields: fields[key].set_value_no_signal(original_values[key])
 info.text=str(record.model)+"\n"+selected_id

func select_for_asset_edit() -> void:
 if not is_instance_valid(target) or selected_id.is_empty(): return
 target.prepare_at(target.to_global(original_transform.origin))
 for node in target.find_children("*","",true,false):
  if not node is HD2DProp: continue
  if str(node.get_meta("world_source_id",""))!=selected_id: continue
  var selection := EditorInterface.get_selection()
  selection.clear();selection.add_node(node)
  controller.select_context(node)
  controller.ui.select_page("assets")
  controller.ui.sections["assets.scene"].set_expanded(true)
  controller.ui.sections["assets.collision"].set_expanded(true)
  dialog.hide();return
 controller.message("此条目使用植被批绘制；请选同模型的关联物件进行批量参数应用。")

func apply() -> void:
 if not is_instance_valid(target) or selected_id.is_empty(): return
 var before: Dictionary=target.world_data().object_overrides.get(selected_id,{}).duplicate(true)
 var after := before.duplicate(true);var xform := original_transform
 xform.origin=Vector3(fields.x.value,fields.y.value,fields.z.value)
 if not is_equal_approx(fields.yaw.value,original_values.yaw): xform.basis=Basis(Vector3.UP,deg_to_rad(fields.yaw.value-original_values.yaw))*xform.basis
 for i in range(3):
  var key: String=["sx","sy","sz"][i]
  if not is_equal_approx(fields[key].value,original_values[key]) and absf(original_values[key])>0.00001:
   xform.basis[i]*=fields[key].value/original_values[key]
 after.transform=xform
 commit(before,after)

func reset_record() -> void:
 if not is_instance_valid(target) or selected_id.is_empty(): return
 var before: Dictionary=target.world_data().object_overrides.get(selected_id,{}).duplicate(true)
 var after := before.duplicate(true);after.erase("transform");after.erase("ground_offset")
 commit(before,after)

func commit(before: Dictionary, after: Dictionary) -> void:
 var undo: EditorUndoRedoManager=controller.get_undo_redo()
 undo.create_action(controller.i18n.t("修改大地图实例布局"),UndoRedo.MERGE_DISABLE,controller.stage)
 undo.add_do_method(self,"restore",target,selected_id,after);undo.add_undo_method(self,"restore",target,selected_id,before);undo.commit_action()
 if not list.get_selected_items().is_empty(): select_record(list.get_selected_items()[0])

func restore(map: HD2DWorldMap, id: String, patch: Dictionary) -> void:
 if not is_instance_valid(map): return
 if patch.is_empty(): map.world_data().object_overrides.erase(id)
 else: map.world_data().object_overrides[id]=patch.duplicate(true)
 map.rebuild();controller.external_dirty[map.data]=true;EditorInterface.mark_scene_as_unsaved()

func dispose() -> void:
 target=null;controller=null

@tool
extends RefCounted
const TITLES := ["1. 准备工程与素材","2. 创建制作副本","3. 恢复完整地形","4. 恢复九层地表","5. 恢复场景布局","6. 配置通行","7. 配置环境","8. 配置队伍与展示","9. 校准参考画面","10. 保存与完整检查"]
var controller
var ui
var library
var dialog: Window
var status: Label
var steps: ItemList
var variant: OptionButton
var destination: LineEdit
var recipe := "res://local_study/case06/prepared/recipe.json"
var replace_dialog: ConfirmationDialog
var chosen_step := 0
var summary: Label
var preparing := false
var spacing: SpinBox
var speed: SpinBox
var objects

func dispose() -> void:
 if objects: objects.dispose();objects=null
 library.cancel()
 if controller.i18n.changed.is_connected(refresh): controller.i18n.changed.disconnect(refresh)
 for connection in library.progress.get_connections(): library.progress.disconnect(connection.callable)
 library.controller=null
 library=null;ui=null;controller=null

func setup(plugin, root: VBoxContainer, dock_ui) -> void:
 controller=plugin;ui=dock_ui
 library=preload("world_library.gd").new();library.controller=controller
 var box: VBoxContainer=ui.section(root,"terrain.world","完整大地图 · 案例 6",false)
 summary=ui.label(box,"创建独立制作副本，按步骤恢复整张地图；原始预设保持只读。")
 ui.button(box,"创建大地图／分步骤重建…",open_dialog)
 ui.button(box,"整图总览与地点定位",controller.open_preview)
 objects=preload("world_objects.gd").new();objects.setup(controller)
 ui.button(box,"编辑原始布局…",objects.open)
 ui.label(box,"大地图保留原始九层地表。区块材质在下方“地表层与绘制”选择。")
 dialog=Window.new();dialog.visible=false;dialog.title="案例 6 · 分步骤重建";dialog.size=Vector2i(860,720);dialog.min_size=Vector2i(640,560)
 dialog.close_requested.connect(func(): library.cancel();dialog.hide());ui.add_child(dialog)
 controller.i18n.bind(dialog,"title","案例 6 · 分步骤重建")
 var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
 dialog.add_child(margin)
 var content := VBoxContainer.new();margin.add_child(content)
 ui.label(content,"从空白工程开始：准备素材 → 创建副本 → 依次执行步骤 → 保存。")
 var bar := HBoxContainer.new();content.add_child(bar)
 ui.button(bar,"检查／准备案例 6 素材",prepare)
 ui.button(bar,"设置素材库位置…",func(): controller.shared_library.choose_location())
 ui.button(bar,"取消准备",func(): library.cancel())
 status=ui.label(content,"")
 variant=OptionButton.new();content.add_child(variant)
 destination=LineEdit.new();destination.text="res://levels/Case06_Authoring";content.add_child(destination)
 destination.tooltip_text="res://…"
 bar=HBoxContainer.new();content.add_child(bar)
 ui.button(bar,"创建独立制作副本",func(): create(false))
 ui.button(bar,"完整重建为新副本",func(): create(true))
 steps=ItemList.new();steps.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(steps)
 bar=HBoxContainer.new();content.add_child(bar)
 ui.button(bar,"执行所选步骤",func(): execute(false))
 ui.button(bar,"检查当前结果",check_result)
 ui.button(bar,"重新生成此步骤…",confirm_replace)
 ui.button(bar,"保存场景与地图数据",save_current)
 replace_dialog=ConfirmationDialog.new();replace_dialog.title="重新生成此步骤";replace_dialog.dialog_text="此操作会替换该步骤的自定义修改。地形步骤替换高度，地表步骤替换九层权重和材质，布局步骤清空实例修改。可以撤销。"
 replace_dialog.confirmed.connect(func(): execute(true));ui.add_child(replace_dialog)
 controller.i18n.bind(replace_dialog,"title","重新生成此步骤");controller.i18n.bind(replace_dialog,"dialog_text",replace_dialog.dialog_text)
 library.progress.connect(func(done,total,text): controller.i18n.text(status,"准备地图素材 %d / %d"%[done,total]+"\n"+text))
 controller.i18n.changed.connect(refresh)

func open_dialog() -> void:
 library.read_catalog()
 variant.clear()
 var source: Dictionary={}
 if FileAccess.file_exists(recipe): source=JSON.parse_string(FileAccess.get_file_as_string(recipe))
 var choices: Array=library.catalog.get("variants",[])
 if choices.is_empty():
  for key in source.get("levels",{}):
   if source.levels[key].terrain: choices.append(key)
 for key in choices:
  variant.add_item(str(key));variant.set_item_metadata(variant.item_count-1,str(key))
  if key=="LV_World_S": variant.select(variant.item_count-1)
 controller.i18n.text(status,"地图配方已准备，可以创建独立制作副本。" if not source.is_empty() else library.error)
 refresh();dialog.popup_centered(Vector2i(860,720))

func prepare() -> void:
 if preparing: return
 preparing=true
 var prepared: String=await library.prepare()
 preparing=false
 if not is_instance_valid(controller) or library==null or not is_instance_valid(status): return
 if prepared.is_empty(): controller.i18n.text(status,library.error if not library.error.is_empty() else "已取消，可以继续准备。");return
 recipe=prepared;open_dialog()

func world() -> HD2DWorldMap:
 return controller.stage.terrain() as HD2DWorldMap if is_instance_valid(controller.stage) else null

func create(complete: bool) -> void:
 if not FileAccess.file_exists(recipe) or variant.selected<0:
  controller.i18n.text(status,"请先准备案例 6 素材。");return
 var folder := destination.text.strip_edges().trim_suffix("/")
 if not folder.begins_with("res://") or folder.contains("..") or folder in ["res:","res://addons"]:
  controller.i18n.text(status,"请选择工程内的新目录，例如 res://levels/Case06_Authoring。");return
 var path: String=controller.unique_path(folder.path_join("Case06_WorldMap.tscn"))
 var stage := HD2DWorldMapRecipe.create_stage(recipe,str(variant.get_item_metadata(variant.selected)))
 if stage==null: controller.i18n.text(status,"地图配方读取失败，请检查准备结果。");return
 if not complete: HD2DWorldMapRecipe.begin_steps(stage)
 else:
  HD2DWorldMapRecipe.execute_step(stage,"reference")
  HD2DWorldMapRecipe.execute_step(stage,"verify")
 var result := HD2DWorldMapRecipe.save_stage(stage,path);stage.free()
 if result!=OK: controller.i18n.text(status,"创建失败："+error_string(result));return
 EditorInterface.get_resource_filesystem().scan();EditorInterface.open_scene_from_path(path)
 EditorInterface.set_main_screen_editor("3D");dialog.hide();controller.message("已创建："+path)

func refresh() -> void:
 if not is_instance_valid(steps): return
 var selected := steps.get_selected_items();var index: int=selected[0] if not selected.is_empty() else 2
 steps.clear()
 var target := world()
 for i in TITLES.size():
  var done: bool=target!=null and HD2DWorldMapRecipe.STEPS[i] in target.world_data().completed_steps
  steps.add_item(("✓ " if done else "○ ")+controller.i18n.t(TITLES[i]))
 steps.select(index)
 if target:
  var d := target.world_data()
  controller.i18n.text(summary,"完整大地图：%d 区块 · %d 个布局实例 · %d 个地点"%[d.tiles.size(),d.placements.size(),d.bookmarks.size()])

func confirm_replace() -> void:
 if world()==null: return
 replace_dialog.popup_centered(Vector2i(660,240))

func execute(replace: bool) -> void:
 var selected := steps.get_selected_items()
 if selected.is_empty(): return
 var index := int(selected[0])
 if index==0: prepare();return
 if index==1: create(false);return
 var target := world()
 if target==null: controller.i18n.text(status,"先创建并选中制作副本的舞台。");return
 controller._finish_stroke()
 var before := capture_step(target.world_data(),index,replace)
 var rig: HD2DCameraRig=controller.stage.camera_rig()
 var camera_before := {"frame_size":rig.frame_size,"pitch_degrees":rig.pitch_degrees} if index==8 else {}
 var result := HD2DWorldMapRecipe.execute_step(controller.stage,HD2DWorldMapRecipe.STEPS[index],replace)
 if result!=OK:
  controller.i18n.text(status,"此步骤已完成；如需替换修改，请使用重新生成。" if result==ERR_ALREADY_EXISTS else "步骤无法执行；请先完成前面的步骤，并检查素材依赖。");return
 var after := capture_step(target.world_data(),index,replace)
 var camera_after := {"frame_size":rig.frame_size,"pitch_degrees":rig.pitch_degrees} if index==8 else {}
 var path := target.data.resource_path
 var undo: EditorUndoRedoManager=controller.get_undo_redo()
 undo.create_action(controller.i18n.t(TITLES[index]),UndoRedo.MERGE_DISABLE,controller.stage)
 undo.add_do_method(self,"restore",target,after,path,camera_after);undo.add_undo_method(self,"restore",target,before,path,camera_before)
 undo.commit_action()
 controller.i18n.text(status,"步骤已完成。检查场景后保存，可以继续编辑或撤销。");refresh()

func capture_step(data: HD2DWorldMapData, index: int, replace: bool) -> Dictionary:
 # Normal checkpoints change flags only. Never retain two full 1135² grids for
 # each enabled step; destructive regeneration snapshots only its own domain.
 var fields := ["completed_steps"]
 var flags := {2:["terrain_enabled"],3:["surface_enabled"],4:["layout_enabled"],5:["collisions_enabled"],6:["environment_enabled"],7:["presentation_enabled","party_enabled"]}
 fields.append_array(flags.get(index,[]))
 if replace:
  var domains := {
   2:["heights","coverage"],
   3:["weights","weights_extra","weights_ninth","weight_boundaries","surface_overrides","surface_period_overrides","surface_name_overrides","active_surface","textures","layer_names","texture_scale"],
   4:["placements","object_overrides"],5:["source_colliders"]}
  fields.append_array(domains.get(index,[]))
 var result := {}
 for field in fields: result[field]=copy_checkpoint_value(data.get(field))
 return result

func copy_checkpoint_value(value: Variant) -> Variant:
 if typeof(value) in [TYPE_ARRAY,TYPE_DICTIONARY]: return value.duplicate(true)
 if typeof(value) in [TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_COLOR_ARRAY,TYPE_PACKED_STRING_ARRAY]: return value.duplicate()
 return value

func restore(target: HD2DWorldMap, value: Dictionary, _path: String, camera: Dictionary = {}) -> void:
 if not is_instance_valid(target): return
 # Keep the same externally tracked Resource. Only this step's fields change.
 var current := target.world_data()
 for field in value: current.set(field,copy_checkpoint_value(value[field]))
 current.emit_changed();controller.external_dirty[current]=true
 if not camera.is_empty():
  var rig: HD2DCameraRig=target.get_parent().camera_rig()
  for field in camera: rig.set(field,camera[field])
  rig.reset_view()
 controller.ui.terrain_panel.sync_target(true);EditorInterface.mark_scene_as_unsaved();refresh()

func check_result() -> void:
 if world()==null: controller.i18n.text(status,"先创建并选中制作副本的舞台。");return
 var errors := HD2DWorldMapRecipe.check(controller.stage)
 controller.i18n.text(status,"结构检查通过；仍需按教程检查视觉与通行。" if errors.is_empty() else "\n".join(errors))

func save_current() -> void:
 if world()==null: return
 var path := world().data.resource_path
 if path.is_empty(): controller.i18n.text(status,"地图数据尚无保存路径，请先创建制作副本。");return
 var result := ResourceSaver.save(world().data,path,ResourceSaver.FLAG_COMPRESS)
 if result==OK:
  controller.external_dirty.erase(world().data)
  EditorInterface.save_scene();controller.i18n.text(status,"场景与地图数据已保存。")
 else: controller.i18n.text(status,"保存失败："+error_string(result))

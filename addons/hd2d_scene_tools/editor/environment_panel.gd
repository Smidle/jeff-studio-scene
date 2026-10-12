@tool
extends RefCounted
## All controls are an editor draft. A single Apply owns the scene transaction.
const FIELDS := ["sky_color","horizon_color","sky_mode","sun_color","sun_energy","sun_yaw","sun_elevation","shadows",
	"ambient_color","ambient_energy","wind_strength","cloud_shadows","fog_enabled","fog_density","saturation","contrast",
	"depth_blur","presentation_enabled","vignette","zone_blur","day_night_enabled","time_of_day","day_night_auto",
	"day_duration","night_brightness","moon_energy","night_sky_color","night_horizon_color","weather_mode","weather_intensity",
	"weather_wind_direction","weather_wind_speed","weather_radius","weather_cover_view","weather_particles","weather_rain_size","weather_snow_size","weather_seed","weather_randomize","weather_lightning_frequency","weather_lightning_duration","weather_thunder_volume",
	"weather_3d_enabled","weather_transition_seconds","weather_quality","weather_sky_backend","weather_wet_ground","weather_splashes","weather_link_wind","weather_leaf_size","weather_fall_speed","weather_flip_speed","weather_leaf_emission_randomness","weather_leaf_fall_randomness","weather_leaf_drift","weather_audio","weather_audio_volume"]
const WEATHER_IDS := [0,2,3,4,5,6,8,9]
var controller
var ui
var target: HD2DStage
var baseline: Dictionary={}
var draft: Dictionary={}
var footer: PanelContainer
var status: Label
var clock_label: Label
var apply_button: Button
var loading := false
var applying := false
var notice := ""
var leaf_aliases: Dictionary={}

func setup(plugin, dock_ui, root_box: VBoxContainer) -> void:
	controller=plugin;ui=dock_ui
	var day: VBoxContainer = ui.section(root_box,"environment.daynight","昼夜系统",true)
	ui.check(day,"day_night_enabled","启用昼夜系统",false)
	ui.slider(day,"time_of_day","开始时间（24小时制）",0,23.99,12)
	clock_label=ui.label(day,"")
	var presets := GridContainer.new();presets.columns=2;day.add_child(presets)
	for item in [["黎明",6.0],["正午",12.0],["黄昏",18.0],["午夜",0.0]]:
		var hour: float=item[1]
		ui.button(presets,item[0],select_hour.bind(hour)).set_meta("jeff_icon","environment")
	ui.check(day,"day_night_auto","运行时自动循环",false)
	ui.number(day,"day_duration","一天时长（秒）",30,7200,1,600)
	ui.label(day,"编辑视图停留在开始时间；循环在运行或场景预览中播放。")
	var box: VBoxContainer = ui.section(day,"environment.night","夜晚与月光",false)
	ui.slider(box,"night_brightness","夜间补光",0,1,0.12)
	ui.slider(box,"moon_energy","月光强度",0,2,0.18)
	ui.color_field(box,"night_sky_color","夜空颜色",Color("0c1733"))
	ui.color_field(box,"night_horizon_color","夜晚地平线",Color("27314c"))
	box=ui.section(day,"environment.sky","天空与背景",false)
	ui.option(box,"sky_mode","天空模式",["程序天空","背景色 / 天空模型"])
	ui.option(box,"weather_sky_backend","增强天空来源",["沿用原环境","Sky3D 像素天空"])
	ui.color_field(box,"sky_color","白天天空",Color("72b5cd"))
	ui.color_field(box,"horizon_color","白天地平线 / 雾颜色",Color("e4e7d0"))
	box=ui.section(day,"environment.sun","日光与阴影",false)
	ui.color_field(box,"sun_color","日光",Color("fff2ca"))
	ui.slider(box,"sun_energy","日光强度",0,8,0.85)
	ui.slider(box,"sun_yaw","太阳方位",-180,180,-35)
	ui.slider(box,"sun_elevation","太阳高度（静态）",0,90,48)
	ui.label(box,"启用昼夜后，太阳高度由时间控制；其余数值作为白天基准。")
	ui.check(box,"shadows","投射阴影",true)
	box=ui.section(day,"environment.ambient","环境补光",false)
	ui.color_field(box,"ambient_color","环境补光颜色",Color(0.86,0.91,0.76))
	ui.slider(box,"ambient_energy","白天环境补光",0,1,0.35)
	var weather: VBoxContainer = ui.section(root_box,"environment.weather","天气系统",true)
	ui.check(weather,"weather_3d_enabled","三维天气增强",false)
	ui.label(weather,"旧场景默认保留原效果；开启增强后支持遮挡、湿润、水花与花叶。")
	ui.option(weather,"weather_mode","天气类型",["晴天","下雨","下雪","雾天","沙尘暴","雷雨","秋日枫叶","春日樱花"])
	for i in WEATHER_IDS.size():ui.controls.weather_mode.set_item_id(i,WEATHER_IDS[i])
	ui.slider(weather,"weather_intensity","天气强度",0,1,0.65)
	var strengths:=HBoxContainer.new();weather.add_child(strengths)
	ui.button(strengths,"轻柔",select_strength.bind(0.4));ui.button(strengths,"强烈",select_strength.bind(0.9))
	ui.number(weather,"weather_transition_seconds","天气过渡（秒）",0,30,0.1,5)
	ui.option(weather,"weather_quality","增强天气质量",["低","中","高"])
	ui.label(weather,"雨雪与风沙覆盖主角和镜头附近。强度为 0 时恢复基础环境。")
	box=ui.section(weather,"environment.precipitation","天气范围与风力",false)
	ui.number(box,"weather_wind_direction","天气风向（度）",-180,180,1,-30)
	ui.number(box,"weather_wind_speed","天气风速（米/秒）",0,10,0.1,2)
	ui.number(box,"weather_radius","基础覆盖半径（米）",8,120,1,40)
	ui.check(box,"weather_cover_view","随镜头扩大覆盖",true)
	ui.label(box,"默认约 80×80 米；镜头覆盖最多扩至 240×240 米，粒子数量受上限限制。")
	ui.number(box,"weather_particles","最大粒子数",100,6000,100,2400)
	ui.number(box,"weather_rain_size","雨滴大小（倍）",0.25,4,0.05,1)
	ui.number(box,"weather_snow_size","雪花大小（倍）",0.25,4,0.05,1)
	ui.number(box,"weather_fall_speed","下落速度（倍）",0.2,3,0.05,1)
	ui.check(box,"weather_randomize","每次运行随机花叶与雨雪",true)
	ui.number(box,"weather_seed","天气随机种子",0,2147483647,1,4701)
	ui.number(box,"weather_lightning_frequency","闪电频率（次/分钟）",0,20,0.5,6)
	ui.number(box,"weather_lightning_duration","闪白持续时间（秒）",0.05,2,0.01,0.36)
	ui.number(box,"weather_thunder_volume","雷声音量（dB，-40 静音）",-40,0,1,-12)
	ui.label(box,"雨滴大小用于下雨与雷雨，雪花大小用于下雪。闪电频率为平均次数；设为 0 关闭闪电和雷声。")
	ui.label(box,"最大粒子数由当前天气使用；切换过渡时共用上限。关闭每次随机可按种子重现。")
	for kind in ["maple","sakura"]:
		var leaves: VBoxContainer=ui.section(weather,"environment."+kind,"秋日枫叶设置" if kind=="maple" else "春日樱花设置",true)
		leaf_number(leaves,kind,"weather_particles","最大粒子数",100,6000,100,2400)
		leaf_number(leaves,kind,"weather_leaf_size","花叶大小（倍）",0.25,4,0.05,1)
		leaf_number(leaves,kind,"weather_leaf_emission_randomness","出现时间随机度",0,1,0.05,0.5)
		leaf_number(leaves,kind,"weather_fall_speed","下落速度（倍）",0.2,3,0.05,1)
		leaf_number(leaves,kind,"weather_leaf_fall_randomness","下落速度差异",0,0.9,0.05,0.25)
		leaf_number(leaves,kind,"weather_leaf_drift","随机飘摆幅度（米/秒）",0,3,0.05,0.7)
		leaf_number(leaves,kind,"weather_flip_speed","花叶翻转速度（倍）",0,3,0.05,1)
		var random_key: String="weather_randomize_"+kind
		ui.check(leaves,random_key,"每次运行随机花叶与雨雪",true)
		leaf_aliases.get_or_add("weather_randomize",[]).append(ui.controls[random_key])
		leaf_number(leaves,kind,"weather_seed","天气随机种子",0,2147483647,1,4701)
		ui.label(leaves,"数量上限配合上方天气强度控制疏密；风向、风速和覆盖范围在天气范围与风力中调整。")
		ui.label(leaves,"出现时间随机度 0 为均匀出现，1 更不规则。速度差异 0 为同速，0.25 为上下浮动 25%；飘摆幅度 0 关闭左右摆动，仍受风影响。")
		ui.label(leaves,"出生位置始终随机分布。开启每次运行随机可换分布；关闭后使用固定种子。调整后先应用，再重新预览比较。")
	box=ui.section(weather,"environment.wind","风与云影",false)
	ui.slider(box,"wind_strength","植物风力",0,3,0.5)
	ui.check(box,"weather_link_wind","天气联动植物风",true)
	ui.slider(box,"cloud_shadows","云影浓度",0,1,0.18)
	ui.label(box,"云影浓度仅保留旧版材质的明暗变化，不再提供多云天气。")
	box=ui.section(weather,"environment.fog","距离雾",false)
	ui.check(box,"fog_enabled","距离雾",true)
	ui.number(box,"fog_density","雾浓度",0,0.1,0.001,0.001)
	ui.label(box,"雾天和沙尘暴会加强距离雾；晴天保留基础雾设置。")
	ui.check(box,"weather_wet_ground","增强天气：全部地表湿润",true)
	ui.check(box,"weather_splashes","增强天气：雨滴落地水花",true)
	ui.label(box,"普通屋顶自动遮雨；室内、廊下与洞穴添加遮挡盒。花叶触地后淡出，不永久堆积。")
	ui.button(box,"添加天气遮挡盒",add_shelter)
	ui.label(box,"天气循环音效（留空静音）")
	var audio:=EditorResourcePicker.new();audio.base_type="AudioStream";box.add_child(audio);ui.controls.weather_audio=audio
	ui.number(box,"weather_audio_volume","天气音效音量（dB）",-60,0,1,-24)
	var other: VBoxContainer = ui.section(root_box,"environment.other","其他环境设置",false)
	box=ui.section(other,"environment.color","调色",false)
	ui.slider(box,"saturation","饱和度",0.2,2,1.05)
	ui.slider(box,"contrast","对比度",0.2,2,1.04)
	box=ui.section(other,"environment.dof","真实景深",false)
	ui.slider(box,"depth_blur","远景景深虚化",0,1,0)
	var compatibility := RenderingServer.get_current_rendering_method()=="gl_compatibility"
	ui.controls.depth_blur.editable=not compatibility;ui.controls.depth_blur_slider.editable=not compatibility
	ui.label(box,"Compatibility 不支持真实景深；昼夜、雨雪与距离雾均可用。" if compatibility else "Forward+ 支持真实景深；昼夜、雨雪使用与 Compatibility 相同的参数。")
	box=ui.section(other,"environment.post","演出后期",false)
	ui.check(box,"presentation_enabled","演出后期（仅游戏 / 隔离测试）",false)
	ui.slider(box,"vignette","暗角",0,1,0.36)
	ui.slider(box,"zone_blur","画面分区虚化（不是景深）",0,2,0)
	ui.label(box,"分区虚化在 Compatibility 也可用；与真实景深分开，不改变原生编辑视口。")
	box=ui.section(other,"environment.world","旧版大地图环境",false)
	ui.check(box,"world_region_grade","启用原地图地区调色",true)
	ui.number(box,"world_region_strength","地区调色强度",0,1,0.01,0.35)
	ui.number(box,"world_effect_speed","水面与云雾速度",0,3,0.05,1)
	ui.button(box,"应用大地图环境",func():
		if controller.stage and controller.stage.has_node("WorldEnvironmentAdapter"):
			controller.set_properties(controller.stage.get_node("WorldEnvironmentAdapter"),{"regional_grading":ui.checked("world_region_grade"),"region_strength":ui.value("world_region_strength"),"effect_speed":ui.value("world_effect_speed")},"应用大地图环境")
		else:controller.message("先创建并选中制作副本的舞台。"))
	footer=PanelContainer.new();footer.name="EnvironmentApplyFrame";footer.theme_type_variation="JeffApplyFrame";ui.add_child(footer)
	var actions := VBoxContainer.new();footer.add_child(actions)
	status=ui.label(actions,"");status.max_lines_visible=3
	apply_button=ui.button(actions,"应用环境设置",apply);apply_button.theme_type_variation="JeffPrimaryButton"
	for key in FIELDS:
		for control in controls_for(key):
			if control is EditorResourcePicker:control.resource_changed.connect(edited.bind(key))
			elif control is ColorPickerButton:control.color_changed.connect(edited.bind(key))
			elif control is OptionButton:control.item_selected.connect(edited.bind(key))
			elif control is BaseButton:control.toggled.connect(edited.bind(key))
			else:control.value_changed.connect(edited.bind(key))
	ui.tabs.tab_changed.connect(func(_index):refresh())
	controller.scene_saved.connect(scene_saved)
	ui.tree_exiting.connect(func():
		if controller.scene_saved.is_connected(scene_saved):controller.scene_saved.disconnect(scene_saved))
	sync_target()

func controls_for(key: String) -> Array:
	return [ui.controls[key]]+leaf_aliases.get(key,[])

func leaf_number(parent: VBoxContainer, kind: String, key: String, title: String, low: float, high: float, step: float, value: float) -> void:
	var alias := key+"_"+kind if ui.controls.has(key) else key
	var control: SpinBox=ui.number(parent,alias,title,low,high,step,value)
	if alias!=key:leaf_aliases.get_or_add(key,[]).append(control)

func read_target(stage: HD2DStage) -> Dictionary:
	var result: Dictionary={}
	for key in FIELDS:result[key]=stage.get(key)
	return result

func is_dirty() -> bool:
	return is_instance_valid(target) and draft!=baseline

func sync_target() -> void:
	var stage: HD2DStage=controller.stage if is_instance_valid(controller.stage) else null
	var incoming := read_target(stage) if stage else {}
	if target!=stage or incoming!=baseline:
		var discarded := not draft.is_empty() and draft!=baseline
		target=stage;baseline=incoming;draft=incoming.duplicate();notice=""
		if discarded and not applying:
			notice="环境目标或场景设置已变化；草稿已同步。";controller.message(notice)
		write_controls()
	refresh()

func write_controls() -> void:
	loading=true
	for key in draft:
		for control in controls_for(key):
			if control is EditorResourcePicker:control.edited_resource=draft[key]
			elif control is ColorPickerButton:control.color=draft[key]
			elif control is OptionButton:
				control.select(maxi(0,control.get_item_index(int(draft[key]))) if key=="weather_mode" else int(draft[key]))
			elif control is BaseButton:control.set_pressed_no_signal(draft[key])
			else:control.set_value_no_signal(draft[key])
		if ui.controls.has(key+"_slider"):ui.controls[key+"_slider"].set_value_no_signal(draft[key])
	loading=false

func edited(value: Variant, key: String) -> void:
	if loading or ui.syncing or not is_instance_valid(target):return
	if key=="weather_mode":value=ui.controls.weather_mode.get_item_id(int(value))
	draft[key]=int(value) if key in ["weather_mode","weather_particles","weather_seed","sky_mode","weather_quality","weather_sky_backend"] else value
	if (key=="weather_mode" and int(value)>=8) or (key=="weather_sky_backend" and int(value)==1):draft.weather_3d_enabled=true;write_controls()
	notice="";write_controls();refresh()

func select_strength(value: float) -> void:
	if not is_instance_valid(target):return
	draft.weather_intensity=value;write_controls();refresh()

func add_shelter() -> void:
	if not is_instance_valid(target):return
	var shelter:=HD2DWeatherShelter.new();shelter.name="WeatherShelter"
	var actor=target.character()
	shelter.position=target.to_local(actor.global_position)+Vector3(0,2.5,0) if is_instance_valid(actor) else Vector3(0,2.5,0)
	var undo=controller.get_undo_redo();undo.create_action(controller.i18n.t("添加天气遮挡盒"),UndoRedo.MERGE_DISABLE,target)
	undo.add_do_method(target,"add_child",shelter,true);undo.add_do_property(shelter,"owner",target)
	undo.add_undo_method(target,"remove_child",shelter);undo.add_do_reference(shelter);undo.commit_action()
	EditorInterface.get_selection().clear();EditorInterface.get_selection().add_node(shelter)
	controller.mark_changed()

func select_hour(hour: float) -> void:
	if not is_instance_valid(target):return
	draft.day_night_enabled=true;draft.time_of_day=hour;notice=""
	write_controls();refresh()

func apply() -> void:
	sync_target()
	if not is_dirty():return
	applying=true
	controller.commit_environment_settings(target,draft.duplicate())
	applying=false
	notice="已应用环境设置；可预览昼夜与天气，Ctrl / Cmd + S 保存。"
	controller.message(notice);refresh()

func scene_saved(path: String) -> void:
	if not is_dirty() and is_instance_valid(target) and target.scene_file_path==path:
		notice="环境设置已保存。";refresh()

func refresh() -> void:
	footer.visible=ui.tabs.current_tab==ui.page_index("environment")
	apply_button.disabled=not is_dirty()
	var text := "未应用修改；先应用，再预览与保存。" if is_dirty() else (notice if not notice.is_empty() else "环境设置与场景一致。")
	if not is_instance_valid(target):text="请先创建或选择场景，再设置环境。"
	controller.i18n.text(status,text)
	var enabled: bool=draft.get("day_night_enabled",false)
	for control in controls_for("weather_seed"):control.editable=not bool(draft.get("weather_randomize",true))
	ui.controls.sun_elevation.editable=not enabled;ui.controls.sun_elevation_slider.editable=not enabled
	var minutes := roundi(float(draft.get("time_of_day",12.0))*60.0)%1440
	controller.i18n.text(clock_label,"开始时间：%s"%("%02d:%02d"%[minutes/60,minutes%60]))
	var mode:int=draft.get("weather_mode",0)
	ui.sections["environment.maple"].visible=mode==8
	ui.sections["environment.sakura"].visible=mode==9
	for key in ["weather_particles","weather_fall_speed","weather_seed"]:ui.controls[key].get_parent().visible=mode not in [8,9]
	ui.controls.weather_randomize.visible=mode not in [8,9]

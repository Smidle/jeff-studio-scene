@tool
extends VBoxContainer
## Music authoring is transactional: clone config -> validate -> one undo action.
var dock
var controller
var library: HD2DMusicLibrary
var selected_index := -1
var bound_stage: HD2DStage
var search: LineEdit
var list: ItemList
var title_edit: LineEdit
var category_edit: LineEdit
var note_edit: TextEdit
var info: Label
var waveform
var seek_bar: HSlider
var playback_info: Label
var audition: HD2DMusicPlayer
var import_busy := false
var preview_path := ""
var last_library: HD2DMusicLibrary
var seeking := false

func setup(value) -> void:
	dock=value; controller=dock.controller
	var box: VBoxContainer=dock.section(self,"music.import","音乐导入与曲库",true)
	dock.label(box,"导入 OGG Vorbis / MP3 / WAV。每个场景选择一首背景音乐，编辑时不自动播放。")
	dock.button(box,"＋ 导入音乐（可多选）",func(): dock.pick(["*.ogg,*.mp3,*.wav ; 音乐"],true,import_tracks))
	search=LineEdit.new(); search.placeholder_text="搜索名称 / 分类…"; box.add_child(search)
	search.text_changed.connect(func(_text): rebuild_list())
	list=ItemList.new(); list.custom_minimum_size.y=140; box.add_child(list)
	list.item_selected.connect(func(index): select_track(int(list.get_item_metadata(index))))
	box=dock.section(self,"music.bgm","场景BGM管理",false)
	var actions := HBoxContainer.new(); box.add_child(actions)
	dock.button(actions,"设为场景 BGM",activate_selected)
	dock.button(actions,"移除条目",remove_selected)
	dock.button(box,"关闭场景 BGM（保留曲库）",func():
		if not valid_stage(): return
		var copy := library.copy_settings(); copy.active_index=-1; commit(copy,"关闭场景音乐"))
	box=dock.section(self,"music.audition","试听与波形",true)
	waveform=preload("music_waveform.gd").new(); waveform.custom_minimum_size.y=64; box.add_child(waveform)
	waveform.tooltip_text="抽样波形概览（非精确裁剪）。试听时点击跳转。"
	waveform.seek_requested.connect(func(seconds):
		if audition.track: audition.player.seek(minf(seconds,audition.player.stream.get_length()-0.001)))
	info=dock.label(self,"尚未选择音乐。")
	var bar := HBoxContainer.new(); box.add_child(bar)
	dock.button(bar,"▶ 试听",play_selected)
	dock.button(bar,"暂停 / 继续",func(): audition.set_manual_pause(not audition.manual_paused))
	dock.button(bar,"■ 停止",func(): audition.fade_stop())
	seek_bar=HSlider.new(); seek_bar.min_value=0; seek_bar.step=0.01; box.add_child(seek_bar)
	seek_bar.drag_started.connect(func(): seeking=true)
	seek_bar.drag_ended.connect(func(changed):
		seeking=false
		if changed and audition.track: audition.player.seek(seek_bar.value))
	playback_info=dock.label(box,"试听未播放")
	box=dock.section(self,"music.identity","名称分类与来源",false)
	dock.label(box,"名称 / 分类")
	title_edit=LineEdit.new(); box.add_child(title_edit)
	category_edit=LineEdit.new(); category_edit.text=dock.i18n.t("背景音乐"); box.add_child(category_edit)
	dock.label(box,"来源与用途说明（随场景保存）")
	note_edit=TextEdit.new(); note_edit.custom_minimum_size.y=55; box.add_child(note_edit)
	box=dock.section(self,"music.playback","自动播放与循环",false)
	dock.check(box,"music_autoplay","运行 / 隔离测试时自动播放",true)
	dock.check(box,"music_loop","循环播放",true)
	dock.check(box,"music_pause_stage","随舞台暂停（默认不勾选）",false)
	box=dock.section(self,"music.volume","音量与淡入淡出",false)
	dock.slider(box,"music_volume","音量（dB，0 为原音量）",-60,0,-18)
	dock.number(box,"music_fade_in","开始淡入（秒）",0,10,0.1,1.5)
	dock.number(box,"music_fade_out","试听停止淡出（秒）",0,10,0.1,0.8)
	box=dock.section(self,"music.interval","循环区间",false)
	dock.number(box,"music_loop_start","循环回到（秒）",0,7200,0.01,0)
	dock.number(box,"music_loop_end","循环终点（0 = 文件结尾）",0,7200,0.01,0)
	dock.label(box,"首次从 0 秒播放，再循环到起点。自定义终点仅支持 PCM WAV；OGG / MP3 使用文件结尾。循环不自动修复曲调接缝。")
	dock.button(self,"应用音乐参数（可撤销）",apply_selected)
	dock.label(self,"试听使用面板待应用参数；只有点击“应用”才保存。关闭预览 / 切换场景立即静音；淡出仅用于主动停止。")
	audition=HD2DMusicPlayer.new(); add_child(audition)

func valid_stage() -> bool:
	return controller.require_stage() and is_instance_valid(bound_stage) and bound_stage==controller.stage

func sync_stage() -> void:
	var current: HD2DStage=controller.stage
	var changed := current!=bound_stage
	if changed:
		stop_now(); selected_index=-1; bound_stage=current
		search.clear()
	library=current.music_library if is_instance_valid(current) and current.music_library else HD2DMusicLibrary.new()
	if library!=last_library:
		stop_now()
		last_library=library
		if selected_index<0 or selected_index>=library.tracks.size(): selected_index=library.active_index
		rebuild_list(); show_track()

func rebuild_list() -> void:
	list.clear()
	if library==null: return
	for i in range(library.tracks.size()):
		var track := library.tracks[i]
		if track==null or (not search.text.is_empty() and not (track.title+" "+track.category).to_lower().contains(search.text.to_lower())): continue
		var row := list.add_item(("♪ " if i==library.active_index else "")+track.title+" · "+track.category)
		list.set_item_metadata(row,i)
		if i==selected_index: list.select(row)

func selected_track() -> HD2DMusicTrack:
	return library.tracks[selected_index] if library and selected_index>=0 and selected_index<library.tracks.size() else null

func select_track(index: int) -> void:
	stop_now(); selected_index=index; show_track()

func show_track() -> void:
	var track := selected_track()
	waveform.set_stream(null); preview_path=""
	if track==null:
		dock.i18n.text(info,"尚未选择音乐。"); title_edit.text=""; note_edit.text=""
		return
	title_edit.text=track.title; category_edit.text=track.category; note_edit.text=track.source_note
	for pair in [["music_volume","volume_db"],["music_fade_in","fade_in"],["music_fade_out","fade_out"],["music_loop_start","loop_start"],["music_loop_end","loop_end"]]: dock.controls[pair[0]].value=track.get(pair[1])
	for pair in [["music_autoplay","autoplay"],["music_loop","loop"],["music_pause_stage","pause_with_stage"]]: dock.controls[pair[0]].button_pressed=track.get(pair[1])
	var duration := track.stream.get_length() if track.stream else 0.0
	seek_bar.max_value=maxf(duration,0.01)
	if track.stream: dock.i18n.text(info,"%s · %.2f 秒\n%s"%[track.stream.get_class(),duration,track.stream.resource_path if not track.stream.resource_path.is_empty() else "—"])
	else: dock.i18n.text(info,"缺少音频")
	if track.stream and not track.stream.resource_path.is_empty():
		preview_path=track.stream.resource_path
		waveform.set_stream(track.stream)

func draft() -> HD2DMusicTrack:
	var source := selected_track()
	if source==null: return null
	var track := source.duplicate() as HD2DMusicTrack
	track.title=title_edit.text.strip_edges(); track.category=category_edit.text.strip_edges(); track.source_note=note_edit.text
	for pair in [["music_volume","volume_db"],["music_fade_in","fade_in"],["music_fade_out","fade_out"],["music_loop_start","loop_start"],["music_loop_end","loop_end"]]: track.set(pair[1],dock.value(pair[0]))
	for pair in [["music_autoplay","autoplay"],["music_loop","loop"],["music_pause_stage","pause_with_stage"]]: track.set(pair[1],dock.checked(pair[0]))
	return track

func commit(copy: HD2DMusicLibrary, action: String) -> void:
	stop_now()
	controller.set_properties(bound_stage,{"music_library":copy},action)

func import_tracks(paths: PackedStringArray) -> void:
	if import_busy or not valid_stage(): return
	import_busy=true
	var destination := bound_stage
	var added: Array[HD2DMusicTrack]=[]
	for path in paths:
		if not path.get_extension().to_lower() in ["ogg","mp3","wav"]: continue
		var resource: Resource=await controller.project_resource(path)
		if not is_instance_valid(destination) or destination!=controller.stage:
			import_busy=false; controller.message("导入期间切换了场景：文件可能已复制，但没有写入其他场景。"); return
		var track := HD2DMusicTrack.new()
		if not resource is AudioStream: continue
		track.stream=resource; track.title=path.get_file().get_basename()
		track.category=dock.i18n.t("背景音乐")
		track.source_note=dock.i18n.t("导入文件：%s")%path.get_file()
		if not track.problem().is_empty(): controller.message(track.problem()); continue
		added.append(track)
	import_busy=false
	if added.is_empty(): return
	# Read the latest library after awaiting import; do not discard concurrent edits.
	var copy := destination.music_library.copy_settings() if destination.music_library else HD2DMusicLibrary.new()
	selected_index=copy.tracks.size()
	copy.tracks.append_array(added)
	if copy.active_index<0: copy.active_index=selected_index
	commit(copy,"导入音乐")
	controller.message("已导入 %d 首。♪ 为场景 BGM；先试听，再应用参数并 Cmd+S 保存。"%added.size())

func activate_selected() -> void:
	if not valid_stage() or selected_track()==null: return
	var copy := library.copy_settings(); copy.active_index=selected_index; commit(copy,"设置场景音乐")

func remove_selected() -> void:
	if not valid_stage() or selected_track()==null: return
	var copy := library.copy_settings(); copy.tracks.remove_at(selected_index)
	if copy.active_index==selected_index: copy.active_index=-1
	elif copy.active_index>selected_index: copy.active_index-=1
	selected_index=-1; commit(copy,"移除音乐条目（保留文件）")

func apply_selected() -> void:
	if not valid_stage(): return
	var track := draft()
	if track==null: return
	if not track.problem().is_empty(): controller.message(track.problem()); return
	var copy := library.copy_settings(); copy.tracks[selected_index]=track; commit(copy,"修改音乐参数")

func play_selected() -> void:
	if not valid_stage(): return
	var track := draft()
	if track==null: return
	if not track.problem().is_empty(): controller.message(track.problem()); return
	if is_instance_valid(controller.preview):
		controller.preview.stop_music()
	audition.play_track(track)

func stop_now() -> void:
	if is_instance_valid(audition): audition.stop_now()

func _process(_delta: float) -> void:
	if not is_instance_valid(audition) or not is_instance_valid(audition.player): return
	var playing := audition.player.playing
	if playing:
		var position := audition.player.get_playback_position()
		if not seeking: seek_bar.set_value_no_signal(position)
		waveform.cursor=position; waveform.queue_redraw()
		playback_info.text=dock.i18n.t(("已暂停" if audition.manual_paused else "试听中")+" · %.2f / %.2f 秒"%[position,audition.player.stream.get_length()])
	else: playback_info.text=dock.i18n.t("试听未播放")

func _exit_tree() -> void:
	stop_now()

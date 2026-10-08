@tool
extends Control
signal seek_requested(seconds: float)
var peaks := PackedVector2Array()
var duration := 0.0
var cursor := 0.0
var generation := 0
var ready_wave := false

func set_stream(stream: AudioStream) -> void:
	generation+=1
	var token := generation
	peaks.clear(); duration=0; cursor=0; ready_wave=false; queue_redraw()
	if stream==null or stream.get_length()<=0: return
	duration=stream.get_length()
	var config := HD2DMusicTrack.new(); config.stream=stream; config.loop=false
	var source := config.playback_stream()
	if source==null: return
	var decoder := source.instantiate_playback()
	decoder.start()
	# A sparse overview, deliberately not a sample-accurate editing waveform.
	for i in range(192):
		if token!=generation or not is_inside_tree(): decoder.stop(); return
		decoder.seek(duration*float(i)/192)
		var frames := decoder.mix_audio(1,1024)
		var lo := 0.0; var hi := 0.0
		for frame in frames:
			lo=minf(lo,minf(frame.x,frame.y)); hi=maxf(hi,maxf(frame.x,frame.y))
		peaks.append(Vector2(lo,hi))
		if i%12==0:
			queue_redraw()
			await get_tree().process_frame
	decoder.stop(); ready_wave=true; queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("172324"))
	draw_line(Vector2(0,size.y/2),Vector2(size.x,size.y/2),Color("526966"))
	for i in range(peaks.size()):
		var x := float(i)*size.x/192
		draw_line(Vector2(x,size.y*(0.5-peaks[i].y*0.45)),Vector2(x,size.y*(0.5-peaks[i].x*0.45)),Color("72d9be"),maxf(1,size.x/192))
	if duration>0:
		var x := clampf(cursor/duration,0,1)*size.x
		draw_line(Vector2(x,0),Vector2(x,size.y),Color("f0cc80"),2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and duration>0:
		seek_requested.emit(clampf(event.position.x/size.x,0,1)*duration)
		accept_event()

func _exit_tree() -> void: generation+=1

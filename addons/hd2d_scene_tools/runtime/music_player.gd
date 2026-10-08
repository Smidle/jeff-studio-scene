@tool
class_name HD2DMusicPlayer
extends Node
## One non-positional voice per stage, outside the three Scenery copies.
var player: AudioStreamPlayer
var track: HD2DMusicTrack
var envelope: Tween
var manual_paused := false
var stage_paused := false
var envelope_suspended := false

func _ready() -> void:
	player=AudioStreamPlayer.new()
	player.name="Audio"
	add_child(player)
	player.max_polyphony=1

func play_track(value: HD2DMusicTrack, from_seconds: float = 0.0) -> bool:
	stop_now()
	if value==null or not value.problem().is_empty(): return false
	track=value.duplicate() as HD2DMusicTrack
	player.stream=track.playback_stream()
	player.volume_db=track.volume_db
	player.volume_linear=0.0 if track.fade_in>0 else db_to_linear(track.volume_db)
	player.play(clampf(from_seconds,0,maxf(0,player.stream.get_length()-0.001)))
	_apply_pause()
	if track.fade_in>0:
		envelope=create_tween()
		envelope.tween_property(player,"volume_linear",db_to_linear(track.volume_db),track.fade_in)
	return true

func stop_now() -> void:
	if is_instance_valid(envelope): envelope.kill()
	envelope_suspended=false
	if is_instance_valid(player):
		player.stop()
		player.stream=null
		player.stream_paused=false
	track=null
	manual_paused=false
	stage_paused=false

func fade_stop() -> void:
	if track==null or player.stream_paused or track.fade_out<=0:
		stop_now()
		return
	if is_instance_valid(envelope): envelope.kill()
	envelope_suspended=false
	envelope=create_tween()
	envelope.tween_property(player,"volume_linear",0.0,track.fade_out)
	envelope.tween_callback(stop_now)

func set_manual_pause(value: bool) -> void:
	manual_paused=value
	_apply_pause()

func set_stage_pause(value: bool) -> void:
	stage_paused=value
	_apply_pause()

func _apply_pause() -> void:
	if not is_instance_valid(player): return
	var paused := manual_paused or (stage_paused and track!=null and track.pause_with_stage)
	player.stream_paused=paused
	if is_instance_valid(envelope) and envelope.is_valid():
		# A finished tween can remain valid until the end of this frame. Never
		# call play() on every stage tick, or on a completed fade envelope.
		if paused and envelope.is_running():
			envelope.pause()
			envelope_suspended=true
		elif not paused and envelope_suspended:
			envelope.play()
			envelope_suspended=false

func _exit_tree() -> void:
	stop_now()

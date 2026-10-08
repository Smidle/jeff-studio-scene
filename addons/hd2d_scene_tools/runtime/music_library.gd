@tool
class_name HD2DMusicLibrary
extends Resource
@export var tracks: Array[HD2DMusicTrack] = []
@export var active_index: int = -1

func active_track() -> HD2DMusicTrack:
	return tracks[active_index] if active_index>=0 and active_index<tracks.size() else null

func copy_settings() -> HD2DMusicLibrary:
	var result := HD2DMusicLibrary.new()
	result.active_index=active_index
	for track in tracks:
		result.tracks.append(track.duplicate() as HD2DMusicTrack if track else null)
	return result

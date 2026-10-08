@tool
class_name HD2DMusicTrack
extends Resource
## Configuration only. Imported streams are never modified in place.
@export var title: String = "音乐"
@export var category: String = "背景音乐"
@export_multiline var source_note: String = ""
@export var stream: AudioStream
@export var autoplay: bool = true
@export var loop: bool = true
@export_range(-60,0,0.1) var volume_db: float = -18.0
@export_range(0,10,0.1) var fade_in: float = 1.5
@export_range(0,10,0.1) var fade_out: float = 0.8
@export_range(0,7200,0.01) var loop_start: float = 0.0
## 0 = EOF. A custom end is supported only by uncompressed PCM WAV.
@export_range(0,7200,0.01) var loop_end: float = 0.0
@export var pause_with_stage: bool = false

func problem() -> String:
	if not (stream is AudioStreamOggVorbis or stream is AudioStreamMP3 or stream is AudioStreamWAV):
		return "请选择 OGG Vorbis、MP3 或 WAV 音频，不支持音频库 / 容器文件。"
	var length := stream.get_length()
	if not is_finite(length) or length<=0: return "音频时长无效。"
	for value in [volume_db,fade_in,fade_out,loop_start,loop_end]:
		if not is_finite(value): return "音乐参数不能是无穷或无效数字。"
	if volume_db < -60 or volume_db > 0 or fade_in<0 or fade_in>10 or fade_out<0 or fade_out>10:
		return "音量范围 -60～0 dB，淡入 / 淡出范围 0～10 秒。"
	if loop_start<0 or loop_end<0: return "循环时间不能小于 0。"
	if loop:
		var end := length if loop_end==0 else loop_end
		if loop_start>=end or end>length+0.001: return "循环起点必须小于终点，且不能超出音乐时长。"
		if loop_end>0 and not (stream is AudioStreamWAV and stream.format in [AudioStreamWAV.FORMAT_8_BITS,AudioStreamWAV.FORMAT_16_BITS]):
			return "自定义循环终点仅支持 PCM WAV；OGG / MP3 请设为 0（文件结尾）。"
	return ""

func playback_stream() -> AudioStream:
	if not problem().is_empty(): return null
	var result := stream.duplicate() as AudioStream
	if result is AudioStreamWAV:
		result.loop_mode=AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		result.loop_begin=int(round(loop_start*result.mix_rate)) if loop else 0
		result.loop_end=int(round((stream.get_length() if loop_end==0 else loop_end)*result.mix_rate))
	else:
		result.loop=loop
		result.loop_offset=loop_start if loop else 0.0
		# Beat metadata must not silently override the requested file-end loop.
		result.beat_count=0
	return result

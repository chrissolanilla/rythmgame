extends Control

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var play_button: Button = $BottomBar/PlayButton
@onready var current_time: Label = $BottomBar/CurrentTime
@onready var bpm_label: Label = $BottomBar/BPM
@onready var seek: HSlider = $Seek
@onready var offset: SpinBox = $BottomBar/Offset

@onready var snap_opt: OptionButton = $TopBar/Option

@onready var down_left_arrow: Node2D = $Main/Center/DownLeftArrow
@onready var left_arrow: Node2D = $Main/Center/LeftArrow
@onready var up_left_arrow: Node2D = $Main/Center/UpLeftArrow
@onready var down_arrow: Node2D = $Main/Center/DownArrow
@onready var middle_note: Node2D = $Main/Center/MiddleNote
@onready var up_arrow: Node2D = $Main/Center/UpArrow
@onready var up_right_arrow: Node2D = $Main/Center/UpRightArrow
@onready var right_arrow: Node2D = $Main/Center/RightArrow
@onready var down_right_arrow: Node2D = $Main/Center/DownRightArrow
@onready var playfield: PlayField = $Main/Center/Playfield

var seconds_per_pixels: float = 0.02
var lane_names: Array = ["upLeft","left","downLeft","down","center","up","upRight","right","downRight"]
var chart_data: Array = []

var selection: int = -1
var drag_kind: String = ""
var active_lane: String = "up"
var placing_poses: bool = false
var snap_div: int = 4
var recording: bool = false
var pending_hold: Dictionary = {}
var song_offset_ms: int = 0
var bpm: float = 120.0
var is_dragging: bool = false
var current_seek: float = 0.0

func _ready() -> void:
	# pass context to playfield
	playfield.audio = audio
	playfield.bpm = bpm
	playfield.snap_div = snap_div
	playfield.song_offset_ms = song_offset_ms
	playfield.chart_data = chart_data
	playfield.receptors = {
		"upLeft":     up_left_arrow,
		"left":       left_arrow,
		"downLeft":   down_left_arrow,
		"down":       down_arrow,
		"center":     middle_note,
		"up":         up_arrow,
		"upRight":    up_right_arrow,
		"right":      right_arrow,
		"downRight":  down_right_arrow,
	}

	seek.drag_started.connect(func(): is_dragging = true)
	seek.drag_ended.connect(func(changed: bool):
		is_dragging = false
		if changed and audio.stream:
			audio.seek(seek.value)
	)
	seek.step = 0.01
	seek.value_changed.connect(_on_seek_value_changed)

	# snap dropdown
	snap_opt.clear()
	for v in [4,8,12,16,24,32]:
		snap_opt.add_item("1/%d" % v, v)
	snap_opt.select(0)
	snap_opt.item_selected.connect(func(idx:int):
		snap_div = int(snap_opt.get_item_id(idx))
		playfield.snap_div = snap_div
	)

	offset.value_changed.connect(func(v:float):
		song_offset_ms = int(v)
		playfield.song_offset_ms = song_offset_ms
	)

func _process(delta: float) -> void:
	if audio.stream:
		if not is_dragging and (audio.playing and not audio.stream_paused):
			var t: float = audio.get_playback_position()
			seek.value = t
			current_time.text = "%0.3f" % t

#signals
func _on_play_button_pressed() -> void:
	if not audio.stream:
		return
	# First press or resume
	if not audio.playing:
		audio.stream_paused = false
		audio.play()
		audio.seek(current_seek)
		return
	# Toggle pause without resetting playback position
	if audio.stream_paused:
		audio.stream_paused = false
	else:
		current_seek = audio.get_playback_position()
		audio.stream_paused = true

func _on_back_to_start_pressed() -> void:
	audio.stream_paused = false
	audio.stop()
	current_time.text = "0.0"
	current_seek = 0.0
	seek.value = 0.0

func _on_open_audio_pressed() -> void:
	var fd := $Audio
	fd.filters = PackedStringArray(["*.wav ; WAV","*.mp3 ; MP3","*.ogg ; OGG"])
	fd.popup_centered()

func _on_audio_file_selected(path: String) -> void:
	var stream := _load_audio_any(path)
	if stream:
		audio.stream = stream
		seek.max_value = stream.get_length()
		seek.value = 0.0
		# build bars + clear notes view
		playfield.build_bars_for_song(stream.get_length())
		playfield.rebuild_notes()
	else:
		push_error("Unsupported or failed to load audio %s" % path)

func _load_audio_any(path: String) -> AudioStream:
	var ext := path.get_extension().to_lower()

	if ext == "mp3":
		var s_mp3 := AudioStreamMP3.new()
		s_mp3.data = FileAccess.get_file_as_bytes(path)
		return s_mp3

	if ext == "wav":
		var s_wav := AudioStreamWAV.new()
		s_wav.data = FileAccess.get_file_as_bytes(path)
		return s_wav

	if ext == "ogg" or ext == "oga":
		var s_ogg := AudioStreamOggVorbis.new()
		if s_ogg.has_method("load_from_file"):
			s_ogg.load_from_file(path)
			return s_ogg
		return null

	return null

func _on_open_chart_pressed() -> void:
	var fd := $Chart
	fd.filters = PackedStringArray(["*.json ; Chart JSON"])
	fd.popup_centered()

func _on_chart_file_selected(path: String) -> void:
	var t := FileAccess.get_file_as_string(path)
	chart_data = JSON.parse_string(t) if t != "" else []
	chart_data.sort_custom(func(a, b): return a["time"] < b["time"])
	playfield.chart_data = chart_data
	playfield.rebuild_notes()

func _on_save_chart_pressed() -> void:
	var data := JSON.stringify(chart_data, "\t")
	var f := FileAccess.open("user://my_chart.json", FileAccess.WRITE)
	f.store_string(data)
	f.close()

func _on_zoom_value_changed(value: float) -> void:
	# no-op for now; vertical zoom would live in PlayField if you add it
	pass

func _on_seek_value_changed(value: float) -> void:
	if audio.stream and is_dragging:
		audio.seek(value)
	if is_dragging and (not audio.playing or audio.stream_paused):
		current_seek = value

func _on_bpm_changed(v: float) -> void:
	bpm = max(1.0, v)
	playfield.bpm = bpm
	playfield.build_bars_for_song(seek.max_value)

func _on_offset_changed(v: float) -> void:
	song_offset_ms = int(v)
	playfield.song_offset_ms = song_offset_ms
	# rebuild bar Y positions
	playfield.build_bars_for_song(seek.max_value)

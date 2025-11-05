extends Control

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var play_button: Button = $BottomBar/PlayButton
@onready var current_time: Label = $BottomBar/CurrentTime
@onready var bpm_label: Label = $BottomBar/BPM
@onready var seek: HSlider = $Seek
@onready var offset: SpinBox = $BottomBar/Offset
@onready var pose_name: OptionButton = $Main/Inspector/PoseName

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
@onready var pose_mode_btn: Button = $Main/Leftbar/ToggleButtons/PoseMode
@onready var speed_slider: HSlider = $song_speed
@onready var speed_slider_label: Label = $song_speed/Label
@onready var save_chart_dialogue: FileDialog = $SaveChart

var seconds_per_pixels: float = 0.02
var lane_names: Array = ["upLeft","left","downLeft","down","center","up","upRight","right","downRight"]
var chart_data: Array = []

var selection: int = -1
var drag_kind: String = ""
var active_lane: String = "up"
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
	seek.drag_started.connect(func():
		is_dragging = true
		# if paused (or not playing), start scrubbing visual immediately
		if (not audio.playing) or audio.stream_paused:
			playfield.set_scrub_time(seek.value)
	)

	seek.value_changed.connect(func(v: float):
		if is_dragging:
			# keep the audio cursor ready for resume
			if audio.stream:
				audio.seek(v)
			# while paused, drive visuals from scrub time
			if (not audio.playing) or audio.stream_paused:
				playfield.set_scrub_time(v)
	)

	seek.drag_ended.connect(func(changed: bool):
		is_dragging = false
		if changed and audio.stream:
			audio.seek(seek.value)
		# if still paused after drag, keep showing the chosen frame;
		# if playing or you immediately hit play, clear the override.
		if audio.playing and not audio.stream_paused:
			playfield.clear_scrub_time()
	)
	seek.step = 0.01
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
	# set initial pose name on playfield
	if pose_name.item_count > 0:
		playfield.pose_current_name = pose_name.get_item_text(pose_name.get_selected_id())

	pose_name.item_selected.connect(func(idx:int):
		playfield.pose_current_name = pose_name.get_item_text(idx)
	)

	pose_mode_btn.toggle_mode = true
	pose_mode_btn.toggled.connect(func(on: bool):
		playfield.pose_mode = on
		# optional: disable arrow ghost when in pose mode (so clicks don’t show ghost)
		playfield.ghost_enabled = !on
	)
	speed_slider.min_value = 0.25
	speed_slider.max_value = 2.0
	speed_slider.step = 0.05
	speed_slider.value = 1.0
	speed_slider.value_changed.connect(func(v: float):
		playfield.set_play_rate(v)
	)

func _process(delta: float) -> void:
	if audio.stream:
		if not is_dragging and (audio.playing and not audio.stream_paused):
			var t: float = audio.get_playback_position()
			seek.value = t
			current_time.text = "Current Time: %0.3f" % t

#signals
func _on_play_button_pressed() -> void:
	if not audio.stream:
		return
	# First press or resume
	if not audio.playing:
		audio.stream_paused = false
		audio.play()
		audio.seek(current_seek)
		playfield.clear_scrub_time()
		return
	# Toggle pause without resetting playback position
	if audio.stream_paused:
		audio.stream_paused = false
		playfield.clear_scrub_time()
	else:
		current_seek = audio.get_playback_position()
		audio.stream_paused = true
		playfield.set_scrub_time(current_seek)

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
	var data := JSON.stringify(playfield.chart_data, "\t")
	#var f := FileAccess.open("user://my_chart.json", FileAccess.WRITE)
	#new
	save_chart_dialogue.popup_centered()
	##>>>>
	#f.store_string(data)
	#f.close()
	#print("saving chart with : ", playfield.chart_data)


func _on_seek_value_changed(value: float) -> void:
	if audio.stream and is_dragging:
		audio.seek(value)
	if is_dragging and (not audio.playing or audio.stream_paused):
		current_seek = value
	current_time.text = "Current Time: %0.3f" % seek.value

func _on_bpm_changed(v: float) -> void:
	bpm = max(1.0, v)
	playfield.bpm = bpm
	playfield.build_bars_for_song(seek.max_value)

func _on_offset_changed(v: float) -> void:
	song_offset_ms = int(v)
	playfield.song_offset_ms = song_offset_ms
	# rebuild bar Y positions
	playfield.build_bars_for_song(seek.max_value)
	


func _on_add_arrows_pressed() -> void:
	playfield.ghost_enabled = true
	

func _on_erase_errows_pressed() -> void:
	playfield.ghost_enabled = false
	playfield.hold_enabled = false

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_P:
		pose_mode_btn.button_pressed = !pose_mode_btn.button_pressed
		pose_mode_btn.emit_signal("toggled", pose_mode_btn.button_pressed)



func _on_pose_mode_pressed() -> void:
	
	pass # Replace with function body.


func _on_song_speed_value_changed(value: float) -> void:
	speed_slider_label.text = "Song Speed: %f" % value
	pass # Replace with function body.


func _on_add_holds_pressed() -> void:
	playfield.hold_enabled = true
	print("playfield.hold_enabled is " , playfield.hold_enabled)

func _on_spin_box_value_changed(value: float) -> void:
	playfield.hold_duration = value


func _on_save_chart_file_selected(path: String) -> void:
	var data := JSON.stringify(playfield.chart_data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(data)
		f.close()
		print("Chart saved to: " , path)
	else:
		push_error("Failed to open file for writing: ", path)

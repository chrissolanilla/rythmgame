extends Control

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var play_button: Button = $BottomBar/PlayButton
@onready var current_time: Label = $BottomBar/CurrentTime
@onready var timeline: Control = $Main/Center/TimelineScroll/Timeline
@onready var seek: HSlider = $Seek
@onready var zoom: HSlider = $Zoom
@onready var record_mode: Button = $TopBar/RecordMode
@onready var snap_opt: OptionButton = $TopBar/Option
@onready var toggle_buttons: GridContainer = $Main/Leftbar/ToggleButtons
@onready var pose_track: Button = $Main/Leftbar/PoseTrack
@onready var erase: Button = $Main/Leftbar/Erase
@onready var waveform: Control = $Main/Center/Waveform
@onready var timeline_scroll: ScrollContainer = $Main/Center/TimelineScroll
@onready var hold_end_time: LineEdit = $Main/Inspector/holdEndTime
@onready var pose_name: OptionButton = $Main/Inspector/PoseName
@onready var convert_to_holdor_split: Button = $Main/Inspector/ConvertToHoldorSplit
@onready var delete: Button = $Main/Inspector/Delete
@onready var back_to_start: Button = $BottomBar/BackToStart
@onready var bpm_label: Label = $BottomBar/BPM
@onready var offset: SpinBox = $BottomBar/Offset
@onready var bpm_change_marker: Button = $BottomBar/BpmChangeMarker

#misc vars
var seconds_per_pixels :=0.02
var lane_names := ["upLeft","left","downLeft","down","center","up","upRight","right","downRight"]
var chart_data : Array = []
# index into chart_data, -1 = none
var selection := -1 
# "move", "resize_start", "resize_end"          
var drag_kind := ""      
# set from LeftBar lane toggles           
var active_lane := "up"    
# toggled by Pose Track button         
var placing_poses := false
# 4 = quarter notes          
var snap_div := 4   
var recording := false
var pending_hold := {}
var song_offset_ms: int = 0     
var bpm: float =120.0    
var is_dragging := false

func _ready():
	# wire editor state into the timeline
	timeline.scroll_container = timeline_scroll
	timeline.chart_data = chart_data
	timeline.bpm = bpm
	timeline.song_offset_ms = song_offset_ms
	timeline.seconds_per_pixel = 0.02  # zoom baseline
	timeline.snap_div = 4              # 1/4 by default
	timeline.audio = audio
	if timeline.audio and audio.stream:
		timeline.custom_minimum_size.y = max(3000.0, audio.stream.get_length() / timeline.seconds_per_pixel)
	timeline.queue_redraw()

	seek.drag_started.connect(func(): is_dragging = true)
	seek.drag_ended.connect(func(changed: bool):
		is_dragging = false
		if changed and audio.stream:
			audio.seek(seek.value)
	)
	seek.step =0.01
	# snap options
	snap_opt.clear()
	for v in [4,8,12,16,24,32]:
		snap_opt.add_item("1/%d" % v, v)
	snap_opt.select(0)

func _process(delta: float) -> void:
	if audio.stream:
		if not is_dragging:
			seek.value = audio.get_playback_position()
		current_time.text = "%0.3f" % audio.get_playback_position()
		#request redraw
		timeline.queue_redraw()
		
#signals
func _on_play_button_pressed() -> void:
	if not audio.stream: return
	if audio.playing: audio.stop()
	else: audio.play()

#func _on_zoom_value_changed(value: float) -> void:
	#if audio.stream and seek.is_drag_successful():
		#audio.seek(value)


func _on_open_audio_pressed() -> void:
	var fd := $Audio
	fd.filters = PackedStringArray(["*.wav ; WAV","*.mp3 ; MP3","*.ogg ; OGG"])
	fd.popup_centered()
	

func _on_audio_file_selected(path: String) -> void:
	var stream := ResourceLoader.load(path)
	if stream is AudioStream:
		audio.stream = stream
		seek.max_value = stream.get_length()
		seek.value = 0.0
		
func _on_open_chart_pressed() -> void:
	var fd := $Chart
	fd.filters = PackedStringArray(["*.json ; Chart JSON"])
	fd.popup_centered()
	

func _on_chart_file_selected(path: String) -> void:
	var t:= FileAccess.get_file_as_string(path)
	chart_data = JSON.parse_string(t) if t!= "" else []
	chart_data.sort_custom(func(a,b): return a["time"] < b["time"])
	timeline.queue_redraw()

func _on_save_chart_pressed() -> void:
	var data := JSON.stringify(chart_data, "\t")
	var f := FileAccess.open("user://my_chart.json", FileAccess.WRITE)
	f.store_string(data)
	f.close()


func _on_zoom_value_changed(value: float) -> void:
	#scale the vedrtical zoom
	timeline.seconds_per_pixel = 0.02 / clamp(value, 0.1, 10.0)
	timeline.queue_redraw()


func _on_seek_value_changed(value: float) -> void:
	if audio.stream and is_dragging:
		audio.seek(value)

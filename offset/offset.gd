extends Control

@onready var middle_note: BaseArrow = $MiddleNote
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var result_label: Label = $ResultLabel # optional

@export var bpm: float = 120.0
@export var hits_needed: int = 20  # how many taps to average over
@export var max_allowed_offset: float = 0.25 # seconds, ignore taps too far off

var beat_interval: float              # 60 / bpm
var metronome_time: float = 0.0       # our "song clock"
var next_beep_time: float = 0.0       # when to play next ping

var offsets: Array[float] = []        # signed time diffs (player - beat)

func _ready() -> void:
	# Hook the receptor press
	middle_note.arrow_pressed.connect(_on_center_pressed)

	beat_interval = 60.0 / bpm
	metronome_time = 0.0
	next_beep_time = 0.0
	offsets.clear()


func _process(delta: float) -> void:
	# advance our "song" timer
	metronome_time += delta

	# ----- PLAY PING SOUND EVERY BEAT -----
	while metronome_time >= next_beep_time:
		audio_stream_player.play()    # one-shot ping
		next_beep_time += beat_interval


func _on_center_pressed(direction: String) -> void:
	var t := metronome_time

	# Find the nearest beat time to now
	var n = round(t / beat_interval)
	var expected_time = n * beat_interval
	var signed_diff: float = t - expected_time   # + late, - early
	var abs_diff = abs(signed_diff)

	# Ignore wildly off presses (like mashing way off-beat)
	if abs_diff > max_allowed_offset:
		return

	offsets.append(signed_diff)
	_update_feedback_label()

	# When we have enough samples, compute the average and store it
	if offsets.size() >= hits_needed:
		var avg := _compute_average_offset()
		GlobalSettings.timing_offset = avg
		print("saving timing offset as: ", GlobalSettings.timing_offset)
		if result_label:
			result_label.text = "Computed offset: %.1f ms\n(Positive = you were late, Negative = you were early)" % (avg * 1000.0)


func _compute_average_offset() -> float:
	var sum := 0.0
	for d in offsets:
		sum += d
	return sum / float(offsets.size())


func _update_feedback_label() -> void:
	if result_label == null:
		return
	if offsets.is_empty():
		result_label.text = ""
		return

	var last_offset = offsets.back()
	var last_ms = last_offset * 1000.0
	var count := offsets.size()
	var avg := _compute_average_offset()
	var avg_ms := avg * 1000.0

	result_label.text = "Last: %.1f ms (%s)\nSamples: %d\nCurrent avg: %.1f ms" % [
		last_ms,
		"late" if last_ms > 0.0 else "early",
		count,
		avg_ms
	]


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

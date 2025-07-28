extends Node2D

@onready var music = $AudioStreamPlayer
var chart_data = []
var start_time = 0.0
var is_recording = false

# Input map: the same keys you already use in your game
var valid_inputs = [
	"upLeft", "up", "upRight",
	"left", "center", "right",
	"downLeft", "down", "downRight"
]

func _ready():
	start_time = Time.get_ticks_msec() / 1000.0
	music.play()
	is_recording = true
	print("🎵 Music started. Press keys now!")

func _input(event):
	if not is_recording:
		return

	if event is InputEventKey and event.pressed:
		for action in valid_inputs:
			if Input.is_action_pressed(action):
				var current_time = (Time.get_ticks_msec() / 1000.0) - start_time
				chart_data.append({
					"time": current_time,
					"direction": action
				})
				print("Recorded:", action, "at", current_time)
				break

	if Input.is_action_just_pressed("ui_cancel"):
		stop_recording()

func _process(_delta):
	if not music.is_playing() and is_recording:
		stop_recording()

func stop_recording():
	is_recording = false
	save_chart()
	print("✅ Recording finished. Chart saved!")

func save_chart():
	var json_data = JSON.stringify(chart_data, "\t")
	var file = FileAccess.open("user://recorded_chart.json", FileAccess.WRITE)
	file.store_string(json_data)
	file.close()
	print("📁 Saved to user://recorded_chart.json")

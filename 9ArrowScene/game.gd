extends Node2D

# Reference to the pause menu node
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var pose: Node = $UDP
var _last_t := 0.0
var test_play: bool = GlobalSettings.test_play

func _ready() -> void:
	print("Globalsettings.testplay is : ", GlobalSettings.test_play)
	pose.connect("pose_updated", Callable(self, "_on_pose"))
	pause_menu.visible = false  # ensure it starts hidden
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		# Read values from the file (with defaults in case they are missing)
		var vol := int(config.get_value("game", "volume", 50))  # 0..100
		vol = clamp(vol, 0, 100)
		var lin := pow(float(vol) / 100.0, 2.0)  # 0..1
		var bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(bus, linear_to_db(lin))
		#var masterVolumeInt = config.get_value("game", "volume") -50
		#var volume_db: float = volume_from_slider(masterVolumeInt)
		##Add the changing of volume of the master control
		#AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume_db))
func slider_to_db(user_vol: int) -> float:
	# Map 0–100 to -60 dB .. 0 dB with a perceptual curve
	var t := pow(float(user_vol) / 100.0, 2.0)  # tweak exponent (1.5–3.0) to taste
	return lerp(-60.0, 0.0, t)

	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # 'Esc' key by default mapped to ui_cancel
		_toggle_pause()

func _toggle_pause() -> void:
	if get_tree().paused:
		# Unpause
		get_tree().paused = false
		pause_menu.visible = false
		if not test_play:
			pause_menu.test_play = false
			
	else:
		# Pause
		get_tree().paused = true
		pause_menu.visible = true
		
func _on_pose():
	var pkt = pose.latest
	
	if pkt.get("changed", false):
		var g := String(pkt.get("gesture",""))
		if g != "": print("Do action for:", g)
		else: print("Gesture cleared")
		

extends Node2D

# Reference to the pause menu node
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var pose: Node = $UDP
var _last_t := 0.0

func _ready() -> void:
	pose.connect("pose_updated", Callable(self, "_on_pose"))
	pause_menu.visible = false  # ensure it starts hidden
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		# Read values from the file (with defaults in case they are missing)
		var masterVolumeInt = config.get_value("game", "volume")
		#Add the changing of volume of the master control
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(masterVolumeInt))
		

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # 'Esc' key by default mapped to ui_cancel
		_toggle_pause()

func _toggle_pause() -> void:
	if get_tree().paused:
		# Unpause
		get_tree().paused = false
		pause_menu.visible = false
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
		

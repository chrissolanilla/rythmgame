extends Control

# Default values if no saved settings exist
var default_volume := 0.0
var default_text := "[b][color=green]Game Volume[/color][/b]"
var arrow_scale: float = 0.2
var globalMapPath: String = ""
var volume: int = 0


func _ready() -> void:
	# Load saved settings if available
	_load_settings()

# Load settings from file, fallback to defaults
func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")

	if err == OK:
		# Read values from the file (with defaults in case they are missing)
		globalMapPath = config.get_value("game", "chartPath", "Empty")
		volume = config.get_value("game", "volume", 0)	
		$HSlider.value = volume
		#Add the changing of volume of the master control

# Load default values into UI
func _load_defaults() -> void:
	GlobalSettings.startingVolume = default_volume
	$HSlider.value = GlobalSettings.startingVolume

# Save settings to file
func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "volume", $HSlider.value)
	config.save("user://Settings.cfg")

# Confirm button pressed
func _on_confirm_pressed() -> void:
	_save_settings()
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

# Cancel button pressed
func _on_cancel_pressed() -> void:
	_load_defaults()  # revert unsaved changes

# Exit button pressed
func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

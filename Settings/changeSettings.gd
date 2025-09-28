extends Control

# Default values if no saved settings exist
var default_volume := 0.0
var scroll_speed = 300.0
var default_text := "[b][color=green]Game Volume[/color][/b]"
var arrow_scale: float = 0.2
var globalMapArray = []
var globalMapPath: String = ""
var startingIndex = 0
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
		globalMapArray = config.get_value("game", "chartPath", [])
		globalMapPath = globalMapArray[config.get_value("game","chartIndex", 0)]
		volume = config.get_value("game", "volume", 0)	
		scroll_speed = config.get_value("game","scrollSpeed", 1)
		$ScrollSpeedSlider.value = scroll_speed
		$HSlider.value = volume
		#Add the changing of volume of the master control

# Load default values into UI
func _load_defaults() -> void:
	GlobalSettings.startingVolume = default_volume
	GlobalSettings.scrollSpeed = scroll_speed
	$HSlider.value = GlobalSettings.startingVolume

# Save settings to file
func _save_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://Settings.cfg")
	if err != OK:
			return
	config.set_value("game", "volume", $HSlider.value)
	config.set_value("game", "scrollSpeed", $ScrollSpeedSlider.value)
	config.save("user://Settings.cfg")

# Confirm button pressed
func _on_confirm_pressed() -> void:
	_save_settings()
	GlobalSettings.load_data()
	print("finished loading settings. Scroll speed is: ", scroll_speed)
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

# Cancel button pressed
func _on_cancel_pressed() -> void:
	_load_defaults()  # revert unsaved changes

# Exit button pressed
func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")


func _on_value_changed(value: float) -> void:
	$RichTextLabel.text = "[b][color=green]Game Volume[/color][/b]: %d" % $HSlider.value
	pass # Replace with function body.


func _on_scroll_speed_slider_value_changed(value: float) -> void:
	$RichTextLabel2.text = "[b][color=green]Scroll Speed[/color][/b]: %d" % $ScrollSpeedSlider.value
	pass # Replace with function body.

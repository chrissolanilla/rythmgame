extends Control

# Default values if no saved settings exist
var default_volume := 0.0
var default_text := "[b][color=green]Game Volume[/color][/b]"

func _ready() -> void:
	# Load saved settings if available
	_load_settings()

# Load settings from file, fallback to defaults
func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://Settings/Settings.cfg")
	if err == OK:
		$HSlider.value = config.get_value("audio", "volume", default_volume)
	else:
		_load_defaults()

# Load default values into UI
func _load_defaults() -> void:
	$HSlider.value = default_volume
	$RichTextLabel.text = default_text

# Save settings to file
func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "volume", $HSlider.value)
	config.save("user://Settings/Settings.cfg")

# Confirm button pressed
func _on_confirm_pressed() -> void:
	_save_settings()
	print("Settings confirmed!")
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

# Cancel button pressed
func _on_cancel_pressed() -> void:
	_load_defaults()  # revert unsaved changes
	print("Changes canceled, reverted to defaults.")

# Exit button pressed
func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

extends Control

# ----------------------------
# Node references
# ----------------------------
@onready var Confirm: Button = $Confirm
@onready var slider: HSlider = $GameVolumeSlider
@onready var ScrollSpeedSlider: HSlider = $ScrollSpeedSlider
@onready var RichTextLabelVol: RichTextLabel = $RichTextLabel
@onready var RichTextLabelSpeed: RichTextLabel = $RichTextLabel2

# ----------------------------
# Lifecycle
# ----------------------------
func _ready() -> void:
	# Load current settings from GlobalSettings
	_load_settings()
	Confirm.grab_focus()

	# Update UI labels
	_update_volume_label(slider.value)
	_update_scroll_label(ScrollSpeedSlider.value)

# ----------------------------
# Load settings from GlobalSettings
# ----------------------------
func _load_settings() -> void:
	slider.value = GlobalSettings.startingVolume
	ScrollSpeedSlider.value = GlobalSettings.scrollSpeed

# ----------------------------
# Save settings to GlobalSettings
# ----------------------------
func _save_settings() -> void:
	GlobalSettings.startingVolume = slider.value
	GlobalSettings.scrollSpeed = ScrollSpeedSlider.value
	GlobalSettings.save_config()  # persist to disk
	print("Saved settings: Volume=", GlobalSettings.startingVolume, " ScrollSpeed=", GlobalSettings.scrollSpeed)

# ----------------------------
# Confirm button pressed
# ----------------------------
func _on_confirm_pressed() -> void:
	_save_settings()
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

# ----------------------------
# Cancel button pressed
# ----------------------------
func _on_cancel_pressed() -> void:
	_load_settings()  # revert unsaved changes
	_update_volume_label(slider.value)
	_update_scroll_label(ScrollSpeedSlider.value)

# ----------------------------
# Exit button pressed
# ----------------------------
func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")

# ----------------------------
# Slider callbacks
# ----------------------------
func _on_value_changed(value: float) -> void:
	_update_volume_label(value)

func _on_scroll_speed_slider_value_changed(value: float) -> void:
	_update_scroll_label(value)

# ----------------------------
# Helper UI updates
# ----------------------------
func _update_volume_label(value: float) -> void:
	RichTextLabelVol.text = "[b][color=green]Game Volume[/color][/b]: %d" % int(value)

func _update_scroll_label(value: float) -> void:
	RichTextLabelSpeed.text = "[b][color=green]Scroll Speed[/color][/b]: %d" % int(value)

# ----------------------------
# Offset button
# ----------------------------
func offset_pressed() -> void:
	get_tree().change_scene_to_file("res://offset/offset.tscn")

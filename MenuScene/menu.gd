extends Control

#@onready var button: Button = $"Edit Arrow Button"
#@onready var panel: Panel = $Panel
#@onready var hideButton: Button = $Panel/Close
#@onready var text_edit: TextEdit = $"Panel/Edit Size"
@onready var button_2: Button = $"Play Game Button"

func _on_quit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.


func _on_play_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuScene/SongSelections.tscn")
	pass # Replace with function body.


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://Settings/globalSettings.tscn")
	pass # Replace with function body.

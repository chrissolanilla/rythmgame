extends Control

@onready var Play: Button = $"Play Game Button"

func _ready() -> void:
	# Set up neighbors manually (you can also do this in the Inspector)
	Play.grab_focus()
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().gui_get_focus_owner().emit_signal("pressed")

func _on_quit_pressed() -> void: 
	get_tree().quit() 
	pass 
# Replace with function body. 

func _on_play_game_button_pressed() -> void: 
	get_tree().change_scene_to_file("res://MenuScene/SongSelections.tscn") 
	pass # Replace with function body. 
	
func _on_settings_pressed() -> void: 
	get_tree().change_scene_to_file("res://Settings/globalSettings.tscn") 
	pass # Replace with function body.		

extends Control

@onready var Play: Button = $"Play Game Button"

func _ready() -> void:
	# Set up neighbors manually (you can also do this in the Inspector)
	Play.grab_focus()
	
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


func _on_chart_creator_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ChartCreator/chart_creator.tscn")
	pass # Replace with function body.

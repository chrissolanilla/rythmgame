extends Control

func _ready() -> void:
	Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	
# Called when Resume button is pressed
func _on_resume_pressed() -> void:
	print("Resume Pressed")
	get_tree().paused = false
	visible = false

func _on_exit_pressed() -> void:
	print("Exit Pressed")
	get_tree().quit()
	pass # Replace with function body.

func _on_main_menu_pressed() -> void:
	print("Main Pressed")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MenuScene/Menu.tscn")
	pass # Replace with function body.


func _on_restart_pressed() -> void:
	print("Restart Pressed")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://9ArrowScene/Game.tscn")
	pass # Replace with function body.

extends Control

#@onready var button: Button = $"Edit Arrow Button"
#@onready var panel: Panel = $Panel
#@onready var hideButton: Button = $Panel/Close
#@onready var text_edit: TextEdit = $"Panel/Edit Size"
@onready var button_2: Button = $"Play Game Button"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_quit_pressed() -> void:
	get_tree().quit(	)
	pass # Replace with function body.


func _on_play_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://9ArrowScene/Game.tscn")
	pass # Replace with function body.

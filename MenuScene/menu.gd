extends Control

@onready var button: Button = $Button
@onready var panel: Panel = $Panel
@onready var hideButton: Button = $Panel/Button
@onready var text_edit: TextEdit = $Panel/TextEdit
@onready var button_2: Button = $Button2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	panel.hide()
	text_edit.text = "0.5"
	GlobalSettings.arrow_scale = 0.5
	print("Starting off, our arrow is ", GlobalSettings.arrow_scale)
	pass # Replace with function body.
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass



func _on_button_pressed() -> void:
	panel.show()
	pass # Replace with function body.


func _on_hide_button_pressed() -> void:
	panel.hide()
	pass # Replace with function body.


func _on_text_edit_text_changed() -> void:
	var new_text = text_edit.text
	GlobalSettings.arrow_scale = new_text
	print("Our new text is ", GlobalSettings.arrow_scale)
	pass # Replace with function body.


func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://ClassicFour/Game.tscn")
	pass # Replace with function body.

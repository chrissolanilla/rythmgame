extends Node2D

# Reference to the pause menu node
@onready var pause_menu = $CanvasLayer/PauseMenu

func _ready() -> void:
	pause_menu.visible = false  # ensure it starts hidden

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # 'Esc' key by default mapped to ui_cancel
		_toggle_pause()

func _toggle_pause() -> void:
	if get_tree().paused:
		# Unpause
		get_tree().paused = false
		pause_menu.visible = false
	else:
		# Pause
		get_tree().paused = true
		pause_menu.visible = true
		

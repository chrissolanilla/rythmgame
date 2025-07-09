extends Node

func _ready():
	var timer = Timer.new()
	timer.wait_time = 30.0
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", Callable(self, "_on_timeout"))
	timer.start()

func _on_timeout():
	print("30 seconds passed! Triggering event now.")
	get_tree().change_scene_to_file("res://MenuScene/Lost.tscn")

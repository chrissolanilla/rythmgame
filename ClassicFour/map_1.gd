extends Node2D

# Speed in pixels per second
@export var move_speed := 100

func _process(delta):
	# Move the entire scene up over time
	position.y -= move_speed * delta

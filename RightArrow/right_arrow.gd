extends BaseArrow

func _ready() -> void:
	direction = "right"
	baseColor = Color("fcf003", 0.35)
	pressedColor = Color("fcf003", 1.0)
	is_receptor = true
	print("x and y position: ", global_position.x, " " , global_position.y)

	super._ready()

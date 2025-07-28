extends BaseArrow

func _ready() -> void:
	direction = "downRight"
	baseColor = Color("c671ff", 0.35)
	pressedColor = Color("c671ff", 1.0)
	is_receptor = true
	print("x and y position: ", global_position.x, " " , global_position.y)

	super._ready()

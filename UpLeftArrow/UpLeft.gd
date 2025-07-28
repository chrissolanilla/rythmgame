extends BaseArrow

func _ready() -> void:
	direction = "upLeft"
	baseColor = Color("fc0303", 0.35)
	pressedColor = Color("fc0303", 1.0)
	is_receptor = true
	print("x and y position: ", global_position.x, " " , global_position.y)

	super._ready()

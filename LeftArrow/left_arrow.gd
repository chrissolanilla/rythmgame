extends BaseArrow

func _ready() -> void:
	direction = "left"
	baseColor = Color("032cfc", 0.35)
	pressedColor = Color("032cfc", 1.0)
	is_receptor = true
	print("x and y position: ", global_position.x, " " , global_position.y)

	super._ready()  # Now base _ready will copy direction into inputAction

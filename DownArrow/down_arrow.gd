extends BaseArrow

func _ready() -> void:
	direction = "down"
	baseColor = Color("e66600", 0.35)
	pressedColor = Color("e66600", 1.0)
	is_receptor = true


	super._ready()  # Now base _ready will copy direction into inputAction

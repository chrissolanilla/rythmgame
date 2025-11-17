extends BaseArrow

func _ready() -> void:
	direction = "down"
	baseColor = Color("e66600", 1)
	#pressedColor = Color("e66600", 1.0)
	pressedColor = Color("00fbff", 1.0)

	is_receptor = true


	super._ready()  # Now base _ready will copy direction into inputAction

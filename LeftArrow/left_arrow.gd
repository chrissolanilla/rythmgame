extends BaseArrow

func _ready() -> void:
	direction = "left"
	baseColor = Color("032cfc", 0.35)
	pressedColor = Color("032cfc", 1.0)
	is_receptor = true


	super._ready()  # Now base _ready will copy direction into inputAction

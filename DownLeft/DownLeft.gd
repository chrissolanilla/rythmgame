extends BaseArrow

func _ready() -> void:
	direction = "downLeft"
	baseColor = Color("c671ff", 0.85)
	#pressedColor = Color("c671ff", 1.0)
	pressedColor = Color("00fbff", 1.0)

	is_receptor = true


	super._ready()

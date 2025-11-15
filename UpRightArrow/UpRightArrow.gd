extends BaseArrow

func _ready() -> void:
	direction = "upRight"
	baseColor = Color("fc0303", 0.85)
	#pressedColor = Color("fc0303", 1.0)
	pressedColor = Color("00fbff", 1.0)

	is_receptor = true


	super._ready()

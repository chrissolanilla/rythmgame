extends BaseArrow

func _ready() -> void:
	direction = "upRight"
	baseColor = Color("fc0303", 0.35)
	pressedColor = Color("fc0303", 1.0)
	is_receptor = true


	super._ready()

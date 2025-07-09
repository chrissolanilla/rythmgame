extends BaseArrow

func _ready() -> void:
	direction = "up"
	baseColor = Color("00bf4b", 0.35)
	pressedColor = Color("00bf4b", 1.0)

	super._ready()

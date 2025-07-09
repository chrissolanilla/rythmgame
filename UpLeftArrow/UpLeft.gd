extends BaseArrow

func _ready() -> void:
	direction = "upLeft"
	baseColor = Color("c671ff", 0.35)
	pressedColor = Color("c671ff", 1.0)

	super._ready()

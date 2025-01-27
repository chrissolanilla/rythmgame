extends BaseArrow


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	arrowScale = GlobalSettings.arrow_scale
	scale = Vector2(arrowScale, arrowScale)
	baseColor = Color("c671ff", 0.35)
	pressedColor = Color("c671ff", 1.0)
	direction = "left"
	inputAction = "left"

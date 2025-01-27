extends BaseArrow


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	arrowScale = GlobalSettings.arrow_scale
	scale = Vector2(arrowScale, arrowScale)
	baseColor = Color("00bf4b", 0.35)
	pressedColor = Color("00bf4b", 1.0)
	direction = "up"
	inputAction = "up"

extends BaseArrow

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	arrowScale = GlobalSettings.arrow_scale
	scale = Vector2(arrowScale, arrowScale)
	baseColor = Color("e66600", 0.35)
	pressedColor = Color("e66600", 1.0)
	direction = "down"
	inputAction = "down"

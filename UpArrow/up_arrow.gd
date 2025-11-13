extends BaseArrow
var arrow = self
func _ready() -> void:
	direction = "up"
	baseColor = Color("00bf4b", 0.85)
	pressedColor = Color("00bf4b", 1.0)
	is_receptor = true


	super._ready()

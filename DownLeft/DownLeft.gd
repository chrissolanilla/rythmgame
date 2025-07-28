extends BaseArrow

func _ready() -> void:
	direction = "downLeft"
	baseColor = Color("c671ff", 0.35)
	pressedColor = Color("c671ff", 1.0)
	is_receptor = true


	super._ready()

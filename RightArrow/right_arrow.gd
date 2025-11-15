extends BaseArrow

func _ready() -> void:
	direction = "right"
	baseColor = Color("fcf003", 0.85)
	pressedColor = Color("fcf003", 1.0)
	pressedColor = Color("00fbff", 1.0)
	is_receptor = true


	super._ready()

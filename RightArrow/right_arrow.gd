extends BaseArrow

func _ready() -> void:
	direction = "right"
	baseColor = Color("fcf003", 0.35)
	pressedColor = Color("fcf003", 1.0)
	is_receptor = true


	super._ready()

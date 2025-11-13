extends BaseArrow

@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite_2d.z_index = 2
	direction = "center"
	baseColor = Color("c671ff", 0.85)
	pressedColor = Color("c671ff", 1.0)
	is_receptor = true


	super._ready()

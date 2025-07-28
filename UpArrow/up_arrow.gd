extends BaseArrow
var arrow = self
func _ready() -> void:
	direction = "up"
	baseColor = Color("00bf4b", 0.35)
	pressedColor = Color("00bf4b", 1.0)
	is_receptor = true
	print("x and y position: ", global_position.x, " " , global_position.y)
	
	print("Spawning note at:", arrow.position)
	print("Direction:", arrow.direction)
	print("Polygon2D exists:", arrow.has_node("Polygon2D"))
	print("Polygon2D size:", arrow.get_node("Polygon2D").polygon.size())


	super._ready()

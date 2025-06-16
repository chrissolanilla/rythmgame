extends Node2D
class_name BaseArrow
@onready var superman := get_node("../Superman")
var arrowScale: float
var baseColor: Color
var pressedColor: Color
var direction: String
var inputAction: String
var transitionSpeed: float = 5.0
var scaled: bool = false
@onready var polygon_2d: Polygon2D = $Polygon2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	arrowScale = GlobalSettings.arrow_scale
	scale = Vector2(arrowScale, arrowScale)
	inputAction = direction
	print("the scale is ", arrowScale)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if not scaled:
		#scale = Vector2(arrowScale,arrowScale)
		#scaled = true
		#print("we scaled")
	#scale = Vector2(arrowScale,arrowScale)
	if Input.is_action_just_pressed(inputAction):
		polygon_2d.color = pressedColor
		#also rotate our superhero
		if direction == "left":
			superman.rotation+= deg_to_rad(-10)
		if direction == "right":
			superman.rotation+= deg_to_rad(10)
		if direction == "up":
			# Move forward relative to Superman's rotation at a speed of 50
			var local_forward = Vector2(0, -1)  # "up" in local space
			local_forward = local_forward.rotated(superman.rotation)
			superman.velocity = local_forward * 500

		if direction == "down":
			# Move forward relative to Superman's rotation at a speed of 50
			var local_down = Vector2(0, -1)  # "up" in local space
			local_down = local_down.rotated(superman.rotation)
			superman.velocity = local_down * -500

	else:
		polygon_2d.color = polygon_2d.color.lerp(baseColor, delta*transitionSpeed)
	#make it so that if the corresponding input(left arrow, right arrow ect) is pressed, make it go from transparent to full opacity
	#for the polygon2d
	pass

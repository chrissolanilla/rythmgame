extends Node2D
class_name BaseArrow

var baseColor: Color = Color(1, 1, 1, 0.35)
var pressedColor: Color = Color(1, 1, 1, 1)
var direction: String = ""
var inputAction: String = ""
var transitionSpeed: float = 5.0

# Delay before showing pressed color (seconds)
@export var press_delay: float = 0.1

# Internal timer and state
var press_timer: float = 0.0
var is_pressing: bool = false

@onready var polygon_2d: Polygon2D = $Polygon2D

func _ready() -> void:

	if inputAction == "":
		inputAction = direction

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(inputAction):
		polygon_2d.color = pressedColor
	else:
		polygon_2d.color = polygon_2d.color.lerp(baseColor, delta*transitionSpeed)
	pass

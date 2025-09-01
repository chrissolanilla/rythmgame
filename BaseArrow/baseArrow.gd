extends Node2D
class_name BaseArrow
# true = stationary arrow that listens for input
@export var is_receptor: bool = false  

var baseColor: Color = Color(1, 1, 1, 0.35)
var pressedColor: Color = Color(1, 1, 1, 1)
var direction: String = ""
var inputAction: String = ""
var transitionSpeed: float = 5.0
var note_time: float
var is_Hold: bool = false
var end_Time: float

@export var press_delay: float = 0.1
var press_timer: float = 0.0
var is_pressing: bool = false

@onready var polygon_2d: Polygon2D = $Polygon2D

signal arrow_pressed(direction: String)

func _ready() -> void:
	if inputAction == "":
		inputAction = direction
		#if is_receptor:
			#print("Set inputAction = ", inputAction)

func _process(delta: float) -> void:
	if not is_receptor:
		return

	if Input.is_action_just_pressed(inputAction):
		emit_signal("arrow_pressed", direction)
		polygon_2d.color = pressedColor
	else:
		polygon_2d.color = polygon_2d.color.lerp(baseColor, delta * transitionSpeed)

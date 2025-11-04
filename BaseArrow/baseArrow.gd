extends Node2D
class_name BaseArrow
# true = stationary arrow that listens for input
@export var is_receptor: bool = false
@onready var tail: Sprite2D = $Tail
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
signal arrow_released(direction: String)

func _ready() -> void:
	if $Tail and not is_Hold:
		$Tail.visible = false
	if inputAction == "":
		inputAction = direction
		#if is_receptor:
			#print("Set inputAction = ", inputAction)
	if baseColor:
		polygon_2d.color = pressedColor

func _process(delta: float) -> void:
	if not is_receptor:
		return

	if Input.is_action_just_pressed(inputAction):
		emit_signal("arrow_pressed", direction)
		polygon_2d.color = pressedColor
	elif Input.is_action_just_released(inputAction):
		emit_signal("arrow_released", direction)
	else:
		if not Input.is_action_pressed(inputAction):
			polygon_2d.color = polygon_2d.color.lerp(baseColor, delta * transitionSpeed)

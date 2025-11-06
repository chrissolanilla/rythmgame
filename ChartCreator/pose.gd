extends Node2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var pose_name: Label = $PoseName
@onready var countdown: Label = $Countdown

var countdown_string: String
var pose_name_string: String
var sprite_path: String
var time: float
var countDown : float
var window : float
func _ready() -> void:
	countdown.text = countdown_string
	pose_name.text = pose_name_string
	#sprite.texture = load(sprite_path)

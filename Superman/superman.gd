extends CharacterBody2D

# Gravity pulling downward
const GRAVITY = 50.0

# How often (in seconds) to pick a new random velocity
const RANDOM_INTERVAL = 2.0

# Max speed range for random velocity
const MAX_RANDOM_SPEED = 100.0

var time_since_random: float = 0.0

func _ready() -> void:
	# Make sure random values differ each run
	randomize()

func _physics_process(delta: float) -> void:
	# 1) Apply gravity to the built-in velocity property
	velocity.y += GRAVITY * delta

	# 2) Move according to that velocity (move_and_slide() returns bool in Godot 4)
	move_and_slide()

	# 3) Every few seconds, pick a new random velocity
	time_since_random += delta
	if time_since_random >= RANDOM_INTERVAL:
		time_since_random = 0.0
		velocity = Vector2(
			randf_range(-MAX_RANDOM_SPEED, MAX_RANDOM_SPEED),
			randf_range(-MAX_RANDOM_SPEED, MAX_RANDOM_SPEED)
		)

	# 4) If Superman leaves the viewport, switch to Game Over scene
	var viewport_rect = get_viewport().get_visible_rect()
	if not viewport_rect.has_point(global_position):
		get_tree().change_scene_to_file("res://MenuScene/gameOver.tscn")

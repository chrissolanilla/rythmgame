extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	show_stats()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func show_stats() -> void:
	var perfectCounter = GlobalSettings.perfectCounter
	var goodCounter = GlobalSettings.goodCounter
	var badCounter = GlobalSettings.badCounter
	var missCounter = GlobalSettings.missCounter
	$Stats.text = "Perfect: %d\nGood:       %d\nBad:         %d\nMiss:        %d\n" % [perfectCounter, goodCounter, badCounter, missCounter]

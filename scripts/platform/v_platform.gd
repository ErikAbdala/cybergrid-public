extends AnimatableBody2D
class_name VPlatform

@export var amplitude := 64.0
@export var speed := 2.2

@onready var start_position : Vector2 = global_position
@onready var elapsed_time := 0.0

func _physics_process(delta):
	if get_tree().paused:
		return
	elapsed_time += delta * speed
	var offset = sin(elapsed_time) * amplitude
	global_position.y = start_position.y + offset

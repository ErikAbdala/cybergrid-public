extends AnimatableBody2D
class_name HPlatform

@export var speed := 160

@onready var path_follow : PathFollow2D = get_parent()
@onready var path_direction := 1

func _physics_process(delta: float) -> void:
	path_follow.progress += speed * path_direction * delta
	var new_progress_ratio = path_follow.progress_ratio
	if new_progress_ratio == 0 or new_progress_ratio == 1:
		path_direction *= -1

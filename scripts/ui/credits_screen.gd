extends Control
class_name CreditsScreen

@export_range(1, 10000, 0.1) var credits_speed : float = 50.0
@export_range(0, 5, 0.1) var initial_delay : float = 1.0

@onready var margin : MarginContainer = $Panel/MarginContainer
@onready var text_node : RichTextLabel = $Panel/MarginContainer/RichTextLabel

func _ready() -> void:
	
	var window_height = get_viewport_rect().size.y
	var text_height = text_node.size.y
	
	margin.position.y = window_height
	
	await get_tree().create_timer(initial_delay).timeout
	
	var total_distance = window_height + text_height
	var animation_time = total_distance / credits_speed
	var tween = create_tween()
	
	tween.tween_property(
		margin,
		"position:y",
		-text_height,
		animation_time
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	
	await tween.finished
	_on_credits_finished()

func _on_credits_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

extends Control
class_name EndScreen

@onready var score_value_label: Label = $Panel/ScoreValueLabel

func _ready() -> void:
	score_value_label.text = str(GameManager.total_score)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("select"):
		GameManager.reset_system()
		get_tree().change_scene_to_file("res://scenes/ui/credits_screen.tscn")

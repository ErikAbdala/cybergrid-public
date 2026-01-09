extends Control
class_name DeathMenu

@onready var restart_button : Button = $Panel/Panel/VBoxContainer/RestartButton

signal restart_data_validation()

func _on_restart_button_pressed() -> void:
	GameManager.consecutive_deaths += 1
	emit_signal("restart_data_validation")
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	GameManager.reset_system()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

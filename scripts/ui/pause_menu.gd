extends Control
class_name PauseMenu

@onready var hud := get_parent().get_node_or_null("HUD")
@onready var death_menu := get_parent().get_node_or_null("DeathMenu")
@onready var window_mode_label : Label = $Panel/HBoxContainer/WindowModeLabel
@onready var controls_panel_label : Label = $Panel/HBoxContainer/ControlsLabel
@onready var controls_panel : Panel = $Panel/ControlsSection

func _ready() -> void:
	var window_mode = DisplayServer.window_get_mode()
	if window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		window_mode_label.text = "[F] DESATIVAR TELA CHEIA"
	else:
		window_mode_label.text = "[F] ATIVAR TELA CHEIA"

func _input(event: InputEvent) -> void:
	if death_menu and death_menu.visible:
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = !get_tree().paused
		visible = get_tree().paused
		if hud:
			hud.visible = !visible
	elif event.is_action_pressed("controls") and visible:
		controls_panel.visible = !controls_panel.visible
		if controls_panel.visible:
			controls_panel_label.text = '[C] ESCONDER CONTROLES'
		else:
			controls_panel_label.text = '[C] MOSTRAR CONTROLES'

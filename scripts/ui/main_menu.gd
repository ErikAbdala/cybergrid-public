extends Control
class_name MainMenu

@onready var main_screen: Panel = $MainScreen
@onready var start_button : Button = $MainScreen/MenuButtons/VBoxContainer/StartButton
@onready var controls_button : Button = $MainScreen/MenuButtons/VBoxContainer/ControlsButton
@onready var options_button : Button = $MainScreen/MenuButtons/VBoxContainer/OptionsButton
@onready var exit_button : Button = $MainScreen/MenuButtons/VBoxContainer/ExitButton
@onready var controls_screen : Panel = $ControlsScreen
@onready var quit_screen : Panel = $QuitScreen
@onready var exit_confirm_button : Button = $QuitScreen/QuitMenu/VBoxContainer/ConfirmButton
@onready var navigation_select : Panel = $NavigationSection/Select
@onready var navigation_navigate : Panel = $NavigationSection/Navigate
@onready var navigation_return : Panel = $NavigationSection/Return
@onready var options_screen: Panel = $OptionsScreen
@onready var fullscreen_check: CheckButton = $OptionsScreen/FullscreenCheckButton

enum State_Machine {
	MAIN,
	CONTROLS,
	OPTIONS,
	EXIT
}

var State : State_Machine = State_Machine.MAIN

func _ready() -> void:
	start_button.grab_focus()

func _process(_delta: float) -> void:
	if (State == State_Machine.CONTROLS) or (State == State_Machine.OPTIONS):
		if Input.is_action_pressed("go_back"):
			State = State_Machine.MAIN
			_return_to_main_menu()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/tutorial/tutorial_level_01.tscn")

func _on_controls_button_pressed() -> void:
	State = State_Machine.CONTROLS
	main_screen.visible = false
	controls_screen.visible = true
	quit_screen.visible = false
	navigation_select.visible = false
	navigation_navigate.visible = false
	navigation_return.visible = true

func _on_options_button_pressed() -> void:
	State = State_Machine.OPTIONS
	main_screen.visible = false
	controls_screen.visible = false
	quit_screen.visible = false
	navigation_select.visible = false
	navigation_navigate.visible = false
	navigation_return.visible = true
	#navigation_return.position.y = -21
	options_screen.visible = true

func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/credits_screen.tscn")

func _on_exit_button_pressed() -> void:
	State = State_Machine.EXIT
	main_screen.visible = false
	controls_screen.visible = false
	quit_screen.visible = true
	exit_confirm_button.grab_focus()

func _on_quit_confirm_button_pressed() -> void:
	get_tree().quit()

func _on_quit_cancel_button_pressed() -> void:
	State = State_Machine.MAIN
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	main_screen.visible = true
	controls_screen.visible = false
	options_screen.visible = false
	quit_screen.visible = false
	navigation_select.visible = true
	navigation_navigate.visible = true
	#navigation_return.position.y = 4
	navigation_return.visible = false
	start_button.grab_focus()

func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

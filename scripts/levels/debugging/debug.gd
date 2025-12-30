extends Node2D
class_name Debug

@onready var portal : AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var camera : Camera2D = $Player/Camera2D2
@onready var player : Player = $Player
@onready var punk_1 : Punk = $Punk
@onready var riot_1 : Riot = $Riot
@onready var pause_menu : PauseMenu = $UI/PauseMenu
@onready var hud : HUD = $UI/HUD

var portal_area_entered := false
var objectives_completed := false
var elapsed_time: float = 0.0

var teste = 0

var objectives : Array = [
	[
		'Derrote todos os inimigos para ativar o portal!',
		'Todos os inimigos foram derrotados!',
		false, false
	]
]

enum Portal_State_Machine {
	DEACTIVATED,
	ACTIVATING,
	ACTIVATED
}

var Portal_State : Portal_State_Machine = Portal_State_Machine.DEACTIVATED

# =============================================================
#                         Main Functions
# =============================================================

func _ready() -> void:
	player.connect("health_changed", Callable(hud, "_update_health"))
	hud._initialize_healthbar(player.health)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	#var win_size = Vector2i(1280, 720)
	var win_size = Vector2i(854, 480)
	DisplayServer.window_set_size(win_size)
	_center_window(win_size)
	#hud._show_objectives_message(objectives[0][0])
	player.parry_attempt.connect(_update_player_performance)
	
	var animation : Animation
	var track_idx : int
	
	animation = punk_1.anim_player.get_animation("attack")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, 0.5)
	
	track_idx = animation.find_track('.:material:shader_parameter/active', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, true)
	
	track_idx = animation.find_track('../ParryHintLabel:visible', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, true)
	
	animation = punk_1.anim_player.get_animation("stunned")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, 0.5)
	
	
	
	animation = riot_1.anim_player.get_animation("attack")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, 0.8)
	
	track_idx = animation.find_track('.:material:shader_parameter/active', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, true)
	
	track_idx = animation.find_track('../ParryHintLabel:visible', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, true)
	
	animation = riot_1.anim_player.get_animation("stunned")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, 0.5)

func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
	if Input.is_key_pressed(KEY_P):
		print(format_time(elapsed_time))
		print(elapsed_time)

func _physics_process(delta: float) -> void:
	
	elapsed_time += delta
	
	match Portal_State:
		
		Portal_State_Machine.DEACTIVATED: _portal_state_deactivated()
		Portal_State_Machine.ACTIVATING: _portal_state_activating()
		Portal_State_Machine.ACTIVATED: _portal_state_activated()
	
	if not objectives_completed:
		if punk_1:
			if punk_1.defeated and not objectives[0][2]:
				Portal_State = Portal_State_Machine.ACTIVATING
				objectives[0][2] = true
				#hud._show_objectives_message(objectives[0][1], '#008000')
				objectives_completed = true
	
	if player.global_position.y > camera.limit_bottom + 50: # margem extra opcional
		player.fall_off_screen = true
		player.State = player.State_Machine.DEATH
	
	if objectives_completed and portal_area_entered:
		hud.interact_label.visible = true
		if Input.is_key_pressed(KEY_T):
			print('Entrou no portal!')
	else:
		if hud:
			hud.interact_label.visible = false

func _on_portal_animation_finished() -> void:
	match portal.animation:
		'activating':
			Portal_State = Portal_State_Machine.ACTIVATED

func _on_portal_area_entered(area: Area2D) -> void:
	if area == player.hurtbox and Portal_State == Portal_State_Machine.ACTIVATED:
		portal_area_entered = true

func _on_portal_area_exited(area: Area2D) -> void:
	if area == player.hurtbox and Portal_State == Portal_State_Machine.ACTIVATED:
		portal_area_entered = false

# =============================================================
#                Portal State Machine Functions
# =============================================================

func _portal_state_deactivated():
	_play_animation('deactivated')

func _portal_state_activating():
	_play_animation('activating')

func _portal_state_activated():
	_play_animation('activated')

# =============================================================
#                      Auxiliary Functions
# =============================================================

func _center_window(win_size: Vector2i):
	# Pega o tamanho da tela do monitor principal
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	# Calcula posição para centralizar
	var pos = (screen_size - win_size) / 2
	# Aplica
	DisplayServer.window_set_position(pos)

func _play_animation(anim_name: StringName) -> void:
	if portal.animation != anim_name:
		portal.play(anim_name)

func _update_player_performance(data) -> void:
	teste += 1
	print(teste)
	print(data)

func format_time(time_sec: float) -> String:
	var minutes = int(time_sec) / 60
	var seconds = int(time_sec) % 60
	var milliseconds = int((time_sec - int(time_sec)) * 100)
	return "%02d:%02d:%02d" % [minutes, seconds, milliseconds]

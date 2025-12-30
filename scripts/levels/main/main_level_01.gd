extends Node2D
class_name Level01

@onready var hud : HUD = $UI/HUD
@onready var player : Player = $Player
@onready var camera : Camera2D = $Player/Camera2D
@onready var portal : AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var laser_wall_a : AnimatedSprite2D = $LaserWallA/AnimatedSprite2D
@onready var laser_wall_a_collision : CollisionShape2D = $LaserWallA/CollisionShape2D
@onready var laser_wall_b : AnimatedSprite2D = $LaserWallB/AnimatedSprite2D
@onready var laser_wall_b_collision : CollisionShape2D = $LaserWallB/CollisionShape2D
@onready var score_multiplier_timer : Timer = $ScoreMultiplierTimer
@onready var laser_wall_on_timer : Timer = $LaserWallOnTimer
@onready var laser_wall_off_timer : Timer = $LaserWallOffTimer
@onready var level_title_timer : Timer = $LevelTitleTimer
@onready var level_hint_timer : Timer = $LevelHintTimer
@onready var death_menu : DeathMenu = $UI/DeathMenu

const LEVEL_TITLE := 'FASE 1'
const LEVEL_HINT := "DERROTAR INIMIGOS LHE DARÁ PONTOS.
VOCÊ RECEBERÁ UM BÔNUS SE DERROTAR INIMIGOS LOGO APÓS UM PARRY BEM SUCEDIDO."

const OBJECTIVES := {
	"uncleared": "- Derrote todos os inimigos",
	"cleared": "- Fase finalizada!\nProssiga para o portal"
}

var player_performance := {
	"platform_data": {
		"fall_deaths": 0,
		"laser_deaths": 0,
	},
	"combat_data": {
		"punk": {
			"damage_taken": 0,
			"defeated_player": 0
		},
		"riot": {
			"damage_taken": 0,
			"defeated_player": 0
		},
	},
	"parry_data": {
		"punk": {
			"parry_attempts": 0,
			"successful_parries": 0
		},
		"riot": {
			"parry_attempts": 0,
			"successful_parries": 0
		}
	}
}

var current_objective := ''
var objectives_completed := false
var portal_area_entered := false
var elapsed_time := 0.0
var level_score := 0

enum Portal_State_Machine {
	DEACTIVATED,
	ACTIVATING,
	ACTIVATED
}

var Portal_State : Portal_State_Machine = Portal_State_Machine.DEACTIVATED

enum Laser_Wall_State_Machine {
	DEACTIVATED,
	ACTIVATED
}

var Laser_Wall_A_State : Laser_Wall_State_Machine = Laser_Wall_State_Machine.ACTIVATED
var Laser_Wall_B_State : Laser_Wall_State_Machine = Laser_Wall_State_Machine.ACTIVATED

# =============================================================
#                         Main Functions
# =============================================================

func _ready() -> void:
	player.connect("health_changed", Callable(hud, "_update_health"))
	player.defeated_by_enemy.connect(_update_player_defeats)
	player.damage_taken.connect(_update_player_damage_taken)
	player.parry_attempt.connect(_update_player_parry_attempts)
	player.parry_successful.connect(_update_player_parries)
	death_menu.restart_data_validation.connect(_validate_data_on_restart)
	_init_settings()
	_validate_DDA()

func _physics_process(delta: float) -> void:
	
	elapsed_time += delta
	
	_validate_objectives()
	
	if (player.global_position.y > camera.limit_bottom + 50) and not death_menu.visible:
		hud.visible = false
		player.health = 0
		player.State = player.State_Machine.DEATH
		player_performance.platform_data.fall_deaths += 1
		death_menu.visible = true
		death_menu.restart_button.grab_focus()
	
	if player.health == 0:
		player.State = player.State_Machine.DEATH
	
	match Portal_State:
		Portal_State_Machine.DEACTIVATED: _play_animation('portal', 'deactivated')
		Portal_State_Machine.ACTIVATING: _play_animation('portal', 'activating')
		Portal_State_Machine.ACTIVATED: _play_animation('portal', 'activated')
	
	match Laser_Wall_A_State:
		Laser_Wall_State_Machine.DEACTIVATED: _play_animation('laser_wall_a', 'deactivated')
		Laser_Wall_State_Machine.ACTIVATED: _play_animation('laser_wall_a', 'activated')
	
	match Laser_Wall_B_State:
		Laser_Wall_State_Machine.DEACTIVATED: _play_animation('laser_wall_b', 'deactivated')
		Laser_Wall_State_Machine.ACTIVATED: _play_animation('laser_wall_b', 'activated')
	
	if Portal_State == Portal_State_Machine.ACTIVATED and objectives_completed and portal_area_entered:
		if hud:
			hud.interact_label.visible = true
		if Input.is_action_just_pressed('interact'):
			GameManager.submit_phase_data(
				player_performance.combat_data,
				player_performance.parry_data,
				player_performance.platform_data,
				true
			)
			var time_spent = int(elapsed_time) % 60
			GameManager.submit_player_score(level_score, time_spent)
			GameManager.advance_to_next_phase()
			get_tree().change_scene_to_file("res://scenes/levels/main/main_level_02.tscn")
	elif hud:
		hud.interact_label.visible = false

func _on_portal_animation_finished() -> void:
	match portal.animation:
		'activating':
			Portal_State = Portal_State_Machine.ACTIVATED

func _on_portal_area_entered(area: Area2D) -> void:
	if area == player.hurtbox:
		portal_area_entered = true

func _on_portal_area_exited(area: Area2D) -> void:
	if area == player.hurtbox:
		portal_area_entered = false

func _on_laser_wall_a_area_entered(_area: Area2D) -> void:
	hud.visible = false
	player.health = 0
	player.State = player.State_Machine.DEATH
	player_performance.platform_data.laser_deaths += 1
	death_menu.visible = true
	death_menu.restart_button.grab_focus()

func _on_laser_wall_b_area_entered(_area: Area2D) -> void:
	hud.visible = false
	player.health = 0
	player.State = player.State_Machine.DEATH
	player_performance.platform_data.laser_deaths += 1
	death_menu.visible = true
	death_menu.restart_button.grab_focus()

func _on_laser_wall_on_timer_timeout() -> void:
	Laser_Wall_A_State = Laser_Wall_State_Machine.DEACTIVATED
	Laser_Wall_B_State = Laser_Wall_State_Machine.DEACTIVATED
	laser_wall_a_collision.disabled = true
	laser_wall_b_collision.disabled = true
	laser_wall_off_timer.start()

func _on_laser_wall_off_timer_timeout() -> void:
	Laser_Wall_A_State = Laser_Wall_State_Machine.ACTIVATED
	Laser_Wall_B_State = Laser_Wall_State_Machine.ACTIVATED
	laser_wall_a_collision.disabled = false
	laser_wall_b_collision.disabled = false
	laser_wall_on_timer.start()

func _on_level_title_timer_timeout() -> void:
	if hud:
		hud._clear_level_title_text()
		hud._show_objective_txt(OBJECTIVES.uncleared)
		hud._show_level_hint_text(LEVEL_HINT)
		level_hint_timer.start()

func _on_level_hint_timer_timeout() -> void:
	if hud:
		hud._clear_level_hint_text()

func _validate_DDA() -> void:
	
	if not GameManager.DDA_ACTIVE:
		return
	
	var deaths := GameManager.consecutive_deaths
	
	if deaths == 0 or deaths == 5:
		GameManager.consecutive_deaths = 0
		GameManager.on_reload_data = {}
	else:
		player_performance = GameManager.on_reload_data
	
	_apply_difficulty_to_enemies()
	_apply_difficulty_to_platforms()

# =============================================================
#                      Auxiliary Functions
# =============================================================

func _play_animation(type: String, anim_name: StringName) -> void:
	if type == 'portal':
		if portal.animation != anim_name:
			portal.play(anim_name)
	elif type == 'laser_wall_a':
		if laser_wall_a.animation != anim_name:
			laser_wall_a.play(anim_name)
	elif type == 'laser_wall_b':
		if laser_wall_b.animation != anim_name:
			laser_wall_b.play(anim_name)

func _init_settings() -> void:
	_init_enemies()
	GameManager.current_phase = GameManager.Phase.PHASE_1
	level_score = GameManager.total_score
	hud._initialize_score(level_score)
	hud._initialize_healthbar(player.health)
	hud._show_level_title_text(LEVEL_TITLE)
	level_title_timer.start()

func _init_enemies() -> void:
	
	var punks = get_tree().get_nodes_in_group("punk")
	var riots = get_tree().get_nodes_in_group("riot")
	var facing_left_enemies = get_tree().get_nodes_in_group("facing-left-enemies")
	
	for punk in punks:
		punk.punk_defeated.connect(_update_player_score)
	
	for riot in riots:
		riot.riot_defeated.connect(_update_player_score)
		riot.left_bounds = riot.spawn_position + Vector2(-32, 0)
		riot.right_bounds = riot.spawn_position + Vector2(32, 0)
	
	for enemy in facing_left_enemies:
		enemy.facing_right = false
		enemy._adjust_orientation(true)

func _update_player_damage_taken(enemy: String, amount: int) -> void:
	if enemy == 'Punk':
		player_performance.combat_data.punk.damage_taken += amount
	elif enemy == 'Riot':
		player_performance.combat_data.riot.damage_taken += amount

func _update_player_defeats(enemy: String) -> void:
	if enemy == 'Punk':
		player_performance.combat_data.punk.defeated_player += 1
	elif enemy == 'Riot':
		player_performance.combat_data.riot.defeated_player += 1
	death_menu.visible = true
	death_menu.restart_button.grab_focus()

func _update_player_parry_attempts(enemy: String) -> void:
	if enemy == 'Punk':
		player_performance.parry_data.punk.parry_attempts += 1
	elif enemy == 'Riot':
		player_performance.parry_data.riot.parry_attempts += 1

func _update_player_parries(enemy: String) -> void:
	if enemy == 'Punk':
		player_performance.parry_data.punk.successful_parries += 1
	elif enemy == 'Riot':
		player_performance.parry_data.riot.successful_parries += 1
	if score_multiplier_timer.time_left <= 0:
		score_multiplier_timer.start()

func _validate_data_on_restart() -> void:
	if GameManager.DDA_ACTIVE:
		if GameManager.consecutive_deaths == 5:
			GameManager.submit_phase_data(
				player_performance.combat_data,
				player_performance.parry_data,
				player_performance.platform_data,
				false
			)
		else:
			GameManager.on_reload_data = player_performance

func _apply_difficulty_to_enemies() -> void:
	
	var punk_params = GameManager.get_enemy_params("punk")
	var riot_params = GameManager.get_enemy_params("riot")
	
	player.punk_damage = punk_params["damage"]
	player.riot_damage = riot_params["damage"]
	
	var punks = get_tree().get_nodes_in_group("punk")
	var riots = get_tree().get_nodes_in_group("riot")
	
	for punk in punks:
		_configure_punk(punk, punk_params)
	
	for riot in riots:
		_configure_riot(riot, riot_params)

func _configure_punk(punk: Node, params: Dictionary) -> void:
	
	punk.health = params["health"]
	punk.speed = params["speed"]
	punk.acceleration = params["acceleration"]
	
	var animation : Animation
	var track_idx : int
	
	animation = punk.anim_player.get_animation("attack")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, params["attack_speed"])
	
	track_idx = animation.find_track('.:material:shader_parameter/active', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, params["flash_enabled"])
	
	track_idx = animation.find_track('../ParryHintLabel:visible', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, params["flash_enabled"])
	
	animation = punk.anim_player.get_animation("stunned")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, params["stun_speed"])

func _configure_riot(riot: Node, params: Dictionary) -> void:
	
	riot.health = params["health"]
	riot.chase_speed = params["speed"]
	riot.acceleration = params["acceleration"]
	
	var animation : Animation
	var track_idx : int
	
	animation = riot.anim_player.get_animation("attack")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, params["attack_speed"])
	
	track_idx = animation.find_track('.:material:shader_parameter/active', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 1, params["flash_enabled"])
	
	track_idx = animation.find_track('../ParryHintLabel:visible', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 1, params["flash_enabled"])
	
	animation = riot.anim_player.get_animation("stunned")
	track_idx = animation.find_track('AnimationPlayer:speed_scale', Animation.TYPE_VALUE)
	if track_idx != -1:
		animation.track_set_key_value(track_idx, 0, params["stun_speed"])

func _apply_difficulty_to_platforms() -> void:
	
	var params = GameManager.get_platform_params()
	
	var h_platforms = get_tree().get_nodes_in_group("h_platform")
	var v_platforms = get_tree().get_nodes_in_group("v_platform")
	
	for platform in h_platforms:
		platform.speed = params["h_platform_speed"]
	
	for platform in v_platforms:
		platform.speed = params["v_platform_speed"]
	
	laser_wall_on_timer.wait_time = params["laser_on_timer"]
	laser_wall_off_timer.wait_time = params["laser_off_timer"]

func _update_player_score(score_to_add: int) -> void:
	if score_multiplier_timer.time_left > 0:
		score_to_add = int(score_to_add * 1.5)
	level_score += score_to_add
	if hud:
		hud._update_score(level_score)

func _validate_objectives() -> void:
	var punks = get_tree().get_nodes_in_group("punk")
	var riots = get_tree().get_nodes_in_group("riot")
	if punks.is_empty() and riots.is_empty() and not objectives_completed:
		if hud:
			hud._show_objective_txt(OBJECTIVES.cleared)
			hud._set_objective_completed()
		Portal_State = Portal_State_Machine.ACTIVATING
		objectives_completed = true

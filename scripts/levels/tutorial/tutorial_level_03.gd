extends Node2D
class_name TutorialLevel03

@onready var hud : HUD = $UI/HUD
@onready var portal : AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var player : Player = $Player
@onready var camera : Camera2D = $Player/Camera2D
@onready var laser_wall_a : AnimatedSprite2D = $LaserWallA/AnimatedSprite2D
@onready var laser_wall_collision_a : CollisionShape2D = $LaserWallA/CollisionShape2D
@onready var laser_wall_b : AnimatedSprite2D = $LaserWallB/AnimatedSprite2D
@onready var laser_wall_collision_b : CollisionShape2D = $LaserWallB/CollisionShape2D
@onready var level_raycast : RayCast2D = $LevelRayCast
@onready var laser_wall_on_timer : Timer = $LaserWallOnTimer
@onready var laser_wall_off_timer : Timer = $LaserWallOffTimer
@onready var level_title_timer : Timer = $LevelTitleTimer
@onready var level_hint_timer : Timer = $LevelHintTimer

const LEVEL_TITLE := 'TUTORIAL - FASE 3: PLATAFORMAS'
const LEVEL_HINT := "APERTE [ESPAÇO] PARA PULAR. APERTE DUAS VEZES SEGUIDAS PARA REALIZAR UM PULO DUPLO."

const OBJECTIVES := {
	"uncleared": "Chegue ao final da fase",
	"cleared": "Fase finalizada!\nProssiga para o portal"
}

var player_performance := { "fall_deaths": 0, "laser_deaths": 0 }

var current_objective := ''
var objectives_completed := false
var portal_area_entered := false
var player_spawn_position : Vector2
var laser_wall_signal_emitted := false

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

var Laser_Wall_State_A : Laser_Wall_State_Machine = Laser_Wall_State_Machine.ACTIVATED
var Laser_Wall_State_B : Laser_Wall_State_Machine = Laser_Wall_State_Machine.ACTIVATED

# =============================================================
#                         Main Functions
# =============================================================

func _ready() -> void:
	player.connect("health_changed", Callable(hud, "_update_health"))
	_init_settings()

func _physics_process(_delta: float) -> void:
	
	if not objectives_completed:
		_detect_player()
	
	if player.defeated and not laser_wall_signal_emitted:
		if player.anim_player.current_animation_position > 0.6:
			player_performance.laser_deaths += 1
			player.defeated = false
			laser_wall_signal_emitted = true
			player.State = player.State_Machine.IDLE
			player.position = player_spawn_position
	
	if player.global_position.y > camera.limit_bottom + 50:
		player_performance.fall_deaths += 1
		player.position = player_spawn_position
	
	match Portal_State:
		Portal_State_Machine.DEACTIVATED: _play_animation('portal', 'deactivated')
		Portal_State_Machine.ACTIVATING: _play_animation('portal', 'activating')
		Portal_State_Machine.ACTIVATED: _play_animation('portal', 'activated')
	
	match Laser_Wall_State_A:
		Laser_Wall_State_Machine.DEACTIVATED: _play_animation('laser_wall_a', 'deactivated')
		Laser_Wall_State_Machine.ACTIVATED: _play_animation('laser_wall_a', 'activated')
	
	match Laser_Wall_State_B:
		Laser_Wall_State_Machine.DEACTIVATED: _play_animation('laser_wall_b', 'deactivated')
		Laser_Wall_State_Machine.ACTIVATED: _play_animation('laser_wall_b', 'activated')
	
	if Portal_State == Portal_State_Machine.ACTIVATED and objectives_completed and portal_area_entered:
		if hud:
			hud.interact_label.visible = true
		if Input.is_action_just_pressed('interact'):
			GameManager.submit_phase_data({}, {}, player_performance, true)
			GameManager.advance_to_next_phase()
			get_tree().change_scene_to_file("res://scenes/levels/main/main_level_01.tscn")
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

func _on_level_title_timer_timeout() -> void:
	if hud:
		hud._clear_level_title_text()
		current_objective = '- ' + OBJECTIVES.uncleared
		hud._show_objective_txt(current_objective)
		hud._show_level_hint_text(LEVEL_HINT)
		level_hint_timer.start()

func _on_level_hint_timer_timeout() -> void:
	if hud:
		hud._clear_level_hint_text()

func _on_laser_wall_on_timer_timeout() -> void:
	Laser_Wall_State_A = Laser_Wall_State_Machine.DEACTIVATED
	Laser_Wall_State_B = Laser_Wall_State_Machine.DEACTIVATED
	laser_wall_collision_a.disabled = true
	laser_wall_collision_b.disabled = true
	laser_wall_off_timer.start()

func _on_laser_wall_off_timer_timeout() -> void:
	Laser_Wall_State_A = Laser_Wall_State_Machine.ACTIVATED
	Laser_Wall_State_B = Laser_Wall_State_Machine.ACTIVATED
	laser_wall_collision_a.disabled = false
	laser_wall_collision_b.disabled = false
	laser_wall_on_timer.start()

func _on_laser_wall_a_area_entered(area: Area2D) -> void:
	if area == player.hurtbox:
		laser_wall_signal_emitted = false
		player.State = Player.State_Machine.DEATH

func _on_laser_wall_b_area_entered(area: Area2D) -> void:
	if area == player.hurtbox:
		laser_wall_signal_emitted = false
		player.State = Player.State_Machine.DEATH

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
	GameManager.current_phase = GameManager.Phase.TUTORIAL_PLATFORM
	player.free_node_disabled = true
	player.damage_taken_disabled = true
	player.attack_disabled = true
	player.parry_disabled = true
	player_spawn_position = player.position
	hud._initialize_healthbar(player.health)
	hud.health_bar.visible = false
	hud._show_level_title_text(LEVEL_TITLE)
	level_title_timer.start()

func _detect_player() -> void:
	if level_raycast.is_colliding():
		var col = level_raycast.get_collider()
		if col is Player:
			objectives_completed = true
			current_objective = '- ' + OBJECTIVES.cleared
			hud._show_objective_txt(current_objective)
			hud._set_objective_completed()
			Portal_State = Portal_State_Machine.ACTIVATING

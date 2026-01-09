extends Node2D
class_name TutorialLevel02

@onready var hud : HUD = $UI/HUD
@onready var portal : AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var punk : Punk = $Enemies/Punk
@onready var riot : Riot = $Enemies/Riot
@onready var player : Player = $Player
@onready var level_title_timer : Timer = $LevelTitleTimer
@onready var level_hint_timer : Timer = $LevelHintTimer
@onready var punk_defeat_timer : Timer = $PunkDefeatTimer
@onready var riot_defeat_timer : Timer = $RiotDefeatTimer

const LEVEL_TITLE := 'TUTORIAL - FASE 2: PARRY'
const LEVEL_HINT := "APERTE [W] NO MOMENTO DO ATAQUE DE UM INIMIGO PARA REALIZAR UM PARRY."

const OBJECTIVES := {
	"punk": "Acerte 5 parries no inimigo Punk",
	"riot": "Acerte 5 parries no inimigo Riot",
	"cleared": "Fase finalizada!\nProssiga para o portal"
}

var player_performance := {
	"punk": {
		"parry_attempts": 0,
		"successful_parries": 0
	},
	"riot": {
		"parry_attempts": 0,
		"successful_parries": 0
	}
}

var current_objective := ''
var objectives_completed := false
var level_hint_time_limit := true
var portal_area_entered := false

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
	player.parry_attempt.connect(_update_player_parry_attempts)
	player.parry_successful.connect(_update_player_parries)
	_init_settings()

func _physics_process(_delta: float) -> void:
	
	match Portal_State:
		Portal_State_Machine.DEACTIVATED: _play_animation('deactivated')
		Portal_State_Machine.ACTIVATING: _play_animation('activating')
		Portal_State_Machine.ACTIVATED: _play_animation('activated')
	
	if Portal_State == Portal_State_Machine.ACTIVATED and objectives_completed and portal_area_entered:
		if hud:
			hud.interact_label.visible = true
		if Input.is_action_just_pressed('interact'):
			GameManager.submit_phase_data({}, player_performance, {}, true)
			GameManager.advance_to_next_phase()
			get_tree().change_scene_to_file("res://scenes/levels/tutorial/tutorial_level_03.tscn")
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
		hud._show_level_hint_text(LEVEL_HINT)
		level_hint_timer.start()

func _on_level_hint_timer_timeout() -> void:
	if hud:
		level_hint_time_limit = false

func _on_punk_defeat_timer_timeout() -> void:
	hud._clear_objective_text()
	current_objective = '- [' + str(player_performance.riot.successful_parries) + '/5] ' + OBJECTIVES.riot
	hud._show_objective_txt(current_objective)
	_disable_riot_node(false)

func _on_riot_defeat_timer_timeout() -> void:
	current_objective = '- ' + OBJECTIVES.cleared
	hud._show_objective_txt(current_objective)
	hud._set_objective_completed()
	Portal_State = Portal_State_Machine.ACTIVATING

# =============================================================
#                      Auxiliary Functions
# =============================================================

func _play_animation(anim_name: StringName) -> void:
	if portal.animation != anim_name:
		portal.play(anim_name)

func _init_settings() -> void:
	GameManager.current_phase = GameManager.Phase.TUTORIAL_PARRY
	player.damage_taken_disabled = true
	player.attack_disabled = true
	punk.damage_taken_disabled = true
	riot.damage_taken_disabled = true
	hud._initialize_healthbar(player.health)
	hud.health_bar.visible = false
	hud._show_level_title_text(LEVEL_TITLE)
	level_title_timer.start()
	current_objective = '- [' + str(player_performance.punk.successful_parries) + '/5] ' + OBJECTIVES.punk
	hud._show_objective_txt(current_objective)
	_disable_riot_node(true)

func _update_player_parry_attempts(enemy: String) -> void:
	if enemy == 'Punk':
		player_performance.punk.parry_attempts += 1
	elif enemy == 'Riot':
		player_performance.riot.parry_attempts += 1

func _update_player_parries(enemy: String) -> void:
	if enemy == 'Punk':
		player_performance.punk.successful_parries += 1
		if (player_performance.punk.successful_parries <= 5):
			current_objective = '- [' + str(player_performance.punk.successful_parries) + '/5] ' + OBJECTIVES.punk
			hud._show_objective_txt(current_objective)
			if (player_performance.punk.successful_parries >= 1 and not level_hint_time_limit):
				hud._clear_level_hint_text()
			if (player_performance.punk.successful_parries == 5):
				hud._set_objective_completed()
				punk._state_death()
				punk.set_physics_process(false)
				punk_defeat_timer.start()
	elif enemy == 'Riot':
		player_performance.riot.successful_parries += 1
		if (player_performance.riot.successful_parries <= 5):
			current_objective = '- [' + str(player_performance.riot.successful_parries) + '/5] ' + OBJECTIVES.riot
			hud._show_objective_txt(current_objective)
			if (player_performance.riot.successful_parries == 5):
				hud._set_objective_completed()
				riot._state_death()
				riot.set_physics_process(false)
				objectives_completed = true
				riot_defeat_timer.start()

func _disable_riot_node(disabled: bool) -> void:
	riot.process_mode = Node.PROCESS_MODE_DISABLED if disabled else Node.PROCESS_MODE_INHERIT
	riot.visible = not disabled

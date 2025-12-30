extends Node2D
class_name TutorialLevel01

@onready var hud : HUD = $UI/HUD
@onready var portal : AnimatedSprite2D = $Portal/AnimatedSprite2D
@onready var punk_1 : Punk = $Enemies/Punk
@onready var punk_2 : Punk = $Enemies/Punk2
@onready var riot_1 : Riot = $Enemies/Riot
@onready var riot_2 : Riot = $Enemies/Riot2
@onready var player : Player = $Player
@onready var level_title_timer : Timer = $LevelTitleTimer
@onready var level_hint_timer : Timer = $LevelHintTimer
@onready var first_wave_timer : Timer = $FirstWaveTimer

const LEVEL_TITLE := 'TUTORIAL - FASE 1: COMBATE'
const LEVEL_HINT := "APERTE [Q] PARA ATACAR. APERTE DUAS VEZES SEGUIDAS PARA REALIZAR UM COMBO."

const OBJECTIVES := {
	"uncleared": "Derrote todos os inimigos!",
	"cleared": "Fase finalizada!\nProssiga para o portal"
}

var player_performance := {
	"punk": { "damage_taken": 0 },
	"riot": { "damage_taken": 0 }
}

var enemies_status := {
	"punk_1": false,
	"punk_2": false,
	"riot_1": false,
	"riot_2": false
}

var current_objective := ''
var objectives_completed := false
var portal_area_entered := false
var first_wave_defeated := false
var second_wave_defeated := false

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
	player.damage_taken.connect(_update_player_damage_taken)
	_init_settings()
	_init_enemies()

func _physics_process(_delta: float) -> void:
	
	_manage_enemies()
	
	match Portal_State:
		Portal_State_Machine.DEACTIVATED: _play_animation('deactivated')
		Portal_State_Machine.ACTIVATING: _play_animation('activating')
		Portal_State_Machine.ACTIVATED: _play_animation('activated')
	
	if Portal_State == Portal_State_Machine.ACTIVATED and objectives_completed and portal_area_entered:
		if hud:
			hud.interact_label.visible = true
		if Input.is_action_just_pressed('interact'):
			GameManager.submit_phase_data(player_performance, {}, {}, true)
			GameManager.advance_to_next_phase()
			get_tree().change_scene_to_file("res://scenes/levels/tutorial/tutorial_level_02.tscn")
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
		hud._clear_level_hint_text()

func _on_first_wave_timer_timeout() -> void:
	punk_2.process_mode = Node.PROCESS_MODE_INHERIT
	punk_2.visible = true
	riot_2.process_mode = Node.PROCESS_MODE_INHERIT
	riot_2.visible = true
	riot_2.facing_right = false
	riot_2._adjust_orientation(true)

# =============================================================
#                      Auxiliary Functions
# =============================================================

func _play_animation(anim_name: StringName) -> void:
	if portal.animation != anim_name:
		portal.play(anim_name)

func _update_player_damage_taken(enemy: String, amount: int) -> void:
	if enemy == 'Punk':
		player_performance.punk.damage_taken += amount
	elif enemy == 'Riot':
		player_performance.riot.damage_taken += amount

func _init_settings() -> void:
	GameManager.current_phase = GameManager.Phase.TUTORIAL_COMBAT
	player.damage_taken_disabled = true
	player.parry_disabled = true
	hud._initialize_healthbar(player.health)
	hud.health_bar.visible = false
	hud._show_level_title_text(LEVEL_TITLE)
	level_title_timer.start()
	current_objective = '- ' + OBJECTIVES.uncleared
	hud._show_objective_txt(current_objective)

func _init_enemies() -> void:
	punk_2.process_mode = Node.PROCESS_MODE_DISABLED
	punk_2.visible = false
	riot_1.process_mode = Node.PROCESS_MODE_DISABLED
	riot_1.visible = false
	riot_2.process_mode = Node.PROCESS_MODE_DISABLED
	riot_2.visible = false

func _manage_enemies() -> void:
	if not first_wave_defeated:
		if punk_1 and punk_1.defeated and not enemies_status.punk_1:
			riot_1.process_mode = Node.PROCESS_MODE_INHERIT
			riot_1.visible = true
			enemies_status.punk_1 = true
			if hud and hud.objectives_label.text != '':
				hud._clear_level_hint_text()
		elif riot_1 and riot_1.defeated and not enemies_status.riot_1:
			enemies_status.riot_1 = true
			first_wave_defeated = true
			first_wave_timer.start()
	elif not second_wave_defeated:
		if punk_2 and punk_2.defeated and not enemies_status.punk_2:
			enemies_status.punk_2 = true
		if riot_2 and riot_2.defeated and not enemies_status.riot_2:
			enemies_status.riot_2 = true
		if enemies_status.punk_2 and enemies_status.riot_2:
			#second_wave_timer.start()
			current_objective = '- ' + OBJECTIVES.cleared
			hud._show_objective_txt(current_objective)
			hud._set_objective_completed()
			second_wave_defeated = true
			objectives_completed = true
			Portal_State = Portal_State_Machine.ACTIVATING

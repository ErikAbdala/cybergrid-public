extends Control
class_name HUD

@onready var health_bar : ProgressBar = $HealthBar
@onready var damage_bar : ProgressBar = $HealthBar/DamageBar
@onready var damage_taken_timer : Timer = $HealthBar/DamageTakenTimer
@onready var level_title_label : Label = $LevelTitleSection/LevelTitleLabel
@onready var objectives_label : RichTextLabel = $ObjectivesSection/ObjectivesLabel
@onready var level_hint_label : RichTextLabel = $LevelHintSection/LevelHintLabel
@onready var interact_label: Label = $ButtonsSection/InteractLabel
@onready var score_label : Label = $ScoreSection/HBoxContainer/ValueLabel
@onready var score_section : Panel = $ScoreSection

var health := 100

func _on_damage_taken_timer_timeout() -> void:
	damage_bar.value = health

func _initialize_healthbar(initial_health: int) -> void:
	health = initial_health
	health_bar.max_value = health
	health_bar.value = health
	damage_bar.max_value = health
	damage_bar.value = health

func _update_health(new_health: int) -> void:
	var prev_health = health
	health = min(health_bar.max_value, new_health)
	health_bar.value = health
	if health <= 0:
		queue_free()
	if health < prev_health:
		damage_taken_timer.start()
	else:
		damage_bar.value = health

func _show_level_title_text(txt: String) -> void:
	level_title_label.text = txt

func _clear_level_title_text() -> void:
	level_title_label.text = ''

func _show_objective_txt(txt: String) -> void:
	objectives_label.text = txt

func _set_objective_completed() -> void:
	objectives_label.add_theme_color_override("default_color", "#83ff6e")

func _clear_objective_text() -> void:
	objectives_label.remove_theme_color_override("default_color")
	objectives_label.text = ''

func _show_level_hint_text(txt: String) -> void:
	level_hint_label.text = txt

func _clear_level_hint_text()-> void:
	level_hint_label.text = ''

func _initialize_score(score: int) -> void:
	score_section.visible = true
	score_label.text = str(score)

func _update_score(new_score: int) -> void:
	score_label.text = str(new_score)

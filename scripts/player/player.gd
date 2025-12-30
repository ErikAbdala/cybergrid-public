extends CharacterBody2D
class_name Player

@onready var sprite_2d : Sprite2D = $Sprite2D
@onready var collision : CollisionShape2D = $Collision
@onready var anim_player : AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var enemy_raycast : RayCast2D = $EnemyRayCast
@onready var combo_timer : Timer = $ComboTimer
@onready var hurtbox : Area2D = $PlayerHurtbox
@onready var hitbox : Area2D = $PlayerAttack
@onready var parry : Area2D = $PlayerParry

signal health_changed(current_health)
signal defeated_by_enemy(enemy)
signal damage_taken(enemy, amount)
signal parry_successful(enemy)
signal parry_attempt(enemy)

const H_SPEED = 12000
const V_SPEED = 690
const MAX_JUMPS := 2
const JUMP_FORCE = -290.0 # -380.0

var health := 100
var defeated := false
var fall_off_screen := false
var move_direction := 0
var can_combo := false
var jumps_used := 0
var fall_height := 0.0
var free_node_disabled := false
var damage_taken_disabled := false
var attack_disabled := false
var parry_disabled := false
var punk_damage := 20
var riot_damage := 40

var buffered_attack := false

enum State_Machine {
	IDLE,
	RUN,
	JUMP,
	DOUBLE_JUMP,
	FALL,
	LAND,
	ATTACK_1,
	ATTACK_2,
	PARRY,
	PARRY_SUCCESS,
	HIT,
	DEATH
}

var State : State_Machine = State_Machine.FALL

# =============================================================
#                         Main Functions
# =============================================================

func _physics_process(delta: float) -> void:
	
	if not is_attacking() and not is_parrying() and not defeated:
		handle_movement()
	
	match State:
		
		State_Machine.IDLE: _state_idle()
		State_Machine.RUN: _state_run(delta)
		State_Machine.JUMP: _state_jump(delta)
		State_Machine.DOUBLE_JUMP: _state_double_jump(delta)
		State_Machine.FALL: _state_fall(delta)
		State_Machine.LAND: _state_land()
		State_Machine.ATTACK_1: _state_attack_1()
		State_Machine.ATTACK_2: _state_attack_2()
		State_Machine.PARRY: _state_parry()
		State_Machine.PARRY_SUCCESS: _state_parry_success()
		State_Machine.HIT: _state_hit()
		State_Machine.DEATH: _state_death(delta)
	
	move_and_slide()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"land":
			State = State_Machine.IDLE
		"attack-1":
			#State = State_Machine.IDLE
			if buffered_attack and can_combo:
				buffered_attack = false
				State = State_Machine.ATTACK_2
			else:
				State = State_Machine.IDLE
		"attack-2":
			State = State_Machine.IDLE
			_reset_combo()
		"parry":
			#State = State_Machine.IDLE
			if State != State_Machine.HIT and State != State_Machine.DEATH:
				State = State_Machine.IDLE
		"parry-success":
			State = State_Machine.IDLE
		"hit":
			#State = State_Machine.IDLE
			State = State_Machine.IDLE if is_on_floor() else State_Machine.FALL
		"death":
			if not free_node_disabled:
				_free_player_node()

func _on_player_hurtbox_area_entered(area: Area2D) -> void:
	call_deferred("_process_hurtbox", area)

func _on_player_parry_area_entered(area: Area2D) -> void:
	if area.is_in_group("punk-attack") or area.is_in_group("riot-attack"):
		if area.is_in_group("punk-attack"):
			emit_signal("parry_successful", "Punk")
		elif area.is_in_group("riot-attack"):
			emit_signal("parry_successful", "Riot")
		State = State_Machine.PARRY_SUCCESS

func _process_hurtbox(area: Area2D) -> void:
	if State == State_Machine.PARRY_SUCCESS:
		return
	if (State != State_Machine.DEATH):
		if area.is_in_group("punk-attack"):
			if damage_taken_disabled:
				emit_signal("damage_taken", "Punk", punk_damage)
				State = State_Machine.HIT
				return
			_take_damage('Punk', punk_damage)
		elif area.is_in_group("riot-attack"):
			if damage_taken_disabled:
				emit_signal("damage_taken", "Riot", riot_damage)
				State = State_Machine.HIT
				return
			_take_damage('Riot', riot_damage)

func _on_combo_timer_timeout() -> void:
	_reset_combo()

# =============================================================
#                    State Machine Functions
# =============================================================

func _state_idle() -> void:
	
	velocity = Vector2.ZERO
	_play_animation('idle')
	
	if not is_on_floor():
		fall_height = global_position.y
		State = State_Machine.FALL
		return
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_jump()
		return
	
	elif Input.is_action_just_pressed("attack") and is_on_floor() and not attack_disabled:
		#State = State_Machine.ATTACK_2 if can_combo else State_Machine.ATTACK_1
		if not can_combo:
			_start_combo_window()
			State = State_Machine.ATTACK_1
		else:
			State = State_Machine.ATTACK_2
	
	elif move_direction != 0 and is_on_floor():
		State = State_Machine.RUN
	
	elif velocity.y < 0 and not is_on_floor():
		State = State_Machine.FALL
	
	elif Input.is_action_just_pressed("parry") and is_on_floor() and not parry_disabled:
		var enemy_nearby = _detect_enemy_nearby()
		if enemy_nearby:
			emit_signal("parry_attempt", enemy_nearby)
		State = State_Machine.PARRY

func _state_run(delta: float) -> void:
	
	_play_animation('run')
	
	if not is_on_floor():
		fall_height = global_position.y
		State = State_Machine.FALL
		return
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_jump()
		return
	
	elif Input.is_action_just_pressed("attack") and is_on_floor() and not attack_disabled:
		#State = State_Machine.ATTACK_2 if can_combo else State_Machine.ATTACK_1
		if not can_combo:
			_start_combo_window()
			State = State_Machine.ATTACK_1
		else:
			State = State_Machine.ATTACK_2
		return
	
	elif Input.is_action_just_pressed("parry") and is_on_floor() and not parry_disabled:
		var enemy_nearby = _detect_enemy_nearby()
		if enemy_nearby:
			emit_signal("parry_attempt", enemy_nearby)
		State = State_Machine.PARRY
		return
	
	if move_direction != 0:
		velocity.x = H_SPEED * move_direction * delta
	else:
		State = State_Machine.IDLE

func _state_jump(delta: float) -> void:
	
	_play_animation('jump')
	_apply_air_physics(delta)
	
	if Input.is_action_just_pressed("jump") and jumps_used < MAX_JUMPS:
		_double_jump()
		return
	
	if velocity.y > 0:
		fall_height = global_position.y
		State = State_Machine.FALL

func _state_double_jump(delta: float) -> void:
	_play_animation('double-jump')
	_apply_air_physics(delta)
	if velocity.y > 0:
		fall_height = global_position.y
		State = State_Machine.FALL

func _state_fall(delta: float) -> void:
	
	_play_animation('fall')
	
	if not is_on_floor():
		_apply_air_physics(delta)
		if Input.is_action_just_pressed("jump") and jumps_used < MAX_JUMPS:
			_double_jump()
	else:
		jumps_used = 0
		var fall_distance = global_position.y - fall_height
		if fall_height != 0 and fall_distance > 120:
			fall_height = 0
			State = State_Machine.LAND
		else:
			fall_height = 0
			State = State_Machine.IDLE if move_direction == 0 else State_Machine.RUN

func _state_land() -> void:
	velocity = Vector2.ZERO
	_play_animation('land')

func _state_attack_1() -> void:
	velocity = Vector2.ZERO
	_play_animation('attack-1')
	#_start_combo_window()
	if Input.is_action_just_pressed("attack"):
		buffered_attack = true

func _state_attack_2() -> void:
	velocity = Vector2.ZERO
	_play_animation('attack-2')
	_reset_combo()

func _state_parry() -> void:
	velocity = Vector2.ZERO
	_play_animation('parry')

func _state_parry_success() -> void:
	velocity = Vector2.ZERO
	_play_animation('parry-success')

func _state_hit() -> void:
	velocity = Vector2.ZERO
	if is_on_floor():
		_play_animation('hit')
	else:
		State = State_Machine.FALL

func _state_death(delta: float) -> void:
	if not defeated:
		if is_on_floor() or fall_off_screen:
			velocity = Vector2.ZERO
			defeated = true
			_play_animation('death')
		else:
			velocity.y += V_SPEED * delta
			velocity.x = 0

# =============================================================
#                      Auxiliary Functions
# =============================================================

func _play_animation(anim_name: String) -> void:
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func handle_movement() -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		move_direction = int(dir)
		sprite_2d.flip_h = false if dir > 0 else true
		enemy_raycast.target_position = Vector2(80 * dir, 0)
		hitbox.scale.x = dir
		parry.scale.x = dir
	else:
		move_direction = 0

func _apply_air_physics(delta: float) -> void:
	velocity.y += V_SPEED * delta
	velocity.x = H_SPEED * move_direction * delta

func _jump() -> void:
	velocity.y = JUMP_FORCE
	State = State_Machine.JUMP
	jumps_used = 1

func _double_jump() -> void:
	velocity.y = JUMP_FORCE
	State = State_Machine.DOUBLE_JUMP
	jumps_used = 2

func _start_combo_window() -> void:
	can_combo = true
	combo_timer.start()

func _reset_combo() -> void:
	can_combo = false
	buffered_attack = false

func _take_damage(enemy: String, amount := 20) -> void:
	var health_before_damage = health
	health = max(health - amount, 0)
	emit_signal("health_changed", health)
	if State == State_Machine.PARRY:
		anim_player.stop()
	if health > 0:
		emit_signal("damage_taken", enemy, amount)
		State = State_Machine.HIT
	else:
		emit_signal("damage_taken", enemy, health_before_damage)
		emit_signal("defeated_by_enemy", enemy)
		State = State_Machine.DEATH

func _detect_enemy_nearby() -> Variant:
	if enemy_raycast.is_colliding():
		var col = enemy_raycast.get_collider()
		if col is Punk:
			return "Punk"
		elif col is Riot:
			return "Riot"
	return null

func is_attacking() -> bool:
	return State == State_Machine.ATTACK_1 or State == State_Machine.ATTACK_2

func is_parrying() -> bool:
	return State == State_Machine.PARRY or State == State_Machine.PARRY_SUCCESS

func _free_player_node() -> void:
	collision.queue_free()
	enemy_raycast.free()
	hurtbox.queue_free()
	hitbox.queue_free()
	parry.queue_free()

extends CharacterBody2D
class_name Riot

@onready var sprite_2d : Sprite2D = $Sprite2D
@onready var anim_player : AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var attack_collision : Area2D = $RiotAttack
@onready var player_raycast : RayCast2D = $PlayerRayCast
@onready var ledge_ahead_raycast : RayCast2D = $LedgeARayCast
@onready var ledge_behind_raycast : RayCast2D = $LedgeBRayCast
@onready var wall_raycast : RayCast2D = $WallRayCast
@onready var guard_timer : Timer = $GuardTimer
@onready var chase_timer : Timer = $ChaseTimer
@onready var block_timer : Timer = $BlockTimer
@onready var death_timer : Timer = $DeathTimer

signal riot_defeated(score)

var player : Player

var health := 100
var speed := 50
var chase_speed := 200
var acceleration := 300
var defeated := false
var blocking := false
var direction : Vector2
var left_bounds : Vector2
var right_bounds : Vector2
var spawn_position : Vector2
var attack_distance := 30
var facing_right := true
var ledge_behind_stop := false
var damage_taken_disabled := false

enum State_Machine {
	GUARD,
	WANDER,
	CHASE,
	RETURN,
	ATTACK,
	STUNNED,
	BLOCK,
	HIT,
	DEATH
}

var State : State_Machine = State_Machine.WANDER

# =============================================================
#                         Main Functions
# =============================================================

func _ready() -> void:
	player = get_tree().get_first_node_in_group('player')
	spawn_position = self.position
	left_bounds = spawn_position + Vector2(-100, 0)
	right_bounds = spawn_position + Vector2(100, 0)

func _physics_process(delta: float) -> void:
	
	match State:
		State_Machine.GUARD: _state_guard()
		State_Machine.WANDER: _state_wander(delta)
		State_Machine.CHASE: _state_chase(delta)
		State_Machine.RETURN: _state_return(delta)
		State_Machine.ATTACK: _state_attack()
		State_Machine.STUNNED: _state_stunned()
		State_Machine.BLOCK: _state_block()
		State_Machine.HIT: _state_hit()
		State_Machine.DEATH: _state_death()
	
	move_and_slide()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack":
			State = State_Machine.CHASE
		"stunned":
			State = State_Machine.CHASE
		"block":
			State = State_Machine.CHASE
		"hit":
			State = State_Machine.CHASE
		"death":
			emit_signal("riot_defeated", 80)
			for child in get_children():
				if child not in [sprite_2d, death_timer]:
					child.queue_free()
			death_timer.start()

func _on_riot_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player-attack") and not defeated:
		var facing_each_other = true if ((facing_right and player.sprite_2d.flip_h)
		or (not facing_right and not player.sprite_2d.flip_h)) else false
		if not facing_each_other or (State in [State_Machine.STUNNED, State_Machine.ATTACK] and not blocking):
			if State in [State_Machine.STUNNED, State_Machine.ATTACK]:
				blocking = true
				block_timer.start()
			if not damage_taken_disabled:
				health = max(health - 20, 0)
			State = State_Machine.DEATH if health <= 0 else State_Machine.HIT
		else:
			State = State_Machine.BLOCK

func _on_riot_attack_area_entered(area: Area2D) -> void:
	if area.is_in_group("player-parry"):
		State = State_Machine.STUNNED

func _on_guard_timer_timeout() -> void:
	if State == State_Machine.GUARD:
		facing_right = !facing_right
		_adjust_orientation(not facing_right)
		State = State_Machine.WANDER

func _on_chase_timer_timeout() -> void:
	State = State_Machine.RETURN

func _on_block_timer_timeout() -> void:
	blocking = false

func _on_death_timer_timeout() -> void:
	queue_free()

# =============================================================
#                    State Machine Functions
# =============================================================

func _state_guard() -> void:
	
	velocity = Vector2.ZERO
	_play_animation('idle')
	
	var player_found = _look_for_player()
	
	if player_found:
		guard_timer.stop()
		State = State_Machine.CHASE

func _state_wander(delta: float) -> void:
	
	var move_direction
	_play_animation('walk')
	
	if facing_right:
		if self.position.x <= right_bounds.x:
			move_direction = Vector2(1, 0)
		else:
			guard_timer.start()
			State = State_Machine.GUARD
			return
	else:
		if self.position.x >= left_bounds.x:
			move_direction = Vector2(-1, 0)
		else:
			guard_timer.start()
			State = State_Machine.GUARD
			return
	
	velocity.x = move_toward(velocity.x, move_direction.x * speed, acceleration * delta)
	
	var player_found = _look_for_player()
	
	if player_found:
		guard_timer.stop()
		State = State_Machine.CHASE

func _state_chase(delta: float) -> void:
	
	if player.defeated:
		State = State_Machine.GUARD
		return
	
	var direction_to_player = (player.position - self.position).normalized()
	var move_direction = sign(direction_to_player.x)
	
	if move_direction > 0:
		facing_right = true
		_adjust_orientation(false)
	else:
		facing_right = false
		_adjust_orientation(true)
	
	var player_found = _look_for_player()
	var distance_to_player = self.position.distance_to(player.position)
	var found_ledge_ahead = _detect_ledge_ahead()
	var found_wall = _detect_wall()
	
	if player_found:
		chase_timer.stop()
	else:
		if chase_timer.time_left <= 0:
			chase_timer.start()
	
	if found_ledge_ahead or found_wall:
		velocity = Vector2.ZERO
		_play_animation('idle')
		if found_wall:
			player_raycast.target_position.x = 28 * move_direction
		if distance_to_player <= attack_distance:
			State = State_Machine.ATTACK
		return
	
	if player_raycast.target_position.x != (150 * move_direction):
		player_raycast.target_position.x = 150 * move_direction
	
	if distance_to_player <= attack_distance:
		State = State_Machine.ATTACK
		return
	
	_play_animation('walk')
	
	velocity.x = move_toward(velocity.x, move_direction * chase_speed, acceleration * delta)
	
	var found_ledge_behind = _detect_ledge_behind()
	
	if found_ledge_behind:
		if not ledge_behind_stop:
			ledge_behind_stop = true
			velocity.x = 0
	else:
		ledge_behind_stop = false

func _state_return(delta: float) -> void:
	
	var move_direction
	_play_animation('walk')
	
	if self.position.x > right_bounds.x:
		move_direction = Vector2(-1, 0)
		if facing_right:
			facing_right = false
			_adjust_orientation(true)
	elif self.position.x < left_bounds.x:
		move_direction = Vector2(1, 0)
		if not facing_right:
			facing_right = true
			_adjust_orientation(false)
	elif self.position.x > left_bounds.x and self.position.x < right_bounds.x:
		State = State_Machine.WANDER
		return
	
	velocity.x = move_toward(velocity.x, move_direction.x * speed, acceleration * delta)
	
	var player_found = _look_for_player()
	
	if player_found:
		State = State_Machine.CHASE
		return

func _state_attack() -> void:
	velocity = Vector2.ZERO
	_play_animation('attack')

func _state_stunned() -> void:
	velocity = Vector2.ZERO
	_play_animation('stunned')

func _state_block() -> void:
	velocity = Vector2.ZERO
	_play_animation('block')

func _state_hit() -> void:
	velocity = Vector2.ZERO
	_play_animation('hit')

func _state_death() -> void:
	velocity = Vector2.ZERO
	if not defeated:
		defeated = true
		_play_animation('death')

# =============================================================
#                      Auxiliary Functions
# =============================================================

func _play_animation(anim_name: String) -> void:
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func _adjust_orientation(flip: bool) -> void:
	sprite_2d.flip_h = flip
	var dir = -1 if flip else 1
	attack_collision.scale.x = dir
	player_raycast.target_position = Vector2(150 * dir, 0)
	wall_raycast.target_position = Vector2(28 * dir, 0)
	ledge_ahead_raycast.position = Vector2(20 * dir, 0)
	ledge_behind_raycast.position = Vector2(-20 * dir, 0)

func _look_for_player() -> Player:
	if player_raycast.is_colliding():
		var col = player_raycast.get_collider()
		if col is Player:
			return col
	return null

func _detect_ledge_ahead() -> bool:
	return true if not ledge_ahead_raycast.is_colliding() else false

func _detect_ledge_behind() -> bool:
	return true if not ledge_behind_raycast.is_colliding() else false

func _detect_wall() -> bool:
	return true if wall_raycast.is_colliding() else false

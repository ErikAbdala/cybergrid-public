extends Node

# ============================================================================
# GAME MANAGER - Gerenciador do Jogo & Sistema de Dificuldade Adaptativa
# ============================================================================

# Singleton responsável por gerenciar o perfil do jogador e ajustar dificuldade
# com base na performance nas mecânicas de combate, parry e plataforma.

const DDA_ACTIVE := true

var initial_start := false
var consecutive_deaths := 0
var on_reload_data := {}
var total_score := 0

enum DifficultyLevel {
	BEGINNER = 1,
	INTERMEDIATE = 2,
	ADVANCED = 3
}

enum Phase {
	TUTORIAL_COMBAT = 0,
	TUTORIAL_PARRY = 1,
	TUTORIAL_PLATFORM = 2,
	PHASE_1 = 3,
	PHASE_2 = 4,
	PHASE_3 = 5
}

# ============================================================================
# VARIÁVEIS DE ESTADO
# ============================================================================

var current_phase: Phase = Phase.TUTORIAL_COMBAT

var combat_levels := {
	"punk": DifficultyLevel.INTERMEDIATE,
	"riot": DifficultyLevel.INTERMEDIATE
}

var parry_levels := {
	"punk": DifficultyLevel.INTERMEDIATE,
	"riot": DifficultyLevel.INTERMEDIATE
}

var platform_level: DifficultyLevel = DifficultyLevel.INTERMEDIATE

# Histórico de dados coletados por fase.
var phase_history := []

# ============================================================================
# PARÂMETROS DE DIFICULDADE
# ============================================================================

var combat_params := {
	"punk": {
		DifficultyLevel.BEGINNER: {
			"damage": 10,
			"health": 75,
			"speed": 190,
			"acceleration": 280
		},
		DifficultyLevel.INTERMEDIATE: {
			"damage": 20,
			"health": 100,
			"speed": 200,
			"acceleration": 300
		},
		DifficultyLevel.ADVANCED: {
			"damage": 30,
			"health": 125,
			"speed": 250,
			"acceleration": 320
		}
	},
	"riot": {
		DifficultyLevel.BEGINNER: {
			"damage": 20,
			"health": 80,
			"speed": 190,
			"acceleration": 280
		},
		DifficultyLevel.INTERMEDIATE: {
			"damage": 40,
			"health": 100,
			"speed": 200,
			"acceleration": 300
		},
		DifficultyLevel.ADVANCED: {
			"damage": 60,
			"health": 120,
			"speed": 230,
			"acceleration": 320
		}
	}
}

var parry_params := {
	"punk": {
		DifficultyLevel.BEGINNER: {
			"attack_speed": 0.5,
			"stun_speed": 0.5,
			"flash_enabled": true
		},
		DifficultyLevel.INTERMEDIATE: {
			"attack_speed": 0.7,
			"stun_speed": 0.65,
			"flash_enabled": false
		},
		DifficultyLevel.ADVANCED: {
			"attack_speed": 1.0,
			"stun_speed": 1.0,
			"flash_enabled": false
		}
	},
	"riot": {
		DifficultyLevel.BEGINNER: {
			"attack_speed": 0.8,
			"stun_speed": 0.5,
			"flash_enabled": true
		},
		DifficultyLevel.INTERMEDIATE: {
			"attack_speed": 1.1,
			"stun_speed": 0.6,
			"flash_enabled": false
		},
		DifficultyLevel.ADVANCED: {
			"attack_speed": 1.4,
			"stun_speed": 1.0,
			"flash_enabled": false
		}
	}
}

var platform_params := {
	DifficultyLevel.BEGINNER: {
		"h_platform_speed": 90,
		"v_platform_speed": 1.2,
		"laser_on_timer": 2.0,
		"laser_off_timer": 3.0
	},
	DifficultyLevel.INTERMEDIATE: {
		"h_platform_speed": 160,
		"v_platform_speed": 2.2,
		"laser_on_timer": 3.0,
		"laser_off_timer": 2.0
	},
	DifficultyLevel.ADVANCED: {
		"h_platform_speed": 250,
		"v_platform_speed": 3.2,
		"laser_on_timer": 4.0,
		"laser_off_timer": 1.0
	}
}

# ============================================================================
# MÉTODOS PRINCIPAIS
# ============================================================================

# Método chamado pelas fases para enviar dados de performance.
func submit_phase_data(combat_data: Dictionary = {}, parry_data: Dictionary = {},
platform_data: Dictionary = {}, phase_completed: bool = true) -> void:
	
	var phase_data := {
		"phase": current_phase,
		"combat": combat_data,
		"parry": parry_data,
		"platform": platform_data,
		"completed": phase_completed,
		"timestamp": Time.get_ticks_msec()
	}
	
	phase_history.append(phase_data)
	
	# Analisa os dados e ajusta níveis.
	_analyze_and_adjust_difficulty(combat_data, parry_data, platform_data, phase_completed)
	
	# Métodos para debug.
	#print_player_performance_report(combat_data, parry_data, platform_data, phase_completed)
	#print_current_state_report()

# Avança para a próxima fase.
func advance_to_next_phase() -> void:
	if current_phase < Phase.PHASE_3:
		var next_index := int(current_phase) + 1
		current_phase = Phase.values()[next_index]
		#print("Avançando para fase: %s" % Phase.keys()[current_phase])

# Obtém parâmetros de combate para um inimigo específico.
func get_combat_params(enemy_type: String) -> Dictionary:
	var level = combat_levels.get(enemy_type, DifficultyLevel.INTERMEDIATE)
	return combat_params[enemy_type][level].duplicate()

# Obtém parâmetros de parry para um inimigo específico.
func get_parry_params(enemy_type: String) -> Dictionary:
	var level = parry_levels.get(enemy_type, DifficultyLevel.INTERMEDIATE)
	return parry_params[enemy_type][level].duplicate()

# Obtém parâmetros de plataforma.
func get_platform_params() -> Dictionary:
	return platform_params[platform_level].duplicate()

# Obtém todos os parâmetros de um inimigo.
func get_enemy_params(enemy_type: String) -> Dictionary:
	var params := {}
	params.merge(get_combat_params(enemy_type))
	params.merge(get_parry_params(enemy_type))
	return params

# ============================================================================
# ANÁLISE E AJUSTE DE DIFICULDADE
# ============================================================================

func _analyze_and_adjust_difficulty(combat_data: Dictionary, parry_data: Dictionary,
platform_data: Dictionary, phase_completed: bool) -> void:
	match current_phase:
		Phase.TUTORIAL_COMBAT:
			_analyze_tutorial_combat(combat_data)
		Phase.TUTORIAL_PARRY:
			_analyze_tutorial_parry(parry_data)
		Phase.TUTORIAL_PLATFORM:
			_analyze_tutorial_platform(platform_data)
		Phase.PHASE_1, Phase.PHASE_2, Phase.PHASE_3:
			_analyze_main_phase(combat_data, parry_data, platform_data, phase_completed)

# ============================================================================
# ANÁLISE - TUTORIAL DE COMBATE
# ============================================================================

func _analyze_tutorial_combat(combat_data: Dictionary) -> void:
	
	if combat_data.has("punk"):
		
		var damage_taken = combat_data["punk"].get("damage_taken", 0)
		
		if damage_taken >= 120:
			combat_levels["punk"] = DifficultyLevel.BEGINNER
		elif damage_taken >= 60:
			combat_levels["punk"] = DifficultyLevel.INTERMEDIATE
		else:
			combat_levels["punk"] = DifficultyLevel.ADVANCED
	
	if combat_data.has("riot"):
		
		var damage_taken = combat_data["riot"].get("damage_taken", 0)
		
		if damage_taken >= 160:
			combat_levels["riot"] = DifficultyLevel.BEGINNER
		elif damage_taken >= 80:
			combat_levels["riot"] = DifficultyLevel.INTERMEDIATE
		else:
			combat_levels["riot"] = DifficultyLevel.ADVANCED

# ============================================================================
# ANÁLISE - TUTORIAL DE PARRY
# ============================================================================

func _analyze_tutorial_parry(parry_data: Dictionary) -> void:
	
	if parry_data.has("punk"):
		
		var attempts = parry_data["punk"].get("parry_attempts", 0)
		
		if attempts > 12:
			parry_levels["punk"] = DifficultyLevel.BEGINNER
		elif attempts >= 7:
			parry_levels["punk"] = DifficultyLevel.INTERMEDIATE
		else:
			parry_levels["punk"] = DifficultyLevel.ADVANCED
	
	if parry_data.has("riot"):
		
		var attempts = parry_data["riot"].get("parry_attempts", 0)
		
		if attempts > 12:
			parry_levels["riot"] = DifficultyLevel.BEGINNER
		elif attempts >= 7:
			parry_levels["riot"] = DifficultyLevel.INTERMEDIATE
		else:
			parry_levels["riot"] = DifficultyLevel.ADVANCED

# ============================================================================
# ANÁLISE - TUTORIAL DE PLATAFORMA
# ============================================================================

func _analyze_tutorial_platform(platform_data: Dictionary) -> void:
	
	var fall_deaths = platform_data.get("fall_deaths", 0)
	var laser_deaths = platform_data.get("laser_deaths", 0)
	var total_deaths = fall_deaths + laser_deaths
	
	if total_deaths >= 4:
		platform_level = DifficultyLevel.BEGINNER
	elif total_deaths > 1 and total_deaths < 4:
		platform_level = DifficultyLevel.INTERMEDIATE
	elif total_deaths <= 1:
		platform_level = DifficultyLevel.ADVANCED

# ============================================================================
# ANÁLISE - FASES PRINCIPAIS (1, 2 e 3)
# ============================================================================

func _analyze_main_phase(combat_data: Dictionary, parry_data: Dictionary,
platform_data: Dictionary, phase_completed: bool) -> void:
	_analyze_main_phase_combat(combat_data, phase_completed)
	_analyze_main_phase_parry(parry_data)
	_analyze_main_phase_platform(platform_data, phase_completed)

func _analyze_main_phase_combat(combat_data: Dictionary, phase_completed: bool) -> void:
	
	if combat_data.has("punk"):
		
		var damage_taken = combat_data["punk"].get("damage_taken", 0)
		var deaths = combat_data["punk"].get("defeated_player", 0)
		
		var current_level = combat_levels["punk"]
		var thresholds = _get_combat_thresholds("punk", current_level)
		
		var performance_score = damage_taken + (deaths * 50)
		
		if performance_score >= thresholds["beginner"]:
			combat_levels["punk"] = DifficultyLevel.BEGINNER
		elif performance_score >= thresholds["intermediate"]:
			combat_levels["punk"] = max(DifficultyLevel.BEGINNER, current_level - 1)
		elif performance_score <= thresholds["advanced"]:
			combat_levels["punk"] = DifficultyLevel.ADVANCED
		else:
			combat_levels["punk"] = DifficultyLevel.INTERMEDIATE
		
		if not phase_completed and combat_levels["punk"] > current_level:
			#print("Nível atual de combate para o Punk mantido (iria subir)!")
			combat_levels["punk"] = current_level
	
	if combat_data.has("riot"):
		
		var damage_taken = combat_data["riot"].get("damage_taken", 0)
		var deaths = combat_data["riot"].get("defeated_player", 0)
		
		var current_level = combat_levels["riot"]
		var thresholds = _get_combat_thresholds("riot", current_level)
		
		var performance_score = damage_taken + (deaths * 80)
		
		if performance_score >= thresholds["beginner"]:
			combat_levels["riot"] = DifficultyLevel.BEGINNER
		elif performance_score >= thresholds["intermediate"]:
			combat_levels["riot"] = max(DifficultyLevel.BEGINNER, current_level - 1)
		elif performance_score <= thresholds["advanced"]:
			combat_levels["riot"] = DifficultyLevel.ADVANCED
		else:
			combat_levels["riot"] = DifficultyLevel.INTERMEDIATE
		
		if not phase_completed and combat_levels["riot"] > current_level:
			#print("Nível atual de combate para o Riot mantido (iria subir)!")
			combat_levels["riot"] = current_level

func _analyze_main_phase_parry(parry_data: Dictionary) -> void:
	
	if parry_data.has("punk"):
		
		var attempts = parry_data["punk"].get("parry_attempts", 0)
		var successes = parry_data["punk"].get("successful_parries", 0)
		
		if not attempts == 0:
			
			var success_rate = float(successes) / float(attempts)
			
			if success_rate >= 0.85:
				parry_levels["punk"] = DifficultyLevel.ADVANCED
			elif success_rate >= 0.60:
				parry_levels["punk"] = DifficultyLevel.INTERMEDIATE
			else:
				parry_levels["punk"] = DifficultyLevel.BEGINNER
	
	if parry_data.has("riot"):
		
		var attempts = parry_data["riot"].get("parry_attempts", 0)
		var successes = parry_data["riot"].get("successful_parries", 0)
		
		if not attempts == 0:
			
			var success_rate = float(successes) / float(attempts)
			
			if success_rate >= 0.75:
				parry_levels["riot"] = DifficultyLevel.ADVANCED
			elif success_rate >= 0.50:
				parry_levels["riot"] = DifficultyLevel.INTERMEDIATE
			else:
				parry_levels["riot"] = DifficultyLevel.BEGINNER

func _analyze_main_phase_platform(platform_data: Dictionary, phase_completed: bool) -> void:
	
	if platform_data.is_empty():
		return
	
	var current_level = platform_level
	var fall_deaths = platform_data.get("fall_deaths", 0)
	var laser_deaths = platform_data.get("laser_deaths", 0)
	var total_deaths = fall_deaths + laser_deaths
	
	if total_deaths >= 4:
		platform_level = DifficultyLevel.BEGINNER
	elif total_deaths > 1 and total_deaths < 4:
		platform_level = DifficultyLevel.INTERMEDIATE
	elif total_deaths <= 1:
		platform_level = DifficultyLevel.ADVANCED
	
	if not phase_completed and platform_level > current_level:
		#print("Nível atual de plataforma mantido (iria subir)!")
		platform_level = current_level

# ============================================================================
# CÁLCULO DE THRESHOLDS DINÂMICOS
# ============================================================================

func _get_combat_thresholds(enemy_type: String, current_level: DifficultyLevel) -> Dictionary:
	
	# Obtém parâmetros do nível atual para calcular thresholds proporcionais
	var params = combat_params[enemy_type][current_level]
	var base_damage = params["damage"]
	var base_health = params["health"]
	
	# Dano específico do player para cada inimigo.
	var player_damage = 25 if enemy_type == "punk" else 20
	var expected_hits_to_kill = ceil(base_health / float(player_damage))
	
	# Considera 4 inimigos de cada tipo em média por fase.
	var total_possible_damage = base_damage * expected_hits_to_kill * 4
	
	# Thresholds baseados no dano possível
	return {
		"beginner": total_possible_damage * 0.70,      # Tomou 70%+ do dano possível
		"intermediate": total_possible_damage * 0.35,  # Tomou 35-70% do dano
		"advanced": total_possible_damage * 0.15       # Tomou menos de 15%
	}

# ============================================================================
# MÉTODOS UTILITÁRIOS
# ============================================================================

# Reseta o sistema quando o jogo for reiniciado.
func reset_system() -> void:
	current_phase = Phase.TUTORIAL_COMBAT
	combat_levels = {
		"punk": DifficultyLevel.INTERMEDIATE,
		"riot": DifficultyLevel.INTERMEDIATE
	}
	parry_levels = {
		"punk": DifficultyLevel.INTERMEDIATE,
		"riot": DifficultyLevel.INTERMEDIATE
	}
	platform_level = DifficultyLevel.INTERMEDIATE
	consecutive_deaths = 0
	on_reload_data = {}
	total_score = 0
	phase_history.clear()
	#print("Perfil de dificuldade do player resettado.")

# Obtém estatísticas do jogador.
func get_player_stats() -> Dictionary:
	return {
		"current_phase": current_phase,
		"combat_levels": combat_levels.duplicate(),
		"parry_levels": parry_levels.duplicate(),
		"platform_level": platform_level,
		"phases_completed": phase_history.size()
	}

# Debug: Imprime o relatório referente à performance atual do jogador.
func print_player_performance_report(combat_data: Dictionary, parry_data: Dictionary,
platform_data: Dictionary, phase_completed: bool) -> void:
	var status = "Completada" if phase_completed else "Interrompida (morte)"
	print("\n====================== PLAYER PERFORMANCE REPORT ======================\n")
	print("> Fase atual: %s - Status: %s" % [Phase.keys()[current_phase], status])
	print("\n> Combate:")
	print("  - Punk: Nível %d - %s" % [combat_levels["punk"], combat_data["punk"]])
	print("  - Riot: Nível %d - %s" % [combat_levels["riot"], combat_data["riot"]])
	print("\n> Parry:")
	print("  - Punk: Nível %d - %s" % [parry_levels["punk"], parry_data["punk"]])
	print("  - Riot: Nível %d - %s" % [parry_levels["riot"], parry_data["riot"]])
	print("\n> Plataforma: Nível %d - %s" % [platform_level, platform_data])
	print("\n=======================================================================\n")

# Debug: Imprime o relatório referente ao estado atual do sistema.
func print_current_state_report() -> void:
	print("\n=================== DIFFICULTY MANAGER STATE REPORT ===================\n")
	print("> Fase atual: %s" % Phase.keys()[current_phase])
	print("\n> Combate:")
	print("  - Punk: Nível %d - %s" % [combat_levels["punk"], _get_params_string("punk", true)])
	print("  - Riot: Nível %d - %s" % [combat_levels["riot"], _get_params_string("riot", true)])
	print("\n> Parry:")
	print("  - Punk: Nível %d - %s" % [parry_levels["punk"], _get_params_string("punk", false)])
	print("  - Riot: Nível %d - %s" % [parry_levels["riot"], _get_params_string("riot", false)])
	print("\n> Plataforma: Nível %d %s" % [platform_level, _get_platform_params_string()])
	print("\n=======================================================================\n")

func _get_params_string(enemy_type: String, is_combat: bool) -> String:
	if is_combat:
		var params = get_combat_params(enemy_type)
		return ("DMG: %d | HP: %d | SPD: %d | ACC: %d" %
			[params["damage"], params["health"],
			params["speed"], params["acceleration"]])
	else:
		var params = get_parry_params(enemy_type)
		return ("ATK_SPD: %.2f | STN_SPD: %.2f | FLASH: %s" %
			[params["attack_speed"], params["stun_speed"],
			"ON" if params["flash_enabled"] else "OFF"])

func _get_platform_params_string() -> String:
	var params = get_platform_params()
	return ("\n  - H_PLT_SPD: %d | V_PLT_SPD: %.2f\n  - LASER_ON_TIME: %.2fs | LASER_OFF_TIME: %.2fs" %
		[params["h_platform_speed"], params["v_platform_speed"],
		params["laser_on_timer"], params["laser_off_timer"]])

# ============================================================================
# MÉTODO PARA GERENCIAMENTO DO SCORE DO PLAYER
# ============================================================================

func submit_player_score(level_score: int, time_spent: int) -> void:
	
	var time_score := 0
	
	match current_phase:
		Phase.PHASE_1:
			if time_spent <= 100:
				time_score = time_spent * 30
			elif time_spent > 100 and time_spent <= 150:
				time_score = time_spent * 20
			else:
				time_score = time_spent * 10
		Phase.PHASE_2:
			if time_spent <= 100:
				time_score = time_spent * 30
			elif time_spent > 100 and time_spent <= 150:
				time_score = time_spent * 20
			else:
				time_score = time_spent * 10
		Phase.PHASE_3:
			if time_spent <= 100:
				time_score = time_spent * 30
			elif time_spent > 100 and time_spent <= 150:
				time_score = time_spent * 20
			else:
				time_score = time_spent * 10
	
	total_score = level_score + time_score

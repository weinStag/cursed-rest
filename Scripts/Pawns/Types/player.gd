extends PawnMobile
signal health_changed(new_health, max_health)
signal stamina_changed(new_stamina, max_stamina)
signal souls_changed(new_souls)
signal heal_changed(heal_remaining, max_heals)

# Attack system
var is_attacking: bool = false
@export var attack_cooldown: float = 0.35
var can_attack: bool = true
var attack_cooldown_timer: float = 0.0  # Timer visual do cooldown
var attack_stamina_cost: int = 3  # Custo de stamina por ataque
var attack_dash_distance: float = 20.0  # Distância do dash no ataque

# Constants for max values
const MAX_HEALTH: int = 250
const MAX_STAMINA: int = 100

var status: Dictionary = {
	'health': 250,
	'stamina': 100,
	'vitality': 10,
	'breath': 10,
	'strength': 10,
	'agility': 10
}

# Soul counter
var souls: int = 0

# Enemy kill counter for heal rewards
var enemy_kills: int = 0
var kills_per_heal: int = 3

const MOVEMENTS: Dictionary = {
	'ui_up': Vector2i.UP,
	'ui_left': Vector2i.LEFT,
	'ui_right': Vector2i.RIGHT,
	'ui_down': Vector2i.DOWN
}

var is_dead: bool = false

# Healing System
var max_heal_uses: int = 2
var heal_uses_remaining: int = 2
var heal_amount: int = 100
var is_healing: bool = false

# Movement Related (+ animation)
var input_history: Array[String] = []
var cur_direction: Vector2i = Vector2i.DOWN
var is_sprinting: bool = false
var sprint_mult: float = 1.5
var base_speed: float = 1.5

# Roll System
var is_rolling: bool = false
var roll_distance: int = 2  # Quantas células o roll percorre
var roll_speed_mult: float = 5.0  # Multiplicador de velocidade do roll
var roll_cooldown: float = 0.5  # Tempo de cooldown entre rolls (em segundos)
var can_roll: bool = true
var roll_timer: Timer
var roll_stamina_cost: int = 15  # Custo de stamina por roll

# Stamina System
var stamina_regen_rate: float = 10.0  # Stamina por segundo
var stamina_regen_delay: float = 1.5  # Delay antes de começar a regenerar
var stamina_regen_timer: float = 0.0
var sprint_stamina_cost: float = 30.0  # Stamina por segundo ao correr

# Knockback System
var is_knockbacking: bool = false
var knockback_distance: int = 2
var knockback_speed_mult: float = 7.5
var knockback_cooldown: float = 0.25
var can_kockback: bool = true
var knockback_timer: Timer

# Detecção de tap vs hold
var roll_button_press_time: float = 0.0
var roll_tap_threshold: float = 0.15  # Tempo máximo para considerar um "tap" (em segundos)



func _ready():
	base_speed = speed
	emit_signal("health_changed", status['health'], MAX_HEALTH)
	emit_signal("stamina_changed", status['stamina'], MAX_STAMINA)
	emit_signal("souls_changed", souls)
	emit_signal("heal_changed", heal_uses_remaining, max_heal_uses)
	# Configurar timer de cooldown do roll
	roll_timer = Timer.new()
	roll_timer.one_shot = true
	roll_timer.timeout.connect(_on_roll_cooldown_finished)
	add_child(roll_timer)
	
		# timer knockback
	knockback_timer = Timer.new()
	knockback_timer.one_shot = true
	knockback_timer.timeout.connect(_on_knockback_cooldown)
	add_child(knockback_timer)

func _on_knockback_cooldown():
	can_kockback = true


func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	$SwordPivot.look_at(mouse_pos)
	
	# Atualiza o timer de cooldown do ataque
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= _delta
		if attack_cooldown_timer <= 0:
			attack_cooldown_timer = 0
	
	if Input.is_action_just_pressed("ui_mb1"):
		try_attack()
	
	# Healing system
	if Input.is_action_just_pressed("ui_heal") and can_heal():
		use_heal()
	
	# ROLL SYSTEM - PROCESSA ANTES DE TUDO
	# Captura direção ENQUANTO as teclas estão pressionadas
	var roll_input_direction: Vector2i = Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		roll_input_direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		roll_input_direction.y += 1
	if Input.is_action_pressed("ui_left"):
		roll_input_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		roll_input_direction.x += 1
	
	# Normaliza diagonal
	if roll_input_direction != Vector2i.ZERO:
		if roll_input_direction.y != 0:
			roll_input_direction.x = 0
	
	# Sistema de detecção tap vs hold para ui_roll
	if Input.is_action_just_pressed("ui_roll"):
		roll_button_press_time = 0.0
	
	if Input.is_action_pressed("ui_roll"):
		roll_button_press_time += _delta
	
	# Se soltar o botão rápido (tap), executa roll
	if Input.is_action_just_released("ui_roll"):
		if roll_button_press_time <= roll_tap_threshold and can_roll and not is_rolling and can_move():
			# Roll/dodge na direção OPOSTA de onde está olhando (backward dodge)
			var dodge_direction: Vector2i = -cur_direction
			execute_roll(dodge_direction)
			roll_button_press_time = 0.0
			return
		roll_button_press_time = 0.0
	
	# Sprint: apenas se estiver segurando por mais tempo que o threshold e tiver stamina
	is_sprinting = Input.is_action_pressed("ui_roll") and roll_button_press_time > roll_tap_threshold and status['stamina'] > 5
	
	# Não permite sprint durante o roll
	if is_rolling:
		is_sprinting = false
	
	# Consome stamina APENAS ao correr (sprint), andar é grátis
	if is_sprinting:
		consume_stamina(sprint_stamina_cost * _delta)
		# Se stamina acabar, cancela sprint
		if status['stamina'] <= 0:
			is_sprinting = false
	else:
		# Regenera stamina quando não está correndo
		regenerate_stamina(_delta)
	
	speed = base_speed * (sprint_mult if is_sprinting else 1.0)
	
	input_priority()
	
	if can_move():
		if Input.is_action_just_pressed("ui_accept"): # To Request dialogue
			Grid.request_event(self, cur_direction, 0)
		
		var input_direction: Vector2i = set_direction()
		if input_direction:
			cur_direction = input_direction
			set_anim_direction(input_direction)
			
			# Checks if the next movement opportunity is possible, if it is move to target position
			var target_position: Vector2i = Grid.request_move(self, input_direction)
			if target_position:
				move_to(target_position)

func try_attack():
	# Verificações mais rigorosas
	if not can_attack or is_rolling or is_knockbacking or is_talking:
		return
	
	# Verifica stamina suficiente
	if status['stamina'] < attack_stamina_cost:
		print("Stamina insuficiente para atacar!")
		return
	
	# Garante que qualquer tween anterior seja limpo
	if move_tween and move_tween.is_running():
		return

	is_attacking = true
	can_attack = false
	attack_cooldown_timer = attack_cooldown  # Inicia o timer visual
	
	# Consome stamina
	consume_stamina(attack_stamina_cost)
	
	# Ativa hitbox IMEDIATAMENTE
	$SwordPivot/SwordArea.monitoring = true
	
	# Calcula direção do dash em direção ao mouse
	var mouse_pos := get_global_mouse_position()
	var dash_direction := (mouse_pos - global_position).normalized()
	var target_pos := global_position + (dash_direction * attack_dash_distance)
	
	# Dash rápido em direção ao mouse
	var dash_tween := create_tween()
	dash_tween.tween_property(self, "global_position", target_pos, 0.1)
	dash_tween.set_ease(Tween.EASE_OUT)
	dash_tween.set_trans(Tween.TRANS_QUAD)

	# animação de ataque (girando espada)
	var swing_tween := create_tween()
	swing_tween.tween_property($SwordPivot, "rotation_degrees", $SwordPivot.rotation_degrees + 120, 0.2)

	swing_tween.finished.connect(_finish_attack)

func _finish_attack():
	# Desativa hitbox
	if $SwordPivot/SwordArea:
		$SwordPivot/SwordArea.monitoring = false
	
	is_attacking = false

	# cooldown do ataque usando create_timer
	get_tree().create_timer(attack_cooldown).timeout.connect(_on_attack_cooldown_finished)

func _on_attack_cooldown_finished():
	# Força o reset do estado de ataque
	is_attacking = false
	can_attack = true
	attack_cooldown_timer = 0.0  # Reseta o timer


func execute_roll(roll_direction: Vector2i):
	"""Executa o roll na direção especificada"""
	# Verifica se tem stamina suficiente
	if status['stamina'] < roll_stamina_cost:
		print("Stamina insuficiente para rolar!")
		return
	
	is_rolling = true
	can_roll = false
	
	# Consome stamina
	consume_stamina(roll_stamina_cost)
	
	# Verifica célula por célula até a distância máxima do roll
	var final_position: Vector2 = position
	var cells_moved: int = 0
	
	# Salva a posição inicial no grid
	var start_cell: Vector2i = Grid.actor_grid.local_to_map(position)
	
	for i in range(1, roll_distance + 1):
		# Calcula a próxima célula na direção do roll
		var next_cell: Vector2i = start_cell + (roll_direction * i)
		var cell_type: int = Grid.actor_grid.get_cell_source_id(next_cell)
		
		# Verifica se a célula está vazia (EMPTY = -1)
		if cell_type == Grid.EMPTY:
			final_position = Grid.actor_grid.map_to_local(next_cell)
			cells_moved = i
		else:
			break  # Para ao encontrar obstáculo
	
	# Executa o movimento do roll se conseguiu mover pelo menos 1 célula
	if cells_moved > 0:
		# Atualiza o grid: limpa posição antiga e marca nova
		var final_cell: Vector2i = Grid.actor_grid.local_to_map(final_position)
		Grid.actor_grid.set_cell(start_cell, Grid.EMPTY, Vector2i.ZERO)
		Grid.actor_grid.set_cell(final_cell, type, Vector2i.ZERO)
		
		# Animação de roll
		set_anim_direction(roll_direction)
		
		roll_to(final_position)
	else:
		# Se não conseguiu rolar, cancela o roll
		finish_roll()

func roll_to(target: Vector2):
	"""Move o player para a posição alvo com velocidade de roll"""
	is_moving = true
	
	var roll_duration: float = (walk_anim_length / base_speed) / roll_speed_mult
	
	move_tween = create_tween()
	move_tween.tween_property(self, "position", target, roll_duration)
	move_tween.finished.connect(_on_roll_finished)

func _on_roll_finished():
	"""Callback quando o roll termina"""
	move_tween.kill()
	finish_roll()

func finish_roll():
	"""Finaliza o estado de roll"""
	is_rolling = false
	is_moving = false
	
	# Inicia cooldown do roll
	roll_timer.start(roll_cooldown)
	
	# Verifica eventos na posição final
	Grid.request_event(self, Vector2i.ZERO, 2)

func _on_roll_cooldown_finished():
	"""Callback quando o cooldown do roll termina"""
	can_roll = true

func can_move() -> bool:
	"""Verifica se o player pode se mover (não está em roll)"""
	return not is_moving and not is_talking and not is_rolling

func input_priority():
	# Input priority system, prioritize the latest inputs
	for direction in MOVEMENTS.keys():
		if Input.is_action_just_released(direction):
			var index: int = input_history.find(direction)
			if index != -1:
				input_history.remove_at(index)
		
		if Input.is_action_just_pressed(direction):
			input_history.append(direction)

func set_direction() -> Vector2i:
	var direction := Vector2i.ZERO
	
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		direction.x += 1

	return Vector2i(round(direction.x), round(direction.y))



func _move_tween_done():
	move_tween.kill()
	switch_walk = !switch_walk
	Grid.request_event(self, Vector2i.ZERO, 2) # Check if there's an event
	is_moving = false

func set_talking(talk_state: bool):
	is_talking = !talk_state
	if is_talking: 
		input_history.clear()
		# Cancela roll se começar a falar
		if is_rolling:
			is_rolling = false

# Função auxiliar para debug/animações
func get_direction_name() -> String:
	match cur_direction:
		Vector2i.UP: return "up"
		Vector2i.DOWN: return "down"
		Vector2i.LEFT: return "left"
		Vector2i.RIGHT: return "right"
		_: return "down"

func receive_damage(amount: int, attacker: Node2D):
	if attacker == null:
		return
	
	# Cancela ataque em andamento se estiver atacando
	if is_attacking:
		is_attacking = false
		if $SwordPivot/SwordArea:
			$SwordPivot/SwordArea.monitoring = false
	
	# Apenas reseta o cooldown, não força can_attack imediatamente
	# O cooldown vai terminar naturalmente e permitir ataques
	if attack_cooldown_timer > 0:
		attack_cooldown_timer = min(attack_cooldown_timer, 0.2)
	
	var new_health := calc_damage(amount)
	# Garante que a vida não fique negativa
	if new_health < 0:
		new_health = 0 
	print(new_health)
	status["health"] = new_health
	emit_signal("health_changed", new_health, MAX_HEALTH)
	if new_health > 0:
		apply_knockback(attacker)
	else:
		get_tree().call_deferred("change_scene_to_file", "res://game_over.tscn")

func die():
	print("Player morreu!")
	get_tree().change_scene_to_file("res://game_over.tscn")
	# Desabilita movimento
	#is_talking = true
	#is_rolling = false
	#is_moving = false
	#is_dead = true
	# Aqui você pode chamar animação, respawn, tela game over, etc.


func calc_damage(damage) -> int:
	var current_life = status.get('health')
	var current_vitality = status.get('vitality')
	var new_health = current_life + current_vitality - damage
	return new_health

func apply_knockback(attacker: Node2D):
	if not can_kockback or is_knockbacking or is_rolling:
		return

	# calcula direção cardinal do impacto
	var diff := global_position - attacker.global_position
	var dir := Vector2i.ZERO

	if diff == Vector2.ZERO:
		dir = -cur_direction
	else:
		if abs(diff.x) > abs(diff.y):
			dir = Vector2i(sign(diff.x), 0)
		else:
			dir = Vector2i(0, sign(diff.y))

	# distância depende do atacante (Enemy ou Boss)
	var force := knockback_distance
	if "knockback_distance" in attacker:
		force = attacker.knockback_distance

	is_knockbacking = true
	can_kockback = false

	var last_valid := position
	for i in range(force):
		var next = Grid.request_move(self, dir)
		if next:
			last_valid = next
		else:
			break

	_knockback_to(last_valid)


func _knockback_to(target: Vector2):
	is_moving = true

	var duration = (walk_anim_length / base_speed) / knockback_speed_mult

	move_tween = create_tween()
	move_tween.tween_property(self, "position", target, duration)
	move_tween.finished.connect(_on_knockback_done)

func _on_knockback_done():
	move_tween.kill()
	_finish_knockback()

func _finish_knockback():
	is_knockbacking = false
	is_moving = false

	knockback_timer.start(knockback_cooldown)

	Grid.request_event(self, Vector2i.ZERO, 2)

func deal_damage(target: Node2D, amount: int):
	if target == null:
		return

	if target.has_method("receive_damage"):
		target.receive_damage(amount, self)

func _on_area_2d_area_entered(area: Area2D):
	var attacker := area.get_parent()
	if not attacker:
		return

	if area.is_in_group("hitbox"):
		receive_damage(25, attacker)
		return

	if area.is_in_group("hitbox_boss"):
		receive_damage(50, attacker)
		return


func _on_sword_area_area_entered(area):
	print("acertou:", area.name)
	var enemy = area.get_parent()
	if enemy.is_in_group("enemy"):
		# Conecta ao sinal de morte do inimigo para ganhar almas
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
		deal_damage(enemy, 10)
	elif enemy.is_in_group("boss"):
		# Boss também dá almas (mais)
		if not enemy.died.is_connected(_on_boss_died):
			enemy.died.connect(_on_boss_died)
		deal_damage(enemy, 5)

func _on_enemy_died(_enemy: Node2D):
	"""Callback quando um inimigo morre - adiciona almas aleatórias"""
	var soul_amount: int = randi_range(50, 100)
	add_souls(soul_amount)
	
	# Incrementa contador de kills e verifica se deve dar heal
	enemy_kills += 1
	if enemy_kills >= kills_per_heal:
		enemy_kills = 0
		grant_heal()
		print("3 inimigos derrotados! Heal concedido!")

func _on_boss_died(_boss: Node2D):
	"""Callback quando um boss morre - adiciona mais almas"""
	var soul_amount: int = randi_range(200, 300)
	add_souls(soul_amount)

func can_heal() -> bool:
	"""Verifica se o player pode usar heal"""
	return heal_uses_remaining > 0 and not is_healing and not is_moving and not is_rolling and not is_attacking and not is_knockbacking

func use_heal():
	"""Usa uma carga de heal"""
	if not can_heal():
		return
	
	is_healing = true
	heal_uses_remaining -= 1
	
	# Cura o player
	var new_health: int = min(status['health'] + heal_amount, MAX_HEALTH)
	status['health'] = new_health
	
	# Emite sinais para atualizar HUD
	emit_signal("health_changed", new_health, MAX_HEALTH)
	emit_signal("heal_changed", heal_uses_remaining, max_heal_uses)
	
	print("Heal usado! Vida: ", new_health, "/", MAX_HEALTH, " - Heals restantes: ", heal_uses_remaining)
	
	# Animação de heal (pequeno delay)
	await get_tree().create_timer(0.5).timeout
	is_healing = false

func consume_stamina(amount: float):
	"""Consome stamina e atualiza a UI"""
	status['stamina'] = max(0, status['stamina'] - amount)
	emit_signal("stamina_changed", status['stamina'], MAX_STAMINA)
	stamina_regen_timer = stamina_regen_delay  # Reseta o timer de regeneração

func regenerate_stamina(delta: float):
	"""Regenera stamina ao longo do tempo"""
	if status['stamina'] >= MAX_STAMINA:
		return
	
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
		return
	
	var regen_amount := stamina_regen_rate * delta
	status['stamina'] = min(MAX_STAMINA, status['stamina'] + regen_amount)
	emit_signal("stamina_changed", status['stamina'], MAX_STAMINA)

func add_souls(amount: int):
	"""Adiciona almas ao contador"""
	souls += amount
	emit_signal("souls_changed", souls)
	print("Almas coletadas: +", amount, " | Total: ", souls)

func grant_heal():
	"""Concede um heal extra ao jogador"""
	if heal_uses_remaining < max_heal_uses:
		heal_uses_remaining += 1
		emit_signal("heal_changed", heal_uses_remaining, max_heal_uses)
		print("Heal extra concedido! Total: ", heal_uses_remaining, "/", max_heal_uses)
	else:
		print("Heals já estão no máximo!")
		
